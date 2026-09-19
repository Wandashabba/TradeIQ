import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { issueToken } from '../auth/auth.service';

describe('tasks routes', () => {
  let clientId: string;
  let otherClientId: string;
  let agentId: string;
  let agentToken: string;
  let managerToken: string;
  let otherToken: string;
  let outletId: string;
  let visitId: string;
  let otherTaskId: string;
  let taskId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'Tasks Test Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: { email: 'tasks-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentId = agent.id;
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });
    const manager = await prisma.user.create({
      data: { email: 'tasks-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'Tasks Outlet',
        code: 'TASKS-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId,
      },
    });
    outletId = outlet.id;
    const visit = await prisma.visit.create({
      data: {
        outletId: outlet.id,
        agentId: agent.id,
        clientId,
        checkinTs: new Date(),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'in_progress',
      },
    });
    visitId = visit.id;

    // A second tenant with its own task, to prove list/patch scoping.
    const otherClient = await prisma.client.create({
      data: { name: 'Tasks Other Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = otherClient.id;
    const otherUser = await prisma.user.create({
      data: {
        email: 'tasks-other-agent@example.com',
        passwordHash: 'x',
        role: 'field_agent',
        clientId: otherClientId,
      },
    });
    otherToken = issueToken({ userId: otherUser.id, role: 'field_agent', clientId: otherClientId });
    const otherOutlet = await prisma.outlet.create({
      data: {
        name: 'Tasks Other Outlet',
        code: 'TASKS-002',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't2',
        clientId: otherClientId,
      },
    });
    const otherTask = await prisma.task.create({
      data: {
        findingType: 'stockout',
        outletId: otherOutlet.id,
        requiredFix: 'Restock',
        priority: 'normal',
        slaDueAt: new Date(),
        ownerId: otherUser.id,
      },
    });
    otherTaskId = otherTask.id;
  });

  afterAll(async () => {
    await prisma.task.deleteMany({ where: { outlet: { clientId: { in: [clientId, otherClientId] } } } });
    await prisma.photo.deleteMany({ where: { visit: { clientId } } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.user.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.client.deleteMany({ where: { id: { in: [clientId, otherClientId] } } });
    await prisma.$disconnect();
  });

  const validBody = () => ({
    outletId,
    findingType: 'planogram_breach',
    requiredFix: 'Rebuild the end cap to planogram',
    priority: 'high',
    visitId,
  });

  const hoursFromNow = (iso: string) => (new Date(iso).getTime() - Date.now()) / 3_600_000;

  it('creates a task with a computed SLA due date (201)', async () => {
    const res = await request(app)
      .post('/tasks')
      .set('Authorization', `Bearer ${agentToken}`)
      .send(validBody());

    expect(res.status).toBe(201);
    expect(res.body.findingType).toBe('planogram_breach');
    expect(res.body.status).toBe('open');
    expect(res.body.ownerId).toBe(agentId); // defaults to the caller
    expect(hoursFromNow(res.body.slaDueAt)).toBeCloseTo(72, 1); // high = +72h
    taskId = res.body.id;
  });

  it('rejects an invalid priority with 400', async () => {
    const res = await request(app)
      .post('/tasks')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ ...validBody(), priority: 'urgent' });
    expect(res.status).toBe(400);
  });

  it("returns 404 when creating against another client's outlet", async () => {
    const res = await request(app)
      .post('/tasks')
      .set('Authorization', `Bearer ${otherToken}`)
      .send(validBody());
    expect(res.status).toBe(404);
  });

  it("lists only the caller's client tasks, ordered by SLA", async () => {
    const res = await request(app).get('/tasks').set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    const ids = res.body.data.map((t: { id: string }) => t.id);
    expect(ids).toContain(taskId);
    expect(ids).not.toContain(otherTaskId);
    const dueDates = res.body.data.map((t: { slaDueAt: string }) => new Date(t.slaDueAt).getTime());
    expect(dueDates).toEqual([...dueDates].sort((a: number, b: number) => a - b));
  });

  it('filters the list by status', async () => {
    const res = await request(app)
      .get('/tasks')
      .query({ status: 'closed' })
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(200);
    expect(res.body.data.map((t: { id: string }) => t.id)).not.toContain(taskId);

    const openRes = await request(app)
      .get('/tasks')
      .query({ status: 'open' })
      .set('Authorization', `Bearer ${managerToken}`);
    expect(openRes.status).toBe(200);
    expect(openRes.body.data.map((t: { id: string }) => t.id)).toContain(taskId);
  });

  it('rejects a garbage status filter with 400', async () => {
    const res = await request(app)
      .get('/tasks')
      .query({ status: 'bogus' })
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(400);
  });

  it('moves a task open → in_progress (200)', async () => {
    const res = await request(app)
      .patch(`/tasks/${taskId}`)
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ status: 'in_progress' });
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('in_progress');
  });

  it('refuses to close a task without a closure photo (400)', async () => {
    const res = await request(app)
      .patch(`/tasks/${taskId}`)
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ status: 'closed' });
    expect(res.status).toBe(400);

    const row = await prisma.task.findUnique({ where: { id: taskId } });
    expect(row?.status).toBe('in_progress');
  });

  it('refuses to close with a closurePhotoUrl that has no uploaded photo (400)', async () => {
    const res = await request(app)
      .patch(`/tasks/${taskId}`)
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ status: 'closed', closurePhotoUrl: 'data:image/jpeg;base64,no-such-photo' });
    expect(res.status).toBe(400);

    const row = await prisma.task.findUnique({ where: { id: taskId } });
    expect(row?.status).toBe('in_progress');
  });

  it('closes a task when a matching uploaded photo backs the closure url (200)', async () => {
    const closureUrl = 'data:image/jpeg;base64,/9j/closure-photo';
    await prisma.photo.create({
      data: {
        visitId,
        section: 'task_closure',
        url: closureUrl,
        gpsTag: { lat: -26.2041, lng: 28.0473 },
        timestamp: new Date(),
      },
    });

    const res = await request(app)
      .patch(`/tasks/${taskId}`)
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ status: 'closed', closurePhotoUrl: closureUrl });
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('closed');
    expect(res.body.closurePhotoUrl).toBe(closureUrl);
  });

  it('forbids a field agent from setting closureVerified (403)', async () => {
    const res = await request(app)
      .patch(`/tasks/${taskId}`)
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ closureVerified: true });
    expect(res.status).toBe(403);
  });

  it('lets a manager set closureVerified (200)', async () => {
    const res = await request(app)
      .patch(`/tasks/${taskId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ closureVerified: true });
    expect(res.status).toBe(200);
    expect(res.body.closureVerified).toBe(true);
  });

  it("returns 404 when patching another client's task", async () => {
    const res = await request(app)
      .patch(`/tasks/${taskId}`)
      .set('Authorization', `Bearer ${otherToken}`)
      .send({ status: 'in_progress' });
    expect(res.status).toBe(404);
  });

  it('rejects an empty patch body with 400', async () => {
    const res = await request(app)
      .patch(`/tasks/${taskId}`)
      .set('Authorization', `Bearer ${agentToken}`)
      .send({});
    expect(res.status).toBe(400);
  });

  it('rejects requests without a bearer token', async () => {
    const created = await request(app).post('/tasks').send(validBody());
    expect(created.status).toBe(401);
    const listed = await request(app).get('/tasks');
    expect(listed.status).toBe(401);
    const patched = await request(app).patch(`/tasks/${taskId}`).send({ status: 'open' });
    expect(patched.status).toBe(401);
  });

  describe('GET /tasks evidencePhotoId', () => {
    let newestPhotoId: string;
    let taskWithPhotosId: string;
    let taskWithoutVisitId: string;
    let taskPhotolessVisitId: string;

    const makeVisit = () =>
      prisma.visit.create({
        data: {
          outletId,
          agentId,
          clientId,
          checkinTs: new Date(),
          checkinLat: -26.2041,
          checkinLng: 28.0473,
          geofencePass: true,
          status: 'in_progress',
        },
      });

    beforeAll(async () => {
      const visitWithPhotos = await makeVisit();
      const photolessVisit = await makeVisit();

      await prisma.photo.create({
        data: {
          visitId: visitWithPhotos.id,
          section: 'visibility',
          url: 'data:image/jpeg;base64,older-photo',
          gpsTag: {},
          timestamp: new Date(),
          createdAt: new Date('2026-07-20T00:00:00.000Z'),
        },
      });
      const newer = await prisma.photo.create({
        data: {
          visitId: visitWithPhotos.id,
          section: 'visibility',
          url: 'data:image/jpeg;base64,newer-photo',
          gpsTag: {},
          timestamp: new Date(),
          createdAt: new Date('2026-07-21T00:00:00.000Z'),
        },
      });
      newestPhotoId = newer.id;

      const makeTask = (forVisitId?: string) =>
        prisma.task.create({
          data: {
            visitId: forVisitId,
            findingType: 'stockout',
            outletId,
            requiredFix: 'Restock',
            priority: 'normal',
            slaDueAt: new Date(),
            ownerId: agentId,
          },
        });
      taskWithPhotosId = (await makeTask(visitWithPhotos.id)).id;
      taskWithoutVisitId = (await makeTask()).id;
      taskPhotolessVisitId = (await makeTask(photolessVisit.id)).id;
    });

    it("lists the newest photo of a task's visit as evidencePhotoId", async () => {
      const res = await request(app)
        .get('/tasks')
        .query({ limit: 200 })
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);

      const row = res.body.data.find((t: { id: string }) => t.id === taskWithPhotosId);
      expect(row).toBeDefined();
      expect(row.evidencePhotoId).toBe(newestPhotoId);
    });

    it('lists null evidencePhotoId for tasks without a visit and for photoless visits', async () => {
      const res = await request(app)
        .get('/tasks')
        .query({ limit: 200 })
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);

      const noVisit = res.body.data.find((t: { id: string }) => t.id === taskWithoutVisitId);
      expect(noVisit).toBeDefined();
      expect(noVisit.evidencePhotoId).toBeNull();

      const photoless = res.body.data.find((t: { id: string }) => t.id === taskPhotolessVisitId);
      expect(photoless).toBeDefined();
      expect(photoless.evidencePhotoId).toBeNull();
    });
  });

  describe('GET /tasks pagination', () => {
    let pagedOutletId: string;
    const pagedTaskIds: string[] = [];
    const PAGE_SEED_COUNT = 25;

    beforeAll(async () => {
      // A fresh outlet keeps this describe block's row count independent of
      // whatever earlier tests in this file created.
      const outlet = await prisma.outlet.create({
        data: {
          name: 'Tasks Paging Outlet',
          code: 'TASKS-PAGE-001',
          channelType: 'hypermarket',
          lat: -26.2041,
          lng: 28.0473,
          territoryId: 't-page',
          clientId,
        },
      });
      pagedOutletId = outlet.id;

      // Distinct slaDueAt per row so ordering is unambiguous, plus enough rows
      // to require three pages at limit=10 (25 rows / 10 = 3 pages).
      for (let i = 0; i < PAGE_SEED_COUNT; i++) {
        const task = await prisma.task.create({
          data: {
            findingType: `paging-task-${i}`,
            outletId: pagedOutletId,
            requiredFix: 'Restock',
            priority: 'normal',
            slaDueAt: new Date(Date.UTC(2027, 0, 1, 0, 0, i)),
            ownerId: agentId,
          },
        });
        pagedTaskIds.push(task.id);
      }
    });

    it('default page size caps the result at 50', async () => {
      const res = await request(app)
        .get('/tasks')
        .query({ outletId: pagedOutletId })
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      expect(res.body.data.length).toBeLessThanOrEqual(50);
      expect(res.body.data).toHaveLength(PAGE_SEED_COUNT); // fewer than 50 seeded
    });

    it('honours ?limit=N', async () => {
      const res = await request(app)
        .get('/tasks')
        .query({ outletId: pagedOutletId, limit: 5 })
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(5);
      expect(res.body.nextCursor).not.toBeNull();
    });

    it('says how many tasks the filter matches, not how many are on the page', async () => {
      const cut = await request(app)
        .get('/tasks')
        .query({ outletId: pagedOutletId, limit: 5 })
        .set('Authorization', `Bearer ${managerToken}`);
      expect(cut.status).toBe(200);
      expect(cut.body.data).toHaveLength(5);
      expect(cut.body.total).toBe(PAGE_SEED_COUNT);

      const whole = await request(app)
        .get('/tasks')
        .query({ outletId: pagedOutletId })
        .set('Authorization', `Bearer ${managerToken}`);
      expect(whole.body.nextCursor).toBeNull();
      expect(whole.body.total).toBe(PAGE_SEED_COUNT);
    });

    it.each([['0'], ['abc'], ['-1']])('rejects ?limit=%s with 400', async (limit) => {
      const res = await request(app)
        .get('/tasks')
        .query({ outletId: pagedOutletId, limit })
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(400);
    });

    it('pages through with no gap and no overlap across the full set', async () => {
      const seen: string[] = [];
      let cursor: string | undefined;
      let guard = 0;

      do {
        const res: request.Response = await request(app)
          .get('/tasks')
          .query({
            outletId: pagedOutletId,
            limit: 10,
            ...(cursor ? { cursor } : {}),
          })
          .set('Authorization', `Bearer ${managerToken}`);
        expect(res.status).toBe(200);
        seen.push(...res.body.data.map((t: { id: string }) => t.id));
        cursor = res.body.nextCursor ?? undefined;
        guard++;
      } while (cursor && guard < 10);

      // No overlap: every id appears exactly once across all pages.
      expect(new Set(seen).size).toBe(seen.length);
      // No gap: every seeded id for this outlet was eventually returned.
      expect(new Set(seen)).toEqual(new Set(pagedTaskIds));
    });

    it("never returns another client's tasks even across pages", async () => {
      const res = await request(app)
        .get('/tasks')
        .query({ limit: 200 })
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      const ids = res.body.data.map((t: { id: string }) => t.id);
      expect(ids).not.toContain(otherTaskId);
    });
  });
});

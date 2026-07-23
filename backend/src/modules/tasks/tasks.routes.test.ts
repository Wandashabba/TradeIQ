import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
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

  describe('GET /tasks pagination', () => {
    beforeAll(async () => {
      await prisma.task.createMany({
        data: [0, 1, 2].map((i) => ({
          findingType: `page-task-${i}`,
          outletId,
          requiredFix: 'Restock',
          priority: 'normal',
          slaDueAt: new Date(`2026-08-1${i}T00:00:00.000Z`),
          ownerId: agentId,
        })),
      });
    });

    it('returns an envelope with data and nextCursor, oldest SLA first', async () => {
      const res = await request(app).get('/tasks').set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body).toHaveProperty('nextCursor');
      const types = res.body.data.map((t: { findingType: string }) => t.findingType);
      expect(types.indexOf('page-task-0')).toBeLessThan(types.indexOf('page-task-2'));
    });

    it('caps the page at limit and returns a cursor to the next page', async () => {
      const first = await request(app)
        .get('/tasks?limit=2')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(first.status).toBe(200);
      expect(first.body.data).toHaveLength(2);
      expect(first.body.nextCursor).not.toBeNull();

      const second = await request(app)
        .get(`/tasks?limit=2&cursor=${first.body.nextCursor}`)
        .set('Authorization', `Bearer ${managerToken}`);
      expect(second.status).toBe(200);
      const firstIds = first.body.data.map((t: { id: string }) => t.id);
      const secondIds = second.body.data.map((t: { id: string }) => t.id);
      expect(secondIds.some((id: string) => firstIds.includes(id))).toBe(false);
    });

    it('clamps limit above the max to 200', async () => {
      const res = await request(app)
        .get('/tasks?limit=9999')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
    });

    it('rejects a non-positive limit with 400', async () => {
      const res = await request(app)
        .get('/tasks?limit=0')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(400);
    });
  });
});

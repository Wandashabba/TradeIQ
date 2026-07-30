import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { issueToken } from '../auth/auth.service';

describe('beatplans routes', () => {
  let clientId: string;
  let clientBId: string;

  let managerToken: string; // manager in client A
  let tokenA: string; // field agent A (owns planA)
  let tokenB: string; // a second field agent in client A (owns planB)

  let agentAId: string;
  let agentBId: string;

  let outlet1Id: string;
  let outlet2Id: string;

  let planAId: string; // agentA, 2 stops
  let planBId: string; // agentB, 1 stop
  let clientBPlanId: string; // isolation

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'BEAT-Client-A', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const manager = await prisma.user.create({
      data: {
        email: 'BEAT-manager-a@example.com',
        passwordHash: 'unused-in-this-test',
        role: 'manager',
        clientId,
      },
    });
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });

    const agentA = await prisma.user.create({
      data: {
        email: 'BEAT-agent-a@example.com',
        passwordHash: 'unused-in-this-test',
        role: 'field_agent',
        clientId,
      },
    });
    agentAId = agentA.id;
    tokenA = issueToken({ userId: agentA.id, role: 'field_agent', clientId });

    const agentB = await prisma.user.create({
      data: {
        email: 'BEAT-agent-b@example.com',
        passwordHash: 'unused-in-this-test',
        role: 'field_agent',
        clientId,
      },
    });
    agentBId = agentB.id;
    tokenB = issueToken({ userId: agentB.id, role: 'field_agent', clientId });

    const outlet1 = await prisma.outlet.create({
      data: {
        name: 'BEAT-Outlet-1',
        code: 'BEAT-OUT-1',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'BEAT-territory-1',
        clientId,
      },
    });
    outlet1Id = outlet1.id;

    const outlet2 = await prisma.outlet.create({
      data: {
        name: 'BEAT-Outlet-2',
        code: 'BEAT-OUT-2',
        channelType: 'hypermarket',
        lat: -26.2051,
        lng: 28.0483,
        territoryId: 'BEAT-territory-1',
        clientId,
      },
    });
    outlet2Id = outlet2.id;

    // planA: agentA, two ordered stops, none visited yet.
    const planA = await prisma.beatPlan.create({
      data: {
        clientId,
        agentId: agentAId,
        name: 'BEAT-Plan-A',
        scheduledDate: new Date('2026-07-02T00:00:00.000Z'),
        stops: {
          create: [
            { outletId: outlet1Id, sequence: 1 },
            { outletId: outlet2Id, sequence: 2 },
          ],
        },
      },
    });
    planAId = planA.id;

    // planB: agentB, single stop.
    const planB = await prisma.beatPlan.create({
      data: {
        clientId,
        agentId: agentBId,
        name: 'BEAT-Plan-B',
        scheduledDate: new Date('2026-07-03T00:00:00.000Z'),
        stops: { create: [{ outletId: outlet1Id, sequence: 1 }] },
      },
    });
    planBId = planB.id;

    // A separate client whose plans must never leak across the tenant boundary.
    const clientB = await prisma.client.create({
      data: { name: 'BEAT-Client-B', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientBId = clientB.id;

    const agentC = await prisma.user.create({
      data: {
        email: 'BEAT-agent-c@example.com',
        passwordHash: 'unused-in-this-test',
        role: 'field_agent',
        clientId: clientBId,
      },
    });

    const outletB = await prisma.outlet.create({
      data: {
        name: 'BEAT-Outlet-B',
        code: 'BEAT-OUT-B',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'BEAT-territory-b',
        clientId: clientBId,
      },
    });

    const clientBPlan = await prisma.beatPlan.create({
      data: {
        clientId: clientBId,
        agentId: agentC.id,
        name: 'BEAT-Plan-ClientB',
        scheduledDate: new Date('2026-07-04T00:00:00.000Z'),
        stops: { create: [{ outletId: outletB.id, sequence: 1 }] },
      },
    });
    clientBPlanId = clientBPlan.id;
  });

  afterAll(async () => {
    // Children before parents.
    await prisma.beatPlanStop.deleteMany({ where: { beatPlan: { clientId } } });
    await prisma.beatPlan.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });

    await prisma.beatPlanStop.deleteMany({ where: { beatPlan: { clientId: clientBId } } });
    await prisma.beatPlan.deleteMany({ where: { clientId: clientBId } });
    await prisma.outlet.deleteMany({ where: { clientId: clientBId } });
    await prisma.user.deleteMany({ where: { clientId: clientBId } });
    await prisma.client.delete({ where: { id: clientBId } });

    await prisma.$disconnect();
  });

  describe('POST /beatplans', () => {
    it('creates a beat plan with 1-based sequenced stops (201)', async () => {
      // Order matters: stops must be sequenced by array index, not outlet order.
      const res = await request(app)
        .post('/beatplans')
        .set('Authorization', `Bearer ${managerToken}`)
        .send({
          agentId: agentAId,
          name: 'BEAT-Created-Plan',
          scheduledDate: '2026-07-05T00:00:00.000Z',
          outletIds: [outlet2Id, outlet1Id],
        });

      expect(res.status).toBe(201);
      expect(res.body.agentId).toBe(agentAId);
      expect(res.body.status).toBe('planned');
      expect(Array.isArray(res.body.stops)).toBe(true);
      expect(res.body.stops).toHaveLength(2);
      expect(res.body.stops[0].sequence).toBe(1);
      expect(res.body.stops[0].outletId).toBe(outlet2Id);
      expect(res.body.stops[0].visited).toBe(false);
      expect(res.body.stops[1].sequence).toBe(2);
      expect(res.body.stops[1].outletId).toBe(outlet1Id);
    });

    it('returns 404 when the agent belongs to another client', async () => {
      const clientBAgent = await prisma.user.findFirst({ where: { clientId: clientBId } });
      const res = await request(app)
        .post('/beatplans')
        .set('Authorization', `Bearer ${managerToken}`)
        .send({
          agentId: clientBAgent!.id,
          name: 'BEAT-Cross-Agent',
          scheduledDate: '2026-07-05T00:00:00.000Z',
          outletIds: [outlet1Id],
        });

      expect(res.status).toBe(404);
    });

    it('returns 404 when an outlet belongs to another client', async () => {
      const clientBOutlet = await prisma.outlet.findFirst({ where: { clientId: clientBId } });
      const res = await request(app)
        .post('/beatplans')
        .set('Authorization', `Bearer ${managerToken}`)
        .send({
          agentId: agentAId,
          name: 'BEAT-Cross-Outlet',
          scheduledDate: '2026-07-05T00:00:00.000Z',
          outletIds: [outlet1Id, clientBOutlet!.id],
        });

      expect(res.status).toBe(404);
    });

    it('rejects an empty outletIds array with 400', async () => {
      const res = await request(app)
        .post('/beatplans')
        .set('Authorization', `Bearer ${managerToken}`)
        .send({
          agentId: agentAId,
          name: 'BEAT-Empty',
          scheduledDate: '2026-07-05T00:00:00.000Z',
          outletIds: [],
        });

      expect(res.status).toBe(400);
    });

    it('forbids a field agent from creating a plan with 403', async () => {
      const res = await request(app)
        .post('/beatplans')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({
          agentId: agentAId,
          name: 'BEAT-Forbidden',
          scheduledDate: '2026-07-05T00:00:00.000Z',
          outletIds: [outlet1Id],
        });

      expect(res.status).toBe(403);
    });

    it('rejects requests without a bearer token', async () => {
      const res = await request(app)
        .post('/beatplans')
        .send({
          agentId: agentAId,
          name: 'BEAT-Unauthed',
          scheduledDate: '2026-07-05T00:00:00.000Z',
          outletIds: [outlet1Id],
        });

      expect(res.status).toBe(401);
    });
  });

  describe('GET /beatplans', () => {
    it('returns the owning field agent only their own plans', async () => {
      const res = await request(app).get('/beatplans').set('Authorization', `Bearer ${tokenA}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
      const ids = res.body.data.map((p: { id: string }) => p.id);
      expect(ids).toContain(planAId);
      expect(ids).not.toContain(planBId);
      expect(res.body.data.every((p: { agentId: string }) => p.agentId === agentAId)).toBe(true);
    });

    it('returns all of the client plans to a manager', async () => {
      const res = await request(app)
        .get('/beatplans')
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(200);
      const ids = res.body.data.map((p: { id: string }) => p.id);
      expect(ids).toContain(planAId);
      expect(ids).toContain(planBId);
    });

    it('does not leak plans from another client (cross-tenant isolation)', async () => {
      const managerRes = await request(app)
        .get('/beatplans')
        .set('Authorization', `Bearer ${managerToken}`);

      expect(managerRes.status).toBe(200);
      const ids = managerRes.body.data.map((p: { id: string }) => p.id);
      expect(ids).not.toContain(clientBPlanId);
      expect(managerRes.body.data.every((p: { clientId: string }) => p.clientId === clientId)).toBe(
        true,
      );
    });

    it('filters by status', async () => {
      const res = await request(app)
        .get('/beatplans?status=planned')
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.every((p: { status: string }) => p.status === 'planned')).toBe(true);
    });

    it('rejects an invalid status filter with 400', async () => {
      const res = await request(app)
        .get('/beatplans?status=bogus')
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(400);
    });

    it('rejects requests without a bearer token', async () => {
      const res = await request(app).get('/beatplans');
      expect(res.status).toBe(401);
    });

    describe('GET /beatplans pagination', () => {
      beforeAll(async () => {
        await prisma.beatPlan.createMany({
          data: [0, 1, 2].map((i) => ({
            clientId,
            agentId: agentAId,
            name: `page-plan-${i}`,
            status: 'planned',
            scheduledDate: new Date(`2026-08-1${i}T00:00:00.000Z`),
          })),
        });
      });

      it('returns an envelope with data and nextCursor, latest first', async () => {
        const res = await request(app)
          .get('/beatplans')
          .set('Authorization', `Bearer ${managerToken}`);
        expect(res.status).toBe(200);
        expect(Array.isArray(res.body.data)).toBe(true);
        expect(res.body).toHaveProperty('nextCursor');
        const names = res.body.data.map((p: { name: string }) => p.name);
        expect(names.indexOf('page-plan-2')).toBeLessThan(names.indexOf('page-plan-0'));
      });

      it('caps the page at limit and returns a cursor to the next page', async () => {
        const first = await request(app)
          .get('/beatplans?limit=2')
          .set('Authorization', `Bearer ${managerToken}`);
        expect(first.status).toBe(200);
        expect(first.body.data).toHaveLength(2);
        expect(first.body.nextCursor).not.toBeNull();

        const second = await request(app)
          .get(`/beatplans?limit=2&cursor=${first.body.nextCursor}`)
          .set('Authorization', `Bearer ${managerToken}`);
        expect(second.status).toBe(200);
        const firstIds = first.body.data.map((p: { id: string }) => p.id);
        const secondIds = second.body.data.map((p: { id: string }) => p.id);
        expect(secondIds.some((id: string) => firstIds.includes(id))).toBe(false);
      });

      it('clamps limit above the max to 200', async () => {
        const res = await request(app)
          .get('/beatplans?limit=9999')
          .set('Authorization', `Bearer ${managerToken}`);
        expect(res.status).toBe(200);
        expect(Array.isArray(res.body.data)).toBe(true);
      });

      it('rejects a non-positive limit with 400', async () => {
        const res = await request(app)
          .get('/beatplans?limit=0')
          .set('Authorization', `Bearer ${managerToken}`);
        expect(res.status).toBe(400);
      });
    });
  });

  describe('GET /beatplans/:id', () => {
    it('returns a plan with ordered stops and zero-visited adherence', async () => {
      const res = await request(app)
        .get(`/beatplans/${planAId}`)
        .set('Authorization', `Bearer ${tokenA}`);

      expect(res.status).toBe(200);
      expect(res.body.stops.map((s: { sequence: number }) => s.sequence)).toEqual([1, 2]);
      expect(res.body.adherence.stopsTotal).toBe(2);
      expect(res.body.adherence.stopsVisited).toBe(0);
      expect(res.body.adherence.adherenceRate).toBe(0);
    });

    it('rounds a fractional adherence rate to 2dp (2 of 3 visited → 66.67)', async () => {
      // A 2/3 ratio is the classic repeating decimal; adherenceRate must be
      // rounded like every other rate rather than emitting 66.66666666666667.
      const plan = await prisma.beatPlan.create({
        data: {
          clientId,
          agentId: agentAId,
          name: 'BEAT-Plan-Rounding',
          scheduledDate: new Date('2026-07-06T00:00:00.000Z'),
          stops: {
            create: [
              { outletId: outlet1Id, sequence: 1, visited: true },
              { outletId: outlet2Id, sequence: 2, visited: true },
              { outletId: outlet1Id, sequence: 3, visited: false },
            ],
          },
        },
      });

      const res = await request(app)
        .get(`/beatplans/${plan.id}`)
        .set('Authorization', `Bearer ${tokenA}`);

      expect(res.status).toBe(200);
      expect(res.body.adherence.stopsTotal).toBe(3);
      expect(res.body.adherence.stopsVisited).toBe(2);
      expect(res.body.adherence.adherenceRate).toBe(66.67);
    });

    it('returns 404 to a field agent reading another agent plan', async () => {
      const res = await request(app)
        .get(`/beatplans/${planAId}`)
        .set('Authorization', `Bearer ${tokenB}`);

      expect(res.status).toBe(404);
    });
  });

  describe('PATCH /beatplans/:id/stops/:stopId', () => {
    it('marks a stop visited and adherence reflects it', async () => {
      const planRes = await request(app)
        .get(`/beatplans/${planAId}`)
        .set('Authorization', `Bearer ${tokenA}`);
      const firstStopId = planRes.body.stops[0].id;

      const patchRes = await request(app)
        .patch(`/beatplans/${planAId}/stops/${firstStopId}`)
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ visited: true });

      expect(patchRes.status).toBe(200);
      expect(patchRes.body.visited).toBe(true);

      const afterRes = await request(app)
        .get(`/beatplans/${planAId}`)
        .set('Authorization', `Bearer ${tokenA}`);
      expect(afterRes.body.adherence.stopsVisited).toBe(1);
      expect(afterRes.body.adherence.adherenceRate).toBe(50);
    });

    it('rejects a non-boolean visited with 400', async () => {
      const planRes = await request(app)
        .get(`/beatplans/${planAId}`)
        .set('Authorization', `Bearer ${tokenA}`);
      const stopId = planRes.body.stops[0].id;

      const res = await request(app)
        .patch(`/beatplans/${planAId}/stops/${stopId}`)
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ visited: 'yes' });

      expect(res.status).toBe(400);
    });

    it('returns 404 when a field agent updates another agent plan stop', async () => {
      const planRes = await request(app)
        .get(`/beatplans/${planAId}`)
        .set('Authorization', `Bearer ${tokenA}`);
      const stopId = planRes.body.stops[0].id;

      // agentB does not own planA — the stop is invisible to them.
      const res = await request(app)
        .patch(`/beatplans/${planAId}/stops/${stopId}`)
        .set('Authorization', `Bearer ${tokenB}`)
        .send({ visited: true });

      expect(res.status).toBe(404);
    });
  });

  describe('PATCH /beatplans/:id', () => {
    it('lets a manager update the plan status (200)', async () => {
      const res = await request(app)
        .patch(`/beatplans/${planBId}`)
        .set('Authorization', `Bearer ${managerToken}`)
        .send({ status: 'in_progress' });

      expect(res.status).toBe(200);
      expect(res.body.status).toBe('in_progress');
    });

    it('rejects an invalid status with 400', async () => {
      const res = await request(app)
        .patch(`/beatplans/${planBId}`)
        .set('Authorization', `Bearer ${managerToken}`)
        .send({ status: 'bogus' });

      expect(res.status).toBe(400);
    });

    it('forbids a field agent from updating plan status with 403', async () => {
      const res = await request(app)
        .patch(`/beatplans/${planBId}`)
        .set('Authorization', `Bearer ${tokenB}`)
        .send({ status: 'completed' });

      expect(res.status).toBe(403);
    });
  });
  describe('POST / recurrence (#98)', () => {
    it('materialises one plan per occurrence, all sharing a seriesId', async () => {
      const res = await request(app)
        .post('/beatplans')
        .set('Authorization', `Bearer ${managerToken}`)
        .send({
          agentId: agentAId,
          name: 'RECUR- Weekly Tuesday beat',
          scheduledDate: '2026-07-07T00:00:00.000Z',
          outletIds: [outlet1Id, outlet2Id],
          recurrence: { frequency: 'weekly', until: '2026-07-28T00:00:00.000Z' },
        });

      expect(res.status).toBe(201);
      // Four Tuesdays: 07, 14, 21, 28 July.
      expect(res.body.occurrences).toBe(4);
      expect(res.body.seriesId).not.toBeNull();

      const series = await prisma.beatPlan.findMany({
        where: { seriesId: res.body.seriesId },
        include: { stops: true },
        orderBy: { scheduledDate: 'asc' },
      });
      expect(series).toHaveLength(4);
      expect(
        series.map((p) => p.scheduledDate.toISOString().slice(0, 10)),
      ).toEqual(['2026-07-07', '2026-07-14', '2026-07-21', '2026-07-28']);

      // Every occurrence carries its own stops, which is the whole reason these
      // are rows rather than a rule expanded on read — `visited` is per-date.
      for (const plan of series) {
        expect(plan.stops).toHaveLength(2);
        expect(plan.stops.every((stop) => stop.visited === false)).toBe(true);
      }
    });

    it('marking one occurrence visited does not touch its siblings', async () => {
      const created = await request(app)
        .post('/beatplans')
        .set('Authorization', `Bearer ${managerToken}`)
        .send({
          agentId: agentAId,
          name: 'RECUR- Daily beat',
          scheduledDate: '2026-08-03T00:00:00.000Z',
          outletIds: [outlet1Id],
          recurrence: { frequency: 'daily', until: '2026-08-05T00:00:00.000Z' },
        });
      expect(created.status).toBe(201);

      const series = await prisma.beatPlan.findMany({
        where: { seriesId: created.body.seriesId },
        include: { stops: true },
        orderBy: { scheduledDate: 'asc' },
      });
      expect(series).toHaveLength(3);

      await prisma.beatPlanStop.update({
        where: { id: series[0].stops[0].id },
        data: { visited: true },
      });

      const after = await prisma.beatPlan.findMany({
        where: { seriesId: created.body.seriesId },
        include: { stops: true },
        orderBy: { scheduledDate: 'asc' },
      });
      expect(after[0].stops[0].visited).toBe(true);
      expect(after[1].stops[0].visited).toBe(false);
      expect(after[2].stops[0].visited).toBe(false);
    });

    it('a one-off create is unchanged — no seriesId, one occurrence', async () => {
      const res = await request(app)
        .post('/beatplans')
        .set('Authorization', `Bearer ${managerToken}`)
        .send({
          agentId: agentAId,
          name: 'RECUR- One off',
          scheduledDate: '2026-09-01T00:00:00.000Z',
          outletIds: [outlet1Id],
        });

      expect(res.status).toBe(201);
      expect(res.body.seriesId).toBeNull();
      expect(res.body.occurrences).toBe(1);
    });

    it('rejects a malformed recurrence rather than silently creating a one-off', async () => {
      for (const recurrence of [
        { frequency: 'yearly', until: '2026-08-01T00:00:00.000Z' },
        { frequency: 'weekly' },
        { frequency: 'weekly', until: 'not-a-date' },
        { frequency: 'weekly', until: '2026-08-01T00:00:00.000Z', interval: 'two' },
        { frequency: 'weekly', until: '2026-08-01T00:00:00.000Z', daysOfWeek: ['mon'] },
      ]) {
        const res = await request(app)
          .post('/beatplans')
          .set('Authorization', `Bearer ${managerToken}`)
          .send({
            agentId: agentAId,
            name: 'RECUR- Bad',
            scheduledDate: '2026-07-07T00:00:00.000Z',
            outletIds: [outlet1Id],
            recurrence,
          });
        expect(res.status).toBe(400);
      }
    });

    it('refuses a series that would exceed the cap, and writes nothing', async () => {
      const before = await prisma.beatPlan.count();

      const res = await request(app)
        .post('/beatplans')
        .set('Authorization', `Bearer ${managerToken}`)
        .send({
          agentId: agentAId,
          name: 'RECUR- Five years daily',
          scheduledDate: '2026-07-07T00:00:00.000Z',
          outletIds: [outlet1Id],
          recurrence: { frequency: 'daily', until: '2031-07-07T00:00:00.000Z' },
        });

      expect(res.status).toBe(400);
      // All-or-nothing: half a journey plan is worse than none.
      expect(await prisma.beatPlan.count()).toBe(before);
    });
  });
});

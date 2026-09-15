import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { userIn, type TestUser } from '../../test-utils/tenants';

/**
 * Issue #52: submitting a visit marks the matching beat-plan stop visited, so
 * the agent's Today route progresses without a manager ticking each store.
 *
 * Every test uses its own calendar day so plans from one test can never be
 * matched by another's visit.
 */
describe('POST /visits/:id/submit marks the beat-plan stop visited (#52)', () => {
  const LAT = -26.2041;
  const LNG = 28.0473;

  let clientId: string;
  let clientBId: string;
  let agent: TestUser;
  let otherAgent: TestUser;
  let outletId: string;
  let otherOutletId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'ROUTE-Client-A', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    const clientB = await prisma.client.create({
      data: { name: 'ROUTE-Client-B', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientBId = clientB.id;

    agent = await userIn(clientId, 'field_agent');
    otherAgent = await userIn(clientId, 'field_agent');

    const outlet = await prisma.outlet.create({
      data: {
        name: 'ROUTE-Outlet-1',
        code: 'ROUTE-OUT-1',
        channelType: 'hypermarket',
        lat: LAT,
        lng: LNG,
        territoryId: 'ROUTE-territory',
        clientId,
      },
    });
    outletId = outlet.id;
    const otherOutlet = await prisma.outlet.create({
      data: {
        name: 'ROUTE-Outlet-2',
        code: 'ROUTE-OUT-2',
        channelType: 'hypermarket',
        lat: LAT,
        lng: LNG,
        territoryId: 'ROUTE-territory',
        clientId,
      },
    });
    otherOutletId = otherOutlet.id;
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  afterAll(async () => {
    // Plans first, for BOTH clients: the cross-tenant test's client-B plan has
    // a stop on a client-A outlet, so no outlet can go while any plan remains.
    const clients = [clientId, clientBId];
    await prisma.beatPlanStop.deleteMany({ where: { beatPlan: { clientId: { in: clients } } } });
    await prisma.beatPlan.deleteMany({ where: { clientId: { in: clients } } });
    for (const id of clients) {
      await prisma.alert.deleteMany({ where: { clientId: id } });
      await prisma.checkInAttempt.deleteMany({ where: { clientId: id } });
      await prisma.visit.deleteMany({ where: { clientId: id } });
      await prisma.outlet.deleteMany({ where: { clientId: id } });
      await prisma.user.deleteMany({ where: { clientId: id } });
      await prisma.client.delete({ where: { id } });
    }
    await prisma.$disconnect();
  });

  async function createPlan(opts: {
    clientId: string;
    agentId: string;
    scheduledDate: string;
    outletIds: string[];
    status?: string;
  }) {
    return prisma.beatPlan.create({
      data: {
        clientId: opts.clientId,
        agentId: opts.agentId,
        name: 'ROUTE-plan',
        scheduledDate: new Date(opts.scheduledDate),
        status: opts.status ?? 'planned',
        stops: {
          create: opts.outletIds.map((id, index) => ({ outletId: id, sequence: index + 1 })),
        },
      },
      include: { stops: { orderBy: { sequence: 'asc' } } },
    });
  }

  async function checkIn(user: TestUser, atOutletId: string, checkinTs: string): Promise<string> {
    const res = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${user.token}`)
      .send({ outletId: atOutletId, lat: LAT, lng: LNG, checkinTs });
    expect(res.status).toBe(201);
    return res.body.id as string;
  }

  function submit(user: TestUser, visitId: string) {
    return request(app)
      .post(`/visits/${visitId}/submit`)
      .set('Authorization', `Bearer ${user.token}`);
  }

  async function visited(stopId: string): Promise<boolean> {
    const stop = await prisma.beatPlanStop.findUniqueOrThrow({ where: { id: stopId } });
    return stop.visited;
  }

  it("marks the stop on the agent's plan for the check-in day — and only that outlet's stop", async () => {
    const plan = await createPlan({
      clientId,
      agentId: agent.userId,
      scheduledDate: '2026-07-02', // how the plan form sends it: midnight UTC
      outletIds: [outletId, otherOutletId],
    });

    const visitId = await checkIn(agent, outletId, '2026-07-02T08:00:00.000Z');
    const res = await submit(agent, visitId);

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('submitted');
    expect(await visited(plan.stops[0].id)).toBe(true);
    expect(await visited(plan.stops[1].id)).toBe(false);
  });

  it('is reflected in the plan adherence the Today screen reads', async () => {
    const plan = await createPlan({
      clientId,
      agentId: agent.userId,
      scheduledDate: '2026-07-04',
      outletIds: [outletId, otherOutletId],
    });

    const visitId = await checkIn(agent, outletId, '2026-07-04T09:30:00.000Z');
    expect((await submit(agent, visitId)).status).toBe(200);

    const res = await request(app)
      .get(`/beatplans/${plan.id}`)
      .set('Authorization', `Bearer ${agent.token}`);
    expect(res.status).toBe(200);
    expect(res.body.adherence).toEqual({ stopsTotal: 2, stopsVisited: 1, adherenceRate: 50 });
    expect(res.body.stops[0].visited).toBe(true);
  });

  it("does not mark another agent's plan for the same outlet and day", async () => {
    const theirs = await createPlan({
      clientId,
      agentId: otherAgent.userId,
      scheduledDate: '2026-07-06',
      outletIds: [outletId],
    });

    const visitId = await checkIn(agent, outletId, '2026-07-06T08:00:00.000Z');
    expect((await submit(agent, visitId)).status).toBe(200);

    expect(await visited(theirs.stops[0].id)).toBe(false);
  });

  it("does not mark another client's plan, even one naming the same agent and outlet", async () => {
    // Deliberately inconsistent data — a client-B plan pointing at client-A's
    // agent and outlet — so the only thing standing between it and the update
    // is the clientId guard itself.
    const foreign = await createPlan({
      clientId: clientBId,
      agentId: agent.userId,
      scheduledDate: '2026-07-07',
      outletIds: [outletId],
    });

    const visitId = await checkIn(agent, outletId, '2026-07-07T08:00:00.000Z');
    expect((await submit(agent, visitId)).status).toBe(200);

    expect(await visited(foreign.stops[0].id)).toBe(false);
  });

  it("matches on the check-in's calendar date in the client timezone, not a neighbouring day's plan", async () => {
    // The client was created without a timezone: Africa/Johannesburg (UTC+2).
    const dayBefore = await createPlan({
      clientId,
      agentId: agent.userId,
      scheduledDate: '2026-07-09',
      outletIds: [outletId],
    });
    const sameDay = await createPlan({
      clientId,
      agentId: agent.userId,
      scheduledDate: '2026-07-10',
      outletIds: [outletId],
    });
    const dayAfter = await createPlan({
      clientId,
      agentId: agent.userId,
      scheduledDate: '2026-07-11',
      outletIds: [outletId],
    });

    // 23:59:59.999 SAST on 10 July — the last local instant of the 10th.
    const lateVisit = await checkIn(agent, outletId, '2026-07-10T21:59:59.999Z');
    expect((await submit(agent, lateVisit)).status).toBe(200);

    expect(await visited(dayBefore.stops[0].id)).toBe(false);
    expect(await visited(sameDay.stops[0].id)).toBe(true);
    expect(await visited(dayAfter.stops[0].id)).toBe(false);

    // Local midnight belongs to the new day — the range is half-open.
    const midnightVisit = await checkIn(agent, outletId, '2026-07-10T22:00:00.000Z');
    expect((await submit(agent, midnightVisit)).status).toBe(200);

    expect(await visited(dayBefore.stops[0].id)).toBe(false);
    expect(await visited(dayAfter.stops[0].id)).toBe(true);
  });

  it("#309: a 00:30 SAST check-in marks TODAY's plan, not yesterday's", async () => {
    // The exact bug: 00:30 SAST on 15 Sep is 22:30Z on the 14th. Matched on the
    // UTC day, this ticked the 14th's plan and left today's route untouched.
    const yesterday = await createPlan({
      clientId,
      agentId: agent.userId,
      scheduledDate: '2026-09-14',
      outletIds: [outletId],
    });
    const today = await createPlan({
      clientId,
      agentId: agent.userId,
      scheduledDate: '2026-09-15',
      outletIds: [outletId],
    });

    const visitId = await checkIn(agent, outletId, '2026-09-14T22:30:00.000Z');
    expect((await submit(agent, visitId)).status).toBe(200);

    expect(await visited(today.stops[0].id)).toBe(true);
    expect(await visited(yesterday.stops[0].id)).toBe(false);
  });

  it('matches a New York client on its local date across the spring-forward DST change', async () => {
    // A tenant of its own, so the zone is the only thing that differs.
    const nyClient = await prisma.client.create({
      data: {
        name: 'ROUTE-Client-NY',
        industry: 'FMCG',
        scorecardWeights: {},
        kpiThresholds: {},
        timezone: 'America/New_York',
      },
    });
    const nyAgent = await userIn(nyClient.id, 'field_agent');
    const nyOutlet = await prisma.outlet.create({
      data: {
        name: 'ROUTE-Outlet-NY',
        code: 'ROUTE-OUT-NY',
        channelType: 'hypermarket',
        lat: LAT,
        lng: LNG,
        territoryId: 'ROUTE-territory',
        clientId: nyClient.id,
      },
    });

    try {
      const plans = await Promise.all(
        ['2026-03-07', '2026-03-08', '2026-03-09'].map((scheduledDate) =>
          createPlan({
            clientId: nyClient.id,
            agentId: nyAgent.userId,
            scheduledDate,
            outletIds: [nyOutlet.id],
          }),
        ),
      );
      const [sat, sun, mon] = plans.map((plan) => plan.stops[0].id);

      // 23:30 EST (-5) on Saturday 7 March — 04:30Z on the 8th.
      const saturdayNight = await checkIn(nyAgent, nyOutlet.id, '2026-03-08T04:30:00.000Z');
      expect((await submit(nyAgent, saturdayNight)).status).toBe(200);
      expect([await visited(sat), await visited(sun), await visited(mon)]).toEqual([
        true,
        false,
        false,
      ]);

      // 23:30 EDT (-4, after the change) on Sunday 8 March — 03:30Z on the 9th.
      // A UTC-day rule would tick Monday's plan.
      const sundayNight = await checkIn(nyAgent, nyOutlet.id, '2026-03-09T03:30:00.000Z');
      expect((await submit(nyAgent, sundayNight)).status).toBe(200);
      expect(await visited(sun)).toBe(true);
      expect(await visited(mon)).toBe(false);

      // 00:30 EDT on Monday 9 March (04:30Z) is Monday's. A fixed EST (-5)
      // offset — the rule in force before the change — would still call this
      // Sunday 23:30, so this is the case only the zone's DST rules get right.
      const mondayMorning = await checkIn(nyAgent, nyOutlet.id, '2026-03-09T04:30:00.000Z');
      expect((await submit(nyAgent, mondayMorning)).status).toBe(200);
      expect(await visited(mon)).toBe(true);
    } finally {
      await prisma.beatPlanStop.deleteMany({ where: { beatPlan: { clientId: nyClient.id } } });
      await prisma.beatPlan.deleteMany({ where: { clientId: nyClient.id } });
      await prisma.alert.deleteMany({ where: { clientId: nyClient.id } });
      await prisma.checkInAttempt.deleteMany({ where: { clientId: nyClient.id } });
      await prisma.visit.deleteMany({ where: { clientId: nyClient.id } });
      await prisma.outlet.deleteMany({ where: { clientId: nyClient.id } });
      await prisma.user.deleteMany({ where: { clientId: nyClient.id } });
      await prisma.client.delete({ where: { id: nyClient.id } });
    }
  });

  it('matches a plan whose scheduledDate is a full instant within that day', async () => {
    const plan = await createPlan({
      clientId,
      agentId: agent.userId,
      scheduledDate: '2026-07-13T10:00:00+02:00', // 08:00Z on the 13th
      outletIds: [outletId],
    });

    const visitId = await checkIn(agent, outletId, '2026-07-13T06:15:00.000Z');
    expect((await submit(agent, visitId)).status).toBe(200);

    expect(await visited(plan.stops[0].id)).toBe(true);
  });

  it('leaves a completed plan alone, and does not change plan status', async () => {
    const closed = await createPlan({
      clientId,
      agentId: agent.userId,
      scheduledDate: '2026-07-15',
      outletIds: [outletId],
      status: 'completed',
    });
    const open = await createPlan({
      clientId,
      agentId: agent.userId,
      scheduledDate: '2026-07-15',
      outletIds: [outletId, otherOutletId],
    });

    const visitId = await checkIn(agent, outletId, '2026-07-15T08:00:00.000Z');
    expect((await submit(agent, visitId)).status).toBe(200);

    expect(await visited(closed.stops[0].id)).toBe(false);
    expect(await visited(open.stops[0].id)).toBe(true);
    const openAfter = await prisma.beatPlan.findUniqueOrThrow({ where: { id: open.id } });
    expect(openAfter.status).toBe('planned');
  });

  it('is idempotent — a re-submit or a duplicate sync changes nothing further', async () => {
    const plan = await createPlan({
      clientId,
      agentId: agent.userId,
      scheduledDate: '2026-07-17',
      outletIds: [outletId, otherOutletId],
    });

    const visitId = await checkIn(agent, outletId, '2026-07-17T08:00:00.000Z');
    expect((await submit(agent, visitId)).status).toBe(200);
    expect((await submit(agent, visitId)).status).toBe(200);

    // A second visit to the same store that day is harmless too.
    const again = await checkIn(agent, outletId, '2026-07-17T14:00:00.000Z');
    expect((await submit(agent, again)).status).toBe(200);

    expect(await visited(plan.stops[0].id)).toBe(true);
    expect(await visited(plan.stops[1].id)).toBe(false);
    const stops = await prisma.beatPlanStop.findMany({ where: { beatPlanId: plan.id } });
    expect(stops).toHaveLength(2);
  });

  it('does not fail the submit when marking the stop fails', async () => {
    const plan = await createPlan({
      clientId,
      agentId: agent.userId,
      scheduledDate: '2026-07-19',
      outletIds: [outletId],
    });
    jest
      .spyOn(prisma.beatPlanStop, 'updateMany')
      .mockRejectedValueOnce(new Error('route bookkeeping unavailable'));
    const errorLog = jest.spyOn(console, 'error').mockImplementation(() => undefined);

    const visitId = await checkIn(agent, outletId, '2026-07-19T08:00:00.000Z');
    const res = await submit(agent, visitId);

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('submitted');
    const persisted = await prisma.visit.findUniqueOrThrow({ where: { id: visitId } });
    expect(persisted.status).toBe('submitted');
    expect(await visited(plan.stops[0].id)).toBe(false);
    expect(errorLog).toHaveBeenCalledWith(
      expect.stringContaining(`Marking beat-plan stops visited failed for visit ${visitId}`),
      expect.any(Error),
    );
  });
});

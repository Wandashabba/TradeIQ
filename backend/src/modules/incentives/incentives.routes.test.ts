import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { issueToken } from '../auth/auth.service';

describe('incentives routes', () => {
  let clientId: string;
  let otherClientId: string;
  let agentAId: string;
  let agentBId: string;
  let agentCId: string;
  let agentAToken: string;
  let managerToken: string;
  let otherManagerToken: string;
  let outletId: string;
  let otherSchemeId: string;
  let schemeId: string;

  // Creates a submitted visit for an agent plus its scorecard, so the
  // scorecard-mean metric has data to aggregate over.
  const seedScoredVisit = async (agentId: string, weightedTotal: number): Promise<void> => {
    const visit = await prisma.visit.create({
      data: {
        outletId,
        agentId,
        clientId,
        checkinTs: new Date(),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'submitted',
      },
    });
    await prisma.scorecard.create({
      data: {
        visitId: visit.id,
        dimensionScores: {},
        weightedTotal,
        ratingBand: 'green',
      },
    });
  };

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'INC Test Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const manager = await prisma.user.create({
      data: { email: 'INC-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });

    const agentA = await prisma.user.create({
      data: { email: 'INC-agent-a@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentAId = agentA.id;
    agentAToken = issueToken({ userId: agentA.id, role: 'field_agent', clientId });

    const agentB = await prisma.user.create({
      data: { email: 'INC-agent-b@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentBId = agentB.id;

    const agentC = await prisma.user.create({
      data: { email: 'INC-agent-c@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentCId = agentC.id;

    const outlet = await prisma.outlet.create({
      data: {
        name: 'INC Outlet',
        code: 'INC-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId,
      },
    });
    outletId = outlet.id;

    // agentA: mean scorecard (80, 90) = 85, plus one closed task.
    await seedScoredVisit(agentAId, 80);
    await seedScoredVisit(agentAId, 90);
    await prisma.task.create({
      data: {
        findingType: 'stockout',
        outletId,
        requiredFix: 'Restock',
        priority: 'normal',
        slaDueAt: new Date(),
        ownerId: agentAId,
        status: 'closed',
      },
    });

    // agentB: mean scorecard 50 — below the 85 threshold.
    await seedScoredVisit(agentBId, 50);

    // agentC: three scored visits (70, 80, 85) → mean 235/3 = 78.33 (a
    // non-terminating mean, so the JS mean() reduce is exercised on the same
    // fractional value the old Postgres AVG produced). No tasks; 3 submitted visits.
    await seedScoredVisit(agentCId, 70);
    await seedScoredVisit(agentCId, 80);
    await seedScoredVisit(agentCId, 85);

    // A second tenant + its own scheme, to prove list/tenant scoping.
    const otherClient = await prisma.client.create({
      data: { name: 'INC Other Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = otherClient.id;
    const otherManager = await prisma.user.create({
      data: {
        email: 'INC-other-manager@example.com',
        passwordHash: 'x',
        role: 'manager',
        clientId: otherClientId,
      },
    });
    otherManagerToken = issueToken({ userId: otherManager.id, role: 'manager', clientId: otherClientId });
    const otherScheme = await prisma.incentiveScheme.create({
      data: {
        clientId: otherClientId,
        name: 'INC Other Scheme',
        metric: 'visits',
        threshold: 1,
        rewardPoints: 10,
      },
    });
    otherSchemeId = otherScheme.id;
  });

  afterAll(async () => {
    const clientIds = [clientId, otherClientId];
    await prisma.incentiveScheme.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.task.deleteMany({ where: { outlet: { clientId: { in: clientIds } } } });
    await prisma.scorecard.deleteMany({ where: { visit: { clientId: { in: clientIds } } } });
    await prisma.visit.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.user.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.client.deleteMany({ where: { id: { in: clientIds } } });
    await prisma.$disconnect();
  });

  const validBody = () => ({
    name: 'Top Scorecard Bonus',
    metric: 'scorecard',
    threshold: 85,
    rewardPoints: 100,
    rewardDetail: 'R500 voucher',
  });

  it('creates a scheme (201)', async () => {
    const res = await request(app)
      .post('/incentives')
      .set('Authorization', `Bearer ${managerToken}`)
      .send(validBody());

    expect(res.status).toBe(201);
    expect(res.body.name).toBe('Top Scorecard Bonus');
    expect(res.body.metric).toBe('scorecard');
    expect(res.body.threshold).toBe(85);
    expect(res.body.rewardPoints).toBe(100);
    expect(res.body.active).toBe(true);
    schemeId = res.body.id;
  });

  it('rejects an invalid metric (400)', async () => {
    const res = await request(app)
      .post('/incentives')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ ...validBody(), metric: 'revenue' });
    expect(res.status).toBe(400);
  });

  it('forbids a field agent from creating (403)', async () => {
    const res = await request(app)
      .post('/incentives')
      .set('Authorization', `Bearer ${agentAToken}`)
      .send(validBody());
    expect(res.status).toBe(403);
  });

  it('lists the client schemes, scoped to the tenant (200)', async () => {
    const res = await request(app).get('/incentives').set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    const ids = res.body.data.map((s: { id: string }) => s.id);
    expect(ids).toContain(schemeId);
    expect(ids).not.toContain(otherSchemeId);
    const created = res.body.data.map((s: { createdAt: string }) => new Date(s.createdAt).getTime());
    expect(created).toEqual([...created].sort((a: number, b: number) => b - a)); // newest first
  });

  describe('GET /incentives pagination', () => {
    beforeAll(async () => {
      await prisma.incentiveScheme.createMany({
        data: [0, 1, 2].map((i) => ({
          clientId,
          name: `page-scheme-${i}`,
          metric: 'visits',
          threshold: 1,
          rewardPoints: 10,
          createdAt: new Date(`2026-07-2${i}T00:00:00.000Z`),
        })),
      });
    });

    it('returns an envelope with data and nextCursor, newest first', async () => {
      const res = await request(app)
        .get('/incentives')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body).toHaveProperty('nextCursor');
      const names = res.body.data.map((s: { name: string }) => s.name);
      expect(names.indexOf('page-scheme-2')).toBeLessThan(names.indexOf('page-scheme-0'));
    });

    it('caps the page at limit and returns a cursor to the next page', async () => {
      const first = await request(app)
        .get('/incentives?limit=2')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(first.status).toBe(200);
      expect(first.body.data).toHaveLength(2);
      expect(first.body.nextCursor).not.toBeNull();

      const second = await request(app)
        .get(`/incentives?limit=2&cursor=${first.body.nextCursor}`)
        .set('Authorization', `Bearer ${managerToken}`);
      expect(second.status).toBe(200);
      const firstIds = first.body.data.map((s: { id: string }) => s.id);
      const secondIds = second.body.data.map((s: { id: string }) => s.id);
      expect(secondIds.some((id: string) => firstIds.includes(id))).toBe(false);
    });

    it('clamps limit above the max to 200', async () => {
      const res = await request(app)
        .get('/incentives?limit=9999')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
    });

    it('rejects a non-positive limit with 400', async () => {
      const res = await request(app)
        .get('/incentives?limit=0')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(400);
    });
  });

  it('computes earned incentives for qualifying agents only (200)', async () => {
    const res = await request(app)
      .get('/incentives/earned')
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    const rows = res.body.filter((r: { schemeId: string }) => r.schemeId === schemeId);
    expect(rows).toHaveLength(1);
    expect(rows[0].agentId).toBe(agentAId); // mean 85 >= 85
    expect(rows[0].email).toBe('INC-agent-a@example.com');
    expect(rows[0].metricValue).toBe(85);
    expect(rows[0].rewardPoints).toBe(100);
    // agentB (mean 50) does not qualify.
    const agentBRows = res.body.filter(
      (r: { schemeId: string; agentId: string }) => r.schemeId === schemeId && r.agentId === agentBId,
    );
    expect(agentBRows).toHaveLength(0);
  });

  it('earned: exact rows across all three metrics, in scheme-outer/agent-inner order', async () => {
    // One active scheme per metric. Thresholds picked so a different subset of
    // agents qualifies for each, and one qualifier (agentC @ scorecard) rides
    // on the non-terminating mean 235/3 = 78.33.
    const score = await prisma.incentiveScheme.create({
      data: { clientId, name: 'INC Score 78', metric: 'scorecard', threshold: 78, rewardPoints: 100 },
    });
    const tasks = await prisma.incentiveScheme.create({
      data: { clientId, name: 'INC Tasks 1', metric: 'tasks_closed', threshold: 1, rewardPoints: 50 },
    });
    const visits = await prisma.incentiveScheme.create({
      data: { clientId, name: 'INC Visits 3', metric: 'visits', threshold: 3, rewardPoints: 20 },
    });
    const myIds = [score.id, tasks.id, visits.id];

    const res = await request(app)
      .get('/incentives/earned')
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(200);
    const rows = res.body.filter((r: { schemeId: string }) => myIds.includes(r.schemeId));

    // Rebuild the exact contract order independently: schemes in the same
    // createdAt-desc order the service reads them, agents in the same
    // field-agent findMany order, scheme-outer / agent-inner. metricValues are
    // hard-known from the seed, so this pins values AND ordering, not just a set.
    const schemesDesc = await prisma.incentiveScheme.findMany({
      where: { clientId, active: true, id: { in: myIds } },
      orderBy: { createdAt: 'desc' },
    });
    const agentOrder = await prisma.user.findMany({
      where: { clientId, role: 'field_agent' },
      select: { id: true, email: true },
    });
    const metricValues: Record<string, Record<string, number>> = {
      scorecard: { [agentAId]: 85, [agentBId]: 50, [agentCId]: 78.33 },
      tasks_closed: { [agentAId]: 1, [agentBId]: 0, [agentCId]: 0 },
      visits: { [agentAId]: 2, [agentBId]: 1, [agentCId]: 3 },
    };
    const expected: unknown[] = [];
    for (const scheme of schemesDesc) {
      for (const agent of agentOrder) {
        const value = metricValues[scheme.metric][agent.id];
        if (value >= scheme.threshold) {
          expected.push({
            schemeId: scheme.id,
            schemeName: scheme.name,
            metric: scheme.metric,
            agentId: agent.id,
            email: agent.email,
            metricValue: value,
            rewardPoints: scheme.rewardPoints,
          });
        }
      }
    }
    expect(rows).toEqual(expected);
    // Explicitly assert the fractional-mean qualifier survived round2.
    expect(rows).toContainEqual(
      expect.objectContaining({ schemeId: score.id, agentId: agentCId, metricValue: 78.33 }),
    );

    // Drop these schemes so later tests' earned output is unchanged.
    await prisma.incentiveScheme.deleteMany({ where: { id: { in: myIds } } });
  });

  it('excludes inactive schemes from earned', async () => {
    const created = await request(app)
      .post('/incentives')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ name: 'Any Visit', metric: 'visits', threshold: 1, rewardPoints: 5 });
    expect(created.status).toBe(201);
    const visitsSchemeId = created.body.id;

    // Active: qualifying agents appear.
    const active = await request(app)
      .get('/incentives/earned')
      .set('Authorization', `Bearer ${managerToken}`);
    expect(active.body.some((r: { schemeId: string }) => r.schemeId === visitsSchemeId)).toBe(true);

    // Deactivate, then the scheme drops out of earned entirely.
    const patched = await request(app)
      .patch(`/incentives/${visitsSchemeId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ active: false });
    expect(patched.status).toBe(200);
    expect(patched.body.active).toBe(false);

    const inactive = await request(app)
      .get('/incentives/earned')
      .set('Authorization', `Bearer ${managerToken}`);
    expect(inactive.body.some((r: { schemeId: string }) => r.schemeId === visitsSchemeId)).toBe(false);
  });

  it('updates a scheme (200)', async () => {
    const res = await request(app)
      .patch(`/incentives/${schemeId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ threshold: 90, rewardDetail: 'R750 voucher' });
    expect(res.status).toBe(200);
    expect(res.body.threshold).toBe(90);
    expect(res.body.rewardDetail).toBe('R750 voucher');
  });

  it('rejects an empty patch body (400)', async () => {
    const res = await request(app)
      .patch(`/incentives/${schemeId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({});
    expect(res.status).toBe(400);
  });

  it('forbids a field agent from patching (403)', async () => {
    const res = await request(app)
      .patch(`/incentives/${schemeId}`)
      .set('Authorization', `Bearer ${agentAToken}`)
      .send({ active: false });
    expect(res.status).toBe(403);
  });

  it("returns 404 when patching another client's scheme", async () => {
    const res = await request(app)
      .patch(`/incentives/${schemeId}`)
      .set('Authorization', `Bearer ${otherManagerToken}`)
      .send({ active: false });
    expect(res.status).toBe(404);
  });

  it('forbids a field agent from deleting (403)', async () => {
    const res = await request(app)
      .delete(`/incentives/${schemeId}`)
      .set('Authorization', `Bearer ${agentAToken}`);
    expect(res.status).toBe(403);
  });

  it("returns 404 when deleting another client's scheme", async () => {
    const res = await request(app)
      .delete(`/incentives/${schemeId}`)
      .set('Authorization', `Bearer ${otherManagerToken}`);
    expect(res.status).toBe(404);
  });

  it('deletes a scheme then it is gone (204)', async () => {
    const res = await request(app)
      .delete(`/incentives/${schemeId}`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(204);

    const gone = await prisma.incentiveScheme.findUnique({ where: { id: schemeId } });
    expect(gone).toBeNull();

    const secondDelete = await request(app)
      .delete(`/incentives/${schemeId}`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(secondDelete.status).toBe(404);
  });

  it('rejects requests without a bearer token (401)', async () => {
    const created = await request(app).post('/incentives').send(validBody());
    expect(created.status).toBe(401);
    const listed = await request(app).get('/incentives');
    expect(listed.status).toBe(401);
    const earned = await request(app).get('/incentives/earned');
    expect(earned.status).toBe(401);
    const patched = await request(app).patch(`/incentives/${schemeId}`).send({ active: false });
    expect(patched.status).toBe(401);
    const deleted = await request(app).delete(`/incentives/${schemeId}`);
    expect(deleted.status).toBe(401);
  });
});

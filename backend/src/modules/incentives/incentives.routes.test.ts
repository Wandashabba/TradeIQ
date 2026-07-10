import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('incentives routes', () => {
  let clientId: string;
  let otherClientId: string;
  let agentAId: string;
  let agentBId: string;
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
    const ids = res.body.map((s: { id: string }) => s.id);
    expect(ids).toContain(schemeId);
    expect(ids).not.toContain(otherSchemeId);
    const created = res.body.map((s: { createdAt: string }) => new Date(s.createdAt).getTime());
    expect(created).toEqual([...created].sort((a: number, b: number) => b - a)); // newest first
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

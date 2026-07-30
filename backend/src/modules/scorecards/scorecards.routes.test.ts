import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';
import { foreignTenant, userIn } from '../../test-utils/tenants';

describe('scorecards routes', () => {
  let clientId: string;
  let agentToken: string;
  let agentBToken: string;
  let managerToken: string;
  let visitId: string;
  let emptyVisitId: string;
  let outletId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: {
        name: 'SCORE-Test Client',
        industry: 'FMCG',
        scorecardWeights: {
          availability: 0.3,
          visibility: 0.25,
          display: 0.15,
          pricing: 0.1,
          competitive: 0.1,
          salesCapability: 0.1,
        },
        kpiThresholds: { green: 80, amber: 60 },
      },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: {
        email: 'score-agent@example.com',
        passwordHash: 'x',
        role: 'field_agent',
        clientId,
      },
    });
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });
    managerToken = (await userIn(clientId, 'manager')).token;

    const agentB = await prisma.user.create({
      data: { email: 'score-agent-b@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentBToken = issueToken({ userId: agentB.id, role: 'field_agent', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'SCORE-Outlet',
        code: 'SCORE-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'score-t1',
        clientId,
      },
    });

    outletId = outlet.id;

    const visitData = {
      outletId: outlet.id,
      agentId: agent.id,
      clientId,
      checkinTs: new Date(),
      checkinLat: -26.2041,
      checkinLng: 28.0473,
      geofencePass: true,
      status: 'in_progress' as const,
    };
    const visit = await prisma.visit.create({ data: visitData });
    visitId = visit.id;
    const emptyVisit = await prisma.visit.create({ data: visitData });
    emptyVisitId = emptyVisit.id;

    const sku = await prisma.sku.create({
      data: {
        clientId,
        name: 'SCORE-Cola',
        category: 'Beverages',
        minFacingsStandard: 4,
        rrp: 19.99,
      },
    });

    // Two stock rows, one out of stock -> availability 50.
    await prisma.visitStock.createMany({
      data: [
        {
          visitId,
          skuId: sku.id,
          unitsAvailable: 20,
          lastStockinDate: new Date('2026-07-01T00:00:00.000Z'),
          daysOutOfStock: 0,
          velocityAvg: 4,
          coverageDaysPredicted: 5,
          salesActual: 100,
          salesTarget: 120,
        },
        {
          visitId,
          skuId: sku.id,
          unitsAvailable: 0,
          lastStockinDate: new Date('2026-06-20T00:00:00.000Z'),
          daysOutOfStock: 3,
          velocityAvg: 4,
          coverageDaysPredicted: 0,
          salesActual: 50,
          salesTarget: 120,
        },
      ],
    });

    // planogram 80 -> visibility 80; cleanliness 4 -> display 80.
    await prisma.visitVisibility.create({
      data: {
        visitId,
        brandingElements: { poster: true },
        planogramCompliancePct: 80,
        facingsCount: { total: 12 },
        highTrafficPass: true,
        cleanlinessScore: 4,
      },
    });

    // |deviation| 10 -> pricing 90.
    await prisma.visitPricing.create({
      data: {
        visitId,
        skuId: sku.id,
        priceActual: 21.99,
        priceMaster: 19.99,
        deviationPct: 10,
        promoActive: false,
        promoMaterialsDetected: {},
        commsRating: 3,
      },
    });

    // Any competitive row -> competitive 100.
    await prisma.visitCompetitive.create({
      data: {
        visitId,
        competitorSku: 'SCORE-Rival Cola',
        competitorPrice: 17.99,
        competitorPosmType: 'shelf_strip',
        competitorPromoterPresent: false,
        geotag: { lat: -26.2041, lng: 28.0473 },
      },
    });

    // quizScore 70 -> salesCapability 70.
    await prisma.visitCapability.create({
      data: {
        visitId,
        staffHeadcountConfirmed: 3,
        repTrainingStatus: { trained: true },
        quizScore: 70,
      },
    });
  });

  afterAll(async () => {
    await prisma.scorecard.deleteMany({ where: { visit: { clientId } } });
    await prisma.visitStock.deleteMany({ where: { visit: { clientId } } });
    await prisma.visitVisibility.deleteMany({ where: { visit: { clientId } } });
    await prisma.visitPricing.deleteMany({ where: { visit: { clientId } } });
    await prisma.visitCompetitive.deleteMany({ where: { visit: { clientId } } });
    await prisma.visitCapability.deleteMany({ where: { visit: { clientId } } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.sku.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  it('computes and stores the scorecard (201)', async () => {
    const res = await request(app)
      .post('/scorecards')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId });

    expect(res.status).toBe(201);
    expect(res.body.dimensionScores).toEqual({
      availability: 50,
      visibility: 80,
      display: 80,
      pricing: 90,
      // Share of shelf: 12 of our facings against 1 competitor facing (#93).
      // This used to be a flat 100 for having captured any competitor at all.
      competitive: 92.31,
      salesCapability: 70,
    });
    // 50*.3 + 80*.25 + 80*.15 + 90*.1 + 92.31*.1 + 70*.1 = 72.23
    expect(res.body.weightedTotal).toBe(72.23);
    expect(res.body.ratingBand).toBe('amber');
  });

  it('is idempotent — re-submitting upserts the same row', async () => {
    const first = await request(app)
      .post('/scorecards')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId });
    const second = await request(app)
      .post('/scorecards')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId });

    expect(second.status).toBe(201);
    expect(second.body.id).toBe(first.body.id);
    expect(second.body.visitId).toBe(visitId);

    const rows = await prisma.scorecard.findMany({ where: { visitId } });
    expect(rows).toHaveLength(1);
  });

  it('GET /scorecards/:visitId returns the scorecard', async () => {
    const res = await request(app)
      .get(`/scorecards/${visitId}`)
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.visitId).toBe(visitId);
    expect(res.body.weightedTotal).toBe(72.23);
    expect(res.body.ratingBand).toBe('amber');
  });

  it('returns 404 when the visit has no scorecard yet', async () => {
    const res = await request(app)
      .get(`/scorecards/${emptyVisitId}`)
      .set('Authorization', `Bearer ${agentToken}`);

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('Scorecard not found');
  });

  it("forbids an agent from generating a scorecard on another agent's visit (404)", async () => {
    const res = await request(app)
      .post('/scorecards')
      .set('Authorization', `Bearer ${agentBToken}`)
      .send({ visitId });
    expect(res.status).toBe(404);
  });

  it('returns 404 for a visit belonging to another client', async () => {
    const otherToken = (await foreignTenant('field_agent')).token;

    const postRes = await request(app)
      .post('/scorecards')
      .set('Authorization', `Bearer ${otherToken}`)
      .send({ visitId });
    expect(postRes.status).toBe(404);

    const getRes = await request(app)
      .get(`/scorecards/${visitId}`)
      .set('Authorization', `Bearer ${otherToken}`);
    expect(getRes.status).toBe(404);
  });

  it('rejects a missing visitId with 400', async () => {
    const res = await request(app)
      .post('/scorecards')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({});
    expect(res.status).toBe(400);
  });

  it('forbids a manager from generating a scorecard with 403', async () => {
    const res = await request(app)
      .post('/scorecards')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ visitId });
    expect(res.status).toBe(403);
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).post('/scorecards').send({ visitId });
    expect(res.status).toBe(401);
  });

  it('GET / lists the callers client scorecards for a manager (200)', async () => {
    // Ensure at least one scorecard exists for this client regardless of order.
    await prisma.scorecard.upsert({
      where: { visitId },
      create: { visitId, dimensionScores: {}, weightedTotal: 73, ratingBand: 'amber' },
      update: {},
    });

    const res = await request(app)
      .get('/scorecards')
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.some((row: { visitId: string }) => row.visitId === visitId)).toBe(true);
  });

  it('GET / returns an envelope and rejects a non-positive limit', async () => {
    const res = await request(app)
      .get('/scorecards?limit=1')
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body).toHaveProperty('nextCursor');

    const bad = await request(app)
      .get('/scorecards?limit=0')
      .set('Authorization', `Bearer ${managerToken}`);
    expect(bad.status).toBe(400);
  });

  it('GET /history defaults to the last handful, and an explicit limit wins', async () => {
    // The old hard-coded `take: 5` is now this endpoint's default limit. The
    // guarantee worth pinning is that it is a DEFAULT, not a second ceiling:
    // asking for fewer must give fewer, and the envelope must still be there.
    const res = await request(app)
      .get(`/scorecards/history?outletId=${outletId}&limit=1`)
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body).toHaveProperty('nextCursor');
  });

  it('GET / forbids a field agent with 403', async () => {
    const res = await request(app).get('/scorecards').set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(403);
  });

  it('GET / rejects requests without a bearer token with 401', async () => {
    const res = await request(app).get('/scorecards');
    expect(res.status).toBe(401);
  });

  describe('GET /history', () => {
    it('lets an agent see their own past scores at an outlet', async () => {
      // The outcome screen tells them "up 6 points from your last visit here".
      // That sentence is only true if they can read the last visit.
      await request(app)
        .post('/scorecards')
        .set('Authorization', `Bearer ${agentToken}`)
        .send({ visitId });

      const res = await request(app)
        .get('/scorecards/history')
        .query({ outletId })
        .set('Authorization', `Bearer ${agentToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.some((row: { visitId: string }) => row.visitId === visitId)).toBe(true);
    });

    it('does not show one agent another agent’s scores', async () => {
      const other = await prisma.user.create({
        data: {
          email: 'score-other-agent@example.com',
          passwordHash: 'x',
          role: 'field_agent',
          clientId,
        },
      });
      const otherVisit = await prisma.visit.create({
        data: {
          outletId,
          agentId: other.id,
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
          visitId: otherVisit.id,
          dimensionScores: {},
          weightedTotal: 91,
          ratingBand: 'green',
        },
      });

      // An agent's score history is feedback on their own work, not a window
      // onto a colleague's — and certainly not a leaderboard nobody opted into.
      const res = await request(app)
        .get('/scorecards/history')
        .query({ outletId })
        .set('Authorization', `Bearer ${agentToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.some((row: { visitId: string }) => row.visitId === otherVisit.id)).toBe(
        false,
      );

      // A manager, whose job is the outlet rather than the agent, sees both.
      const managerRes = await request(app)
        .get('/scorecards/history')
        .query({ outletId })
        .set('Authorization', `Bearer ${managerToken}`);

      expect(
        managerRes.body.data.some((row: { visitId: string }) => row.visitId === otherVisit.id),
      ).toBe(true);
    });

    it('requires an outletId', async () => {
      const res = await request(app)
        .get('/scorecards/history')
        .set('Authorization', `Bearer ${agentToken}`);
      expect(res.status).toBe(400);
    });
  });
});

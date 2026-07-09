import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('scorecards routes', () => {
  let clientId: string;
  let agentToken: string;
  let managerToken: string;
  let visitId: string;
  let emptyVisitId: string;

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
    managerToken = issueToken({ userId: 'score-manager', role: 'manager', clientId });

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
      competitive: 100,
      salesCapability: 70,
    });
    // 50*.3 + 80*.25 + 80*.15 + 90*.1 + 100*.1 + 70*.1 = 73
    expect(res.body.weightedTotal).toBe(73);
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
    expect(res.body.weightedTotal).toBe(73);
    expect(res.body.ratingBand).toBe('amber');
  });

  it('returns 404 when the visit has no scorecard yet', async () => {
    const res = await request(app)
      .get(`/scorecards/${emptyVisitId}`)
      .set('Authorization', `Bearer ${agentToken}`);

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('Scorecard not found');
  });

  it('returns 404 for a visit belonging to another client', async () => {
    const otherToken = issueToken({
      userId: 'x',
      role: 'field_agent',
      clientId: 'no-such-client',
    });

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

  it('GET / (bare listing) is not implemented yet', async () => {
    const res = await request(app).get('/scorecards').set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(501);
  });
});

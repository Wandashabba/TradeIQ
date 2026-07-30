import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { issueToken } from '../auth/auth.service';
import { userIn } from '../../test-utils/tenants';

describe('dashboard routes', () => {
  let clientId: string;
  let otherClientId: string;
  let emptyClientId: string;
  let managerToken: string;
  let agentToken: string;
  let emptyManagerToken: string;
  let territory1Id: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'DASH-Client A', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    managerToken = (await userIn(clientId, 'manager')).token;

    const agent = await prisma.user.create({
      data: { email: 'dash-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });

    const outlet1 = await prisma.outlet.create({
      data: {
        name: 'DASH-Outlet 1',
        code: 'DASH-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'dash-t1',
        clientId,
      },
    });
    const outlet2 = await prisma.outlet.create({
      data: {
        name: 'DASH-Outlet 2',
        code: 'DASH-002',
        channelType: 'spaza',
        lat: -26.1,
        lng: 28.1,
        territoryId: 'dash-t2',
        clientId,
      },
    });

    // A real Territory row, distinct id vs code, so territoryId filtering can
    // be tested against the actual client-facing contract (Territory.id in,
    // resolved to Territory.code internally) rather than the free-text code
    // directly — see the id/code doc comment on the Territory model.
    const territory1 = await prisma.territory.create({
      data: { clientId, name: 'DASH-Territory 1', code: 'dash-t1' },
    });
    territory1Id = territory1.id;

    const sku = await prisma.sku.create({
      data: { clientId, name: 'DASH-Cola', category: 'Beverages', minFacingsStandard: 4, rrp: 19.99 },
    });

    const visit1 = await prisma.visit.create({
      data: {
        outletId: outlet1.id,
        agentId: agent.id,
        clientId,
        checkinTs: new Date('2026-07-01T09:00:00.000Z'),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'submitted',
      },
    });
    const visit2 = await prisma.visit.create({
      data: {
        outletId: outlet2.id,
        agentId: agent.id,
        clientId,
        checkinTs: new Date('2026-07-02T09:00:00.000Z'),
        checkinLat: -26.1,
        checkinLng: 28.1,
        geofencePass: true,
        status: 'submitted',
      },
    });

    // Visit 1: 2 stock rows (1 in stock -> osa 50), visibility (planogram 80,
    // facings total 8), 2 pricing rows (one within the 5% tolerance -> 50),
    // 2 competitive rows (-> share of shelf 8/(8+2) = 80), amber scorecard.
    await prisma.visitStock.createMany({
      data: [
        {
          visitId: visit1.id,
          skuId: sku.id,
          unitsAvailable: 20,
          lastStockinDate: new Date('2026-06-28T00:00:00.000Z'),
          daysOutOfStock: 0,
          velocityAvg: 4,
          coverageDaysPredicted: 5,
          salesActual: 100,
          salesTarget: 120,
        },
        {
          visitId: visit1.id,
          skuId: sku.id,
          unitsAvailable: 0,
          lastStockinDate: new Date('2026-06-20T00:00:00.000Z'),
          daysOutOfStock: 4,
          velocityAvg: 4,
          coverageDaysPredicted: 0,
          salesActual: 40,
          salesTarget: 120,
        },
      ],
    });
    await prisma.visitVisibility.create({
      data: {
        visitId: visit1.id,
        brandingElements: { poster: true },
        planogramCompliancePct: 80,
        facingsCount: { total: 8 },
        highTrafficPass: true,
        cleanlinessScore: 4,
      },
    });
    await prisma.visitPricing.createMany({
      data: [
        {
          visitId: visit1.id,
          skuId: sku.id,
          priceActual: 20.59,
          priceMaster: 19.99,
          deviationPct: 3,
          promoActive: false,
          promoMaterialsDetected: {},
          commsRating: 3,
        },
        {
          visitId: visit1.id,
          skuId: sku.id,
          priceActual: 21.99,
          priceMaster: 19.99,
          deviationPct: 10,
          promoActive: false,
          promoMaterialsDetected: {},
          commsRating: 3,
        },
      ],
    });
    await prisma.visitCompetitive.createMany({
      data: [
        {
          visitId: visit1.id,
          competitorSku: 'DASH-Rival A',
          competitorPrice: 17.99,
          competitorPosmType: 'shelf_strip',
          competitorPromoterPresent: false,
          geotag: {},
        },
        {
          visitId: visit1.id,
          competitorSku: 'DASH-Rival B',
          competitorPrice: 18.49,
          competitorPosmType: 'poster',
          competitorPromoterPresent: true,
          geotag: {},
        },
      ],
    });
    await prisma.scorecard.create({
      data: {
        visitId: visit1.id,
        dimensionScores: {},
        weightedTotal: 73,
        ratingBand: 'amber',
      },
    });

    // Visit 2: no section rows, green scorecard.
    await prisma.scorecard.create({
      data: {
        visitId: visit2.id,
        dimensionScores: {},
        weightedTotal: 90,
        ratingBand: 'green',
      },
    });

    // Second client with data (same territory name!) to prove tenant isolation.
    const otherClient = await prisma.client.create({
      data: { name: 'DASH-Client B', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = otherClient.id;
    const otherAgent = await prisma.user.create({
      data: {
        email: 'dash-agent-b@example.com',
        passwordHash: 'x',
        role: 'field_agent',
        clientId: otherClientId,
      },
    });
    const otherOutlet = await prisma.outlet.create({
      data: {
        name: 'DASH-Outlet B',
        code: 'DASH-B01',
        channelType: 'hypermarket',
        lat: -25.7,
        lng: 28.2,
        territoryId: 'dash-t1',
        clientId: otherClientId,
      },
    });
    const otherSku = await prisma.sku.create({
      data: {
        clientId: otherClientId,
        name: 'DASH-Other Cola',
        category: 'Beverages',
        minFacingsStandard: 4,
        rrp: 9.99,
      },
    });
    const otherVisit = await prisma.visit.create({
      data: {
        outletId: otherOutlet.id,
        agentId: otherAgent.id,
        clientId: otherClientId,
        checkinTs: new Date('2026-07-01T10:00:00.000Z'),
        checkinLat: -25.7,
        checkinLng: 28.2,
        geofencePass: true,
        status: 'submitted',
      },
    });
    await prisma.visitStock.create({
      data: {
        visitId: otherVisit.id,
        skuId: otherSku.id,
        unitsAvailable: 0,
        lastStockinDate: new Date('2026-06-01T00:00:00.000Z'),
        daysOutOfStock: 10,
        velocityAvg: 2,
        coverageDaysPredicted: 0,
        salesActual: 10,
        salesTarget: 100,
      },
    });
    await prisma.scorecard.create({
      data: {
        visitId: otherVisit.id,
        dimensionScores: {},
        weightedTotal: 20,
        ratingBand: 'red',
      },
    });

    // Third client with no data at all.
    const emptyClient = await prisma.client.create({
      data: { name: 'DASH-Client C', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    emptyClientId = emptyClient.id;
    emptyManagerToken = (await userIn(emptyClientId, 'manager')).token;
  });

  afterAll(async () => {
    const clientIds = [clientId, otherClientId, emptyClientId];
    await prisma.scorecard.deleteMany({ where: { visit: { clientId: { in: clientIds } } } });
    await prisma.visitStock.deleteMany({ where: { visit: { clientId: { in: clientIds } } } });
    await prisma.visitVisibility.deleteMany({ where: { visit: { clientId: { in: clientIds } } } });
    await prisma.visitPricing.deleteMany({ where: { visit: { clientId: { in: clientIds } } } });
    await prisma.visitCompetitive.deleteMany({ where: { visit: { clientId: { in: clientIds } } } });
    await prisma.visit.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.territory.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.sku.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.user.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.client.deleteMany({ where: { id: { in: clientIds } } });
    await prisma.$disconnect();
  });

  it('aggregates KPIs scoped to the caller client', async () => {
    const res = await request(app).get('/dashboard').set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.kpis).toEqual({
      numericDistribution: 100, // 2 of 2 outlets visited
      weightedDistribution: 100,
      osaPct: 50, // 1 of 2 stock rows in stock (client B's OOS row excluded)
      executionScore: 81.5, // mean(73, 90)
      priceCompliancePct: 50, // 1 of 2 pricing rows within +-5%
      visibilityCompliancePct: 80,
      shareOfShelf: 80, // 8 own facings vs 2 competitor rows
      perfectStoreRate: 50, // 1 of 2 scorecards green
    });
    expect(res.body.totals).toEqual({ visits: 2, outletsVisited: 2, outletsTotal: 2 });
  });

  it('filters by territoryId (visits and outlet denominator)', async () => {
    const res = await request(app)
      .get('/dashboard')
      .query({ territoryId: territory1Id })
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.totals).toEqual({ visits: 1, outletsVisited: 1, outletsTotal: 1 });
    expect(res.body.kpis.numericDistribution).toBe(100);
    expect(res.body.kpis.executionScore).toBe(73);
    expect(res.body.kpis.perfectStoreRate).toBe(0); // the t1 visit is amber
    // Client B also has a visit in territory dash-t1 — it must not leak in.
    expect(res.body.kpis.osaPct).toBe(50);
  });

  it('returns all-zero KPIs for a territoryId that does not exist for this client', async () => {
    const res = await request(app)
      .get('/dashboard')
      .query({ territoryId: 'no-such-territory-id' })
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.totals).toEqual({ visits: 0, outletsVisited: 0, outletsTotal: 0 });
  });

  it('filters by from date', async () => {
    const res = await request(app)
      .get('/dashboard')
      .query({ from: '2026-07-02T00:00:00.000Z' })
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.totals.visits).toBe(1);
    expect(res.body.kpis.executionScore).toBe(90);
    expect(res.body.kpis.perfectStoreRate).toBe(100);
  });

  it('rejects an unparseable date with 400', async () => {
    const res = await request(app)
      .get('/dashboard')
      .query({ from: 'not-a-date' })
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(400);
  });

  it('returns all-zero KPIs for a client with no data', async () => {
    const res = await request(app)
      .get('/dashboard')
      .set('Authorization', `Bearer ${emptyManagerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.kpis).toEqual({
      numericDistribution: 0,
      weightedDistribution: 0,
      osaPct: 0,
      executionScore: 0,
      priceCompliancePct: 0,
      visibilityCompliancePct: 0,
      shareOfShelf: 0,
      perfectStoreRate: 0,
    });
    expect(res.body.totals).toEqual({ visits: 0, outletsVisited: 0, outletsTotal: 0 });
  });

  it('forbids a field agent with 403', async () => {
    const res = await request(app).get('/dashboard').set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(403);
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).get('/dashboard');
    expect(res.status).toBe(401);
  });
});

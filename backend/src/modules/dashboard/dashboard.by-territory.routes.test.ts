import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';
import { userIn } from '../../test-utils/tenants';

interface TerritoryDashboardResponseItem {
  territoryId: string;
  territoryName: string;
  kpis: {
    numericDistribution: number;
    weightedDistribution: number;
    osaPct: number;
    executionScore: number;
    priceCompliancePct: number;
    visibilityCompliancePct: number;
    shareOfShelf: number;
    perfectStoreRate: number;
  };
  totals: {
    visits: number;
    outletsVisited: number;
    outletsTotal: number;
  };
}

/**
 * #97 — the manager dashboard used to call `GET /dashboard?territoryId=<id>`
 * once per territory (N+1), AND that call filtered `Outlet.territoryId` —
 * a free-text column that actually stores `Territory.code` — against
 * `Territory.id`, a UUID that never matches it. Every per-territory KPI was
 * silently zeroed out.
 *
 * This suite creates real `Territory` rows (unlike `dashboard.routes.test.ts`,
 * which only ever set the free-text `Outlet.territoryId` string directly and
 * so could never have caught the id/code mismatch) with an auto-generated
 * `id` that is guaranteed to differ from the literal `code` we choose, then
 * asserts `GET /dashboard/by-territory` returns real, non-zero, correctly
 * scoped KPIs keyed by `Territory.id`. If the join regresses to filtering by
 * `territory.id` instead of `territory.code`, every KPI below collapses to 0
 * and these assertions fail.
 */
describe('dashboard by-territory route (#97)', () => {
  let clientId: string;
  let otherClientId: string;
  let managerToken: string;
  let agentToken: string;
  let northId: string;
  let southId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'DASHT-Client A', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    managerToken = (await userIn(clientId, 'manager')).token;

    const agent = await prisma.user.create({
      data: { email: 'dasht-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });

    // id auto-generated (uuid), code chosen literally — id !== code is
    // guaranteed, which is exactly the condition that exposes the bug.
    const north = await prisma.territory.create({
      data: { clientId, name: 'DASHT-Territory North', code: 'dasht-north' },
    });
    northId = north.id;
    const south = await prisma.territory.create({
      data: { clientId, name: 'DASHT-Territory South', code: 'dasht-south' },
    });
    southId = south.id;

    // Outlets link by territoryId === Territory.code, never Territory.id.
    const outletN1 = await prisma.outlet.create({
      data: {
        name: 'DASHT-Outlet N1',
        code: 'DASHT-N1',
        channelType: 'hypermarket',
        lat: -26.2,
        lng: 28.0,
        territoryId: north.code,
        clientId,
      },
    });
    const outletN2 = await prisma.outlet.create({
      data: {
        name: 'DASHT-Outlet N2',
        code: 'DASHT-N2',
        channelType: 'spaza',
        lat: -26.21,
        lng: 28.01,
        territoryId: north.code,
        clientId,
      },
    });
    void outletN2;
    const outletS1 = await prisma.outlet.create({
      data: {
        name: 'DASHT-Outlet S1',
        code: 'DASHT-S1',
        channelType: 'general_trade',
        lat: -26.3,
        lng: 28.2,
        territoryId: south.code,
        clientId,
      },
    });

    const sku = await prisma.sku.create({
      data: { clientId, name: 'DASHT-Cola', category: 'Beverages', minFacingsStandard: 4, rrp: 19.99 },
    });

    // North: 2 outlets, only N1 visited -> numericDistribution 50.
    const visitN1 = await prisma.visit.create({
      data: {
        outletId: outletN1.id,
        agentId: agent.id,
        clientId,
        checkinTs: new Date('2026-07-01T09:00:00.000Z'),
        checkinLat: -26.2,
        checkinLng: 28.0,
        geofencePass: true,
        status: 'submitted',
      },
    });
    // South: 1 outlet, visited -> numericDistribution 100.
    const visitS1 = await prisma.visit.create({
      data: {
        outletId: outletS1.id,
        agentId: agent.id,
        clientId,
        checkinTs: new Date('2026-07-05T09:30:00.000Z'),
        checkinLat: -26.3,
        checkinLng: 28.2,
        geofencePass: true,
        status: 'submitted',
      },
    });

    // North stock: 2 rows, 1 in stock -> osaPct 50.
    await prisma.visitStock.createMany({
      data: [
        {
          visitId: visitN1.id,
          skuId: sku.id,
          unitsAvailable: 10,
          lastStockinDate: new Date('2026-06-28T00:00:00.000Z'),
          daysOutOfStock: 0,
          velocityAvg: 4,
          coverageDaysPredicted: 5,
          salesActual: 80,
          salesTarget: 100,
        },
        {
          visitId: visitN1.id,
          skuId: sku.id,
          unitsAvailable: 0,
          lastStockinDate: new Date('2026-06-20T00:00:00.000Z'),
          daysOutOfStock: 3,
          velocityAvg: 4,
          coverageDaysPredicted: 0,
          salesActual: 20,
          salesTarget: 100,
        },
      ],
    });
    // South stock: 1 row, in stock -> osaPct 100.
    await prisma.visitStock.create({
      data: {
        visitId: visitS1.id,
        skuId: sku.id,
        unitsAvailable: 15,
        lastStockinDate: new Date('2026-06-29T00:00:00.000Z'),
        daysOutOfStock: 0,
        velocityAvg: 3,
        coverageDaysPredicted: 5,
        salesActual: 90,
        salesTarget: 100,
      },
    });

    await prisma.scorecard.create({
      data: { visitId: visitN1.id, dimensionScores: {}, weightedTotal: 65, ratingBand: 'amber' },
    });
    await prisma.scorecard.create({
      data: { visitId: visitS1.id, dimensionScores: {}, weightedTotal: 95, ratingBand: 'green' },
    });

    // Second client, its own territory using the SAME code string as client
    // A's North territory, to prove tenant isolation survives the code join.
    const otherClient = await prisma.client.create({
      data: { name: 'DASHT-Client B', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = otherClient.id;
    await prisma.territory.create({
      data: { clientId: otherClientId, name: 'DASHT-Other North', code: 'dasht-north' },
    });
    const otherAgent = await prisma.user.create({
      data: {
        email: 'dasht-agent-b@example.com',
        passwordHash: 'x',
        role: 'field_agent',
        clientId: otherClientId,
      },
    });
    const otherOutlet = await prisma.outlet.create({
      data: {
        name: 'DASHT-Outlet B1',
        code: 'DASHT-B1',
        channelType: 'hypermarket',
        lat: -25.7,
        lng: 28.2,
        territoryId: 'dasht-north',
        clientId: otherClientId,
      },
    });
    const otherSku = await prisma.sku.create({
      data: {
        clientId: otherClientId,
        name: 'DASHT-Other Cola',
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
      data: { visitId: otherVisit.id, dimensionScores: {}, weightedTotal: 20, ratingBand: 'red' },
    });
  });

  afterAll(async () => {
    const clientIds = [clientId, otherClientId];
    await prisma.scorecard.deleteMany({ where: { visit: { clientId: { in: clientIds } } } });
    await prisma.visitStock.deleteMany({ where: { visit: { clientId: { in: clientIds } } } });
    await prisma.visitVisibility.deleteMany({ where: { visit: { clientId: { in: clientIds } } } });
    await prisma.visitPricing.deleteMany({ where: { visit: { clientId: { in: clientIds } } } });
    await prisma.visitCompetitive.deleteMany({ where: { visit: { clientId: { in: clientIds } } } });
    await prisma.visit.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.sku.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.territory.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.user.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.client.deleteMany({ where: { id: { in: clientIds } } });
    await prisma.$disconnect();
  });

  it('returns one entry per territory, keyed by Territory.id, joined via Territory.code', async () => {
    const res = await request(app)
      .get('/dashboard/by-territory')
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    // Exactly the two territories belonging to client A — client B's
    // same-code territory must not appear.
    expect(res.body).toHaveLength(2);

    const byId = new Map(
      (res.body as TerritoryDashboardResponseItem[]).map((s) => [s.territoryId, s]),
    );

    const north = byId.get(northId);
    expect(north).toBeDefined();
    expect(north!.territoryName).toBe('DASHT-Territory North');
    expect(north!.totals).toEqual({ visits: 1, outletsVisited: 1, outletsTotal: 2 });
    expect(north!.kpis.numericDistribution).toBe(50); // 1 of 2 outlets visited
    expect(north!.kpis.osaPct).toBe(50); // 1 of 2 stock rows in stock
    expect(north!.kpis.executionScore).toBe(65);

    const south = byId.get(southId);
    expect(south).toBeDefined();
    expect(south!.territoryName).toBe('DASHT-Territory South');
    expect(south!.totals).toEqual({ visits: 1, outletsVisited: 1, outletsTotal: 1 });
    expect(south!.kpis.numericDistribution).toBe(100); // 1 of 1 outlets visited
    expect(south!.kpis.osaPct).toBe(100); // 1 of 1 stock rows in stock
    expect(south!.kpis.executionScore).toBe(95);
  });

  it('never leaks another client, even one with a territory of the same code', async () => {
    const res = await request(app)
      .get('/dashboard/by-territory')
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    const territoryNames = (res.body as TerritoryDashboardResponseItem[]).map((s) => s.territoryName);
    expect(territoryNames).not.toContain('DASHT-Other North');

    // Client B's outlet/visit data (a red, zeroed-out scorecard) must not
    // have blended into client A's "dasht-north"-coded North territory.
    const north = (res.body as TerritoryDashboardResponseItem[]).find((s) => s.territoryId === northId);
    expect(north!.kpis.executionScore).toBe(65);
  });

  it('filters by from date', async () => {
    const res = await request(app)
      .get('/dashboard/by-territory')
      .query({ from: '2026-07-03T00:00:00.000Z' })
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    const byId = new Map(
      (res.body as TerritoryDashboardResponseItem[]).map((s) => [s.territoryId, s]),
    );
    // North's only visit was 2026-07-01 — excluded by the from filter.
    expect(byId.get(northId)!.totals).toEqual({ visits: 0, outletsVisited: 0, outletsTotal: 2 });
    // South's visit was 2026-07-05 — included.
    expect(byId.get(southId)!.totals).toEqual({ visits: 1, outletsVisited: 1, outletsTotal: 1 });
  });

  it('rejects an unparseable date with 400', async () => {
    const res = await request(app)
      .get('/dashboard/by-territory')
      .query({ from: 'not-a-date' })
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(400);
  });

  it('forbids a field agent with 403', async () => {
    const res = await request(app)
      .get('/dashboard/by-territory')
      .set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(403);
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).get('/dashboard/by-territory');
    expect(res.status).toBe(401);
  });
});

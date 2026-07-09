import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

// Two distinct, fixed 2026 weeks so day/week bucketing is deterministic.
// Monday of week A is 2026-03-02; Monday of week B is 2026-03-09 (both UTC).
const WEEK_A_MONDAY = '2026-03-02T00:00:00.000Z';
const WEEK_B_MONDAY = '2026-03-09T00:00:00.000Z';
const A_DAY_1 = new Date('2026-03-03T10:00:00.000Z'); // Tue, week A
const A_DAY_2 = new Date('2026-03-05T14:00:00.000Z'); // Thu, week A
const A_STOCK = new Date('2026-03-04T08:00:00.000Z'); // Wed, week A
const B_DAY_1 = new Date('2026-03-10T09:00:00.000Z'); // Tue, week B
const B_DAY_2 = new Date('2026-03-12T16:00:00.000Z'); // Thu, week B
const B_STOCK = new Date('2026-03-11T12:00:00.000Z'); // Wed, week B

describe('trends routes', () => {
  let clientId: string;
  let otherClientId: string;
  let managerToken: string;
  let agentToken: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'TREND-Client A', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    managerToken = issueToken({ userId: 'trend-manager', role: 'manager', clientId });

    const agent = await prisma.user.create({
      data: { email: 'trend-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'TREND-Outlet 1',
        code: 'TREND-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'trend-t1',
        clientId,
      },
    });
    const sku = await prisma.sku.create({
      data: {
        clientId,
        name: 'TREND-Cola',
        category: 'Beverages',
        minFacingsStandard: 4,
        rrp: 19.99,
      },
    });

    // A scorecard has a unique visitId, so one visit is created per scorecard.
    // Bucketing keys off each row's own createdAt, not the visit's checkinTs.
    const makeVisit = async (checkin: Date): Promise<string> => {
      const visit = await prisma.visit.create({
        data: {
          outletId: outlet.id,
          agentId: agent.id,
          clientId,
          checkinTs: checkin,
          checkinLat: -26.2041,
          checkinLng: 28.0473,
          geofencePass: true,
          status: 'submitted',
        },
      });
      return visit.id;
    };

    const [visitA1, visitA2, visitB1, visitB2] = await Promise.all([
      makeVisit(A_DAY_1),
      makeVisit(A_DAY_2),
      makeVisit(B_DAY_1),
      makeVisit(B_DAY_2),
    ]);

    // Week A scorecards: 60 (amber) + 90 (green) -> mean 75, green rate 50%.
    // Week B scorecards: 80 (green) + 100 (green) -> mean 90, green rate 100%.
    await prisma.scorecard.createMany({
      data: [
        {
          visitId: visitA1,
          dimensionScores: {},
          weightedTotal: 60,
          ratingBand: 'amber',
          createdAt: A_DAY_1,
        },
        {
          visitId: visitA2,
          dimensionScores: {},
          weightedTotal: 90,
          ratingBand: 'green',
          createdAt: A_DAY_2,
        },
        {
          visitId: visitB1,
          dimensionScores: {},
          weightedTotal: 80,
          ratingBand: 'green',
          createdAt: B_DAY_1,
        },
        {
          visitId: visitB2,
          dimensionScores: {},
          weightedTotal: 100,
          ratingBand: 'green',
          createdAt: B_DAY_2,
        },
      ],
    });

    // Week A stock: units [10, 0, 5] -> 2 of 3 in stock -> OSA 66.67 (count 3).
    // Week B stock: units [0, 8] -> 1 of 2 in stock -> OSA 50 (count 2).
    const stockRow = (visitId: string, units: number, createdAt: Date) => ({
      visitId,
      skuId: sku.id,
      unitsAvailable: units,
      lastStockinDate: new Date('2026-02-20T00:00:00.000Z'),
      daysOutOfStock: units > 0 ? 0 : 5,
      velocityAvg: 4,
      coverageDaysPredicted: units > 0 ? 5 : 0,
      salesActual: 100,
      salesTarget: 120,
      createdAt,
    });
    await prisma.visitStock.createMany({
      data: [
        stockRow(visitA1, 10, A_STOCK),
        stockRow(visitA1, 0, A_STOCK),
        stockRow(visitA1, 5, A_STOCK),
        stockRow(visitB1, 0, B_STOCK),
        stockRow(visitB1, 8, B_STOCK),
      ],
    });

    // Second client with a green scorecard + in-stock row in week A: must never
    // leak into client A's series.
    const otherClient = await prisma.client.create({
      data: { name: 'TREND-Client B', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = otherClient.id;
    const otherAgent = await prisma.user.create({
      data: {
        email: 'trend-agent-b@example.com',
        passwordHash: 'x',
        role: 'field_agent',
        clientId: otherClientId,
      },
    });
    const otherOutlet = await prisma.outlet.create({
      data: {
        name: 'TREND-Outlet B',
        code: 'TREND-B01',
        channelType: 'hypermarket',
        lat: -25.7,
        lng: 28.2,
        territoryId: 'trend-t1',
        clientId: otherClientId,
      },
    });
    const otherVisit = await prisma.visit.create({
      data: {
        outletId: otherOutlet.id,
        agentId: otherAgent.id,
        clientId: otherClientId,
        checkinTs: A_DAY_1,
        checkinLat: -25.7,
        checkinLng: 28.2,
        geofencePass: true,
        status: 'submitted',
      },
    });
    await prisma.scorecard.create({
      data: {
        visitId: otherVisit.id,
        dimensionScores: {},
        weightedTotal: 5,
        ratingBand: 'red',
        createdAt: A_DAY_1,
      },
    });
    await prisma.visitStock.create({
      data: stockRow(otherVisit.id, 999, A_STOCK),
    });
  });

  afterAll(async () => {
    const clientIds = [clientId, otherClientId];
    await prisma.scorecard.deleteMany({ where: { visit: { clientId: { in: clientIds } } } });
    await prisma.visitStock.deleteMany({ where: { visit: { clientId: { in: clientIds } } } });
    await prisma.visit.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.sku.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.user.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.client.deleteMany({ where: { id: { in: clientIds } } });
    await prisma.$disconnect();
  });

  it('buckets scorecards by week with mean weightedTotal', async () => {
    const res = await request(app)
      .get('/trends/scorecards')
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.interval).toBe('week');
    expect(res.body.points).toEqual([
      { period: WEEK_A_MONDAY, value: 75, count: 2 },
      { period: WEEK_B_MONDAY, value: 90, count: 2 },
    ]);
  });

  it('buckets availability by week as OSA%', async () => {
    const res = await request(app)
      .get('/trends/availability')
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.points).toEqual([
      { period: WEEK_A_MONDAY, value: 66.67, count: 3 },
      { period: WEEK_B_MONDAY, value: 50, count: 2 },
    ]);
  });

  it('buckets perfect-store rate by week', async () => {
    const res = await request(app)
      .get('/trends/perfect-store')
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.points).toEqual([
      { period: WEEK_A_MONDAY, value: 50, count: 2 },
      { period: WEEK_B_MONDAY, value: 100, count: 2 },
    ]);
  });

  it('buckets by day when interval=day', async () => {
    const res = await request(app)
      .get('/trends/scorecards')
      .query({ interval: 'day' })
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.interval).toBe('day');
    expect(res.body.points).toEqual([
      { period: '2026-03-03T00:00:00.000Z', value: 60, count: 1 },
      { period: '2026-03-05T00:00:00.000Z', value: 90, count: 1 },
      { period: '2026-03-10T00:00:00.000Z', value: 80, count: 1 },
      { period: '2026-03-12T00:00:00.000Z', value: 100, count: 1 },
    ]);
  });

  it('honours the from/to window', async () => {
    const res = await request(app)
      .get('/trends/scorecards')
      .query({ from: '2026-03-09T00:00:00.000Z', to: '2026-03-16T00:00:00.000Z' })
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.points).toEqual([{ period: WEEK_B_MONDAY, value: 90, count: 2 }]);
  });

  it('returns an empty series for a window with no rows', async () => {
    const res = await request(app)
      .get('/trends/scorecards')
      .query({ from: '2025-01-01T00:00:00.000Z', to: '2025-02-01T00:00:00.000Z' })
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.points).toEqual([]);
  });

  it('rejects a bad interval with 400', async () => {
    const res = await request(app)
      .get('/trends/scorecards')
      .query({ interval: 'month' })
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(400);
  });

  it('rejects an unparseable date with 400', async () => {
    const res = await request(app)
      .get('/trends/availability')
      .query({ from: 'not-a-date' })
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(400);
  });

  it('forbids a field agent with 403', async () => {
    const res = await request(app)
      .get('/trends/scorecards')
      .set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(403);
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).get('/trends/scorecards');
    expect(res.status).toBe(401);
  });
});

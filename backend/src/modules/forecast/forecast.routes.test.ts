import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { startOfLocalDay } from '../../lib/clientTime';
import { forecastCoverageDays, forecastDemand } from '../../services/forecast.service';
import { TestUser, foreignTenant, userIn } from '../../test-utils/tenants';
import { trailingLocalDays } from '../salesTargets/salesMonth';
import { FORECAST_HISTORY_DAYS } from './forecast.service';

const ZONE = 'Africa/Johannesburg';
const HOUR_MS = 60 * 60 * 1000;

describe('forecast routes', () => {
  let clientId: string;
  let manager: TestUser;
  let agent: TestUser;
  let foreign: Awaited<ReturnType<typeof foreignTenant>>;
  let skuId: string;
  let quietSkuId: string;
  let foreignSkuId: string;
  let outletId: string;
  let otherOutletId: string;
  let foreignOutletId: string;

  // The series the forecast should see: index 27 is yesterday (local), 26 the day before.
  let dates: Date[];

  async function order(
    outlet: string,
    sku: string,
    quantity: number,
    createdAt: Date,
    options: { status?: string; clientId?: string; agentId?: string } = {},
  ) {
    await prisma.order.create({
      data: {
        clientId: options.clientId ?? clientId,
        outletId: outlet,
        agentId: options.agentId ?? agent.userId,
        status: options.status ?? 'submitted',
        createdAt,
        lines: { create: [{ skuId: sku, quantity, unitPrice: 1 }] },
      },
    });
  }

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'FCAST-Client A', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    manager = await userIn(clientId, 'manager');
    agent = await userIn(clientId, 'field_agent');

    const outlet = (code: string, cid = clientId) =>
      prisma.outlet.create({
        data: { name: code, code, channelType: 'hypermarket', lat: -26.2, lng: 28.04, territoryId: 'fcast-t1', clientId: cid },
      });
    outletId = (await outlet('FCAST-001')).id;
    otherOutletId = (await outlet('FCAST-002')).id;
    const sku = (name: string, cid = clientId) =>
      prisma.sku.create({ data: { clientId: cid, name, category: 'Beverages', minFacingsStandard: 4, rrp: 19.99 } });
    skuId = (await sku('FCAST-Cola')).id;
    quietSkuId = (await sku('FCAST-Quiet')).id;

    foreign = await foreignTenant('field_agent');
    foreignSkuId = (await sku('FCAST-Other Cola', foreign.clientId)).id;
    foreignOutletId = (await outlet('FCAST-FX', foreign.clientId)).id;

    const now = new Date();
    ({ dates } = trailingLocalDays(now, FORECAST_HISTORY_DAYS, ZONE));
    const at = (day: Date, hours: number) => new Date(startOfLocalDay(day, ZONE).getTime() + hours * HOUR_MS);
    const yesterday = dates[27];
    const dayBefore = dates[26];

    await order(outletId, skuId, 10, at(yesterday, 9));
    await order(outletId, skuId, 20, at(yesterday, 15));
    await order(otherOutletId, skuId, 5, at(yesterday, 11));
    await order(outletId, skuId, 10, at(dayBefore, 12));
    // 23:59 local on the day before yesterday — still that day, though it is 21:59Z.
    await order(outletId, skuId, 2, new Date(startOfLocalDay(yesterday, ZONE).getTime() - 60_000));
    // Excluded: cancelled, still today, before the window, another tenant.
    await order(outletId, skuId, 500, at(yesterday, 10), { status: 'cancelled' });
    await order(outletId, skuId, 999, now);
    await order(outletId, skuId, 300, at(dates[0], -24));
    await order(foreignOutletId, skuId, 1000, at(yesterday, 10), { clientId: foreign.clientId, agentId: foreign.userId });

    // A shelf observation: its unitsAvailable feeds coverage; its salesActual is
    // the old input and must no longer count for anything.
    const visit = await prisma.visit.create({
      data: {
        outletId,
        agentId: agent.userId,
        clientId,
        checkinTs: at(yesterday, 8),
        checkinLat: -26.2,
        checkinLng: 28.04,
        geofencePass: true,
        status: 'submitted',
      },
    });
    await prisma.visitStock.create({
      data: {
        visitId: visit.id,
        skuId,
        unitsAvailable: 60,
        lastStockinDate: yesterday,
        daysOutOfStock: 0,
        velocityAvg: 5,
        coverageDaysPredicted: 12,
        salesActual: 777,
        salesTarget: 40,
      },
    });
  });

  afterAll(async () => {
    const clientIds = [clientId, foreign.clientId];
    await prisma.visitStock.deleteMany({ where: { visit: { clientId: { in: clientIds } } } });
    await prisma.visit.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.orderLine.deleteMany({ where: { order: { clientId: { in: clientIds } } } });
    await prisma.order.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.sku.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await foreign.cleanup();
    await prisma.$disconnect();
  });

  const expectedSeries = (yesterdayUnits: number, dayBeforeUnits: number) => {
    const series = new Array<number>(FORECAST_HISTORY_DAYS).fill(0);
    series[27] = yesterdayUnits;
    series[26] = dayBeforeUnits;
    return series;
  };

  it('forecasts from daily order sell-in in the client timezone, not VisitStock.salesActual', async () => {
    const res = await request(app).get('/forecast').query({ skuId }).set('Authorization', `Bearer ${manager.token}`);

    expect(res.status).toBe(200);
    const series = expectedSeries(35, 12);
    expect(res.body).toEqual({
      skuId,
      method: 'exponential_smoothing',
      historySource: 'sell_in_orders',
      historyDays: FORECAST_HISTORY_DAYS,
      historyPoints: series,
      forecastNextPeriod: forecastDemand(series),
      forecastCoverageDays: forecastCoverageDays({ unitsAvailable: 60, salesHistory: series }),
    });
    expect(res.body.forecastNextPeriod).toBeGreaterThan(0);
  });

  it('narrows the series to one outlet', async () => {
    const res = await request(app)
      .get('/forecast')
      .query({ skuId, outletId: otherOutletId })
      .set('Authorization', `Bearer ${manager.token}`);
    expect(res.status).toBe(200);
    expect(res.body.historyPoints).toEqual(expectedSeries(5, 0));
  });

  it('is a flat zero series with no coverage estimate for a SKU nobody ordered', async () => {
    const res = await request(app).get('/forecast').query({ skuId: quietSkuId }).set('Authorization', `Bearer ${manager.token}`);
    expect(res.status).toBe(200);
    expect(res.body.historyPoints).toEqual(new Array(FORECAST_HISTORY_DAYS).fill(0));
    expect(res.body.forecastNextPeriod).toBe(0);
    // Zero demand is infinite cover, which JSON carries as null.
    expect(res.body.forecastCoverageDays).toBeNull();
  });

  it('404s for a SKU belonging to another client', async () => {
    const res = await request(app).get('/forecast').query({ skuId: foreignSkuId }).set('Authorization', `Bearer ${manager.token}`);
    expect(res.status).toBe(404);
  });

  it('400s when skuId is missing', async () => {
    const res = await request(app).get('/forecast').set('Authorization', `Bearer ${manager.token}`);
    expect(res.status).toBe(400);
  });

  it('forbids a field agent with 403', async () => {
    const res = await request(app).get('/forecast').query({ skuId }).set('Authorization', `Bearer ${agent.token}`);
    expect(res.status).toBe(403);
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).get('/forecast').query({ skuId });
    expect(res.status).toBe(401);
  });
});

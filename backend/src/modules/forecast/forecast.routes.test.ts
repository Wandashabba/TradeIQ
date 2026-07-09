import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('forecast routes', () => {
  let clientId: string;
  let otherClientId: string;
  let managerToken: string;
  let agentToken: string;
  let skuId: string;
  let otherSkuId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'FCAST-Client A', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    managerToken = issueToken({ userId: 'fcast-manager', role: 'manager', clientId });

    const agent = await prisma.user.create({
      data: { email: 'fcast-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'FCAST-Outlet 1',
        code: 'FCAST-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'fcast-t1',
        clientId,
      },
    });

    const sku = await prisma.sku.create({
      data: { clientId, name: 'FCAST-Cola', category: 'Beverages', minFacingsStandard: 4, rrp: 19.99 },
    });
    skuId = sku.id;

    // Three visits, each with one stock row, increasing salesActual (10, 20, 30)
    // and ascending createdAt so the history series is deterministic.
    const salesSeries = [10, 20, 30];
    for (let i = 0; i < salesSeries.length; i += 1) {
      const visit = await prisma.visit.create({
        data: {
          outletId: outlet.id,
          agentId: agent.id,
          clientId,
          checkinTs: new Date(`2026-07-0${i + 1}T09:00:00.000Z`),
          checkinLat: -26.2041,
          checkinLng: 28.0473,
          geofencePass: true,
          status: 'submitted',
        },
      });
      await prisma.visitStock.create({
        data: {
          visitId: visit.id,
          skuId: sku.id,
          unitsAvailable: 60,
          lastStockinDate: new Date(`2026-07-0${i + 1}T00:00:00.000Z`),
          daysOutOfStock: 0,
          velocityAvg: 5,
          coverageDaysPredicted: 12,
          salesActual: salesSeries[i],
          salesTarget: 40,
          createdAt: new Date(`2026-07-0${i + 1}T10:00:00.000Z`),
        },
      });
    }

    // Second client with its own SKU — used to prove tenant isolation (404).
    const otherClient = await prisma.client.create({
      data: { name: 'FCAST-Client B', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = otherClient.id;
    const otherSku = await prisma.sku.create({
      data: {
        clientId: otherClientId,
        name: 'FCAST-Other Cola',
        category: 'Beverages',
        minFacingsStandard: 4,
        rrp: 9.99,
      },
    });
    otherSkuId = otherSku.id;
  });

  afterAll(async () => {
    const clientIds = [clientId, otherClientId];
    await prisma.visitStock.deleteMany({ where: { visit: { clientId: { in: clientIds } } } });
    await prisma.visit.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.sku.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.user.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.client.deleteMany({ where: { id: { in: clientIds } } });
    await prisma.$disconnect();
  });

  it('returns an exponential-smoothing forecast for the SKU', async () => {
    const res = await request(app)
      .get('/forecast')
      .query({ skuId })
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.skuId).toBe(skuId);
    expect(res.body.method).toBe('exponential_smoothing');
    expect(res.body.historyPoints).toHaveLength(3);
    expect(typeof res.body.forecastNextPeriod).toBe('number');
    expect(typeof res.body.forecastCoverageDays).toBe('number');
  });

  it('404s for a SKU belonging to another client', async () => {
    const res = await request(app)
      .get('/forecast')
      .query({ skuId: otherSkuId })
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(404);
  });

  it('400s when skuId is missing', async () => {
    const res = await request(app).get('/forecast').set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(400);
  });

  it('forbids a field agent with 403', async () => {
    const res = await request(app)
      .get('/forecast')
      .query({ skuId })
      .set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(403);
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).get('/forecast').query({ skuId });
    expect(res.status).toBe(401);
  });
});

import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('skus routes', () => {
  let clientId: string;
  let token: string;
  let agentId: string;
  let outletId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'Sku Test Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    token = issueToken({ userId: 'sku-agent', role: 'field_agent', clientId });

    const agent = await prisma.user.create({
      data: { email: 'sku-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentId = agent.id;

    const outlet = await prisma.outlet.create({
      data: {
        name: 'Sku Outlet',
        code: 'SKU-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId,
      },
    });
    outletId = outlet.id;

    await prisma.sku.create({
      data: { clientId, name: 'Test Cola 500ml', category: 'Beverages', minFacingsStandard: 4, rrp: 19.99 },
    });
  });

  afterAll(async () => {
    await prisma.visitStock.deleteMany({ where: { visit: { clientId } } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.sku.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  it("lists SKUs for the caller's client", async () => {
    const res = await request(app).get('/skus').query({ outletId }).set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].name).toBe('Test Cola 500ml');
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).get('/skus').query({ outletId });
    expect(res.status).toBe(401);
  });

  it('rejects a request without outletId with 400', async () => {
    const res = await request(app).get('/skus').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(400);
  });

  it('does not leak SKUs across clients', async () => {
    const clientB = await prisma.client.create({
      data: { name: 'Sku Client B', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    const tokenB = issueToken({ userId: 'sku-agent-b', role: 'field_agent', clientId: clientB.id });
    try {
      const res = await request(app).get('/skus').query({ outletId }).set('Authorization', `Bearer ${tokenB}`);
      expect(res.status).toBe(200);
      expect(res.body).toHaveLength(0);
    } finally {
      await prisma.client.delete({ where: { id: clientB.id } });
    }
  });

  it('returns the SKU catalog with 0/0 stock context for a foreign/bogus outletId', async () => {
    // outletId isn't validated against the caller's client — the SKU catalog
    // itself is client-scoped, not outlet-gated. A foreign/nonexistent
    // outlet simply yields no matching history rows, so every SKU falls
    // back to the "no history" defaults (0/0) rather than erroring or
    // leaking another client's history.
    const bogusOutletId = '00000000-0000-0000-0000-000000000000';
    const res = await request(app)
      .get('/skus')
      .query({ outletId: bogusOutletId })
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.length).toBeGreaterThan(0);
    expect(res.body.every((s: { daysOutOfStock: number; velocityAvg: number }) => s.daysOutOfStock === 0 && s.velocityAvg === 0)).toBe(
      true,
    );
  });

  it('computes daysOutOfStock/velocityAvg from VisitStock history for the outlet', async () => {
    const sku = await prisma.sku.create({
      data: { clientId, name: 'History Fanta 500ml', category: 'Beverages', minFacingsStandard: 4, rrp: 15.99 },
    });

    const now = new Date();
    const tenDaysAgo = new Date(now.getTime() - 10 * 24 * 60 * 60 * 1000);
    const fiveDaysAgo = new Date(now.getTime() - 5 * 24 * 60 * 60 * 1000);

    const olderVisit = await prisma.visit.create({
      data: {
        outletId,
        agentId,
        clientId,
        checkinTs: tenDaysAgo,
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'submitted',
      },
    });
    const newerVisit = await prisma.visit.create({
      data: {
        outletId,
        agentId,
        clientId,
        checkinTs: fiveDaysAgo,
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'submitted',
      },
    });

    await prisma.visitStock.create({
      data: {
        visitId: olderVisit.id,
        skuId: sku.id,
        unitsAvailable: 100,
        lastStockinDate: tenDaysAgo,
        daysOutOfStock: 0,
        velocityAvg: 0,
        coverageDaysPredicted: 0,
      },
    });
    await prisma.visitStock.create({
      data: {
        visitId: newerVisit.id,
        skuId: sku.id,
        unitsAvailable: 80,
        lastStockinDate: fiveDaysAgo,
        daysOutOfStock: 0,
        velocityAvg: 0,
        coverageDaysPredicted: 0,
      },
    });

    const res = await request(app).get('/skus').query({ outletId }).set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    const historySku = res.body.find((s: { id: string }) => s.id === sku.id);
    expect(historySku).toBeDefined();
    expect(historySku.velocityAvg).toBe(4);
    // Days since the most recent in-stock reading (5 days ago), not 0 —
    // having stock at the last reading doesn't mean it's in stock now.
    expect(historySku.daysOutOfStock).toBe(5);
  });
});

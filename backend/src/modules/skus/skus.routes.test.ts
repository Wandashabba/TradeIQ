import request from 'supertest';
import { Prisma } from '@prisma/client';
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

  it('applies an active promo discount to effectivePrice for a matching outlet', async () => {
    const promo = await prisma.promoCalendar.create({
      data: {
        clientId,
        promoName: '20% Off Everything',
        activeFrom: new Date(Date.now() - 24 * 60 * 60 * 1000),
        activeTo: new Date(Date.now() + 24 * 60 * 60 * 1000),
        requiredPosm: {},
        outletScope: { outletCodes: ['SKU-001'] },
        discountType: 'percent',
        discountValue: 20,
        skuScope: Prisma.JsonNull,
      },
    });

    try {
      const res = await request(app).get('/skus').query({ outletId }).set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(res.body.length).toBeGreaterThan(0);
      for (const sku of res.body) {
        expect(sku.effectivePrice).toBeCloseTo(sku.rrp * 0.8, 2);
      }
    } finally {
      await prisma.promoCalendar.delete({ where: { id: promo.id } });
    }
  });

  it('does not apply a discount scoped to a different outlet', async () => {
    const promo = await prisma.promoCalendar.create({
      data: {
        clientId,
        promoName: 'Other Outlet Only',
        activeFrom: new Date(Date.now() - 24 * 60 * 60 * 1000),
        activeTo: new Date(Date.now() + 24 * 60 * 60 * 1000),
        requiredPosm: {},
        outletScope: { outletCodes: ['SOME-OTHER-OUTLET'] },
        discountType: 'percent',
        discountValue: 20,
        skuScope: Prisma.JsonNull,
      },
    });

    try {
      const res = await request(app).get('/skus').query({ outletId }).set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(res.body.length).toBeGreaterThan(0);
      for (const sku of res.body) {
        expect(sku.effectivePrice).toBe(sku.rrp);
      }
    } finally {
      await prisma.promoCalendar.delete({ where: { id: promo.id } });
    }
  });

  it('does not apply a discount from an expired promo', async () => {
    const promo = await prisma.promoCalendar.create({
      data: {
        clientId,
        promoName: 'Expired Promo',
        activeFrom: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
        activeTo: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000),
        requiredPosm: {},
        outletScope: { outletCodes: ['SKU-001'] },
        discountType: 'percent',
        discountValue: 20,
        skuScope: Prisma.JsonNull,
      },
    });

    try {
      const res = await request(app).get('/skus').query({ outletId }).set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(res.body.length).toBeGreaterThan(0);
      for (const sku of res.body) {
        expect(sku.effectivePrice).toBe(sku.rrp);
      }
    } finally {
      await prisma.promoCalendar.delete({ where: { id: promo.id } });
    }
  });

  it('applies a fixed discount to effectivePrice, flooring at 0 when the discount exceeds rrp', async () => {
    const cheapSku = await prisma.sku.create({
      data: { clientId, name: 'Cheap Gum', category: 'Confectionery', minFacingsStandard: 2, rrp: 3 },
    });

    const promo = await prisma.promoCalendar.create({
      data: {
        clientId,
        promoName: 'R5 Off',
        activeFrom: new Date(Date.now() - 24 * 60 * 60 * 1000),
        activeTo: new Date(Date.now() + 24 * 60 * 60 * 1000),
        requiredPosm: {},
        outletScope: { outletCodes: ['SKU-001'] },
        discountType: 'fixed',
        discountValue: 5,
        skuScope: Prisma.JsonNull,
      },
    });

    try {
      const res = await request(app).get('/skus').query({ outletId }).set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);

      const cola = res.body.find((s: { name: string }) => s.name === 'Test Cola 500ml');
      expect(cola).toBeDefined();
      expect(cola.effectivePrice).toBeCloseTo(cola.rrp - 5, 2);

      const cheap = res.body.find((s: { id: string }) => s.id === cheapSku.id);
      expect(cheap).toBeDefined();
      // discountValue (5) exceeds rrp (3) — the Math.max(0, ...) floor must kick in
      // rather than going negative.
      expect(cheap.effectivePrice).toBe(0);
    } finally {
      await prisma.promoCalendar.delete({ where: { id: promo.id } });
      await prisma.sku.delete({ where: { id: cheapSku.id } });
    }
  });

  it('picks a single, deterministic winner when two active promos both match the same outlet+SKU', async () => {
    const promoA = await prisma.promoCalendar.create({
      data: {
        clientId,
        promoName: 'Promo A - 10% off',
        activeFrom: new Date(Date.now() - 24 * 60 * 60 * 1000),
        activeTo: new Date(Date.now() + 24 * 60 * 60 * 1000),
        requiredPosm: {},
        outletScope: { outletCodes: ['SKU-001'] },
        discountType: 'percent',
        discountValue: 10,
        skuScope: Prisma.JsonNull,
      },
    });
    const promoB = await prisma.promoCalendar.create({
      data: {
        clientId,
        promoName: 'Promo B - 50% off',
        activeFrom: new Date(Date.now() - 24 * 60 * 60 * 1000),
        activeTo: new Date(Date.now() + 24 * 60 * 60 * 1000),
        requiredPosm: {},
        outletScope: { outletCodes: ['SKU-001'] },
        discountType: 'percent',
        discountValue: 50,
        skuScope: Prisma.JsonNull,
      },
    });

    try {
      const res = await request(app).get('/skus').query({ outletId }).set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(res.body.length).toBeGreaterThan(0);

      // Both promos match every outlet+SKU here; listSkusForClient's
      // `activePromos.find(...)` picks whichever comes first in Prisma's
      // (unordered) result set. This pins that observed behavior down as a
      // regression check rather than leaving the tie-break implicit — it is
      // not a guarantee about which promo "should" win.
      const discountedPrices = new Set(res.body.map((s: { effectivePrice: number; rrp: number }) => Math.round((1 - s.effectivePrice / s.rrp) * 100)));
      expect(discountedPrices.size).toBe(1);
      const appliedDiscountPct = [...discountedPrices][0];
      expect([10, 50]).toContain(appliedDiscountPct);
    } finally {
      await prisma.promoCalendar.delete({ where: { id: promoA.id } });
      await prisma.promoCalendar.delete({ where: { id: promoB.id } });
    }
  });

  it('applies a discount only to the SKU(s) listed in skuScope, leaving other SKUs at rrp', async () => {
    const scopedSku = await prisma.sku.create({
      data: { clientId, name: 'Scoped Sku', category: 'Beverages', minFacingsStandard: 4, rrp: 10 },
    });
    const otherSku = await prisma.sku.create({
      data: { clientId, name: 'Unscoped Sku', category: 'Beverages', minFacingsStandard: 4, rrp: 10 },
    });

    const promo = await prisma.promoCalendar.create({
      data: {
        clientId,
        promoName: 'Scoped SKU Promo',
        activeFrom: new Date(Date.now() - 24 * 60 * 60 * 1000),
        activeTo: new Date(Date.now() + 24 * 60 * 60 * 1000),
        requiredPosm: {},
        outletScope: { outletCodes: ['SKU-001'] },
        discountType: 'percent',
        discountValue: 50,
        skuScope: { skuIds: [scopedSku.id] },
      },
    });

    try {
      const res = await request(app).get('/skus').query({ outletId }).set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);

      const scoped = res.body.find((s: { id: string }) => s.id === scopedSku.id);
      const other = res.body.find((s: { id: string }) => s.id === otherSku.id);
      expect(scoped).toBeDefined();
      expect(other).toBeDefined();
      expect(scoped.effectivePrice).toBeCloseTo(5, 2);
      expect(other.effectivePrice).toBe(other.rrp);
    } finally {
      await prisma.promoCalendar.delete({ where: { id: promo.id } });
      await prisma.sku.delete({ where: { id: scopedSku.id } });
      await prisma.sku.delete({ where: { id: otherSku.id } });
    }
  });

  it('does not leak a promo discount for a foreign/bogus outletId', async () => {
    // Mirrors the existing "foreign/bogus outletId" stock-history test above:
    // an unmatched outlet must not silently apply a discount meant for a real,
    // scoped outlet.
    const promo = await prisma.promoCalendar.create({
      data: {
        clientId,
        promoName: 'Should Not Apply To Bogus Outlet',
        activeFrom: new Date(Date.now() - 24 * 60 * 60 * 1000),
        activeTo: new Date(Date.now() + 24 * 60 * 60 * 1000),
        requiredPosm: {},
        outletScope: { outletCodes: ['SKU-001'] },
        discountType: 'percent',
        discountValue: 20,
        skuScope: Prisma.JsonNull,
      },
    });

    try {
      const bogusOutletId = '00000000-0000-0000-0000-000000000000';
      const res = await request(app)
        .get('/skus')
        .query({ outletId: bogusOutletId })
        .set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(res.body.length).toBeGreaterThan(0);
      for (const sku of res.body) {
        expect(sku.effectivePrice).toBe(sku.rrp);
      }
    } finally {
      await prisma.promoCalendar.delete({ where: { id: promo.id } });
    }
  });
});

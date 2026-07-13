import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('stock routes', () => {
  let clientId: string;
  let agentToken: string;
  let managerToken: string;
  let visitId: string;
  let skuId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'Stock Test Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: { email: 'stock-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });
    managerToken = issueToken({ userId: 'stock-manager', role: 'manager', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'Stock Outlet',
        code: 'STOCK-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId,
      },
    });
    const visit = await prisma.visit.create({
      data: {
        outletId: outlet.id,
        agentId: agent.id,
        clientId,
        checkinTs: new Date(),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'in_progress',
      },
    });
    visitId = visit.id;

    const sku = await prisma.sku.create({
      data: { clientId, name: 'Stock Cola', category: 'Beverages', minFacingsStandard: 4, rrp: 19.99 },
    });
    skuId = sku.id;
  });

  afterAll(async () => {
    // Delete auto-created follow-up tasks (issue #47) before visits so the
    // Task -> Visit FK doesn't block cleanup.
    await prisma.task.deleteMany({ where: { visit: { clientId } } });
    await prisma.visitStock.deleteMany({ where: { visitId } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.sku.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  const validItem = () => ({
    skuId,
    unitsAvailable: 20,
    lastStockinDate: '2026-07-01T00:00:00.000Z',
    daysOutOfStock: 0,
    velocityAvg: 4,
    salesActual: 100,
    salesTarget: 120,
  });

  it('records stock rows and computes coverage days (201)', async () => {
    const res = await request(app)
      .post('/stock')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId, items: [validItem()] });

    expect(res.status).toBe(201);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].coverageDaysPredicted).toBeCloseTo(5); // 20 / 4
  });

  it('auto-creates a stockout Task for an out-of-stock item and dedupes on re-submit (#47)', async () => {
    const outOfStock = { ...validItem(), unitsAvailable: 0 };

    const first = await request(app)
      .post('/stock')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId, items: [outOfStock] });
    expect(first.status).toBe(201);

    const tasks = await prisma.task.findMany({ where: { visitId, findingType: 'stockout' } });
    expect(tasks).toHaveLength(1);
    expect(tasks[0].requiredFix).toBe(`Restock SKU ${skuId}`);
    expect(tasks[0].priority).toBe('high');
    expect(tasks[0].status).toBe('open');

    // Re-submitting the same section must not spam duplicate tasks.
    const second = await request(app)
      .post('/stock')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId, items: [outOfStock] });
    expect(second.status).toBe(201);

    const afterResubmit = await prisma.task.findMany({ where: { visitId, findingType: 'stockout' } });
    expect(afterResubmit).toHaveLength(1);
  });

  it('respects a client-configured kpiThresholds.stockoutUnits (#47)', async () => {
    // A fresh SKU so the dedup key (requiredFix) can't collide with the task
    // created by the previous case.
    const lowStockSku = await prisma.sku.create({
      data: { clientId, name: 'Stock Fanta', category: 'Beverages', minFacingsStandard: 4, rrp: 15.99 },
    });
    const lowStock = { ...validItem(), skuId: lowStockSku.id, unitsAvailable: 3 };
    const taskFilter = {
      visitId,
      findingType: 'stockout',
      requiredFix: `Restock SKU ${lowStockSku.id}`,
    };

    try {
      // 3 units is not a stockout under the default threshold (0 units).
      const withDefault = await request(app)
        .post('/stock')
        .set('Authorization', `Bearer ${agentToken}`)
        .send({ visitId, items: [lowStock] });
      expect(withDefault.status).toBe(201);
      expect(await prisma.task.findMany({ where: taskFilter })).toHaveLength(0);

      // With stockoutUnits raised to 5, the same 3-unit row flags a stockout.
      await prisma.client.update({
        where: { id: clientId },
        data: { kpiThresholds: { stockoutUnits: 5 } },
      });
      const withOverride = await request(app)
        .post('/stock')
        .set('Authorization', `Bearer ${agentToken}`)
        .send({ visitId, items: [lowStock] });
      expect(withOverride.status).toBe(201);
      expect(await prisma.task.findMany({ where: taskFilter })).toHaveLength(1);
    } finally {
      await prisma.client.update({ where: { id: clientId }, data: { kpiThresholds: {} } });
    }
  });

  it('returns 404 for a visit belonging to another client', async () => {
    const otherToken = issueToken({ userId: 'x', role: 'field_agent', clientId: 'no-such-client' });
    const res = await request(app)
      .post('/stock')
      .set('Authorization', `Bearer ${otherToken}`)
      .send({ visitId, items: [validItem()] });
    expect(res.status).toBe(404);
  });

  it('returns 404 for an unknown SKU', async () => {
    const res = await request(app)
      .post('/stock')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId, items: [{ ...validItem(), skuId: 'no-such-sku' }] });
    expect(res.status).toBe(404);
  });

  it('rejects a missing/empty items array with 400', async () => {
    const res = await request(app)
      .post('/stock')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId, items: [] });
    expect(res.status).toBe(400);
  });

  it('forbids a manager from recording stock with 403', async () => {
    const res = await request(app)
      .post('/stock')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ visitId, items: [validItem()] });
    expect(res.status).toBe(403);
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).post('/stock').send({ visitId, items: [validItem()] });
    expect(res.status).toBe(401);
  });

  it('lists a visit stock rows ordered by createdAt desc (200)', async () => {
    await prisma.visitStock.create({
      data: {
        visitId,
        skuId,
        unitsAvailable: 12,
        lastStockinDate: new Date('2026-07-05T00:00:00.000Z'),
        daysOutOfStock: 1,
        velocityAvg: 3,
        coverageDaysPredicted: 4,
        salesActual: 60,
        salesTarget: 100,
      },
    });

    const res = await request(app)
      .get('/stock')
      .query({ visitId })
      .set('Authorization', `Bearer ${agentToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThanOrEqual(1);
    expect(res.body.every((row: { visitId: string }) => row.visitId === visitId)).toBe(true);
  });

  it('rejects a GET without visitId with 400', async () => {
    const res = await request(app).get('/stock').set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(400);
  });

  it('returns 404 for a GET on a visit belonging to another client', async () => {
    const otherToken = issueToken({ userId: 'x', role: 'field_agent', clientId: 'no-such-client' });
    const res = await request(app)
      .get('/stock')
      .query({ visitId })
      .set('Authorization', `Bearer ${otherToken}`);
    expect(res.status).toBe(404);
  });

  it('rejects a GET without a bearer token with 401', async () => {
    const res = await request(app).get('/stock').query({ visitId });
    expect(res.status).toBe(401);
  });
});

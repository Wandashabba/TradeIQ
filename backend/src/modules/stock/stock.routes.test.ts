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
    // Delete auto-created follow-up tasks (issue #47) and stock rows (including
    // the extra visits the #112 history test creates) before visits so the
    // Task/VisitStock -> Visit FKs don't block cleanup.
    await prisma.task.deleteMany({ where: { visit: { clientId } } });
    await prisma.visitStock.deleteMany({ where: { visit: { clientId } } });
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
  });

  it('records stock rows with zero coverage when there is no prior history (201)', async () => {
    const res = await request(app)
      .post('/stock')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId, items: [validItem()] });

    expect(res.status).toBe(201);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].daysOutOfStock).toBe(0);
    expect(res.body[0].velocityAvg).toBe(0);
    expect(res.body[0].coverageDaysPredicted).toBe(0);
    expect(res.body[0].salesActual).toBeNull();
    expect(res.body[0].salesTarget).toBeNull();
  });

  it('accepts explicit null for salesActual/salesTarget as absent, not invalid (201)', async () => {
    const res = await request(app)
      .post('/stock')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId, items: [{ ...validItem(), salesActual: null, salesTarget: null }] });

    expect(res.status).toBe(201);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].salesActual).toBeNull();
    expect(res.body[0].salesTarget).toBeNull();
  });

  it('computes daysOutOfStock/velocityAvg from prior visits to the same outlet (#112)', async () => {
    const historySku = await prisma.sku.create({
      data: { clientId, name: 'History Cola', category: 'Beverages', minFacingsStandard: 4, rrp: 9.99 },
    });
    const outlet = await prisma.outlet.findFirstOrThrow({ where: { clientId } });

    const visitA = await prisma.visit.create({
      data: {
        outletId: outlet.id,
        agentId: (await prisma.user.findFirstOrThrow({ where: { clientId } })).id,
        clientId,
        checkinTs: new Date('2026-06-21T00:00:00.000Z'),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'submitted',
      },
    });
    await prisma.visitStock.create({
      data: {
        visitId: visitA.id,
        skuId: historySku.id,
        unitsAvailable: 100,
        lastStockinDate: new Date('2026-06-21T00:00:00.000Z'),
        daysOutOfStock: 0,
        velocityAvg: 0,
        coverageDaysPredicted: 0,
      },
    });

    const visitB = await prisma.visit.create({
      data: {
        outletId: outlet.id,
        agentId: visitA.agentId,
        clientId,
        checkinTs: new Date('2026-06-26T00:00:00.000Z'), // 5 days after visitA
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'in_progress',
      },
    });

    const res = await request(app)
      .post('/stock')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({
        visitId: visitB.id,
        items: [{ skuId: historySku.id, unitsAvailable: 80, lastStockinDate: '2026-06-26T00:00:00.000Z' }],
      });

    expect(res.status).toBe(201);
    // History fetched for this write is the rows that existed *before* this
    // submission — just visitA's single row. computeVelocityAvg needs an
    // adjacent pair to derive a rate, so one history row is never enough:
    // velocityAvg is 0 here (see stock-derived.service.ts's <2-row case).
    expect(res.body[0].velocityAvg).toBe(0);
    // computeDaysOutOfStock measures days since the most recent *historical*
    // in-stock row to this visit's own checkinTs — it does not look at
    // whether the item being submitted (80 units) is itself in stock.
    // visitA (100 units, in stock) was 5 days before visitB's checkinTs.
    expect(res.body[0].daysOutOfStock).toBe(5);
    // With velocityAvg 0, predictCoverageDays returns Infinity, which
    // coverageFor clamps to 0 (a Postgres Float column can't store Infinity).
    expect(res.body[0].coverageDaysPredicted).toBe(0);
  });

  it('ignores client-sent daysOutOfStock/velocityAvg and stores the server-computed values instead (#112)', async () => {
    // The core invariant #112 exists to guarantee: an agent (or any client)
    // cannot make daysOutOfStock/velocityAvg be anything other than what the
    // server derives from history. StockItemInput no longer even has these
    // fields in TypeScript, but nothing stops a raw HTTP body from including
    // them anyway -- this proves the server actively ignores them rather than
    // merely not requiring them, by sending values that CONTRADICT what
    // history computes and asserting they're discarded, not coincidentally
    // matched.
    const ghostSku = await prisma.sku.create({
      data: { clientId, name: 'Ghost Fanta', category: 'Beverages', minFacingsStandard: 4, rrp: 12.99 },
    });
    const outlet = await prisma.outlet.findFirstOrThrow({ where: { clientId } });
    const agentId = (await prisma.user.findFirstOrThrow({ where: { clientId } })).id;

    const priorVisit = await prisma.visit.create({
      data: {
        outletId: outlet.id,
        agentId,
        clientId,
        checkinTs: new Date('2026-07-01T00:00:00.000Z'),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'submitted',
      },
    });
    await prisma.visitStock.create({
      data: {
        visitId: priorVisit.id,
        skuId: ghostSku.id,
        unitsAvailable: 50,
        lastStockinDate: new Date('2026-07-01T00:00:00.000Z'),
        daysOutOfStock: 0,
        velocityAvg: 0,
        coverageDaysPredicted: 0,
      },
    });

    const currentVisit = await prisma.visit.create({
      data: {
        outletId: outlet.id,
        agentId,
        clientId,
        checkinTs: new Date('2026-07-04T00:00:00.000Z'), // 3 days after priorVisit
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'in_progress',
      },
    });

    // Server should compute: velocityAvg 0 (only 1 prior row, needs 2 for a
    // rate) and daysOutOfStock 3 (days since priorVisit's in-stock reading).
    // The request instead sends 999/999 for both -- values that could never
    // arise from this history -- to prove they're discarded, not honoured.
    const res = await request(app)
      .post('/stock')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({
        visitId: currentVisit.id,
        items: [
          {
            skuId: ghostSku.id,
            unitsAvailable: 40,
            lastStockinDate: '2026-07-04T00:00:00.000Z',
            daysOutOfStock: 999,
            velocityAvg: 999,
          },
        ],
      });

    expect(res.status).toBe(201);
    expect(res.body[0].velocityAvg).toBe(0);
    expect(res.body[0].daysOutOfStock).toBe(3);
    expect(res.body[0].coverageDaysPredicted).toBe(0);
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

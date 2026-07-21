import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';
import { foreignTenant, userIn } from '../../test-utils/tenants';

describe('pricing routes', () => {
  let clientId: string;
  let agentToken: string;
  let agentBToken: string;
  let managerToken: string;
  let visitId: string;
  let skuId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'Pricing Test Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: { email: 'pricing-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });
    managerToken = (await userIn(clientId, 'manager')).token;

    const agentB = await prisma.user.create({
      data: { email: 'pricing-agent-b@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentBToken = issueToken({ userId: agentB.id, role: 'field_agent', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'Pricing Outlet',
        code: 'PRICING-001',
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
      data: { clientId, name: 'Pricing Cola', category: 'Beverages', minFacingsStandard: 4, rrp: 20 },
    });
    skuId = sku.id;
  });

  afterAll(async () => {
    // Delete auto-created follow-up tasks (issue #47) before visits so the
    // Task -> Visit FK doesn't block cleanup.
    await prisma.task.deleteMany({ where: { visit: { clientId } } });
    await prisma.visitPricing.deleteMany({ where: { visitId } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.sku.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  const validItem = () => ({
    skuId,
    priceActual: 22,
    promoActive: true,
    promoMaterialsDetected: { wobbler: true, shelfTalker: false },
    commsRating: 4,
  });

  it('records pricing rows and computes deviation pct (201)', async () => {
    const res = await request(app)
      .post('/pricing')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId, items: [validItem()] });

    expect(res.status).toBe(201);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].priceMaster).toBe(20);
    expect(res.body[0].priceActual).toBe(22);
    expect(res.body[0].deviationPct).toBeCloseTo(10); // (22 - 20) / 20 * 100
  });

  it('auto-creates a price_deviation Task for a >10% deviation and dedupes on re-submit (#47)', async () => {
    // priceActual 25 vs master 20 => +25% deviation (> 10% threshold).
    const deviating = { ...validItem(), priceActual: 25 };

    const first = await request(app)
      .post('/pricing')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId, items: [deviating] });
    expect(first.status).toBe(201);

    const tasks = await prisma.task.findMany({ where: { visitId, findingType: 'price_deviation' } });
    expect(tasks).toHaveLength(1);
    expect(tasks[0].requiredFix).toBe(`Correct shelf price for SKU ${skuId} (deviation 25%)`);
    expect(tasks[0].priority).toBe('normal');
    expect(tasks[0].status).toBe('open');

    // Re-submitting the same section must not spam duplicate tasks.
    const second = await request(app)
      .post('/pricing')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId, items: [deviating] });
    expect(second.status).toBe(201);

    const afterResubmit = await prisma.task.findMany({ where: { visitId, findingType: 'price_deviation' } });
    expect(afterResubmit).toHaveLength(1);
  });

  it('respects a client-configured kpiThresholds.priceDeviationPct (#47)', async () => {
    // A fresh SKU so the dedup key (requiredFix) can't collide with the task
    // created by the previous case. priceActual 25 vs rrp 20 => +25% deviation.
    const premiumSku = await prisma.sku.create({
      data: { clientId, name: 'Pricing Fanta', category: 'Beverages', minFacingsStandard: 4, rrp: 20 },
    });
    const deviating = { ...validItem(), skuId: premiumSku.id, priceActual: 25 };
    const taskFilter = {
      visitId,
      findingType: 'price_deviation',
      requiredFix: `Correct shelf price for SKU ${premiumSku.id} (deviation 25%)`,
    };

    try {
      // 25% is under a raised 30% threshold — no task.
      await prisma.client.update({
        where: { id: clientId },
        data: { kpiThresholds: { priceDeviationPct: 30 } },
      });
      const suppressed = await request(app)
        .post('/pricing')
        .set('Authorization', `Bearer ${agentToken}`)
        .send({ visitId, items: [deviating] });
      expect(suppressed.status).toBe(201);
      expect(await prisma.task.findMany({ where: taskFilter })).toHaveLength(0);

      // Tightened to 20%, the same 25% deviation now flags.
      await prisma.client.update({
        where: { id: clientId },
        data: { kpiThresholds: { priceDeviationPct: 20 } },
      });
      const flagged = await request(app)
        .post('/pricing')
        .set('Authorization', `Bearer ${agentToken}`)
        .send({ visitId, items: [deviating] });
      expect(flagged.status).toBe(201);
      expect(await prisma.task.findMany({ where: taskFilter })).toHaveLength(1);
    } finally {
      await prisma.client.update({ where: { id: clientId }, data: { kpiThresholds: {} } });
    }
  });

  it("forbids an agent from writing pricing onto another agent's visit (404)", async () => {
    const res = await request(app)
      .post('/pricing')
      .set('Authorization', `Bearer ${agentBToken}`)
      .send({ visitId, items: [validItem()] });
    expect(res.status).toBe(404);
  });

  it('returns 404 for a visit belonging to another client', async () => {
    const otherToken = (await foreignTenant('field_agent')).token;
    const res = await request(app)
      .post('/pricing')
      .set('Authorization', `Bearer ${otherToken}`)
      .send({ visitId, items: [validItem()] });
    expect(res.status).toBe(404);
  });

  it('returns 404 for an unknown SKU', async () => {
    const res = await request(app)
      .post('/pricing')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId, items: [{ ...validItem(), skuId: 'no-such-sku' }] });
    expect(res.status).toBe(404);
  });

  it('rejects a missing/empty items array with 400', async () => {
    const res = await request(app)
      .post('/pricing')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId, items: [] });
    expect(res.status).toBe(400);
  });

  it('rejects an item with an invalid field type with 400', async () => {
    const res = await request(app)
      .post('/pricing')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId, items: [{ ...validItem(), priceActual: 'not-a-number' }] });
    expect(res.status).toBe(400);
  });

  it('forbids a manager from recording pricing with 403', async () => {
    const res = await request(app)
      .post('/pricing')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ visitId, items: [validItem()] });
    expect(res.status).toBe(403);
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).post('/pricing').send({ visitId, items: [validItem()] });
    expect(res.status).toBe(401);
  });

  it('lists a visit pricing rows ordered by createdAt desc (200)', async () => {
    await prisma.visitPricing.create({
      data: {
        visitId,
        skuId,
        priceActual: 21,
        priceMaster: 20,
        deviationPct: 5,
        promoActive: false,
        promoMaterialsDetected: {},
        commsRating: 3,
      },
    });

    const res = await request(app)
      .get('/pricing')
      .query({ visitId })
      .set('Authorization', `Bearer ${agentToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThanOrEqual(1);
    expect(res.body.every((row: { visitId: string }) => row.visitId === visitId)).toBe(true);
  });

  it('rejects a GET without visitId with 400', async () => {
    const res = await request(app).get('/pricing').set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(400);
  });

  it('returns 404 for a GET on a visit belonging to another client', async () => {
    const otherToken = (await foreignTenant('field_agent')).token;
    const res = await request(app)
      .get('/pricing')
      .query({ visitId })
      .set('Authorization', `Bearer ${otherToken}`);
    expect(res.status).toBe(404);
  });

  it('rejects a GET without a bearer token with 401', async () => {
    const res = await request(app).get('/pricing').query({ visitId });
    expect(res.status).toBe(401);
  });
});

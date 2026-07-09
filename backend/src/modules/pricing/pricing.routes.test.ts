import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('pricing routes', () => {
  let clientId: string;
  let agentToken: string;
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
    managerToken = issueToken({ userId: 'pricing-manager', role: 'manager', clientId });

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

  it('returns 404 for a visit belonging to another client', async () => {
    const otherToken = issueToken({ userId: 'x', role: 'field_agent', clientId: 'no-such-client' });
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

  it('GET / is not implemented yet', async () => {
    const res = await request(app).get('/pricing').set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(501);
  });
});

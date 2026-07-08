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

  it('GET / is not implemented yet', async () => {
    const res = await request(app).get('/stock').set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(501);
  });
});

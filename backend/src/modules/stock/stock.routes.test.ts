import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('stock routes', () => {
  let clientId: string;
  let token: string;
  let visitId: string;
  let skuId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'Test Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: {
        email: 'stock-test-agent@example.com',
        passwordHash: 'unused-in-this-test',
        role: 'field_agent',
        clientId,
      },
    });
    token = issueToken({ userId: agent.id, role: 'field_agent', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'Test Outlet',
        code: 'STOCK-TEST-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'territory-1',
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
      data: { clientId, name: 'Test SKU', category: 'Beverages', minFacingsStandard: 4, rrp: 19.99 },
    });
    skuId = sku.id;
  });

  afterAll(async () => {
    await prisma.visitStock.deleteMany({ where: { visitId } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.sku.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  it('creates a VisitStock row with a server-computed coverageDaysPredicted', async () => {
    const res = await request(app)
      .post('/stock')
      .set('Authorization', `Bearer ${token}`)
      .send({
        visitId,
        skuId,
        unitsAvailable: 40,
        lastStockinDate: '2026-06-30',
        daysOutOfStock: 0,
        velocityAvg: 10,
        salesActual: 350,
        salesTarget: 400,
      });

    expect(res.status).toBe(201);
    expect(res.body.visitId).toBe(visitId);
    expect(res.body.skuId).toBe(skuId);
    expect(res.body.coverageDaysPredicted).toBe(4);
  });

  it('returns 404 when the visit belongs to another client', async () => {
    const otherClient = await prisma.client.create({
      data: { name: 'Other Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    const otherAgent = await prisma.user.create({
      data: {
        email: 'stock-test-agent-b@example.com',
        passwordHash: 'unused-in-this-test',
        role: 'field_agent',
        clientId: otherClient.id,
      },
    });
    const otherOutlet = await prisma.outlet.create({
      data: {
        name: 'Other Outlet',
        code: 'STOCK-TEST-OTHER-001',
        channelType: 'hypermarket',
        lat: -25.7461,
        lng: 28.1881,
        territoryId: 'territory-2',
        clientId: otherClient.id,
      },
    });
    const otherVisit = await prisma.visit.create({
      data: {
        outletId: otherOutlet.id,
        agentId: otherAgent.id,
        clientId: otherClient.id,
        checkinTs: new Date(),
        checkinLat: -25.7461,
        checkinLng: 28.1881,
        geofencePass: true,
        status: 'in_progress',
      },
    });

    try {
      // Authenticate as the ORIGINAL client with a skuId that IS valid for
      // them, so only the cross-tenant visitId can cause the 404 — proves
      // the visit-tenant check independently, rather than relying on the
      // sku check to also (coincidentally) fail and mask a broken visit check.
      const res = await request(app)
        .post('/stock')
        .set('Authorization', `Bearer ${token}`)
        .send({
          visitId: otherVisit.id,
          skuId,
          unitsAvailable: 40,
          lastStockinDate: '2026-06-30',
          daysOutOfStock: 0,
          velocityAvg: 10,
          salesActual: 350,
          salesTarget: 400,
        });

      expect(res.status).toBe(404);
    } finally {
      await prisma.visit.deleteMany({ where: { clientId: otherClient.id } });
      await prisma.outlet.deleteMany({ where: { clientId: otherClient.id } });
      await prisma.user.deleteMany({ where: { clientId: otherClient.id } });
      await prisma.client.delete({ where: { id: otherClient.id } });
    }
  });

  it('returns 404 when the sku belongs to another client', async () => {
    const otherClient = await prisma.client.create({
      data: { name: 'Other Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    const otherSku = await prisma.sku.create({
      data: { clientId: otherClient.id, name: 'Other SKU', category: 'Snacks', minFacingsStandard: 2, rrp: 9.99 },
    });

    try {
      const res = await request(app)
        .post('/stock')
        .set('Authorization', `Bearer ${token}`)
        .send({
          visitId,
          skuId: otherSku.id,
          unitsAvailable: 40,
          lastStockinDate: '2026-06-30',
          daysOutOfStock: 0,
          velocityAvg: 10,
          salesActual: 350,
          salesTarget: 400,
        });

      expect(res.status).toBe(404);
    } finally {
      await prisma.sku.deleteMany({ where: { clientId: otherClient.id } });
      await prisma.client.delete({ where: { id: otherClient.id } });
    }
  });

  it('rejects a request with a missing required field', async () => {
    const res = await request(app)
      .post('/stock')
      .set('Authorization', `Bearer ${token}`)
      .send({ visitId, skuId });

    expect(res.status).toBe(400);
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).post('/stock').send({ visitId, skuId });
    expect(res.status).toBe(401);
  });

  it('GET / is not implemented yet', async () => {
    const res = await request(app).get('/stock').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(501);
  });
});

import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('skus routes', () => {
  let clientId: string;
  let token: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'Test Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    token = issueToken({ userId: 'seed-user', role: 'manager', clientId });

    await prisma.sku.create({
      data: { clientId, name: 'Test SKU', category: 'Beverages', minFacingsStandard: 4, rrp: 19.99 },
    });
  });

  afterAll(async () => {
    await prisma.sku.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  it("lists SKUs for the caller's client", async () => {
    const res = await request(app).get('/skus').set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].name).toBe('Test SKU');
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).get('/skus');
    expect(res.status).toBe(401);
  });

  it('does not leak SKUs across clients', async () => {
    const otherClient = await prisma.client.create({
      data: { name: 'Other Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    await prisma.sku.create({
      data: { clientId: otherClient.id, name: 'Other Client SKU', category: 'Snacks', minFacingsStandard: 2, rrp: 9.99 },
    });

    try {
      const res = await request(app).get('/skus').set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(res.body.some((sku: { name: string }) => sku.name === 'Other Client SKU')).toBe(false);
    } finally {
      await prisma.sku.deleteMany({ where: { clientId: otherClient.id } });
      await prisma.client.delete({ where: { id: otherClient.id } });
    }
  });
});

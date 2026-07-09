import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('skus routes', () => {
  let clientId: string;
  let token: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'Sku Test Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    token = issueToken({ userId: 'sku-agent', role: 'field_agent', clientId });

    await prisma.sku.create({
      data: { clientId, name: 'Test Cola 500ml', category: 'Beverages', minFacingsStandard: 4, rrp: 19.99 },
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
    expect(res.body[0].name).toBe('Test Cola 500ml');
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).get('/skus');
    expect(res.status).toBe(401);
  });

  it('does not leak SKUs across clients', async () => {
    const clientB = await prisma.client.create({
      data: { name: 'Sku Client B', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    const tokenB = issueToken({ userId: 'sku-agent-b', role: 'field_agent', clientId: clientB.id });
    try {
      const res = await request(app).get('/skus').set('Authorization', `Bearer ${tokenB}`);
      expect(res.status).toBe(200);
      expect(res.body).toHaveLength(0);
    } finally {
      await prisma.client.delete({ where: { id: clientB.id } });
    }
  });
});

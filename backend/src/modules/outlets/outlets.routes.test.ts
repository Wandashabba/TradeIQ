import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('outlets routes', () => {
  let clientId: string;
  let token: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: {
        name: 'Test Client',
        industry: 'FMCG',
        scorecardWeights: {},
        kpiThresholds: {},
      },
    });
    clientId = client.id;
    token = issueToken({ userId: 'seed-user', role: 'manager', clientId });
  });

  afterAll(async () => {
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  it('creates and lists outlets for the caller\'s client', async () => {
    const createRes = await request(app)
      .post('/outlets')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: 'Test Hypermarket',
        code: 'TH-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'territory-1',
        teamProfile: { headcount: 3 },
      });

    expect(createRes.status).toBe(201);
    expect(createRes.body.name).toBe('Test Hypermarket');

    const listRes = await request(app)
      .get('/outlets')
      .set('Authorization', `Bearer ${token}`);

    expect(listRes.status).toBe(200);
    expect(listRes.body).toHaveLength(1);
    expect(listRes.body[0].code).toBe('TH-001');
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).get('/outlets');
    expect(res.status).toBe(401);
  });
});

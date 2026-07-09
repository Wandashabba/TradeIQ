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

  it('creates an outlet with 201 when teamProfile is omitted', async () => {
    const res = await request(app)
      .post('/outlets')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: 'No Team Profile Outlet',
        code: 'NTP-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'territory-1',
      });

    expect(res.status).toBe(201);
    expect(res.body.teamProfile).toBeNull();
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).get('/outlets');
    expect(res.status).toBe(401);
  });

  it('forbids a field agent from creating an outlet with 403', async () => {
    const agentToken = issueToken({ userId: 'seed-agent', role: 'field_agent', clientId });
    const res = await request(app)
      .post('/outlets')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({
        name: 'Agent Outlet',
        code: 'AGT-403',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'territory-1',
      });

    expect(res.status).toBe(403);

    const outlets = await prisma.outlet.findMany({ where: { code: 'AGT-403' } });
    expect(outlets).toHaveLength(0);
  });

  it('rejects outlet creation with a missing required field', async () => {
    const res = await request(app)
      .post('/outlets')
      .set('Authorization', `Bearer ${token}`)
      .send({
        code: 'MISSING-NAME',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'territory-1',
        teamProfile: {},
      });

    expect(res.status).toBe(400);
  });

  it('rejects a duplicate outlet code with 409', async () => {
    const payload = {
      name: 'Duplicate Outlet',
      code: 'DUP-001',
      channelType: 'hypermarket',
      lat: -26.2041,
      lng: 28.0473,
      territoryId: 'territory-1',
      teamProfile: {},
    };

    const firstRes = await request(app)
      .post('/outlets')
      .set('Authorization', `Bearer ${token}`)
      .send(payload);
    expect(firstRes.status).toBe(201);

    const secondRes = await request(app)
      .post('/outlets')
      .set('Authorization', `Bearer ${token}`)
      .send(payload);
    expect(secondRes.status).toBe(409);
  });

  it('does not leak outlets across clients', async () => {
    const clientB = await prisma.client.create({
      data: {
        name: 'Other Client',
        industry: 'FMCG',
        scorecardWeights: {},
        kpiThresholds: {},
      },
    });
    const tokenB = issueToken({ userId: 'seed-user-b', role: 'manager', clientId: clientB.id });

    try {
      const createResB = await request(app)
        .post('/outlets')
        .set('Authorization', `Bearer ${tokenB}`)
        .send({
          name: 'Client B Outlet',
          code: 'CB-001',
          channelType: 'convenience',
          lat: -25.7461,
          lng: 28.1881,
          territoryId: 'territory-2',
          teamProfile: {},
        });
      expect(createResB.status).toBe(201);

      const listResA = await request(app)
        .get('/outlets')
        .set('Authorization', `Bearer ${token}`);

      expect(listResA.status).toBe(200);
      expect(listResA.body.some((outlet: { code: string }) => outlet.code === 'CB-001')).toBe(false);
    } finally {
      await prisma.outlet.deleteMany({ where: { clientId: clientB.id } });
      await prisma.client.delete({ where: { id: clientB.id } });
    }
  });
});

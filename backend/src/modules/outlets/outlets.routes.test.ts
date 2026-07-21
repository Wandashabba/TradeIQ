import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';

import { userIn } from '../../test-utils/tenants';

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
    token = (await userIn(clientId, 'manager')).token;

    // Outlet creation now requires territoryId to name a real territory of the
    // caller's client, so the territory these tests post has to exist.
    await prisma.territory.create({
      data: { clientId, name: 'Territory One', code: 'territory-1' },
    });
  });

  afterAll(async () => {
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.territory.deleteMany({ where: { clientId } });
    // userIn() puts a real user in this tenant now, and the FK blocks
    // deleting a client that still has one.
    await prisma.user.deleteMany({ where: { clientId: clientId } });
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
    const agentToken = (await userIn(clientId, 'field_agent')).token;
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

  it('rejects an outlet whose territory does not exist', async () => {
    // Previously accepted with 201. The outlet was then silently absent from
    // coverage counts and every territory-scoped view, with nothing to explain
    // why — the failure looked like missing data, not bad input.
    const res = await request(app)
      .post('/outlets')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: 'Typo Outlet',
        code: 'TYPO-001',
        channelType: 'convenience',
        lat: -26.1,
        lng: 28.0,
        territoryId: 'terrritory-1',
      });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('terrritory-1');
  });

  it('rejects a territory NAME where a code is required', async () => {
    // The mistake seen in real use: an outlet created against territory
    // "Hurlingham" whose actual code was "2773u". Looks right to a human,
    // matches nothing.
    const res = await request(app)
      .post('/outlets')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: 'Name Not Code',
        code: 'NNC-001',
        channelType: 'convenience',
        lat: -26.1,
        lng: 28.0,
        territoryId: 'Territory One',
      });

    expect(res.status).toBe(400);
    // The message has to name the distinction, or the caller retries the same
    // string and concludes the API is broken.
    expect(res.body.error).toContain('code');
  });

  it('rejects a territory belonging to a different client', async () => {
    const clientC = await prisma.client.create({
      data: {
        name: 'Third Client',
        industry: 'FMCG',
        scorecardWeights: {},
        kpiThresholds: {},
      },
    });
    await prisma.territory.create({
      data: { clientId: clientC.id, name: 'Foreign', code: 'foreign-territory' },
    });

    try {
      const res = await request(app)
        .post('/outlets')
        .set('Authorization', `Bearer ${token}`)
        .send({
          name: 'Cross Tenant',
          code: 'XT-001',
          channelType: 'convenience',
          lat: -26.1,
          lng: 28.0,
          territoryId: 'foreign-territory',
        });

      // The lookup is scoped by clientId, so another tenant's territory code is
      // as unknown as one that does not exist anywhere.
      expect(res.status).toBe(400);
    } finally {
      await prisma.territory.deleteMany({ where: { clientId: clientC.id } });
      // userIn() puts a real user in this tenant now, and the FK blocks
      // deleting a client that still has one.
      await prisma.user.deleteMany({ where: { clientId: clientC.id } });
      await prisma.client.delete({ where: { id: clientC.id } });
    }
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
    const tokenB = (await userIn(clientB.id, 'manager')).token;
    await prisma.territory.create({
      data: { clientId: clientB.id, name: 'Territory Two', code: 'territory-2' },
    });

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
      await prisma.territory.deleteMany({ where: { clientId: clientB.id } });
      // userIn() puts a real user in this tenant now, and the FK blocks
      // deleting a client that still has one.
      await prisma.user.deleteMany({ where: { clientId: clientB.id } });
      await prisma.client.delete({ where: { id: clientB.id } });
    }
  });
});

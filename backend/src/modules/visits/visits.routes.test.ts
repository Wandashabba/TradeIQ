import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('visits routes', () => {
  let clientId: string;
  let token: string;
  let outletId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'Test Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: {
        email: 'visit-test-agent@example.com',
        passwordHash: 'unused-in-this-test',
        role: 'field_agent',
        clientId,
      },
    });
    token = issueToken({ userId: agent.id, role: 'field_agent', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'Test Outlet',
        code: 'VISIT-TEST-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'territory-1',
        clientId,
      },
    });
    outletId = outlet.id;
  });

  afterAll(async () => {
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  it('creates a Visit when the check-in is within the outlet geofence', async () => {
    const res = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${token}`)
      .send({ outletId, lat: -26.20400, lng: 28.0473 }); // ~11m north, within 50m

    expect(res.status).toBe(201);
    expect(res.body.outletId).toBe(outletId);
    expect(res.body.geofencePass).toBe(true);
    expect(res.body.status).toBe('in_progress');
  });

  it('rejects a check-in outside the outlet geofence with 422', async () => {
    const res = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${token}`)
      .send({ outletId, lat: -26.2100, lng: 28.0473 }); // ~650m away

    expect(res.status).toBe(422);

    // Scoped to this attempt's coordinates (rather than all visits for the
    // outlet) because an earlier test in this suite already created a
    // passing Visit for the same outlet at different coordinates.
    const visits = await prisma.visit.findMany({ where: { outletId, checkinLat: -26.21 } });
    expect(visits).toHaveLength(0);
  });

  it('returns 404 when the outlet belongs to another client', async () => {
    const otherClient = await prisma.client.create({
      data: { name: 'Other Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    const otherAgent = await prisma.user.create({
      data: {
        email: 'visit-test-agent-b@example.com',
        passwordHash: 'unused-in-this-test',
        role: 'field_agent',
        clientId: otherClient.id,
      },
    });
    const otherToken = issueToken({ userId: otherAgent.id, role: 'field_agent', clientId: otherClient.id });

    try {
      const res = await request(app)
        .post('/visits')
        .set('Authorization', `Bearer ${otherToken}`)
        .send({ outletId, lat: -26.2041, lng: 28.0473 });

      expect(res.status).toBe(404);
    } finally {
      await prisma.user.deleteMany({ where: { clientId: otherClient.id } });
      await prisma.client.delete({ where: { id: otherClient.id } });
    }
  });

  it('rejects a check-in with a missing required field', async () => {
    const res = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${token}`)
      .send({ outletId });

    expect(res.status).toBe(400);
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).post('/visits').send({ outletId, lat: -26.2041, lng: 28.0473 });
    expect(res.status).toBe(401);
  });

  it('forbids a manager from checking in with 403', async () => {
    const managerToken = issueToken({ userId: 'seed-manager', role: 'manager', clientId });
    const res = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ outletId, lat: -26.20400, lng: 28.0473 });

    expect(res.status).toBe(403);
  });

  it('stores the client-supplied check-in timestamp', async () => {
    const checkinTs = '2026-07-01T08:30:00.000Z';
    const res = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${token}`)
      .send({ outletId, lat: -26.20400, lng: 28.0473, checkinTs });

    expect(res.status).toBe(201);
    expect(res.body.checkinTs).toBe(checkinTs);
  });

  it('submits a visit and marks it submitted (200)', async () => {
    const createRes = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${token}`)
      .send({ outletId, lat: -26.20400, lng: 28.0473 });
    const visitId = createRes.body.id;

    const res = await request(app)
      .post(`/visits/${visitId}/submit`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('submitted');
  });

  it('returns 404 submitting a visit that belongs to another agent', async () => {
    const createRes = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${token}`)
      .send({ outletId, lat: -26.20400, lng: 28.0473 });
    const visitId = createRes.body.id;

    const otherAgentToken = issueToken({ userId: 'different-agent', role: 'field_agent', clientId });
    const res = await request(app)
      .post(`/visits/${visitId}/submit`)
      .set('Authorization', `Bearer ${otherAgentToken}`);

    expect(res.status).toBe(404);
  });

  it('forbids a manager from submitting a visit with 403', async () => {
    const createRes = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${token}`)
      .send({ outletId, lat: -26.20400, lng: 28.0473 });
    const visitId = createRes.body.id;

    const managerToken = issueToken({ userId: 'seed-manager', role: 'manager', clientId });
    const res = await request(app)
      .post(`/visits/${visitId}/submit`)
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(403);
  });

  it('GET / is not implemented yet', async () => {
    const res = await request(app).get('/visits').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(501);
  });
});

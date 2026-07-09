import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('visits routes', () => {
  let clientId: string;
  let clientBId: string;
  let token: string; // agent A (owning field agent)
  let agentBToken: string; // a second field agent in the same client
  let managerToken: string;
  let outletId: string;

  let agentAId: string;
  let agentBId: string;
  let agentAVisitId: string;
  let agentBVisitId: string;
  let clientBVisitId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'VISITS-Client-A', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const agentA = await prisma.user.create({
      data: {
        email: 'VISITS-agent-a@example.com',
        passwordHash: 'unused-in-this-test',
        role: 'field_agent',
        clientId,
      },
    });
    agentAId = agentA.id;
    token = issueToken({ userId: agentA.id, role: 'field_agent', clientId });

    const agentB = await prisma.user.create({
      data: {
        email: 'VISITS-agent-b@example.com',
        passwordHash: 'unused-in-this-test',
        role: 'field_agent',
        clientId,
      },
    });
    agentBId = agentB.id;
    agentBToken = issueToken({ userId: agentB.id, role: 'field_agent', clientId });

    managerToken = issueToken({ userId: 'VISITS-manager', role: 'manager', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'VISITS-Outlet-A',
        code: 'VISITS-OUT-A',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'territory-1',
        clientId,
      },
    });
    outletId = outlet.id;

    // Deterministic visits used by the GET /visits assertions.
    const agentAVisit = await prisma.visit.create({
      data: {
        outletId,
        agentId: agentAId,
        clientId,
        checkinTs: new Date('2026-07-02T08:00:00.000Z'),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        checkinDistanceM: 0,
        status: 'in_progress',
      },
    });
    agentAVisitId = agentAVisit.id;

    const agentBVisit = await prisma.visit.create({
      data: {
        outletId,
        agentId: agentBId,
        clientId,
        checkinTs: new Date('2026-07-02T09:00:00.000Z'),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        checkinDistanceM: 0,
        status: 'in_progress',
      },
    });
    agentBVisitId = agentBVisit.id;

    // A separate client whose visits must never leak across the tenant boundary.
    const clientB = await prisma.client.create({
      data: { name: 'VISITS-Client-B', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientBId = clientB.id;

    const agentC = await prisma.user.create({
      data: {
        email: 'VISITS-agent-c@example.com',
        passwordHash: 'unused-in-this-test',
        role: 'field_agent',
        clientId: clientBId,
      },
    });

    const outletB = await prisma.outlet.create({
      data: {
        name: 'VISITS-Outlet-B',
        code: 'VISITS-OUT-B',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'territory-1',
        clientId: clientBId,
      },
    });

    const clientBVisit = await prisma.visit.create({
      data: {
        outletId: outletB.id,
        agentId: agentC.id,
        clientId: clientBId,
        checkinTs: new Date('2026-07-02T10:00:00.000Z'),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        checkinDistanceM: 0,
        status: 'in_progress',
      },
    });
    clientBVisitId = clientBVisit.id;
  });

  afterAll(async () => {
    await prisma.checkInAttempt.deleteMany({ where: { clientId } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });

    await prisma.checkInAttempt.deleteMany({ where: { clientId: clientBId } });
    await prisma.visit.deleteMany({ where: { clientId: clientBId } });
    await prisma.outlet.deleteMany({ where: { clientId: clientBId } });
    await prisma.user.deleteMany({ where: { clientId: clientBId } });
    await prisma.client.delete({ where: { id: clientBId } });

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
    // The measured distance is persisted (no longer a hardcoded literal).
    expect(typeof res.body.checkinDistanceM).toBe('number');
    expect(res.body.checkinDistanceM).toBeGreaterThan(0);
    expect(res.body.checkinDistanceM).toBeLessThanOrEqual(50);
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
      data: { name: 'VISITS-Other-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    const otherAgent = await prisma.user.create({
      data: {
        email: 'VISITS-agent-404@example.com',
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

    const res = await request(app)
      .post(`/visits/${visitId}/submit`)
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(403);
  });

  describe('GET /visits', () => {
    it('returns the owning field agent their own visit', async () => {
      const res = await request(app).get('/visits').set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      const ids = res.body.map((v: { id: string }) => v.id);
      expect(ids).toContain(agentAVisitId);
      // Every returned visit belongs to the requesting agent.
      expect(res.body.every((v: { agentId: string }) => v.agentId === agentAId)).toBe(true);
    });

    it('does not let a field agent see another agent visit', async () => {
      const res = await request(app).get('/visits').set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      const ids = res.body.map((v: { id: string }) => v.id);
      expect(ids).not.toContain(agentBVisitId);
    });

    it('scopes a second field agent to their own visit', async () => {
      const res = await request(app).get('/visits').set('Authorization', `Bearer ${agentBToken}`);

      expect(res.status).toBe(200);
      const ids = res.body.map((v: { id: string }) => v.id);
      expect(ids).toContain(agentBVisitId);
      expect(ids).not.toContain(agentAVisitId);
    });

    it('returns all of the client visits to a manager', async () => {
      const res = await request(app).get('/visits').set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(200);
      const ids = res.body.map((v: { id: string }) => v.id);
      expect(ids).toContain(agentAVisitId);
      expect(ids).toContain(agentBVisitId);
    });

    it('does not leak visits from another client (cross-tenant isolation)', async () => {
      const agentRes = await request(app).get('/visits').set('Authorization', `Bearer ${token}`);
      const managerRes = await request(app)
        .get('/visits')
        .set('Authorization', `Bearer ${managerToken}`);

      expect(agentRes.status).toBe(200);
      expect(managerRes.status).toBe(200);
      const agentIds = agentRes.body.map((v: { id: string }) => v.id);
      const managerIds = managerRes.body.map((v: { id: string }) => v.id);
      expect(agentIds).not.toContain(clientBVisitId);
      expect(managerIds).not.toContain(clientBVisitId);
      // Never any foreign-client rows at all.
      expect(managerRes.body.every((v: { clientId: string }) => v.clientId === clientId)).toBe(true);
    });

    it('filters by status', async () => {
      const createRes = await request(app)
        .post('/visits')
        .set('Authorization', `Bearer ${token}`)
        .send({ outletId, lat: -26.20400, lng: 28.0473 });
      const submittedVisitId = createRes.body.id;
      await request(app)
        .post(`/visits/${submittedVisitId}/submit`)
        .set('Authorization', `Bearer ${token}`);

      const res = await request(app)
        .get('/visits?status=submitted')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.every((v: { status: string }) => v.status === 'submitted')).toBe(true);
      const ids = res.body.map((v: { id: string }) => v.id);
      expect(ids).toContain(submittedVisitId);
      // The seeded in_progress visit is excluded by the filter.
      expect(ids).not.toContain(agentAVisitId);
    });

    it('rejects an invalid status filter with 400', async () => {
      const res = await request(app)
        .get('/visits?status=bogus')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(400);
    });

    it('rejects requests without a bearer token', async () => {
      const res = await request(app).get('/visits');
      expect(res.status).toBe(401);
    });
  });
});

import request from 'supertest';
import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('territories routes', () => {
  let clientId: string;
  let otherClientId: string;
  let managerId: string;
  let agentId: string;
  let otherAgentId: string;
  let managerToken: string;
  let agentToken: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'TERR-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const manager = await prisma.user.create({
      data: { email: 'TERR-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    managerId = manager.id;
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });

    const agent = await prisma.user.create({
      data: { email: 'TERR-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentId = agent.id;
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });

    const otherClient = await prisma.client.create({
      data: { name: 'TERR-Other-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = otherClient.id;

    const otherAgent = await prisma.user.create({
      data: {
        email: 'TERR-other-agent@example.com',
        passwordHash: 'x',
        role: 'field_agent',
        clientId: otherClient.id,
      },
    });
    otherAgentId = otherAgent.id;
  });

  afterAll(async () => {
    await prisma.userTerritory.deleteMany({
      where: { territory: { clientId: { in: [clientId, otherClientId] } } },
    });
    await prisma.visit.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.territory.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.user.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.client.deleteMany({ where: { id: { in: [clientId, otherClientId] } } });
    await prisma.$disconnect();
  });

  it('creates a territory for the caller client', async () => {
    const res = await request(app)
      .post('/territories')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ name: 'TERR-North', code: 'TERR-N1', region: 'Gauteng' });
    expect(res.status).toBe(201);
    expect(res.body.name).toBe('TERR-North');
    expect(res.body.code).toBe('TERR-N1');
    expect(res.body.clientId).toBe(clientId);
  });

  it('rejects a duplicate code for the same client with 409', async () => {
    const res = await request(app)
      .post('/territories')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ name: 'TERR-North-Dup', code: 'TERR-N1' });
    expect(res.status).toBe(409);
  });

  it('rejects creation with a missing required field', async () => {
    const res = await request(app)
      .post('/territories')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ name: 'TERR-NoCode' });
    expect(res.status).toBe(400);
  });

  it('rejects territory creation by a field agent with 403', async () => {
    const res = await request(app)
      .post('/territories')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ name: 'TERR-South', code: 'TERR-S1' });
    expect(res.status).toBe(403);
  });

  it('rejects unauthenticated requests', async () => {
    const res = await request(app).get('/territories');
    expect(res.status).toBe(401);
  });

  it("lists the client's territories ordered by name for a manager", async () => {
    await request(app)
      .post('/territories')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ name: 'TERR-Alpha', code: 'TERR-A1' });

    const res = await request(app)
      .get('/territories')
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    const names = (res.body as Array<{ name: string }>).map((t) => t.name);
    expect(names).toContain('TERR-North');
    expect(names).toContain('TERR-Alpha');
    // ordered by name asc
    expect([...names].sort()).toEqual(names);
  });

  it('rejects a field agent listing territories with 403', async () => {
    // Previously open by omission while every other route on this router was
    // gated. Territories are a planning construct; no agent flow reads them,
    // and both app screens that do are manager/admin actions at the write end.
    const res = await request(app)
      .get('/territories')
      .set('Authorization', `Bearer ${agentToken}`);

    expect(res.status).toBe(403);
  });

  it('assigns an agent to a territory', async () => {
    const territory = await prisma.territory.create({
      data: { clientId, name: 'TERR-Assign', code: 'TERR-AS1' },
    });
    const res = await request(app)
      .post(`/territories/${territory.id}/agents`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ userId: agentId });
    expect(res.status).toBe(201);
    expect(res.body.territoryId).toBe(territory.id);
    expect(res.body.userId).toBe(agentId);
  });

  it('rejects assigning a user from another client with 404', async () => {
    const territory = await prisma.territory.create({
      data: { clientId, name: 'TERR-CrossClient', code: 'TERR-XC1' },
    });
    const res = await request(app)
      .post(`/territories/${territory.id}/agents`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ userId: otherAgentId });
    expect(res.status).toBe(404);
  });

  it('returns coverage with matching outlets and assigned agents', async () => {
    const territory = await prisma.territory.create({
      data: { clientId, name: 'TERR-Coverage', code: 'TERR-COV1' },
    });
    // Outlet linked by territoryId === territory.code, same client.
    const outlet = await prisma.outlet.create({
      data: {
        name: 'TERR-Outlet-In',
        code: 'TERR-OUT-IN',
        channelType: 'general_trade',
        lat: -26.2,
        lng: 28.04,
        territoryId: territory.code,
        clientId,
      },
    });
    // Non-matching outlet (different territory code) must be excluded.
    await prisma.outlet.create({
      data: {
        name: 'TERR-Outlet-Out',
        code: 'TERR-OUT-OUT',
        channelType: 'general_trade',
        lat: -26.2,
        lng: 28.04,
        territoryId: 'TERR-OTHER-CODE',
        clientId,
      },
    });
    await prisma.userTerritory.create({ data: { territoryId: territory.id, userId: managerId } });

    const res = await request(app)
      .get(`/territories/${territory.id}/coverage`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(200);
    expect(res.body.territory.id).toBe(territory.id);
    const outletIds = (res.body.outlets as Array<{ id: string }>).map((o) => o.id);
    expect(outletIds).toEqual([outlet.id]);
    const agentIds = (res.body.agents as Array<{ id: string }>).map((a) => a.id);
    expect(agentIds).toContain(managerId);
  });

  it('never exposes passwordHash on the agents in a coverage response', async () => {
    const territory = await prisma.territory.create({
      data: { clientId, name: 'TERR-NoHash', code: 'TERR-NOHASH' },
    });
    const assigned = await prisma.user.create({
      data: {
        email: 'TERR-hash-victim@example.com',
        passwordHash: 'super-secret-bcrypt-hash',
        role: 'manager',
        clientId,
      },
    });
    await prisma.userTerritory.create({
      data: { userId: assigned.id, territoryId: territory.id },
    });

    const res = await request(app)
      .get(`/territories/${territory.id}/coverage`)
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    const agents = res.body.agents as Array<Record<string, unknown>>;
    expect(agents.length).toBeGreaterThan(0);
    for (const agent of agents) {
      expect(agent).not.toHaveProperty('passwordHash');
    }
    // The whole serialized body, not just the parsed field — a hash must not
    // reach the wire by any path.
    expect(JSON.stringify(res.body)).not.toContain('super-secret-bcrypt-hash');
  });

  it('forbids a field agent from reading territory coverage', async () => {
    const territory = await prisma.territory.create({
      data: { clientId, name: 'TERR-AgentForbidden', code: 'TERR-FORBID' },
    });

    const res = await request(app)
      .get(`/territories/${territory.id}/coverage`)
      .set('Authorization', `Bearer ${agentToken}`);

    expect(res.status).toBe(403);
  });

  it('returns coverageRate computed from distinct visited outlets', async () => {
    const territory = await prisma.territory.create({
      data: { clientId, name: 'TERR-CoverageRate', code: 'TERR-COVR1' },
    });
    const outletA = await prisma.outlet.create({
      data: {
        name: 'TERR-Outlet-A',
        code: 'TERR-OUT-A',
        channelType: 'general_trade',
        lat: -26.2,
        lng: 28.04,
        territoryId: territory.code,
        clientId,
      },
    });
    const outletB = await prisma.outlet.create({
      data: {
        name: 'TERR-Outlet-B',
        code: 'TERR-OUT-B',
        channelType: 'general_trade',
        lat: -26.2,
        lng: 28.04,
        territoryId: territory.code,
        clientId,
      },
    });
    await prisma.outlet.create({
      data: {
        name: 'TERR-Outlet-C',
        code: 'TERR-OUT-C',
        channelType: 'general_trade',
        lat: -26.2,
        lng: 28.04,
        territoryId: territory.code,
        clientId,
      },
    });
    // Outlet A visited twice in-window; still counts once toward outletsVisited.
    await prisma.visit.create({
      data: {
        outletId: outletA.id,
        agentId,
        clientId,
        checkinTs: new Date('2026-07-01T09:00:00.000Z'),
        checkinLat: -26.2,
        checkinLng: 28.04,
        geofencePass: true,
        status: 'submitted',
      },
    });
    await prisma.visit.create({
      data: {
        outletId: outletA.id,
        agentId,
        clientId,
        checkinTs: new Date('2026-07-03T09:00:00.000Z'),
        checkinLat: -26.2,
        checkinLng: 28.04,
        geofencePass: true,
        status: 'submitted',
      },
    });
    await prisma.visit.create({
      data: {
        outletId: outletB.id,
        agentId,
        clientId,
        checkinTs: new Date('2026-07-05T09:00:00.000Z'),
        checkinLat: -26.2,
        checkinLng: 28.04,
        geofencePass: true,
        status: 'submitted',
      },
    });

    const res = await request(app)
      .get(`/territories/${territory.id}/coverage`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(200);
    expect(res.body.coverage).toEqual({ outletsVisited: 2, outletsTotal: 3, coverageRate: 66.67 });

    // Narrowing the window to exclude the outletB visit drops the rate.
    const windowed = await request(app)
      .get(`/territories/${territory.id}/coverage`)
      .query({ from: '2026-07-01T00:00:00.000Z', to: '2026-07-04T00:00:00.000Z' })
      .set('Authorization', `Bearer ${managerToken}`);
    expect(windowed.status).toBe(200);
    expect(windowed.body.coverage).toEqual({ outletsVisited: 1, outletsTotal: 3, coverageRate: 33.33 });
  });

  it('tags each outlet in the response with a visited boolean', async () => {
    const territory = await prisma.territory.create({
      data: { clientId, name: 'TERR-Visited', code: 'TERR-VIS1' },
    });
    const visitedOutlet = await prisma.outlet.create({
      data: {
        name: 'TERR-Outlet-Visited',
        code: 'TERR-OUT-VISITED',
        channelType: 'general_trade',
        lat: -26.2,
        lng: 28.04,
        territoryId: territory.code,
        clientId,
      },
    });
    const unvisitedOutlet = await prisma.outlet.create({
      data: {
        name: 'TERR-Outlet-Unvisited',
        code: 'TERR-OUT-UNVISITED',
        channelType: 'general_trade',
        lat: -26.2,
        lng: 28.04,
        territoryId: territory.code,
        clientId,
      },
    });
    await prisma.visit.create({
      data: {
        outletId: visitedOutlet.id,
        agentId,
        clientId,
        checkinTs: new Date('2026-07-01T09:00:00.000Z'),
        checkinLat: -26.2,
        checkinLng: 28.04,
        geofencePass: true,
        status: 'submitted',
      },
    });

    const res = await request(app)
      .get(`/territories/${territory.id}/coverage`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(200);
    const byId = new Map(
      (res.body.outlets as Array<{ id: string; visited: boolean }>).map((o) => [o.id, o.visited]),
    );
    expect(byId.get(visitedOutlet.id)).toBe(true);
    expect(byId.get(unvisitedOutlet.id)).toBe(false);
  });

  it('rejects an invalid from date with 400', async () => {
    const territory = await prisma.territory.create({
      data: { clientId, name: 'TERR-BadFrom', code: 'TERR-BADFROM1' },
    });
    const res = await request(app)
      .get(`/territories/${territory.id}/coverage`)
      .query({ from: 'not-a-date' })
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(400);
  });

  it('rejects an invalid to date with 400', async () => {
    const territory = await prisma.territory.create({
      data: { clientId, name: 'TERR-BadTo', code: 'TERR-BADTO1' },
    });
    const res = await request(app)
      .get(`/territories/${territory.id}/coverage`)
      .query({ to: 'not-a-date' })
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(400);
  });

  it('returns zero coverage for a territory with no outlets', async () => {
    const territory = await prisma.territory.create({
      data: { clientId, name: 'TERR-Empty', code: 'TERR-EMPTY1' },
    });
    const res = await request(app)
      .get(`/territories/${territory.id}/coverage`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(200);
    expect(res.body.outlets).toEqual([]);
    expect(res.body.coverage).toEqual({ outletsVisited: 0, outletsTotal: 0, coverageRate: 0 });
  });

  it('does not count an outlet with only an in-progress visit as visited', async () => {
    const territory = await prisma.territory.create({
      data: { clientId, name: 'TERR-InProgress', code: 'TERR-INPROG1' },
    });
    const outlet = await prisma.outlet.create({
      data: {
        name: 'TERR-Outlet-InProgress',
        code: 'TERR-OUT-INPROG',
        channelType: 'general_trade',
        lat: -26.2,
        lng: 28.04,
        territoryId: territory.code,
        clientId,
      },
    });
    // Check-in started but never submitted — should not count toward coverage.
    await prisma.visit.create({
      data: {
        outletId: outlet.id,
        agentId,
        clientId,
        checkinTs: new Date('2026-07-01T09:00:00.000Z'),
        checkinLat: -26.2,
        checkinLng: 28.04,
        geofencePass: true,
        status: 'in_progress',
      },
    });

    const res = await request(app)
      .get(`/territories/${territory.id}/coverage`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(200);
    expect(res.body.coverage).toEqual({ outletsVisited: 0, outletsTotal: 1, coverageRate: 0 });
  });

  it('returns 404 coverage for a territory of another client', async () => {
    const otherTerritory = await prisma.territory.create({
      data: { clientId: otherClientId, name: 'TERR-Foreign', code: 'TERR-FGN1' },
    });
    const res = await request(app)
      .get(`/territories/${otherTerritory.id}/coverage`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(404);
  });

  it('surfaces P2002 typing for duplicate assignments as 409', async () => {
    const territory = await prisma.territory.create({
      data: { clientId, name: 'TERR-Idem', code: 'TERR-IDEM1' },
    });
    const first = await request(app)
      .post(`/territories/${territory.id}/agents`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ userId: agentId });
    expect(first.status).toBe(201);

    const second = await request(app)
      .post(`/territories/${territory.id}/agents`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ userId: agentId });
    expect(second.status).toBe(409);

    // Assert the underlying Prisma error is the known-request type we catch.
    try {
      await prisma.userTerritory.create({ data: { territoryId: territory.id, userId: agentId } });
    } catch (err) {
      expect(err).toBeInstanceOf(Prisma.PrismaClientKnownRequestError);
      expect((err as Prisma.PrismaClientKnownRequestError).code).toBe('P2002');
    }
  });
});

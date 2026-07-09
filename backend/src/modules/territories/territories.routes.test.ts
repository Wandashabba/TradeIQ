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

  it("lists the client's territories ordered by name for any authenticated role", async () => {
    await request(app)
      .post('/territories')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ name: 'TERR-Alpha', code: 'TERR-A1' });

    const res = await request(app).get('/territories').set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    const names = (res.body as Array<{ name: string }>).map((t) => t.name);
    expect(names).toContain('TERR-North');
    expect(names).toContain('TERR-Alpha');
    // ordered by name asc
    expect([...names].sort()).toEqual(names);
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
      .set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(200);
    expect(res.body.territory.id).toBe(territory.id);
    const outletIds = (res.body.outlets as Array<{ id: string }>).map((o) => o.id);
    expect(outletIds).toEqual([outlet.id]);
    const agentIds = (res.body.agents as Array<{ id: string }>).map((a) => a.id);
    expect(agentIds).toContain(managerId);
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

import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { issueToken } from '../auth/auth.service';

// Outlet location (Johannesburg CBD) — agent distances are seeded relative to it.
const OUTLET_LAT = -26.2041;
const OUTLET_LNG = 28.0473;

describe('dispatch routes', () => {
  let clientId: string;
  let otherClientId: string;
  let managerToken: string;
  let agentToken: string;
  let outletId: string;
  let otherOutletId: string;
  let agentNearId: string;
  let agentFarId: string;
  let agentNoLocId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'DISP-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const manager = await prisma.user.create({
      data: { email: 'DISP-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'DISP-Outlet',
        code: 'DISP-OUT-1',
        channelType: 'general_trade',
        lat: OUTLET_LAT,
        lng: OUTLET_LNG,
        territoryId: 'DISP-t1',
        clientId,
      },
    });
    outletId = outlet.id;

    // Territory whose code mirrors the outlet's free-text territoryId.
    const territory = await prisma.territory.create({
      data: { clientId, name: 'DISP-Territory-1', code: 'DISP-t1' },
    });

    // ~50m north of the outlet, assigned to territory DISP-t1 → in-territory + closest.
    const agentNear = await prisma.user.create({
      data: {
        email: 'DISP-agent-near@example.com',
        displayName: 'Nandi Near',
        passwordHash: 'x',
        role: 'field_agent',
        clientId,
        lastLat: OUTLET_LAT + 0.00045,
        lastLng: OUTLET_LNG,
        lastSeenAt: new Date('2026-07-09T08:00:00.000Z'),
      },
    });
    agentNearId = agentNear.id;
    await prisma.userTerritory.create({
      data: { territoryId: territory.id, userId: agentNear.id },
    });

    // ~5km north of the outlet, not assigned to any territory.
    const agentFar = await prisma.user.create({
      data: {
        email: 'DISP-agent-far@example.com',
        passwordHash: 'x',
        role: 'field_agent',
        clientId,
        lastLat: OUTLET_LAT + 0.045,
        lastLng: OUTLET_LNG,
        lastSeenAt: new Date('2026-07-09T07:30:00.000Z'),
      },
    });
    agentFarId = agentFar.id;

    // Never reported a location.
    const agentNoLoc = await prisma.user.create({
      data: {
        email: 'DISP-agent-noloc@example.com',
        passwordHash: 'x',
        role: 'field_agent',
        clientId,
      },
    });
    agentNoLocId = agentNoLoc.id;
    agentToken = issueToken({ userId: agentNoLoc.id, role: 'field_agent', clientId });

    // A second tenant with its own outlet — used for cross-tenant isolation.
    const otherClient = await prisma.client.create({
      data: { name: 'DISP-Other-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = otherClient.id;

    const otherOutlet = await prisma.outlet.create({
      data: {
        name: 'DISP-Other-Outlet',
        code: 'DISP-OUT-OTHER',
        channelType: 'general_trade',
        lat: OUTLET_LAT,
        lng: OUTLET_LNG,
        territoryId: 'DISP-other',
        clientId: otherClientId,
      },
    });
    otherOutletId = otherOutlet.id;
  });

  afterAll(async () => {
    await prisma.userTerritory.deleteMany({
      where: { territory: { clientId: { in: [clientId, otherClientId] } } },
    });
    await prisma.territory.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.user.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.client.deleteMany({ where: { id: { in: [clientId, otherClientId] } } });
    await prisma.$disconnect();
  });

  it('ranks in-territory + closest agent first and unlocated agent last', async () => {
    const res = await request(app)
      .post('/dispatch')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ outletId });

    expect(res.status).toBe(200);
    expect(res.body.outletId).toBe(outletId);

    const candidates = res.body.candidates as Array<{
      agentId: string;
      email: string;
      distanceM: number | null;
      inTerritory: boolean;
      lastSeenAt: string | null;
    }>;
    expect(candidates).toHaveLength(3);

    // agentNear: in-territory and closest.
    expect(candidates[0].agentId).toBe(agentNearId);
    expect(candidates[0].inTerritory).toBe(true);
    expect(typeof candidates[0].distanceM).toBe('number');
    expect(candidates[0].distanceM).toBeLessThan(100);

    // agentFar: located but far and not in-territory.
    expect(candidates[1].agentId).toBe(agentFarId);
    expect(candidates[1].inTerritory).toBe(false);
    expect(typeof candidates[1].distanceM).toBe('number');
    expect(candidates[1].distanceM as number).toBeGreaterThan(
      candidates[0].distanceM as number,
    );

    // agentNoLoc: null distance ranks last.
    expect(candidates[2].agentId).toBe(agentNoLocId);
    expect(candidates[2].distanceM).toBeNull();

    // Recommended is the top candidate.
    expect(res.body.recommended.agentId).toBe(agentNearId);
  });

  it('returns each candidate\'s display name alongside the email, null when unset (#280)', async () => {
    const res = await request(app)
      .post('/dispatch')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ outletId });

    expect(res.status).toBe(200);
    const candidates = res.body.candidates as Array<{
      agentId: string;
      email: string;
      displayName: string | null;
    }>;
    const near = candidates.find((c) => c.agentId === agentNearId);
    const far = candidates.find((c) => c.agentId === agentFarId);
    expect(near).toMatchObject({ email: 'DISP-agent-near@example.com', displayName: 'Nandi Near' });
    // Additive: the email is still there for older clients, and a person with
    // no name says so explicitly rather than omitting the key.
    expect(far).toMatchObject({ email: 'DISP-agent-far@example.com', displayName: null });
    expect(res.body.recommended.displayName).toBe('Nandi Near');
  });

  it('returns the same ranking via GET /dispatch/agents', async () => {
    const res = await request(app)
      .get('/dispatch/agents')
      .query({ outletId })
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.outletId).toBe(outletId);
    const candidates = res.body.candidates as Array<{ agentId: string }>;
    expect(candidates.map((c) => c.agentId)).toEqual([agentNearId, agentFarId, agentNoLocId]);
  });

  it('rejects POST /dispatch with a missing outletId with 400', async () => {
    const res = await request(app)
      .post('/dispatch')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({});
    expect(res.status).toBe(400);
  });

  it('rejects GET /dispatch/agents with a missing outletId with 400', async () => {
    const res = await request(app)
      .get('/dispatch/agents')
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(400);
  });

  it('returns 404 for an outlet belonging to another client', async () => {
    const res = await request(app)
      .post('/dispatch')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ outletId: otherOutletId });
    expect(res.status).toBe(404);
  });

  it('forbids a field agent with 403', async () => {
    const res = await request(app)
      .post('/dispatch')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ outletId });
    expect(res.status).toBe(403);
  });

  it('rejects unauthenticated requests with 401', async () => {
    const res = await request(app).post('/dispatch').send({ outletId });
    expect(res.status).toBe(401);
  });
});

import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';
import { foreignTenant, userIn } from '../../test-utils/tenants';

describe('capability routes', () => {
  let clientId: string;
  let agentToken: string;
  let agentBToken: string;
  let managerToken: string;
  let visitId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'Capability Test Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: { email: 'capability-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });
    managerToken = (await userIn(clientId, 'manager')).token;

    const agentB = await prisma.user.create({
      data: { email: 'capability-agent-b@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentBToken = issueToken({ userId: agentB.id, role: 'field_agent', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'Capability Outlet',
        code: 'CAPABILITY-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId,
      },
    });
    const visit = await prisma.visit.create({
      data: {
        outletId: outlet.id,
        agentId: agent.id,
        clientId,
        checkinTs: new Date(),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'in_progress',
      },
    });
    visitId = visit.id;
  });

  afterAll(async () => {
    await prisma.visitCapability.deleteMany({ where: { visitId } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  const validBody = () => ({
    visitId,
    staffHeadcountConfirmed: 3,
    repTrainingStatus: { productKnowledge: 'trained', merchandising: 'pending' },
    quizScore: 80,
  });

  it('records capability for a visit (201)', async () => {
    const res = await request(app)
      .post('/capability')
      .set('Authorization', `Bearer ${agentToken}`)
      .send(validBody());

    expect(res.status).toBe(201);
    expect(res.body.staffHeadcountConfirmed).toBe(3);
    expect(res.body.quizScore).toBe(80);
  });

  it('is idempotent — re-submitting upserts the same row', async () => {
    const res = await request(app)
      .post('/capability')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ ...validBody(), quizScore: 95 });

    expect(res.status).toBe(201);
    expect(res.body.quizScore).toBe(95);

    const rows = await prisma.visitCapability.findMany({ where: { visitId } });
    expect(rows).toHaveLength(1);
  });

  it("forbids an agent from writing capability onto another agent's visit (404)", async () => {
    const res = await request(app)
      .post('/capability')
      .set('Authorization', `Bearer ${agentBToken}`)
      .send(validBody());
    expect(res.status).toBe(404);
  });

  it('returns 404 for a visit belonging to another client', async () => {
    const otherToken = (await foreignTenant('field_agent')).token;
    const res = await request(app)
      .post('/capability')
      .set('Authorization', `Bearer ${otherToken}`)
      .send(validBody());
    expect(res.status).toBe(404);
  });

  it('rejects a missing required field with 400', async () => {
    const { staffHeadcountConfirmed, ...rest } = validBody();
    void staffHeadcountConfirmed;
    const res = await request(app)
      .post('/capability')
      .set('Authorization', `Bearer ${agentToken}`)
      .send(rest);
    expect(res.status).toBe(400);
  });

  it('rejects an invalid field type with 400', async () => {
    const res = await request(app)
      .post('/capability')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ ...validBody(), repTrainingStatus: null });
    expect(res.status).toBe(400);
  });

  it('forbids a manager from recording capability with 403', async () => {
    const res = await request(app)
      .post('/capability')
      .set('Authorization', `Bearer ${managerToken}`)
      .send(validBody());
    expect(res.status).toBe(403);
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).post('/capability').send(validBody());
    expect(res.status).toBe(401);
  });

  it('lists a visit capability rows ordered by createdAt desc (200)', async () => {
    // A capability row for this visit was upserted by the earlier POST cases.
    const res = await request(app)
      .get('/capability')
      .query({ visitId })
      .set('Authorization', `Bearer ${agentToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThanOrEqual(1);
    expect(res.body.every((row: { visitId: string }) => row.visitId === visitId)).toBe(true);
  });

  it('rejects a GET without visitId with 400', async () => {
    const res = await request(app).get('/capability').set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(400);
  });

  it('returns 404 for a GET on a visit belonging to another client', async () => {
    const otherToken = (await foreignTenant('field_agent')).token;
    const res = await request(app)
      .get('/capability')
      .query({ visitId })
      .set('Authorization', `Bearer ${otherToken}`);
    expect(res.status).toBe(404);
  });

  it('rejects a GET without a bearer token with 401', async () => {
    const res = await request(app).get('/capability').query({ visitId });
    expect(res.status).toBe(401);
  });
});

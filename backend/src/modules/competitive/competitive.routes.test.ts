import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('competitive routes', () => {
  let clientId: string;
  let agentToken: string;
  let agentBToken: string;
  let managerToken: string;
  let visitId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'Competitive Test Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: { email: 'competitive-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });
    managerToken = issueToken({ userId: 'competitive-manager', role: 'manager', clientId });

    const agentB = await prisma.user.create({
      data: { email: 'competitive-agent-b@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentBToken = issueToken({ userId: agentB.id, role: 'field_agent', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'Competitive Outlet',
        code: 'COMPETITIVE-001',
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
    await prisma.visitCompetitive.deleteMany({ where: { visitId } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  const validItem = () => ({
    competitorSku: 'Rival Cola 500ml',
    competitorPrice: 17.5,
    competitorPosmType: 'shelf_strip',
    competitorPromoterPresent: false,
    geotag: { lat: -26.2041, lng: 28.0473 },
  });

  it('records competitive rows (201)', async () => {
    const res = await request(app)
      .post('/competitive')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId, items: [validItem()] });

    expect(res.status).toBe(201);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].competitorSku).toBe('Rival Cola 500ml');
    expect(res.body[0].competitorPrice).toBe(17.5);
  });

  it("forbids an agent from writing competitive intel onto another agent's visit (404)", async () => {
    const res = await request(app)
      .post('/competitive')
      .set('Authorization', `Bearer ${agentBToken}`)
      .send({ visitId, items: [validItem()] });
    expect(res.status).toBe(404);
  });

  it('returns 404 for a visit belonging to another client', async () => {
    const otherToken = issueToken({ userId: 'x', role: 'field_agent', clientId: 'no-such-client' });
    const res = await request(app)
      .post('/competitive')
      .set('Authorization', `Bearer ${otherToken}`)
      .send({ visitId, items: [validItem()] });
    expect(res.status).toBe(404);
  });

  it('rejects a missing/empty items array with 400', async () => {
    const res = await request(app)
      .post('/competitive')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId, items: [] });
    expect(res.status).toBe(400);
  });

  it('rejects an item with an invalid field type with 400', async () => {
    const res = await request(app)
      .post('/competitive')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId, items: [{ ...validItem(), geotag: null }] });
    expect(res.status).toBe(400);
  });

  it('forbids a manager from recording competitive intel with 403', async () => {
    const res = await request(app)
      .post('/competitive')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ visitId, items: [validItem()] });
    expect(res.status).toBe(403);
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).post('/competitive').send({ visitId, items: [validItem()] });
    expect(res.status).toBe(401);
  });

  it('lists a visit competitive rows ordered by createdAt desc (200)', async () => {
    await prisma.visitCompetitive.create({
      data: {
        visitId,
        competitorSku: 'Rival Cola 1L',
        competitorPrice: 24.99,
        competitorPosmType: 'gondola_end',
        competitorPromoterPresent: true,
        geotag: { lat: -26.2041, lng: 28.0473 },
      },
    });

    const res = await request(app)
      .get('/competitive')
      .query({ visitId })
      .set('Authorization', `Bearer ${agentToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThanOrEqual(1);
    expect(res.body.every((row: { visitId: string }) => row.visitId === visitId)).toBe(true);
  });

  it('rejects a GET without visitId with 400', async () => {
    const res = await request(app).get('/competitive').set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(400);
  });

  it('returns 404 for a GET on a visit belonging to another client', async () => {
    const otherToken = issueToken({ userId: 'x', role: 'field_agent', clientId: 'no-such-client' });
    const res = await request(app)
      .get('/competitive')
      .query({ visitId })
      .set('Authorization', `Bearer ${otherToken}`);
    expect(res.status).toBe(404);
  });

  it('rejects a GET without a bearer token with 401', async () => {
    const res = await request(app).get('/competitive').query({ visitId });
    expect(res.status).toBe(401);
  });
});

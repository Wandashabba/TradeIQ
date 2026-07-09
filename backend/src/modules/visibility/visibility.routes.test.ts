import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('visibility routes', () => {
  let clientId: string;
  let agentToken: string;
  let managerToken: string;
  let visitId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'Vis Test Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: { email: 'vis-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });
    managerToken = issueToken({ userId: 'vis-manager', role: 'manager', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'Vis Outlet',
        code: 'VIS-001',
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
    await prisma.visitVisibility.deleteMany({ where: { visitId } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  const validBody = () => ({
    visitId,
    brandingElements: { poster: true, shelfStrip: false },
    planogramCompliancePct: 82.5,
    facingsCount: { total: 12 },
    highTrafficPass: true,
    cleanlinessScore: 90,
  });

  it('records visibility for a visit (201)', async () => {
    const res = await request(app)
      .post('/visibility')
      .set('Authorization', `Bearer ${agentToken}`)
      .send(validBody());

    expect(res.status).toBe(201);
    expect(res.body.planogramCompliancePct).toBe(82.5);
    expect(res.body.highTrafficPass).toBe(true);
  });

  it('is idempotent — re-submitting upserts the same row', async () => {
    const res = await request(app)
      .post('/visibility')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ ...validBody(), cleanlinessScore: 75 });

    expect(res.status).toBe(201);
    expect(res.body.cleanlinessScore).toBe(75);

    const rows = await prisma.visitVisibility.findMany({ where: { visitId } });
    expect(rows).toHaveLength(1);
  });

  it('returns 404 for a visit belonging to another client', async () => {
    const otherToken = issueToken({ userId: 'x', role: 'field_agent', clientId: 'no-such-client' });
    const res = await request(app)
      .post('/visibility')
      .set('Authorization', `Bearer ${otherToken}`)
      .send(validBody());
    expect(res.status).toBe(404);
  });

  it('rejects a missing required field with 400', async () => {
    const { planogramCompliancePct, ...rest } = validBody();
    void planogramCompliancePct;
    const res = await request(app)
      .post('/visibility')
      .set('Authorization', `Bearer ${agentToken}`)
      .send(rest);
    expect(res.status).toBe(400);
  });

  it('forbids a manager from recording visibility with 403', async () => {
    const res = await request(app)
      .post('/visibility')
      .set('Authorization', `Bearer ${managerToken}`)
      .send(validBody());
    expect(res.status).toBe(403);
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).post('/visibility').send(validBody());
    expect(res.status).toBe(401);
  });

  it('GET / is not implemented yet', async () => {
    const res = await request(app).get('/visibility').set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(501);
  });
});

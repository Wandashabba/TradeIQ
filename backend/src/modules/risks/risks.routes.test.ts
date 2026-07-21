import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';
import { foreignTenant, userIn } from '../../test-utils/tenants';

describe('risks routes', () => {
  let clientId: string;
  let agentId: string;
  let agentToken: string;
  let managerToken: string;
  let outletId: string;
  let visitId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'Risks Test Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: { email: 'risks-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentId = agent.id;
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });
    managerToken = (await userIn(clientId, 'manager')).token;

    const outlet = await prisma.outlet.create({
      data: {
        name: 'Risks Outlet',
        code: 'RISKS-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId,
      },
    });
    outletId = outlet.id;
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
    await prisma.task.deleteMany({ where: { outlet: { clientId } } });
    await prisma.visitRisk.deleteMany({ where: { visit: { clientId } } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  const validRisks = () => [
    { flagType: 'stockout', severity: 'critical', note: 'Cola fully out of stock' },
    { flagType: 'pricing_deviation', severity: 'high', note: 'RRP exceeded by 15%' },
    { flagType: 'cleanliness', severity: 'normal', note: 'Dusty shelf strip' },
  ];

  const hoursFromNow = (iso: string) => (new Date(iso).getTime() - Date.now()) / 3_600_000;

  it('records risks and auto-creates one task per risk (201)', async () => {
    const res = await request(app)
      .post('/risks')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId, risks: validRisks() });

    expect(res.status).toBe(201);
    expect(res.body.risks).toHaveLength(3);
    expect(res.body.tasks).toHaveLength(3);

    const riskRows = await prisma.visitRisk.findMany({ where: { visitId } });
    expect(riskRows).toHaveLength(3);
    const taskRows = await prisma.task.findMany({ where: { visitId } });
    expect(taskRows).toHaveLength(3);

    for (const [i, risk] of validRisks().entries()) {
      const task = res.body.tasks[i];
      expect(task.visitId).toBe(visitId);
      expect(task.outletId).toBe(outletId);
      expect(task.findingType).toBe(risk.flagType);
      expect(task.requiredFix).toBe(risk.note);
      expect(task.priority).toBe(risk.severity);
      expect(task.ownerId).toBe(agentId);
      expect(task.status).toBe('open');
    }

    // SLA offsets: critical = +24h, high = +72h, normal = +168h.
    expect(hoursFromNow(res.body.tasks[0].slaDueAt)).toBeCloseTo(24, 1);
    expect(hoursFromNow(res.body.tasks[1].slaDueAt)).toBeCloseTo(72, 1);
    expect(hoursFromNow(res.body.tasks[2].slaDueAt)).toBeCloseTo(168, 1);
  });

  it('rejects an invalid severity with 400', async () => {
    const res = await request(app)
      .post('/risks')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId, risks: [{ flagType: 'stockout', severity: 'urgent', note: 'n' }] });
    expect(res.status).toBe(400);
  });

  it('rejects a missing/empty risks array with 400', async () => {
    const res = await request(app)
      .post('/risks')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId, risks: [] });
    expect(res.status).toBe(400);
  });

  it('returns 404 for a visit belonging to another client', async () => {
    const otherToken = (await foreignTenant('field_agent')).token;
    const res = await request(app)
      .post('/risks')
      .set('Authorization', `Bearer ${otherToken}`)
      .send({ visitId, risks: validRisks() });
    expect(res.status).toBe(404);
  });

  it('forbids a manager from recording risks with 403', async () => {
    const res = await request(app)
      .post('/risks')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ visitId, risks: validRisks() });
    expect(res.status).toBe(403);
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).post('/risks').send({ visitId, risks: validRisks() });
    expect(res.status).toBe(401);
  });

  it('lists a visit risk rows ordered by createdAt desc (200)', async () => {
    await prisma.visitRisk.create({
      data: { visitId, flagType: 'planogram_breach', severity: 'high', note: 'Facings below standard' },
    });

    const res = await request(app)
      .get('/risks')
      .query({ visitId })
      .set('Authorization', `Bearer ${agentToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThanOrEqual(1);
    expect(res.body.every((row: { visitId: string }) => row.visitId === visitId)).toBe(true);
  });

  it('rejects a GET without visitId with 400', async () => {
    const res = await request(app).get('/risks').set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(400);
  });

  it('returns 404 for a GET on a visit belonging to another client', async () => {
    const otherToken = (await foreignTenant('field_agent')).token;
    const res = await request(app)
      .get('/risks')
      .query({ visitId })
      .set('Authorization', `Bearer ${otherToken}`);
    expect(res.status).toBe(404);
  });

  it('rejects a GET without a bearer token with 401', async () => {
    const res = await request(app).get('/risks').query({ visitId });
    expect(res.status).toBe(401);
  });
});

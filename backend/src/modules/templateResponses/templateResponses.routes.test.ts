import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';
import { foreignTenant, userIn } from '../../test-utils/tenants';

describe('template-responses routes', () => {
  let clientId: string;
  let agentToken: string;
  let agentBToken: string;
  let managerToken: string;
  let visitId: string;
  let templateId: string;

  const sampleSchema = {
    sections: [
      {
        id: 'availability',
        fields: [{ id: 'onShelf', type: 'boolean', label: 'On shelf?' }],
      },
    ],
    scoring: { onShelf: 10 },
  };

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'TMPLRESP-Test Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: { email: 'tmplresp-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });
    managerToken = (await userIn(clientId, 'manager')).token;

    const agentB = await prisma.user.create({
      data: { email: 'tmplresp-agent-b@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentBToken = issueToken({ userId: agentB.id, role: 'field_agent', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'TMPLRESP Outlet',
        code: 'TMPLRESP-001',
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

    const template = await prisma.auditTemplate.create({
      data: { clientId, name: 'TMPLRESP-Standard Audit', schema: sampleSchema },
    });
    templateId = template.id;
  });

  afterAll(async () => {
    await prisma.visitTemplateResponse.deleteMany({ where: { visitId } });
    await prisma.auditTemplate.deleteMany({ where: { clientId } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  const validBody = () => ({
    visitId,
    templateId,
    answers: { onShelf: true },
  });

  it('records a template response snapshotting the template version (201)', async () => {
    const res = await request(app)
      .post('/template-responses')
      .set('Authorization', `Bearer ${agentToken}`)
      .send(validBody());

    expect(res.status).toBe(201);
    expect(res.body.visitId).toBe(visitId);
    expect(res.body.templateId).toBe(templateId);
    expect(res.body.templateVersion).toBe(1);
    expect(res.body.answers).toEqual({ onShelf: true });
  });

  it('is idempotent — re-submitting upserts the same row', async () => {
    const res = await request(app)
      .post('/template-responses')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ ...validBody(), answers: { onShelf: false } });

    expect(res.status).toBe(201);
    expect(res.body.answers).toEqual({ onShelf: false });

    const rows = await prisma.visitTemplateResponse.findMany({ where: { visitId } });
    expect(rows).toHaveLength(1);
  });

  it('re-records against the bumped version after a schema patch', async () => {
    await request(app)
      .patch(`/templates/${templateId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ schema: { ...sampleSchema, scoring: { onShelf: 20 } } });

    const res = await request(app)
      .post('/template-responses')
      .set('Authorization', `Bearer ${agentToken}`)
      .send(validBody());

    expect(res.status).toBe(201);
    expect(res.body.templateVersion).toBe(2);
  });

  it("forbids an agent from writing a template response onto another agent's visit (404)", async () => {
    const res = await request(app)
      .post('/template-responses')
      .set('Authorization', `Bearer ${agentBToken}`)
      .send(validBody());
    expect(res.status).toBe(404);
  });

  it('returns 404 for a visit belonging to another client', async () => {
    const otherToken = (await foreignTenant('field_agent')).token;
    const res = await request(app)
      .post('/template-responses')
      .set('Authorization', `Bearer ${otherToken}`)
      .send(validBody());
    expect(res.status).toBe(404);
  });

  it('returns 404 for a template belonging to another client', async () => {
    const otherClient = await prisma.client.create({
      data: { name: 'TMPLRESP-Other Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    const otherTemplate = await prisma.auditTemplate.create({
      data: { clientId: otherClient.id, name: 'TMPLRESP-Foreign', schema: sampleSchema },
    });
    try {
      const res = await request(app)
        .post('/template-responses')
        .set('Authorization', `Bearer ${agentToken}`)
        .send({ ...validBody(), templateId: otherTemplate.id });
      expect(res.status).toBe(404);
    } finally {
      await prisma.auditTemplate.delete({ where: { id: otherTemplate.id } });
      await prisma.client.delete({ where: { id: otherClient.id } });
    }
  });

  it('rejects a missing templateId with 400', async () => {
    const { templateId: _omitted, ...rest } = validBody();
    void _omitted;
    const res = await request(app)
      .post('/template-responses')
      .set('Authorization', `Bearer ${agentToken}`)
      .send(rest);
    expect(res.status).toBe(400);
  });

  it('rejects non-object answers with 400', async () => {
    const res = await request(app)
      .post('/template-responses')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ ...validBody(), answers: [1, 2, 3] });
    expect(res.status).toBe(400);
  });

  it('forbids a manager from recording a response with 403', async () => {
    const res = await request(app)
      .post('/template-responses')
      .set('Authorization', `Bearer ${managerToken}`)
      .send(validBody());
    expect(res.status).toBe(403);
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).post('/template-responses').send(validBody());
    expect(res.status).toBe(401);
  });

  it('lists a visit template responses (200), filterable by templateId', async () => {
    const res = await request(app)
      .get('/template-responses')
      .query({ visitId })
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.length).toBeGreaterThanOrEqual(1);
    expect(res.body.data.every((row: { visitId: string }) => row.visitId === visitId)).toBe(true);

    const filtered = await request(app)
      .get('/template-responses')
      .query({ visitId, templateId: 'no-such-template' })
      .set('Authorization', `Bearer ${managerToken}`);
    expect(filtered.status).toBe(200);
    expect(filtered.body.data).toHaveLength(0);
  });

  it('rejects a GET without visitId with 400', async () => {
    const res = await request(app)
      .get('/template-responses')
      .set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(400);
  });

  it('returns 404 for a GET on a visit belonging to another client', async () => {
    const otherToken = (await foreignTenant('field_agent')).token;
    const res = await request(app)
      .get('/template-responses')
      .query({ visitId })
      .set('Authorization', `Bearer ${otherToken}`);
    expect(res.status).toBe(404);
  });
});

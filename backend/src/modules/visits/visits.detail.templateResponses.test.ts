import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { foreignTenant, userIn } from '../../test-utils/tenants';

// GET /visits/:id carries the visit's answers to the client's audit template —
// the client-questions section that supplements S1–S10 (#122).
describe('GET /visits/:id — template responses', () => {
  let clientId: string;
  let managerToken: string;
  let agentToken: string;
  let visitId: string;
  let emptyVisitId: string;
  let templateId: string;
  let foreign: Awaited<ReturnType<typeof foreignTenant>>;

  const schema = {
    sections: [
      {
        id: 'promo',
        title: 'Promo check',
        fields: [
          { id: 'standUp', type: 'boolean', label: 'Promo stand up?', required: true, weight: 5 },
          { id: 'facings', type: 'number', label: 'Promo facings' },
        ],
      },
    ],
  };

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'VDTMPL-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    managerToken = (await userIn(clientId, 'manager')).token;
    const agent = await userIn(clientId, 'field_agent');
    agentToken = agent.token;

    const outlet = await prisma.outlet.create({
      data: {
        name: 'VDTMPL-Outlet',
        code: 'VDT-001',
        channelType: 'supermarket',
        lat: -26.2,
        lng: 28.04,
        territoryId: 't1',
        clientId,
      },
    });
    const visitData = {
      outletId: outlet.id,
      agentId: agent.userId,
      clientId,
      checkinTs: new Date(),
      checkinLat: -26.2,
      checkinLng: 28.04,
      geofencePass: true,
      status: 'in_progress' as const,
    };
    visitId = (await prisma.visit.create({ data: visitData })).id;
    emptyVisitId = (await prisma.visit.create({ data: visitData })).id;

    templateId = (
      await prisma.auditTemplate.create({ data: { clientId, name: 'VDTMPL-Promo', schema } })
    ).id;
    foreign = await foreignTenant('manager');
  });

  afterAll(async () => {
    await prisma.visitTemplateResponse.deleteMany({ where: { visit: { clientId } } });
    await prisma.auditTemplate.deleteMany({ where: { clientId } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await foreign.cleanup();
    await prisma.$disconnect();
  });

  const get = (id: string, token: string) =>
    request(app).get(`/visits/${id}`).set('Authorization', `Bearer ${token}`);

  it('an agent’s saved answers reach the manager with the schema to label them', async () => {
    const posted = await request(app)
      .post('/template-responses')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId, templateId, templateVersion: 1, answers: { standUp: true, facings: 4 } });
    expect(posted.status).toBe(201);

    // The template moves on after the agent answered: the detail must still say
    // which version the answers belong to.
    await prisma.auditTemplate.update({
      where: { id: templateId },
      data: { version: { increment: 1 } },
    });

    const res = await get(visitId, managerToken);
    expect(res.status).toBe(200);
    expect(res.body.templateResponses).toEqual([
      {
        templateId,
        templateName: 'VDTMPL-Promo',
        templateVersion: 1,
        currentVersion: 2,
        schema,
        answers: { standUp: true, facings: 4 },
        recordedAt: expect.any(String),
      },
    ]);
    // Supplements, never scores: an unscored draft stays unscored.
    expect(res.body.score).toBeNull();
  });

  it('is an empty list for a visit with no template answers', async () => {
    const res = await get(emptyVisitId, managerToken);
    expect(res.status).toBe(200);
    expect(res.body.templateResponses).toEqual([]);
  });

  it('is invisible to another tenant (404)', async () => {
    const res = await get(visitId, foreign.token);
    expect(res.status).toBe(404);
    expect(res.body.templateResponses).toBeUndefined();
  });
});

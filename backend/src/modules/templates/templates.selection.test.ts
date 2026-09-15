import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { foreignTenant, userIn } from '../../test-utils/tenants';

// The client's audit template (#122): the questions agents answer as an extra
// section after S1–S10.
describe('GET/PUT /templates/selected', () => {
  let clientId: string;
  let managerToken: string;
  let adminToken: string;
  let agentToken: string;
  let templateId: string;
  let otherTemplateId: string;
  let pausedTemplateId: string;
  const foreignCleanups: Array<() => Promise<void>> = [];

  const schema = {
    sections: [
      {
        id: 'promo',
        title: 'Promo check',
        fields: [{ id: 'standUp', type: 'boolean', label: 'Promo stand up?', required: true }],
      },
    ],
  };

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'TMPLSEL-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    managerToken = (await userIn(clientId, 'manager')).token;
    adminToken = (await userIn(clientId, 'admin')).token;
    agentToken = (await userIn(clientId, 'field_agent')).token;

    templateId = (
      await prisma.auditTemplate.create({ data: { clientId, name: 'TMPLSEL-Promo', schema } })
    ).id;
    otherTemplateId = (
      await prisma.auditTemplate.create({ data: { clientId, name: 'TMPLSEL-Other', schema } })
    ).id;
    pausedTemplateId = (
      await prisma.auditTemplate.create({
        data: { clientId, name: 'TMPLSEL-Paused', schema, active: false },
      })
    ).id;
  });

  afterAll(async () => {
    await prisma.client.update({ where: { id: clientId }, data: { auditTemplateId: null } });
    await prisma.auditTemplate.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    for (const cleanup of foreignCleanups) await cleanup();
    await prisma.$disconnect();
  });

  const select = (token: string, body: unknown) =>
    request(app).put('/templates/selected').set('Authorization', `Bearer ${token}`).send(body as object);

  const read = (token: string) =>
    request(app).get('/templates/selected').set('Authorization', `Bearer ${token}`);

  it('is null before a template is chosen', async () => {
    const res = await read(agentToken);
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ template: null });
  });

  it('a manager selects one of the client’s templates, and an agent reads it with its schema', async () => {
    const put = await select(managerToken, { templateId });
    expect(put.status).toBe(200);
    expect(put.body.template.id).toBe(templateId);

    const res = await read(agentToken);
    expect(res.status).toBe(200);
    expect(res.body.template.id).toBe(templateId);
    expect(res.body.template.name).toBe('TMPLSEL-Promo');
    expect(res.body.template.version).toBe(1);
    expect(res.body.template.schema).toEqual(schema);
  });

  it('an admin can switch to another template — one at a time', async () => {
    const put = await select(adminToken, { templateId: otherTemplateId });
    expect(put.status).toBe(200);

    const res = await read(managerToken);
    expect(res.body.template.id).toBe(otherTemplateId);
    const client = await prisma.client.findUnique({ where: { id: clientId } });
    expect(client?.auditTemplateId).toBe(otherTemplateId);
  });

  it('clears with templateId null', async () => {
    const put = await select(managerToken, { templateId: null });
    expect(put.status).toBe(200);
    expect(put.body).toEqual({ template: null });
    expect((await read(agentToken)).body).toEqual({ template: null });
  });

  it('forbids a field agent from choosing (403)', async () => {
    const res = await select(agentToken, { templateId });
    expect(res.status).toBe(403);
  });

  it('rejects a missing or malformed templateId (400)', async () => {
    expect((await select(managerToken, {})).status).toBe(400);
    expect((await select(managerToken, { templateId: '' })).status).toBe(400);
    expect((await select(managerToken, { templateId: 42 })).status).toBe(400);
  });

  it('refuses a paused template (400)', async () => {
    const res = await select(managerToken, { templateId: pausedTemplateId });
    expect(res.status).toBe(400);
  });

  it('refuses another client’s template (404) and leaves the selection alone', async () => {
    await select(managerToken, { templateId });

    const foreign = await foreignTenant('manager');
    foreignCleanups.push(foreign.cleanup);
    const foreignTemplate = await prisma.auditTemplate.create({
      data: { clientId: foreign.clientId, name: 'TMPLSEL-Foreign', schema },
    });
    foreignCleanups.unshift(async () => {
      await prisma.client.update({
        where: { id: foreign.clientId },
        data: { auditTemplateId: null },
      });
      await prisma.auditTemplate.delete({ where: { id: foreignTemplate.id } });
    });

    const res = await select(managerToken, { templateId: foreignTemplate.id });
    expect(res.status).toBe(404);
    expect((await read(agentToken)).body.template.id).toBe(templateId);
  });

  it('never shows one client’s selection to another client', async () => {
    const foreign = await foreignTenant('field_agent');
    foreignCleanups.push(foreign.cleanup);
    const res = await read(foreign.token);
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ template: null });
  });

  it('pausing the selected template clears it', async () => {
    await select(managerToken, { templateId });

    const patch = await request(app)
      .patch(`/templates/${templateId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ active: false });
    expect(patch.status).toBe(200);
    expect(patch.body.active).toBe(false);

    expect((await read(agentToken)).body).toEqual({ template: null });
    const client = await prisma.client.findUnique({ where: { id: clientId } });
    expect(client?.auditTemplateId).toBeNull();
  });

  it('pausing a template that is not selected leaves the selection alone', async () => {
    await select(managerToken, { templateId: otherTemplateId });
    await prisma.auditTemplate.update({ where: { id: templateId }, data: { active: true } });

    const patch = await request(app)
      .patch(`/templates/${templateId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ active: false });
    expect(patch.status).toBe(200);
    expect((await read(agentToken)).body.template.id).toBe(otherTemplateId);
  });

  it('a schema edit bumps the version an agent reads', async () => {
    await select(managerToken, { templateId: otherTemplateId });
    await request(app)
      .patch(`/templates/${otherTemplateId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ schema: { ...schema, scoring: { standUp: 5 } } });

    const res = await read(agentToken);
    expect(res.body.template.version).toBe(2);
  });

  it('requires a bearer token (401)', async () => {
    expect((await request(app).get('/templates/selected')).status).toBe(401);
  });
});

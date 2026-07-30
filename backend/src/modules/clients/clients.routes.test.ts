import request from 'supertest';
import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { issueToken } from '../auth/auth.service';

describe('clients routes', () => {
  let clientId: string;
  let otherClientId: string;
  let adminToken: string;
  let managerToken: string;
  let agentToken: string;
  let otherAdminToken: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: {
        name: 'CLIENT-Primary',
        industry: 'FMCG',
        scorecardWeights: { availability: 0.3, visibility: 0.7 } as Prisma.InputJsonValue,
        kpiThresholds: { green: 80 } as Prisma.InputJsonValue,
      },
    });
    clientId = client.id;

    const admin = await prisma.user.create({
      data: { email: 'CLIENT-admin@example.com', passwordHash: 'x', role: 'admin', clientId },
    });
    adminToken = issueToken({ userId: admin.id, role: 'admin', clientId });

    const manager = await prisma.user.create({
      data: { email: 'CLIENT-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });

    const agent = await prisma.user.create({
      data: { email: 'CLIENT-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });

    const otherClient = await prisma.client.create({
      data: {
        name: 'CLIENT-Other',
        industry: 'Pharma',
        scorecardWeights: { pricing: 1 } as Prisma.InputJsonValue,
        kpiThresholds: { green: 90 } as Prisma.InputJsonValue,
      },
    });
    otherClientId = otherClient.id;

    const otherAdmin = await prisma.user.create({
      data: {
        email: 'CLIENT-other-admin@example.com',
        passwordHash: 'x',
        role: 'admin',
        clientId: otherClient.id,
      },
    });
    otherAdminToken = issueToken({ userId: otherAdmin.id, role: 'admin', clientId: otherClient.id });
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.client.deleteMany({ where: { id: { in: [clientId, otherClientId] } } });
    await prisma.$disconnect();
  });

  it("returns the caller's client config for any authenticated role", async () => {
    const res = await request(app).get('/clients/me').set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(200);
    expect(res.body.id).toBe(clientId);
    expect(res.body.name).toBe('CLIENT-Primary');
    expect(res.body.industry).toBe('FMCG');
    expect(res.body.scorecardWeights).toEqual({ availability: 0.3, visibility: 0.7 });
    expect(res.body.kpiThresholds).toEqual({ green: 80 });
  });

  it('rejects unauthenticated requests with 401', async () => {
    const res = await request(app).get('/clients/me');
    expect(res.status).toBe(401);
  });

  it('lets an admin update scorecardWeights and reflects it on re-GET', async () => {
    const res = await request(app)
      .patch('/clients/me')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ scorecardWeights: { availability: 0.5, visibility: 0.5 } });
    expect(res.status).toBe(200);
    expect(res.body.scorecardWeights).toEqual({ availability: 0.5, visibility: 0.5 });
    // kpiThresholds untouched by a scorecardWeights-only update.
    expect(res.body.kpiThresholds).toEqual({ green: 80 });

    const reGet = await request(app).get('/clients/me').set('Authorization', `Bearer ${adminToken}`);
    expect(reGet.status).toBe(200);
    expect(reGet.body.scorecardWeights).toEqual({ availability: 0.5, visibility: 0.5 });
  });

  it('lets an admin update kpiThresholds', async () => {
    const res = await request(app)
      .patch('/clients/me')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ kpiThresholds: { green: 85, amber: 60 } });
    expect(res.status).toBe(200);
    expect(res.body.kpiThresholds).toEqual({ green: 85, amber: 60 });
  });

  it('rejects a non-numeric kpiThreshold with 400', async () => {
    // Every consumer reads thresholds as numbers and falls back to a default on
    // anything else — so without this guard a bad value looks accepted while
    // silently doing nothing.
    const res = await request(app)
      .patch('/clients/me')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ kpiThresholds: { green: '85' } });
    expect(res.status).toBe(400);
  });

  it('rejects a non-finite kpiThreshold with 400', async () => {
    const res = await request(app)
      .patch('/clients/me')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ kpiThresholds: { stockoutUnits: null } });
    expect(res.status).toBe(400);
  });

  it('forbids a manager from updating config with 403', async () => {
    const res = await request(app)
      .patch('/clients/me')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ kpiThresholds: { green: 70 } });
    expect(res.status).toBe(403);
  });

  it('forbids a field agent from updating config with 403', async () => {
    const res = await request(app)
      .patch('/clients/me')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ kpiThresholds: { green: 70 } });
    expect(res.status).toBe(403);
  });

  it('rejects an empty PATCH body with 400', async () => {
    const res = await request(app)
      .patch('/clients/me')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({});
    expect(res.status).toBe(400);
  });

  it('rejects a non-object scorecardWeights with 400', async () => {
    const res = await request(app)
      .patch('/clients/me')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ scorecardWeights: 'not-an-object' });
    expect(res.status).toBe(400);
  });

  it('rejects a negative scorecardWeights value with 400', async () => {
    const res = await request(app)
      .patch('/clients/me')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ scorecardWeights: { availability: -1 } });
    expect(res.status).toBe(400);
  });

  it('rejects a non-finite (NaN -> null over JSON) scorecardWeights value with 400', async () => {
    const res = await request(app)
      .patch('/clients/me')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ scorecardWeights: { availability: Number.NaN } });
    expect(res.status).toBe(400);
  });

  it('scopes GET to the caller client — a second client admin sees only their own', async () => {
    const res = await request(app)
      .get('/clients/me')
      .set('Authorization', `Bearer ${otherAdminToken}`);
    expect(res.status).toBe(200);
    expect(res.body.id).toBe(otherClientId);
    expect(res.body.name).toBe('CLIENT-Other');
    expect(res.body.scorecardWeights).toEqual({ pricing: 1 });
  });
});

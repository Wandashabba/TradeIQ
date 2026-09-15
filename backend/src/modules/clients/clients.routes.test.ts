import request from 'supertest';
import { randomUUID } from 'crypto';
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

  describe('timezone (#309)', () => {
    it('defaults to Africa/Johannesburg for a client created without one', async () => {
      const res = await request(app).get('/clients/me').set('Authorization', `Bearer ${agentToken}`);
      expect(res.status).toBe(200);
      expect(res.body.timezone).toBe('Africa/Johannesburg');
    });

    it('gives a pre-existing row the default at the database level', async () => {
      // Written with raw SQL that never names the column — how rows that
      // existed before the migration look — so this is the column default and
      // not Prisma filling one in client-side.
      const id = randomUUID();
      await prisma.$executeRaw`
        INSERT INTO clients (id, name, industry, scorecard_weights, kpi_thresholds)
        VALUES (${id}, 'CLIENT-Legacy', 'FMCG', '{}'::jsonb, '{}'::jsonb)`;
      try {
        const row = await prisma.client.findUniqueOrThrow({ where: { id }, select: { timezone: true } });
        expect(row.timezone).toBe('Africa/Johannesburg');
      } finally {
        await prisma.client.delete({ where: { id } });
      }
    });

    it('lets a manager set the timezone, and reflects it on re-GET', async () => {
      const res = await request(app)
        .patch('/clients/me')
        .set('Authorization', `Bearer ${managerToken}`)
        .send({ timezone: 'America/New_York' });
      expect(res.status).toBe(200);
      expect(res.body.timezone).toBe('America/New_York');
      // Nothing else moved.
      expect(res.body.kpiThresholds).toEqual({ green: 85, amber: 60 });

      const reGet = await request(app).get('/clients/me').set('Authorization', `Bearer ${agentToken}`);
      expect(reGet.body.timezone).toBe('America/New_York');
    });

    it('lets an admin set the timezone alongside scoring config', async () => {
      const res = await request(app)
        .patch('/clients/me')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ timezone: 'Africa/Johannesburg', kpiThresholds: { green: 85, amber: 60 } });
      expect(res.status).toBe(200);
      expect(res.body.timezone).toBe('Africa/Johannesburg');
    });

    it('accepts UTC', async () => {
      const res = await request(app)
        .patch('/clients/me')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ timezone: 'UTC' });
      expect(res.status).toBe(200);
      expect(res.body.timezone).toBe('UTC');
    });

    it.each([
      ['an unknown zone', 'Mars/Olympus_Mons'],
      ['a case-folded name', 'africa/johannesburg'],
      ['a fixed offset', '+02:00'],
      ['an abbreviation', 'SAST'],
      ['an empty string', ''],
      ['a number', 2],
      ['null', null],
    ])('rejects %s with 400 and changes nothing', async (_label, timezone) => {
      const before = await prisma.client.findUniqueOrThrow({ where: { id: clientId } });
      const res = await request(app)
        .patch('/clients/me')
        .set('Authorization', `Bearer ${managerToken}`)
        .send({ timezone });
      expect(res.status).toBe(400);
      expect(res.body.error).toMatch(/IANA/);
      const after = await prisma.client.findUniqueOrThrow({ where: { id: clientId } });
      expect(after.timezone).toBe(before.timezone);
    });

    it('forbids a manager from sneaking scoring config in with a timezone', async () => {
      const before = await prisma.client.findUniqueOrThrow({ where: { id: clientId } });
      const res = await request(app)
        .patch('/clients/me')
        .set('Authorization', `Bearer ${managerToken}`)
        .send({ timezone: 'Europe/London', scorecardWeights: { availability: 1 } });
      expect(res.status).toBe(403);
      const after = await prisma.client.findUniqueOrThrow({ where: { id: clientId } });
      expect(after.timezone).toBe(before.timezone);
      expect(after.scorecardWeights).toEqual(before.scorecardWeights);
    });

    it('forbids a field agent from setting the timezone', async () => {
      const res = await request(app)
        .patch('/clients/me')
        .set('Authorization', `Bearer ${agentToken}`)
        .send({ timezone: 'Europe/London' });
      expect(res.status).toBe(403);
    });

    it("only ever changes the caller's own client", async () => {
      const res = await request(app)
        .patch('/clients/me')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ timezone: 'Asia/Tokyo' });
      expect(res.status).toBe(200);

      const other = await request(app)
        .get('/clients/me')
        .set('Authorization', `Bearer ${otherAdminToken}`);
      expect(other.body.id).toBe(otherClientId);
      expect(other.body.timezone).toBe('Africa/Johannesburg');

      const otherRes = await request(app)
        .patch('/clients/me')
        .set('Authorization', `Bearer ${otherAdminToken}`)
        .send({ timezone: 'Europe/Berlin' });
      expect(otherRes.status).toBe(200);
      const mine = await prisma.client.findUniqueOrThrow({ where: { id: clientId } });
      expect(mine.timezone).toBe('Asia/Tokyo');
    });
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

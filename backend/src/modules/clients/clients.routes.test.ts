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

  /**
   * #153 T2 — the window background location tracking may run in. Managers may
   * edit it as well as admins, like the timezone, because when the team works is
   * a fact about the team rather than a scoring policy.
   */
  describe('working hours', () => {
    const patch = (token: string, body: object) =>
      request(app).patch('/clients/me').set('Authorization', `Bearer ${token}`).send(body);

    const stored = () => prisma.client.findUniqueOrThrow({ where: { id: clientId } });

    afterEach(async () => {
      await prisma.client.update({
        where: { id: clientId },
        data: { workHoursStart: '07:00', workHoursEnd: '17:00', workDays: [1, 2, 3, 4, 5] },
      });
    });

    it('GET reports the Monday-to-Friday 07:00-17:00 default', async () => {
      const res = await request(app)
        .get('/clients/me')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      expect(res.body.workHoursStart).toBe('07:00');
      expect(res.body.workHoursEnd).toBe('17:00');
      expect(res.body.workDays).toEqual([1, 2, 3, 4, 5]);
    });

    it('a manager may set the whole window', async () => {
      const res = await patch(managerToken, {
        workHoursStart: '06:30',
        workHoursEnd: '18:00',
        workDays: [1, 2, 3, 4, 5, 6],
      });
      expect(res.status).toBe(200);
      expect(res.body).toMatchObject({
        workHoursStart: '06:30',
        workHoursEnd: '18:00',
        workDays: [1, 2, 3, 4, 5, 6],
      });
      expect(await stored()).toMatchObject({ workHoursStart: '06:30', workHoursEnd: '18:00' });
    });

    it('an admin may too', async () => {
      expect((await patch(adminToken, { workHoursEnd: '18:00' })).status).toBe(200);
    });

    it('a field agent may not', async () => {
      expect((await patch(agentToken, { workHoursEnd: '18:00' })).status).toBe(403);
      expect((await stored()).workHoursEnd).toBe('17:00');
    });

    it('stores the days sorted, however they were sent', async () => {
      const res = await patch(managerToken, { workDays: [6, 1, 3] });
      expect(res.status).toBe(200);
      expect(res.body.workDays).toEqual([1, 3, 6]);
    });

    it('writes all three together, so a new start never lands against an old end', async () => {
      // Only the start is sent; the other two must come back unchanged rather
      // than being dropped or defaulted.
      await patch(managerToken, { workHoursStart: '08:00', workHoursEnd: '16:00', workDays: [2, 4] });
      const res = await patch(managerToken, { workHoursStart: '09:00' });
      expect(res.status).toBe(200);
      expect(res.body).toMatchObject({
        workHoursStart: '09:00',
        workHoursEnd: '16:00',
        workDays: [2, 4],
      });
    });

    it('validates a partial edit against what is STORED, not against the one field sent', async () => {
      await patch(managerToken, { workHoursStart: '09:00', workHoursEnd: '17:00' });
      // 08:00 alone is a fine time; it is only wrong next to the stored end.
      const res = await patch(managerToken, { workHoursEnd: '08:00' });
      expect(res.status).toBe(400);
      expect(res.body.error).toMatch(/before/);
      expect((await stored()).workHoursEnd).toBe('17:00');
    });

    it.each([
      ['a start equal to the end', { workHoursStart: '08:00', workHoursEnd: '08:00' }],
      ['an overnight window', { workHoursStart: '22:00', workHoursEnd: '06:00' }],
      ['a single-digit hour', { workHoursStart: '7:00' }],
      ['seconds', { workHoursStart: '07:00:00' }],
      ['a 12-hour clock', { workHoursEnd: '5pm' }],
      ['hour 24', { workHoursEnd: '24:00' }],
      ['an empty day list', { workDays: [] }],
      ['a non-array day list', { workDays: 'weekdays' }],
      ['day 0', { workDays: [0, 1] }],
      ['day 8', { workDays: [8] }],
      ['a repeated day', { workDays: [1, 1] }],
    ])('refuses %s with a 400 and changes nothing', async (_label, body) => {
      const before = await stored();
      const res = await patch(managerToken, body);
      expect(res.status).toBe(400);
      expect(typeof res.body.error).toBe('string');
      const after = await stored();
      expect(after.workHoursStart).toBe(before.workHoursStart);
      expect(after.workHoursEnd).toBe(before.workHoursEnd);
      expect(after.workDays).toEqual(before.workDays);
    });

    it('still refuses a manager who sends scoring config alongside the hours', async () => {
      const res = await patch(managerToken, {
        workHoursEnd: '18:00',
        kpiThresholds: { green: 70 },
      });
      expect(res.status).toBe(403);
      expect((await stored()).workHoursEnd).toBe('17:00');
    });

    it('an empty body still names every editable field', async () => {
      const res = await patch(managerToken, {});
      expect(res.status).toBe(400);
      expect(res.body.error).toMatch(/workHoursStart/);
    });

    it('does not touch another tenant', async () => {
      expect((await patch(otherAdminToken, { workHoursEnd: '18:00' })).status).toBe(200);
      expect((await stored()).workHoursEnd).toBe('17:00');
      const other = await prisma.client.findUniqueOrThrow({ where: { id: otherClientId } });
      expect(other.workHoursEnd).toBe('18:00');
    });
  });
});

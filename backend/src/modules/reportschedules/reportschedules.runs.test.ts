import request from 'supertest';
import { Prisma, WebhookDeliveryStatus } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { issueToken } from '../auth/auth.service';
import { REPORT_LINK_TTL_MS } from './reportschedules.links';
import { summariseRun } from './reportschedules.runs';
import type { ReportDeliveryOutcome } from './reportschedules.delivery';

// Run history (#66). Runs and delivery rows are written directly: the
// history reads what the scheduler and the delivery pipelines left behind.

describe('summariseRun', () => {
  const webhookQueued: ReportDeliveryOutcome = {
    channel: 'webhook',
    status: 'queued',
    targets: ['https://a.test'],
    webhookDeliveryIds: ['w1'],
  };
  const emailQueued: ReportDeliveryOutcome = {
    channel: 'email',
    status: 'queued',
    targets: ['a@x.test', 'b@x.test'],
    emailDeliveryIds: ['e1', 'e2'],
  };

  it('is delivering while anything is queued or retrying', () => {
    const r = summariseRun([webhookQueued, emailQueued], { succeeded: 1 }, { succeeded: 1, failed_retrying: 1 });
    expect(r.status).toBe('delivering');
    expect(r.summary.email).toEqual({ status: 'queued', sent: 1, failed: 0, pending: 1, notConfigured: 0 });
    expect(r.reason).toBeNull();
  });

  it('is delivered when everything succeeded', () => {
    const r = summariseRun([webhookQueued, emailQueued], { succeeded: 1 }, { succeeded: 2 });
    expect(r.status).toBe('delivered');
    expect(r.summary.webhook).toEqual({ status: 'queued', delivered: 1, failed: 0, pending: 0 });
  });

  it('is partial when some gave up and some succeeded, and says how many', () => {
    const r = summariseRun([webhookQueued, emailQueued], { gave_up: 1 }, { succeeded: 1, gave_up: 1 });
    expect(r.status).toBe('partial');
    expect(r.reason).toBe('1 webhook delivery gave up after retries; 1 email could not be sent');
  });

  it('is failed when a channel failed and nothing succeeded', () => {
    const r = summariseRun(
      [{ channel: 'webhook', status: 'failed', targets: [], detail: 'boom' }],
      {},
      {},
    );
    expect(r.status).toBe('failed');
    expect(r.reason).toBe('boom');
  });

  it('is not sent when nothing was queued, with every reason and the unconfigured count', () => {
    const r = summariseRun(
      [
        { channel: 'webhook', status: 'no_subscribers', targets: [], detail: 'No active webhook' },
        { channel: 'email', status: 'not_configured', targets: ['a@x.test', 'b@x.test'], detail: 'SMTP off' },
      ],
      {},
      {},
    );
    expect(r.status).toBe('not_sent');
    expect(r.summary.email.notConfigured).toBe(2);
    expect(r.reason).toBe('No active webhook; SMTP off');
  });

  it('says so when a run recorded no delivery at all', () => {
    const r = summariseRun([], {}, {});
    expect(r.status).toBe('not_sent');
    expect(r.reason).toBe('No delivery was recorded for this run');
  });
});

describe('GET /report-schedules/:id/runs', () => {
  let clientId: string;
  let otherClientId: string;
  let managerToken: string;
  let adminToken: string;
  let agentToken: string;
  let otherToken: string;
  let scheduleId: string;
  let otherScheduleId: string;
  let webhookId: string;
  const runIds: string[] = [];
  const savedEnv = { base: process.env.PUBLIC_API_URL, secret: process.env.REPORT_LINK_SECRET };

  const path = () => `/report-schedules/${scheduleId}/runs`;
  const get = (url: string, token: string) => request(app).get(url).set('Authorization', `Bearer ${token}`);

  async function createRun(
    at: Date,
    deliveries: ReportDeliveryOutcome[],
    extra: Partial<Prisma.ReportScheduleRunUncheckedCreateInput> = {},
  ) {
    const run = await prisma.reportScheduleRun.create({
      data: {
        scheduleId,
        clientId,
        trigger: 'manual',
        generatedAt: at,
        createdAt: at,
        rowCount: 3,
        deliveries: deliveries as unknown as Prisma.InputJsonValue,
        ...extra,
      },
    });
    return run.id;
  }

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'RUNS-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    const other = await prisma.client.create({
      data: { name: 'RUNS-Other', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = other.id;

    const users = await Promise.all(
      [
        { email: 'RUNS-manager@example.com', role: 'manager' as const, clientId },
        { email: 'RUNS-admin@example.com', role: 'admin' as const, clientId },
        { email: 'RUNS-agent@example.com', role: 'field_agent' as const, clientId },
        { email: 'RUNS-other@example.com', role: 'manager' as const, clientId: otherClientId },
      ].map((u) => prisma.user.create({ data: { ...u, passwordHash: 'x' } })),
    );
    [managerToken, adminToken, agentToken, otherToken] = users.map((u) =>
      issueToken({ userId: u.id, role: u.role, clientId: u.clientId! }),
    );

    const definition = await prisma.reportDefinition.create({
      data: { clientId, name: 'RUNS-Report', type: 'visits', filters: {} },
    });
    const schedule = await prisma.reportSchedule.create({
      data: {
        clientId,
        reportDefinitionId: definition.id,
        cadence: 'daily',
        recipients: ['a@example.com', 'b@example.com'] as Prisma.InputJsonValue,
      },
    });
    scheduleId = schedule.id;

    const otherDefinition = await prisma.reportDefinition.create({
      data: { clientId: otherClientId, name: 'RUNS-Other Report', type: 'visits', filters: {} },
    });
    const otherSchedule = await prisma.reportSchedule.create({
      data: {
        clientId: otherClientId,
        reportDefinitionId: otherDefinition.id,
        cadence: 'daily',
        recipients: ['o@example.com'] as Prisma.InputJsonValue,
      },
    });
    otherScheduleId = otherSchedule.id;
    await prisma.reportScheduleRun.create({
      data: {
        scheduleId: otherScheduleId,
        clientId: otherClientId,
        trigger: 'manual',
        generatedAt: new Date(),
        rowCount: 1,
        deliveries: [],
      },
    });

    const webhook = await prisma.webhook.create({
      data: { clientId, url: 'https://hooks.example.com/runs', event: 'report.generated' },
    });
    webhookId = webhook.id;

    const base = Date.now();
    // Oldest: nothing sent (no subscriber, email off).
    runIds.push(
      await createRun(new Date(base - 3 * 60_000), [
        { channel: 'webhook', status: 'no_subscribers', targets: [], detail: 'No active webhook is subscribed to report.generated' },
        { channel: 'email', status: 'not_configured', targets: ['a@example.com', 'b@example.com'], detail: 'Email delivery not configured' },
      ]),
    );

    // Middle: a scheduled run whose webhook delivered and whose emails went
    // one sent, one gave up, one retrying.
    const middleAt = new Date(base - 2 * 60_000);
    const delivery = await prisma.webhookDelivery.create({
      data: {
        webhookId,
        clientId,
        event: 'report.generated',
        payload: {},
        status: 'succeeded',
        attempts: 1,
        lastStatusCode: 204,
        deliveredAt: middleAt,
      },
    });
    const middleId = await createRun(
      middleAt,
      [
        { channel: 'webhook', status: 'queued', targets: [webhook.url], webhookDeliveryIds: [delivery.id] },
        { channel: 'email', status: 'queued', targets: ['a@example.com', 'b@example.com', 'c@example.com'] },
      ],
      { trigger: 'scheduled', dueAt: middleAt },
    );
    runIds.push(middleId);
    const emails: Array<[string, WebhookDeliveryStatus, string | null]> = [
      ['a@example.com', 'succeeded', null],
      ['b@example.com', 'gave_up', 'SMTP 550: mailbox unavailable'],
      ['c@example.com', 'failed_retrying', 'SMTP 421: try later'],
    ];
    await prisma.reportEmailDelivery.createMany({
      data: emails.map(([recipient, status, lastError]) => ({
        runId: middleId,
        clientId,
        recipient,
        status,
        lastError,
        attempts: status === 'succeeded' ? 1 : 2,
      })),
    });

    // Newest: a webhook delivery that gave up, email sent.
    const newestAt = new Date(base - 60_000);
    const failed = await prisma.webhookDelivery.create({
      data: {
        webhookId,
        clientId,
        event: 'report.generated',
        payload: {},
        status: 'gave_up',
        attempts: 6,
        lastStatusCode: 500,
        lastError: 'HTTP 500',
      },
    });
    const newestId = await createRun(newestAt, [
      { channel: 'webhook', status: 'queued', targets: [webhook.url], webhookDeliveryIds: [failed.id] },
      { channel: 'email', status: 'queued', targets: ['a@example.com'] },
    ]);
    runIds.push(newestId);
    await prisma.reportEmailDelivery.create({
      data: { runId: newestId, clientId, recipient: 'a@example.com', status: 'succeeded', attempts: 1 },
    });
  });

  afterEach(() => {
    const restore = (name: 'PUBLIC_API_URL' | 'REPORT_LINK_SECRET', value: string | undefined) => {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    };
    restore('PUBLIC_API_URL', savedEnv.base);
    restore('REPORT_LINK_SECRET', savedEnv.secret);
  });

  afterAll(async () => {
    const clients = { in: [clientId, otherClientId] };
    await prisma.webhook.deleteMany({ where: { clientId: clients } });
    await prisma.reportSchedule.deleteMany({ where: { clientId: clients } });
    await prisma.reportDefinition.deleteMany({ where: { clientId: clients } });
    await prisma.user.deleteMany({ where: { clientId: clients } });
    await prisma.client.deleteMany({ where: { id: clients } });
    await prisma.$disconnect();
  });

  it('lists runs newest first with status, times, row count and summary counts', async () => {
    delete process.env.PUBLIC_API_URL;
    const res = await get(path(), managerToken);

    expect(res.status).toBe(200);
    expect(res.body.nextCursor).toBeNull();
    expect(res.body.data.map((r: { id: string }) => r.id)).toEqual([...runIds].reverse());

    const [newest, middle, oldest] = res.body.data;

    expect(newest).toMatchObject({
      scheduleId,
      trigger: 'manual',
      dueAt: null,
      rowCount: 3,
      status: 'partial',
      reason: '1 webhook delivery gave up after retries',
      summary: {
        webhook: { status: 'queued', delivered: 0, failed: 1, pending: 0 },
        email: { status: 'queued', sent: 1, failed: 0, pending: 0, notConfigured: 0 },
      },
      csvDownloadUrl: null,
      csvDownloadExpiresAt: null,
    });
    expect(newest.webhookDeliveries).toEqual([
      expect.objectContaining({
        webhookId,
        url: 'https://hooks.example.com/runs',
        status: 'gave_up',
        attempts: 6,
        lastStatusCode: 500,
        lastError: 'HTTP 500',
      }),
    ]);

    expect(middle).toMatchObject({
      trigger: 'scheduled',
      status: 'delivering',
      reason: '1 email could not be sent',
      summary: {
        webhook: { delivered: 1, failed: 0, pending: 0 },
        email: { sent: 1, failed: 1, pending: 1, notConfigured: 0 },
      },
    });
    expect(middle.dueAt).toBe(middle.generatedAt);

    expect(oldest).toMatchObject({
      status: 'not_sent',
      reason: 'No active webhook is subscribed to report.generated; Email delivery not configured',
      summary: {
        webhook: { status: 'no_subscribers', delivered: 0, failed: 0, pending: 0 },
        email: { status: 'not_configured', sent: 0, failed: 0, pending: 0, notConfigured: 2 },
      },
      webhookDeliveries: [],
    });
  });

  it('pages with limit and cursor', async () => {
    const first = await get(`${path()}?limit=2`, managerToken);
    expect(first.status).toBe(200);
    expect(first.body.data.map((r: { id: string }) => r.id)).toEqual([runIds[2], runIds[1]]);
    expect(first.body.nextCursor).toBe(runIds[1]);

    const second = await get(`${path()}?limit=2&cursor=${first.body.nextCursor}`, managerToken);
    expect(second.status).toBe(200);
    expect(second.body.data.map((r: { id: string }) => r.id)).toEqual([runIds[0]]);
    expect(second.body.nextCursor).toBeNull();

    const bad = await get(`${path()}?limit=0`, managerToken);
    expect(bad.status).toBe(400);
  });

  it('carries the signed CSV link when links are configured, and drops it once expired', async () => {
    process.env.PUBLIC_API_URL = 'https://api.example.com/';
    process.env.REPORT_LINK_SECRET = 'x'.repeat(40);

    const res = await get(path(), adminToken);
    expect(res.status).toBe(200);
    const newest = res.body.data[0];
    expect(newest.csvDownloadUrl).toMatch(/^https:\/\/api\.example\.com\/report-downloads\/[^/]+\.[^/]+$/);
    expect(new Date(newest.csvDownloadExpiresAt).getTime()).toBe(
      new Date(newest.generatedAt).getTime() + REPORT_LINK_TTL_MS,
    );

    const expiredId = await createRun(new Date(Date.now() - REPORT_LINK_TTL_MS - 60_000), [], {
      createdAt: new Date(Date.now() - 30_000),
    });
    try {
      const again = await get(`${path()}?limit=1`, managerToken);
      expect(again.body.data[0].id).toBe(expiredId);
      expect(again.body.data[0].csvDownloadUrl).toBeNull();
      expect(again.body.data[0].csvDownloadExpiresAt).toBeNull();
      expect(again.body.data[0].reason).toBe('No delivery was recorded for this run');
    } finally {
      await prisma.reportScheduleRun.delete({ where: { id: expiredId } });
    }
  });

  it("is tenant-scoped: another client's schedule is a 404, and never lists its runs", async () => {
    const foreign = await get(path(), otherToken);
    expect(foreign.status).toBe(404);

    const mine = await get(`/report-schedules/${otherScheduleId}/runs`, managerToken);
    expect(mine.status).toBe(404);

    const unknown = await get('/report-schedules/no-such-schedule/runs', managerToken);
    expect(unknown.status).toBe(404);
  });

  it('is manager/admin only (403 for a field agent, 401 without a token)', async () => {
    expect((await get(path(), agentToken)).status).toBe(403);
    expect((await request(app).get(path())).status).toBe(401);
  });
});

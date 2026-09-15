import request from 'supertest';
import { fetch } from 'undici';
import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { issueToken } from '../auth/auth.service';
import { settleInFlightDeliveries } from '../webhooks/webhooks.service';
import { DAY_MS } from './reportschedules.cadence';

// "Run now" now delivers through webhooks (#66): no real network, and the DNS
// pre-check is stubbed, as in webhooks.delivery.test.ts.
jest.mock('undici', () => ({
  ...jest.requireActual('undici'),
  fetch: jest.fn().mockResolvedValue({ status: 204, body: null }),
}));
jest.mock('../../lib/urlGuard', () => ({
  ...jest.requireActual('../../lib/urlGuard'),
  assertPublicHostname: jest.fn().mockResolvedValue(undefined),
}));

const fetchMock = fetch as unknown as jest.Mock;

describe('report-schedules routes', () => {
  let clientId: string;
  let otherClientId: string;
  let managerToken: string;
  let agentToken: string;
  let otherToken: string;
  let outletId: string;
  let agentId: string;
  let reportDefinitionId: string;
  let otherReportDefinitionId: string;
  let scheduleId: string;
  let otherScheduleId: string;
  let runId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'SCHED-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const manager = await prisma.user.create({
      data: { email: 'SCHED-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });
    const agent = await prisma.user.create({
      data: { email: 'SCHED-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentId = agent.id;
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'SCHED-Outlet',
        code: 'SCHED-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId,
      },
    });
    outletId = outlet.id;

    // A couple of visits so the linked (type 'visits') report yields rows.
    await prisma.visit.createMany({
      data: [
        {
          outletId,
          agentId: agent.id,
          clientId,
          checkinTs: new Date(Date.now() - 60_000),
          checkinLat: -26.2041,
          checkinLng: 28.0473,
          geofencePass: true,
          status: 'submitted',
        },
        {
          outletId,
          agentId: agent.id,
          clientId,
          checkinTs: new Date(Date.now() - 60_000),
          checkinLat: -26.2041,
          checkinLng: 28.0473,
          geofencePass: true,
          status: 'in_progress',
        },
      ],
    });

    const definition = await prisma.reportDefinition.create({
      data: { clientId, name: 'SCHED-Visits Report', type: 'visits', filters: {} },
    });
    reportDefinitionId = definition.id;

    // A second tenant with its own outlet + definition + schedule, to prove scoping.
    const otherClient = await prisma.client.create({
      data: { name: 'SCHED-Other', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = otherClient.id;
    const otherManager = await prisma.user.create({
      data: {
        email: 'SCHED-other-manager@example.com',
        passwordHash: 'x',
        role: 'manager',
        clientId: otherClientId,
      },
    });
    otherToken = issueToken({ userId: otherManager.id, role: 'manager', clientId: otherClientId });
    const otherDefinition = await prisma.reportDefinition.create({
      data: { clientId: otherClientId, name: 'SCHED-Other Report', type: 'visits', filters: {} },
    });
    otherReportDefinitionId = otherDefinition.id;
    const otherSchedule = await prisma.reportSchedule.create({
      data: {
        clientId: otherClientId,
        reportDefinitionId: otherReportDefinitionId,
        cadence: 'weekly',
        recipients: ['other@example.com'] as Prisma.InputJsonValue,
      },
    });
    otherScheduleId = otherSchedule.id;
  });

  afterAll(async () => {
    await settleInFlightDeliveries();
    const clients = { in: [clientId, otherClientId] };
    await prisma.webhook.deleteMany({ where: { clientId: clients } });
    await prisma.reportSchedule.deleteMany({ where: { clientId: clients } });
    await prisma.reportDefinition.deleteMany({ where: { clientId: clients } });
    await prisma.visit.deleteMany({ where: { clientId: clients } });
    await prisma.outlet.deleteMany({ where: { clientId: clients } });
    await prisma.user.deleteMany({ where: { clientId: clients } });
    await prisma.client.deleteMany({ where: { id: clients } });
    await prisma.$disconnect();
  });

  const validBody = () => ({
    reportDefinitionId,
    cadence: 'daily',
    recipients: ['ops@example.com', 'lead@example.com'],
  });

  const approx = (iso: string | null, expected: number) => {
    expect(iso).not.toBeNull();
    expect(Math.abs(new Date(iso!).getTime() - expected)).toBeLessThan(10_000);
  };

  it('creates a schedule whose first run is one period away (201)', async () => {
    const res = await request(app)
      .post('/report-schedules')
      .set('Authorization', `Bearer ${managerToken}`)
      .send(validBody());

    expect(res.status).toBe(201);
    expect(res.body.reportDefinitionId).toBe(reportDefinitionId);
    expect(res.body.cadence).toBe('daily');
    expect(res.body.recipients).toEqual(['ops@example.com', 'lead@example.com']);
    expect(res.body.active).toBe(true);
    expect(res.body.lastRunAt).toBeNull();
    approx(res.body.nextRunAt, Date.now() + DAY_MS);
    scheduleId = res.body.id;
  });

  it('rejects an invalid cadence with 400', async () => {
    const res = await request(app)
      .post('/report-schedules')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ ...validBody(), cadence: 'monthly' });
    expect(res.status).toBe(400);
  });

  it('rejects empty recipients with 400', async () => {
    const res = await request(app)
      .post('/report-schedules')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ ...validBody(), recipients: [] });
    expect(res.status).toBe(400);
  });

  it('rejects recipients that are not email addresses with 400, naming them', async () => {
    const res = await request(app)
      .post('/report-schedules')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ ...validBody(), recipients: ['ops@example.com', 'https://hooks.example.com/x'] });
    expect(res.status).toBe(400);
    expect(res.body.error).toContain('not an email address: https://hooks.example.com/x');
  });

  it("returns 404 when the report definition belongs to another client", async () => {
    const res = await request(app)
      .post('/report-schedules')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ ...validBody(), reportDefinitionId: otherReportDefinitionId });
    expect(res.status).toBe(404);
  });

  it("lists only the caller's schedules with the definition name and run times (200)", async () => {
    const res = await request(app)
      .get('/report-schedules')
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    const ids = res.body.data.map((s: { id: string }) => s.id);
    expect(ids).toContain(scheduleId);
    expect(ids).not.toContain(otherScheduleId);
    const mine = res.body.data.find((s: { id: string }) => s.id === scheduleId);
    expect(mine.reportDefinition.name).toBe('SCHED-Visits Report');
    expect(mine).toHaveProperty('nextRunAt');
    expect(mine).toHaveProperty('lastRunAt');
  });

  it('pausing clears the next run (200)', async () => {
    const res = await request(app)
      .patch(`/report-schedules/${scheduleId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ active: false, cadence: 'weekly' });
    expect(res.status).toBe(200);
    expect(res.body.active).toBe(false);
    expect(res.body.cadence).toBe('weekly');
    expect(res.body.nextRunAt).toBeNull();
  });

  it('resuming schedules the next run one period from now (200)', async () => {
    const res = await request(app)
      .patch(`/report-schedules/${scheduleId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ active: true });
    expect(res.status).toBe(200);
    expect(res.body.active).toBe(true);
    approx(res.body.nextRunAt, Date.now() + 7 * DAY_MS);
  });

  it('rejects an empty patch body with 400', async () => {
    const res = await request(app)
      .patch(`/report-schedules/${scheduleId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({});
    expect(res.status).toBe(400);
  });

  it('rejects an invalid patch cadence with 400', async () => {
    const res = await request(app)
      .patch(`/report-schedules/${scheduleId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ cadence: 'hourly' });
    expect(res.status).toBe(400);
  });

  it('run now with no subscribed webhook: generated, recorded, delivered nowhere (200)', async () => {
    const before = await prisma.reportSchedule.findUniqueOrThrow({ where: { id: scheduleId } });
    const res = await request(app)
      .post(`/report-schedules/${scheduleId}/run`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send();

    expect(res.status).toBe(200);
    expect(res.body.schedule.lastRunAt).not.toBeNull();
    expect(res.body.rowCount).toBe(2);
    expect(res.body.trigger).toBe('manual');
    // No longer an echo of the recipients: nothing was queued anywhere.
    expect(res.body.deliveredTo).toEqual([]);
    expect(res.body.deliveries).toEqual([
      expect.objectContaining({ channel: 'webhook', status: 'no_subscribers' }),
      {
        channel: 'email',
        status: 'not_configured',
        targets: ['ops@example.com', 'lead@example.com'],
        // SMTP is not set in the test environment, and the reason says so.
        detail: 'Email delivery not configured: SMTP_HOST and SMTP_FROM are not set',
      },
    ]);
    // A manual run is extra: the cadence's next run does not move.
    expect(res.body.schedule.nextRunAt).toBe(before.nextRunAt!.toISOString());
  });

  it('run now delivers to webhooks subscribed to report.generated (200)', async () => {
    const webhook = await prisma.webhook.create({
      data: { clientId, url: 'https://hooks.example.com/sched', event: 'report.generated' },
    });
    const res = await request(app)
      .post(`/report-schedules/${scheduleId}/run`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send();
    await settleInFlightDeliveries();

    expect(res.status).toBe(200);
    expect(res.body.deliveredTo).toEqual(['https://hooks.example.com/sched']);
    runId = res.body.runId;

    const deliveries = await prisma.webhookDelivery.findMany({ where: { webhookId: webhook.id } });
    expect(deliveries).toHaveLength(1);
    expect(res.body.deliveries[0]).toEqual({
      channel: 'webhook',
      status: 'queued',
      targets: ['https://hooks.example.com/sched'],
      webhookDeliveryIds: [deliveries[0].id],
    });
    expect((deliveries[0].payload as { payload: { runId: string; trigger: string } }).payload).toMatchObject({
      runId,
      trigger: 'manual',
      csvPath: `/report-schedules/${scheduleId}/runs/${runId}/csv`,
    });
    expect(fetchMock).toHaveBeenCalled();

    const run = await prisma.reportScheduleRun.findUniqueOrThrow({ where: { id: runId } });
    expect(run).toMatchObject({ clientId, scheduleId, trigger: 'manual', dueAt: null, rowCount: 2 });
  });

  it("serves a run's CSV, bounded to when the run was generated (200)", async () => {
    // A visit checked in after the run is not part of that run's report.
    await prisma.visit.create({
      data: {
        outletId,
        agentId,
        clientId,
        checkinTs: new Date(Date.now() + 60_000),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'submitted',
      },
    });

    const res = await request(app)
      .get(`/report-schedules/${scheduleId}/runs/${runId}/csv`)
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/^text\/csv/);
    expect(res.headers['content-disposition']).toBe(`attachment; filename="report-${runId}.csv"`);
    const lines = res.text.split('\n');
    expect(lines[0]).toContain('checkinTs');
    // Header + the two visits that existed at the run.
    expect(lines).toHaveLength(3);
  });

  it("the run CSV is tenant- and role-guarded (404/403/401)", async () => {
    const path = `/report-schedules/${scheduleId}/runs/${runId}/csv`;

    const foreign = await request(app).get(path).set('Authorization', `Bearer ${otherToken}`);
    expect(foreign.status).toBe(404);

    // The right run under another schedule's id is not found either.
    const mismatched = await request(app)
      .get(`/report-schedules/${otherScheduleId}/runs/${runId}/csv`)
      .set('Authorization', `Bearer ${otherToken}`);
    expect(mismatched.status).toBe(404);

    const unknown = await request(app)
      .get(`/report-schedules/${scheduleId}/runs/no-such-run/csv`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(unknown.status).toBe(404);

    const agent = await request(app).get(path).set('Authorization', `Bearer ${agentToken}`);
    expect(agent.status).toBe(403);

    const anonymous = await request(app).get(path);
    expect(anonymous.status).toBe(401);
  });

  it("returns 404 when running another client's schedule", async () => {
    // Client B's manager cannot run client A's schedule (tenant-scoped 404).
    const res = await request(app)
      .post(`/report-schedules/${scheduleId}/run`)
      .set('Authorization', `Bearer ${otherToken}`)
      .send();
    expect(res.status).toBe(404);
  });

  it("returns 404 when deleting another client's schedule", async () => {
    const res = await request(app)
      .delete(`/report-schedules/${otherScheduleId}`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(404);
  });

  it('deletes a schedule (204) then it and its runs are gone', async () => {
    const res = await request(app)
      .delete(`/report-schedules/${scheduleId}`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(204);

    const row = await prisma.reportSchedule.findUnique({ where: { id: scheduleId } });
    expect(row).toBeNull();
    expect(await prisma.reportScheduleRun.count({ where: { scheduleId } })).toBe(0);
  });

  it('forbids a field agent from create/run/delete (403)', async () => {
    const created = await request(app)
      .post('/report-schedules')
      .set('Authorization', `Bearer ${agentToken}`)
      .send(validBody());
    expect(created.status).toBe(403);

    const ran = await request(app)
      .post(`/report-schedules/${otherScheduleId}/run`)
      .set('Authorization', `Bearer ${agentToken}`)
      .send();
    expect(ran.status).toBe(403);

    const deleted = await request(app)
      .delete(`/report-schedules/${otherScheduleId}`)
      .set('Authorization', `Bearer ${agentToken}`);
    expect(deleted.status).toBe(403);
  });

  it('rejects requests without a bearer token (401)', async () => {
    const created = await request(app).post('/report-schedules').send(validBody());
    expect(created.status).toBe(401);
    const listed = await request(app).get('/report-schedules');
    expect(listed.status).toBe(401);
  });
});

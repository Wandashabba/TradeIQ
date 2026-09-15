import { fetch } from 'undici';
import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import * as reportsService from '../reports/reports.service';
import { settleInFlightDeliveries } from '../webhooks/webhooks.service';
import { DAY_MS } from './reportschedules.cadence';
import {
  deliverReport,
  emailDeliveryChannel,
  EMAIL_NOT_CONFIGURED,
  REPORT_GENERATED_EVENT,
  ReportDeliveryContext,
  ReportDeliveryOutcome,
} from './reportschedules.delivery';
import {
  claimDueSchedules,
  fireClaimedSchedule,
  processDueSchedules,
  SCHEDULE_CLAIM_LEASE_MS,
  updateSchedule,
} from './reportschedules.service';
import { startReportScheduleWorker } from './reportschedules.worker';

// No real network: subscribers are a stubbed undici fetch, and the DNS
// pre-check is stubbed — the same setup as webhooks.delivery.test.ts.
jest.mock('undici', () => ({
  ...jest.requireActual('undici'),
  fetch: jest.fn(),
}));
jest.mock('../../lib/urlGuard', () => ({
  ...jest.requireActual('../../lib/urlGuard'),
  assertPublicHostname: jest.fn().mockResolvedValue(undefined),
}));

const fetchMock = fetch as unknown as jest.Mock;

// Email and signed links stay off here, whatever the shell has set: this suite
// pins the unconfigured behaviour. reportschedules.email.test.ts covers them on.
const DELIVERY_ENV = ['SMTP_HOST', 'SMTP_PORT', 'SMTP_SECURE', 'SMTP_USER', 'SMTP_PASS', 'SMTP_FROM', 'REPORT_LINK_SECRET'];
const EMAIL_OFF = `${EMAIL_NOT_CONFIGURED}: SMTP_HOST and SMTP_FROM are not set`;

describe('report schedule worker (#66)', () => {
  let clientId: string;
  let otherClientId: string;
  let definitionId: string;
  let otherDefinitionId: string;
  const savedEnv: Record<string, string | undefined> = {};

  beforeAll(async () => {
    for (const key of DELIVERY_ENV) {
      savedEnv[key] = process.env[key];
      delete process.env[key];
    }
    const client = await prisma.client.create({
      data: { name: 'RSW-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    const other = await prisma.client.create({
      data: { name: 'RSW-Other', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = other.id;

    const agent = await prisma.user.create({
      data: { email: 'rsw-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    const outlet = await prisma.outlet.create({
      data: {
        name: 'RSW-Outlet',
        code: 'RSW-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId,
      },
    });
    // Two visits for the first client; the other client has none, so a report
    // generated for it that came back with rows would be reading across tenants.
    await prisma.visit.createMany({
      data: [1, 2].map(() => ({
        outletId: outlet.id,
        agentId: agent.id,
        clientId,
        checkinTs: new Date(Date.now() - 60 * 60_000),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'submitted' as const,
      })),
    });

    definitionId = (
      await prisma.reportDefinition.create({
        data: { clientId, name: 'RSW-Visits', type: 'visits', filters: {} },
      })
    ).id;
    otherDefinitionId = (
      await prisma.reportDefinition.create({
        data: { clientId: otherClientId, name: 'RSW-Other Visits', type: 'visits', filters: {} },
      })
    ).id;
  });

  beforeEach(() => {
    fetchMock.mockReset();
    fetchMock.mockResolvedValue({ status: 204, body: null });
  });

  afterEach(async () => {
    jest.restoreAllMocks();
    await settleInFlightDeliveries();
    const clients = { in: [clientId, otherClientId] };
    await prisma.webhook.deleteMany({ where: { clientId: clients } });
    // Runs cascade with their schedules.
    await prisma.reportSchedule.deleteMany({ where: { clientId: clients } });
  });

  afterAll(async () => {
    const clients = { in: [clientId, otherClientId] };
    await prisma.reportDefinition.deleteMany({ where: { clientId: clients } });
    await prisma.visit.deleteMany({ where: { clientId: clients } });
    await prisma.outlet.deleteMany({ where: { clientId: clients } });
    await prisma.user.deleteMany({ where: { clientId: clients } });
    await prisma.client.deleteMany({ where: { id: clients } });
    await prisma.$disconnect();
    for (const key of DELIVERY_ENV) {
      if (savedEnv[key] === undefined) delete process.env[key];
      else process.env[key] = savedEnv[key];
    }
  });

  async function makeSchedule(
    overrides: {
      clientId?: string;
      cadence?: string;
      nextRunAt?: Date | null;
      active?: boolean;
      claimedUntil?: Date | null;
    } = {},
  ) {
    const owner = overrides.clientId ?? clientId;
    return prisma.reportSchedule.create({
      data: {
        clientId: owner,
        reportDefinitionId: owner === clientId ? definitionId : otherDefinitionId,
        cadence: overrides.cadence ?? 'daily',
        recipients: ['ops@example.com'] as Prisma.InputJsonValue,
        nextRunAt:
          overrides.nextRunAt === undefined ? new Date(Date.now() - 60_000) : overrides.nextRunAt,
        active: overrides.active ?? true,
        claimedUntil: overrides.claimedUntil ?? null,
      },
    });
  }

  async function makeWebhook(overrides: { clientId?: string; event?: string; active?: boolean; url?: string } = {}) {
    return prisma.webhook.create({
      data: {
        clientId: overrides.clientId ?? clientId,
        url: overrides.url ?? 'https://hooks.example.com/reports',
        event: overrides.event ?? REPORT_GENERATED_EVENT,
        secret: 'whsec_rsw',
        active: overrides.active ?? true,
      },
    });
  }

  const runsFor = (scheduleId: string) =>
    prisma.reportScheduleRun.findMany({ where: { scheduleId }, orderBy: { createdAt: 'asc' } });

  it('fires a due schedule: generates the report and queues report.generated deliveries', async () => {
    const subscribed = await makeWebhook();
    const otherEvent = await makeWebhook({ event: 'order.created' });
    const paused = await makeWebhook({ active: false });
    const due = new Date(Date.now() - 5 * 60_000);
    const schedule = await makeSchedule({ nextRunAt: due });

    const now = new Date();
    expect(await processDueSchedules(now)).toBe(1);
    await settleInFlightDeliveries();

    const [run] = await runsFor(schedule.id);
    expect(run).toMatchObject({
      clientId,
      trigger: 'scheduled',
      dueAt: due,
      rowCount: 2,
    });

    const deliveries = await prisma.webhookDelivery.findMany({ where: { clientId } });
    expect(deliveries.map((d) => d.webhookId)).toEqual([subscribed.id]);
    expect(deliveries.some((d) => d.webhookId === otherEvent.id || d.webhookId === paused.id)).toBe(false);
    const [delivery] = deliveries;
    expect(delivery.event).toBe(REPORT_GENERATED_EVENT);
    expect(delivery.status).toBe('succeeded');
    const envelope = delivery.payload as { event: string; payload: Record<string, unknown> };
    expect(envelope.event).toBe(REPORT_GENERATED_EVENT);
    expect(envelope.payload).toEqual({
      scheduleId: schedule.id,
      reportId: definitionId,
      reportName: 'RSW-Visits',
      reportType: 'visits',
      runId: run.id,
      trigger: 'scheduled',
      generatedAt: run.generatedAt.toISOString(),
      rowCount: 2,
      csvPath: `/report-schedules/${schedule.id}/runs/${run.id}/csv`,
      csvUrl: null,
      // Additive (#66): null while signed links are not configured.
      csvDownloadUrl: null,
      csvDownloadExpiresAt: null,
    });
    // A pointer, never the rows: the body stays small whatever the report size.
    expect(JSON.stringify(delivery.payload).length).toBeLessThan(1024);
    expect(fetchMock).toHaveBeenCalledTimes(1);

    // What happened is recorded on the run.
    const outcomes = run.deliveries as unknown as ReportDeliveryOutcome[];
    expect(outcomes).toEqual([
      {
        channel: 'webhook',
        status: 'queued',
        targets: ['https://hooks.example.com/reports'],
        webhookDeliveryIds: [delivery.id],
      },
      {
        channel: 'email',
        status: 'not_configured',
        targets: ['ops@example.com'],
        detail: EMAIL_OFF,
      },
    ]);
    expect(await prisma.reportEmailDelivery.count({ where: { clientId } })).toBe(0);

    const after = await prisma.reportSchedule.findUniqueOrThrow({ where: { id: schedule.id } });
    expect(after.nextRunAt).toEqual(new Date(due.getTime() + DAY_MS));
    expect(after.lastRunAt).toEqual(run.generatedAt);
    expect(after.claimedUntil).toBeNull();
  });

  it('records no_subscribers when no webhook listens for report.generated', async () => {
    await makeWebhook({ event: 'visit.submitted' });
    const schedule = await makeSchedule();

    await processDueSchedules(new Date());

    const [run] = await runsFor(schedule.id);
    const outcomes = run.deliveries as unknown as ReportDeliveryOutcome[];
    expect(outcomes[0]).toMatchObject({ channel: 'webhook', status: 'no_subscribers', targets: [] });
    expect(await prisma.webhookDelivery.count({ where: { clientId } })).toBe(0);
  });

  it('a schedule missed across several periods fires once, then waits for the next slot', async () => {
    const now = new Date();
    const due = new Date(now.getTime() - 3.5 * DAY_MS);
    const schedule = await makeSchedule({ cadence: 'daily', nextRunAt: due });

    expect(await processDueSchedules(now)).toBe(1);
    // Polling again — even many times — finds nothing more due.
    expect(await processDueSchedules(now)).toBe(0);
    expect(await processDueSchedules(new Date(now.getTime() + 60_000))).toBe(0);

    expect(await runsFor(schedule.id)).toHaveLength(1);
    const after = await prisma.reportSchedule.findUniqueOrThrow({ where: { id: schedule.id } });
    // The first slot on the original grid still ahead: due + 4 days.
    expect(after.nextRunAt).toEqual(new Date(due.getTime() + 4 * DAY_MS));
    expect(after.nextRunAt!.getTime()).toBeGreaterThan(now.getTime());
  });

  it('does not fire a schedule that is not yet due', async () => {
    const schedule = await makeSchedule({ nextRunAt: new Date(Date.now() + 60_000) });
    expect(await processDueSchedules(new Date())).toBe(0);
    expect(await runsFor(schedule.id)).toHaveLength(0);
  });

  it('paused schedules do not fire, and resuming schedules the next run from now', async () => {
    await makeWebhook();
    // Even with a stale due time left on the row, inactive is never claimed.
    const stale = await makeSchedule({ active: false, nextRunAt: new Date(Date.now() - DAY_MS) });
    const schedule = await makeSchedule();

    const pausedAt = new Date();
    const paused = await updateSchedule(schedule.id, clientId, { active: false }, pausedAt);
    expect(paused.nextRunAt).toBeNull();

    expect(await processDueSchedules(new Date())).toBe(0);
    expect(await runsFor(schedule.id)).toHaveLength(0);
    expect(await runsFor(stale.id)).toHaveLength(0);
    expect(await prisma.webhookDelivery.count({ where: { clientId } })).toBe(0);

    const resumedAt = new Date(pausedAt.getTime() + 3 * DAY_MS);
    const resumed = await updateSchedule(schedule.id, clientId, { active: true }, resumedAt);
    expect(resumed.nextRunAt).toEqual(new Date(resumedAt.getTime() + DAY_MS));
    // Resuming does not fire for the time spent paused.
    expect(await processDueSchedules(resumedAt)).toBe(0);
  });

  it('concurrent processors never fire one due time twice', async () => {
    await makeWebhook();
    const schedules = await Promise.all([1, 2, 3, 4].map(() => makeSchedule()));

    const now = new Date();
    const claimed = await Promise.all([
      processDueSchedules(now, 2),
      processDueSchedules(now, 2),
      processDueSchedules(now, 2),
      processDueSchedules(now, 2),
    ]);
    // Drain anything a processor skipped past while others held locks.
    let more: number;
    do {
      more = await processDueSchedules(now, 2);
    } while (more > 0);
    await settleInFlightDeliveries();

    expect(claimed.reduce((a, b) => a + b, 0)).toBeLessThanOrEqual(4);
    for (const schedule of schedules) {
      expect(await runsFor(schedule.id)).toHaveLength(1);
    }
    expect(await prisma.webhookDelivery.count({ where: { clientId } })).toBe(4);
  });

  it('concurrent claims take disjoint rows, and a held lease is not re-claimed', async () => {
    await Promise.all([1, 2, 3].map(() => makeSchedule()));
    const now = new Date();

    const [a, b] = await Promise.all([claimDueSchedules(now, 3), claimDueSchedules(now, 3)]);
    const ids = [...a, ...b].map((c) => c.id);
    expect(new Set(ids).size).toBe(ids.length);
    expect(ids).toHaveLength(3);

    // Every row is leased: nothing to claim until the lease lapses.
    expect(await claimDueSchedules(now, 10)).toHaveLength(0);
    const lapsed = await claimDueSchedules(new Date(now.getTime() + SCHEDULE_CLAIM_LEASE_MS + 1), 10);
    expect(lapsed).toHaveLength(3);
  });

  it('a due time already recorded is not delivered again (a run that outlived its lease)', async () => {
    await makeWebhook();
    const due = new Date(Date.now() - 60_000);
    const schedule = await makeSchedule({ nextRunAt: due });
    // Another processor already recorded this due time.
    await prisma.reportScheduleRun.create({
      data: {
        scheduleId: schedule.id,
        clientId,
        trigger: 'scheduled',
        dueAt: due,
        generatedAt: new Date(),
        rowCount: 2,
        deliveries: [],
      },
    });

    const [claim] = await claimDueSchedules(new Date(), 1);
    expect(await fireClaimedSchedule(claim)).toBe('already_fired');

    expect(await runsFor(schedule.id)).toHaveLength(1);
    expect(await prisma.webhookDelivery.count({ where: { clientId } })).toBe(0);
    const after = await prisma.reportSchedule.findUniqueOrThrow({ where: { id: schedule.id } });
    expect(after.nextRunAt).toEqual(new Date(due.getTime() + DAY_MS));
    expect(after.claimedUntil).toBeNull();
  });

  it('a schedule paused between claim and fire is skipped and released', async () => {
    const schedule = await makeSchedule();
    const [claim] = await claimDueSchedules(new Date(), 1);
    await updateSchedule(schedule.id, clientId, { active: false });

    expect(await fireClaimedSchedule(claim)).toBe('skipped');
    expect(await runsFor(schedule.id)).toHaveLength(0);
    const after = await prisma.reportSchedule.findUniqueOrThrow({ where: { id: schedule.id } });
    expect(after.claimedUntil).toBeNull();
    expect(after.nextRunAt).toBeNull();
  });

  it('a run that throws leaves the due time and the lease, so it is retried later', async () => {
    const due = new Date(Date.now() - 60_000);
    const schedule = await makeSchedule({ nextRunAt: due });
    jest.spyOn(reportsService, 'generateReport').mockRejectedValueOnce(new Error('db blip'));
    jest.spyOn(console, 'error').mockImplementation(() => undefined);

    const [claim] = await claimDueSchedules(new Date(), 1);
    expect(await fireClaimedSchedule(claim)).toBe('failed');

    const after = await prisma.reportSchedule.findUniqueOrThrow({ where: { id: schedule.id } });
    expect(after.nextRunAt).toEqual(due);
    expect(after.claimedUntil).not.toBeNull();
    expect(await runsFor(schedule.id)).toHaveLength(0);

    // Once the lease lapses it fires normally.
    const later = new Date(after.claimedUntil!.getTime() + 1);
    expect(await processDueSchedules(later)).toBe(1);
    expect(await runsFor(schedule.id)).toHaveLength(1);
  });

  it("keeps tenants apart: each client's report and deliveries stay its own", async () => {
    const mine = await makeWebhook({ url: 'https://hooks.example.com/mine' });
    const theirs = await makeWebhook({ clientId: otherClientId, url: 'https://hooks.example.com/theirs' });
    const mySchedule = await makeSchedule();
    const theirSchedule = await makeSchedule({ clientId: otherClientId });

    expect(await processDueSchedules(new Date())).toBe(2);
    await settleInFlightDeliveries();

    const [myRun] = await runsFor(mySchedule.id);
    const [theirRun] = await runsFor(theirSchedule.id);
    expect(myRun).toMatchObject({ clientId, rowCount: 2 });
    // The other client has no visits: its report must not see this client's.
    expect(theirRun).toMatchObject({ clientId: otherClientId, rowCount: 0 });

    const myDeliveries = await prisma.webhookDelivery.findMany({ where: { webhookId: mine.id } });
    const theirDeliveries = await prisma.webhookDelivery.findMany({ where: { webhookId: theirs.id } });
    expect(myDeliveries).toHaveLength(1);
    expect(theirDeliveries).toHaveLength(1);
    expect((myDeliveries[0].payload as { payload: { runId: string } }).payload.runId).toBe(myRun.id);
    expect((theirDeliveries[0].payload as { payload: { runId: string } }).payload.runId).toBe(theirRun.id);
    expect(myDeliveries[0].clientId).toBe(clientId);
    expect(theirDeliveries[0].clientId).toBe(otherClientId);
  });

  describe('delivery channels', () => {
    const context: ReportDeliveryContext = {
      clientId: 'c-unused',
      recipients: ['ops@example.com', 'lead@example.com'],
      payload: {
        scheduleId: 's',
        reportId: 'r',
        reportName: 'n',
        reportType: 'visits',
        runId: 'run',
        trigger: 'manual',
        generatedAt: new Date().toISOString(),
        rowCount: 0,
        csvPath: '/report-schedules/s/runs/run/csv',
        csvUrl: null,
        csvDownloadUrl: null,
        csvDownloadExpiresAt: null,
      },
    };

    it('with SMTP unset, email sends nothing and records why', async () => {
      expect(await deliverReport(context, [emailDeliveryChannel])).toEqual([
        {
          channel: 'email',
          status: 'not_configured',
          targets: ['ops@example.com', 'lead@example.com'],
          detail: 'Email delivery not configured: SMTP_HOST and SMTP_FROM are not set',
        },
      ]);
    });

    it('a channel that throws is recorded as failed without failing the others', async () => {
      jest.spyOn(console, 'error').mockImplementation(() => undefined);
      const outcomes = await deliverReport(context, [
        { name: 'broken', deliver: () => Promise.reject(new Error('smtp down')) },
        emailDeliveryChannel,
      ]);
      expect(outcomes).toEqual([
        { channel: 'broken', status: 'failed', targets: [], detail: 'smtp down' },
        expect.objectContaining({ channel: 'email', status: 'not_configured' }),
      ]);
    });

    it('uses PUBLIC_API_URL for csvUrl when it is configured', async () => {
      await makeWebhook();
      const schedule = await makeSchedule();
      const previous = process.env.PUBLIC_API_URL;
      process.env.PUBLIC_API_URL = 'https://api.tradeiq.test/';
      try {
        await processDueSchedules(new Date());
      } finally {
        if (previous === undefined) delete process.env.PUBLIC_API_URL;
        else process.env.PUBLIC_API_URL = previous;
      }
      const [run] = await runsFor(schedule.id);
      const [delivery] = await prisma.webhookDelivery.findMany({ where: { clientId } });
      expect((delivery.payload as { payload: { csvUrl: string } }).payload.csvUrl).toBe(
        `https://api.tradeiq.test/report-schedules/${schedule.id}/runs/${run.id}/csv`,
      );
    });
  });

  it('the worker fires due schedules on its interval and stops cleanly', async () => {
    const schedule = await makeSchedule();
    const worker = startReportScheduleWorker({ intervalMs: 10 });
    try {
      const deadline = Date.now() + 5000;
      while ((await runsFor(schedule.id)).length === 0 && Date.now() < deadline) {
        await new Promise((resolve) => setTimeout(resolve, 20));
      }
    } finally {
      await worker.stop();
    }
    expect(await runsFor(schedule.id)).toHaveLength(1);
  });
});

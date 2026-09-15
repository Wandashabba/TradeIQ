import request from 'supertest';
import { createTransport, SendMailOptions, Transport } from 'nodemailer';
import { fetch } from 'undici';
import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { formatLocalDate, formatLocalDateTime, localCalendarDate } from '../../lib/clientTime';
import * as reportsService from '../reports/reports.service';
import { issueToken } from '../auth/auth.service';
import { MAX_ATTEMPTS, RETRY_DELAYS_MS, settleInFlightDeliveries } from '../webhooks/webhooks.service';
import { DAY_MS } from './reportschedules.cadence';
import { REPORT_GENERATED_EVENT } from './reportschedules.delivery';
import {
  composeReportEmail,
  EMAIL_NOT_CONFIGURED,
  MAX_CSV_ATTACHMENT_BYTES,
  MAX_EMAIL_RECIPIENTS,
  processDueReportEmails,
  readSmtpConfig,
  ReportEmailInput,
  setReportMailTransport,
  settleInFlightReportEmails,
  validateRecipients,
} from './reportschedules.email';
import { REPORT_LINK_TTL_MS } from './reportschedules.links';
import { processDueSchedules, runCsvForClient, runSchedule } from './reportschedules.service';

// Webhooks fire alongside email: no real network for either. Mail goes to a
// nodemailer JSON (or failing custom) transport and never opens a socket.
jest.mock('undici', () => ({
  ...jest.requireActual('undici'),
  fetch: jest.fn(),
}));
jest.mock('../../lib/urlGuard', () => ({
  ...jest.requireActual('../../lib/urlGuard'),
  assertPublicHostname: jest.fn().mockResolvedValue(undefined),
}));

const fetchMock = fetch as unknown as jest.Mock;

const ENV_KEYS = [
  'SMTP_HOST',
  'SMTP_PORT',
  'SMTP_SECURE',
  'SMTP_USER',
  'SMTP_PASS',
  'SMTP_FROM',
  'PUBLIC_API_URL',
  'REPORT_LINK_SECRET',
];
const API = 'https://api.tradeiq.test';
const LINK_SECRET = 'email-test-link-secret-0123456789abcdef';
const FROM = 'TradeIQ Reports <reports@tradeiq.test>';
const TZ = 'Africa/Johannesburg';
const EMAIL_OFF = `${EMAIL_NOT_CONFIGURED}: SMTP_HOST and SMTP_FROM are not set`;

function linksOn() {
  process.env.PUBLIC_API_URL = API;
  process.env.REPORT_LINK_SECRET = LINK_SECRET;
}

/** A JSON transport that records every message handed to it. */
function jsonMailer() {
  const transporter = createTransport({ jsonTransport: true });
  const sendMail = jest.spyOn(transporter, 'sendMail');
  setReportMailTransport({ from: FROM, transporter });
  return {
    sent: () => (sendMail.mock.calls as unknown as Array<[SendMailOptions]>).map(([mail]) => mail),
  };
}

/** A transport whose every send fails the way a flaky SMTP server does. */
function failingMailer() {
  const failing: Transport = {
    name: 'failing',
    version: '1.0.0',
    send: (_mail, callback) =>
      callback(Object.assign(new Error('Connection closed'), { responseCode: 421 }), undefined as never),
  };
  setReportMailTransport({ from: FROM, transporter: createTransport(failing) });
}

describe('report email delivery (#66)', () => {
  let clientId: string;
  let otherClientId: string;
  let definitionId: string;
  let otherDefinitionId: string;
  let managerToken: string;
  const savedEnv: Record<string, string | undefined> = {};

  beforeAll(async () => {
    for (const key of ENV_KEYS) {
      savedEnv[key] = process.env[key];
      delete process.env[key];
    }

    const client = await prisma.client.create({
      data: { name: 'RSE-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {}, timezone: TZ },
    });
    clientId = client.id;
    const other = await prisma.client.create({
      data: { name: 'RSE-Other', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {}, timezone: 'UTC' },
    });
    otherClientId = other.id;

    const manager = await prisma.user.create({
      data: { email: 'rse-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });
    const agent = await prisma.user.create({
      data: { email: 'rse-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    const outlet = await prisma.outlet.create({
      data: {
        name: 'RSE-Outlet',
        code: 'RSE-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId,
      },
    });
    // Two visits for the first client; the other client has none.
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
        data: { clientId, name: 'RSE-Visits', type: 'visits', filters: {} },
      })
    ).id;
    otherDefinitionId = (
      await prisma.reportDefinition.create({
        data: { clientId: otherClientId, name: 'RSE-Other Visits', type: 'visits', filters: {} },
      })
    ).id;
  });

  beforeEach(() => {
    fetchMock.mockReset();
    fetchMock.mockResolvedValue({ status: 204, body: null });
  });

  afterEach(async () => {
    await settleInFlightReportEmails();
    await settleInFlightDeliveries();
    setReportMailTransport(null);
    jest.restoreAllMocks();
    for (const key of ENV_KEYS) delete process.env[key];
    const clients = { in: [clientId, otherClientId] };
    await prisma.webhook.deleteMany({ where: { clientId: clients } });
    // Runs, and their email deliveries, cascade with their schedules.
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
    for (const key of ENV_KEYS) {
      if (savedEnv[key] === undefined) delete process.env[key];
      else process.env[key] = savedEnv[key];
    }
  });

  async function makeSchedule(overrides: { clientId?: string; recipients?: string[] } = {}) {
    const owner = overrides.clientId ?? clientId;
    return prisma.reportSchedule.create({
      data: {
        clientId: owner,
        reportDefinitionId: owner === clientId ? definitionId : otherDefinitionId,
        cadence: 'daily',
        recipients: (overrides.recipients ?? ['ops@example.com']) as Prisma.InputJsonValue,
        nextRunAt: new Date(Date.now() - 60_000),
      },
    });
  }

  const emailRows = (runId: string) =>
    prisma.reportEmailDelivery.findMany({ where: { runId }, orderBy: { recipient: 'asc' } });

  it('emails each recipient the CSV attached, with the period in the client timezone', async () => {
    linksOn();
    const mail = jsonMailer();
    const schedule = await makeSchedule({
      recipients: ['ops@example.com', ' Lead@Example.com ', 'lead@example.com', 'not an email'],
    });

    const result = await runSchedule(schedule.id, clientId);
    await settleInFlightReportEmails();

    const email = result.deliveries.find((d) => d.channel === 'email')!;
    expect(email).toMatchObject({
      status: 'queued',
      targets: ['ops@example.com', 'Lead@Example.com'],
      detail: 'Skipped entries that are not email addresses: not an email',
    });
    expect(email.emailDeliveryIds).toHaveLength(2);
    expect(result.deliveredTo).toEqual(['ops@example.com', 'Lead@Example.com']);

    const rows = await emailRows(result.runId);
    expect(rows.map((r) => [r.recipient, r.status, r.attempts, r.csvAttached, r.clientId])).toEqual([
      ['Lead@Example.com', 'succeeded', 1, true, clientId],
      ['ops@example.com', 'succeeded', 1, true, clientId],
    ]);
    // What happened is kept on the run, as for webhooks.
    const run = await prisma.reportScheduleRun.findUniqueOrThrow({ where: { id: result.runId } });
    expect(run.deliveries).toContainEqual(email);

    const sent = mail.sent();
    expect(sent.map((m) => m.to).sort()).toEqual(['Lead@Example.com', 'ops@example.com']);
    const message = sent[0];
    // A run-now's period is the cadence window ending when it was generated.
    const generatedAt = new Date(result.generatedAt);
    const start = new Date(generatedAt.getTime() - DAY_MS);
    expect(message.from).toBe(FROM);
    expect(message.subject).toBe(
      `TradeIQ report: RSE-Visits for RSE-Client, ${formatLocalDate(start, TZ)} – ${formatLocalDate(generatedAt, TZ)}`,
    );
    expect(message.text).toContain(
      `Period:    ${formatLocalDateTime(start, TZ)} – ${formatLocalDateTime(generatedAt, TZ)} (${TZ}, daily)`,
    );
    expect(message.text).toContain(`Generated: ${formatLocalDateTime(generatedAt, TZ)} (${TZ})`);
    expect(message.text).toContain('Rows:      2');
    expect(message.text).toContain('The report is attached as a CSV file.');
    expect(message.headers).toEqual({ 'X-TradeIQ-Report-Run': result.runId });

    const { csv } = await runCsvForClient(schedule.id, result.runId, clientId);
    expect(message.attachments).toEqual([
      {
        filename: `rse-visits-${localCalendarDate(generatedAt, TZ).toISOString().slice(0, 10)}.csv`,
        content: csv,
        contentType: 'text/csv; charset=utf-8',
      },
    ]);

    // The emailed link downloads the same CSV, with no token.
    const link = /https:\/\/api\.tradeiq\.test(\/report-downloads\/[\w-]+\.[\w-]+)/.exec(String(message.text));
    expect(link).not.toBeNull();
    const download = await request(app).get(link![1]);
    expect(download.status).toBe(200);
    expect(download.text).toBe(csv);
  });

  it('over the attachment cap: sends the link only', async () => {
    linksOn();
    const mail = jsonMailer();
    jest.spyOn(reportsService, 'rowsToCsv').mockReturnValue('x'.repeat(MAX_CSV_ATTACHMENT_BYTES + 1));
    const schedule = await makeSchedule();

    const result = await runSchedule(schedule.id, clientId);
    await settleInFlightReportEmails();

    const [row] = await emailRows(result.runId);
    expect(row).toMatchObject({ status: 'succeeded', csvAttached: false });
    const [message] = mail.sent();
    expect(message.attachments).toBeUndefined();
    expect(message.text).toContain('The CSV is 5.0 MB, over the 5.0 MB attachment limit, so it is not attached.');
    expect(message.text).toMatch(/Download the CSV \(link expires [^)]+\): https:\/\/api\.tradeiq\.test\/report-downloads\//);
    expect(message.html).toContain('href="https://api.tradeiq.test/report-downloads/');
  });

  it('unconfigured: recorded as not_configured with the reason, and nothing is queued', async () => {
    const schedule = await makeSchedule();
    const result = await runSchedule(schedule.id, clientId);

    const email = result.deliveries.find((d) => d.channel === 'email');
    expect(email).toEqual({
      channel: 'email',
      status: 'not_configured',
      targets: ['ops@example.com'],
      detail: EMAIL_OFF,
    });
    expect(result.deliveredTo).toEqual([]);
    expect(await prisma.reportEmailDelivery.count({ where: { clientId } })).toBe(0);
    const run = await prisma.reportScheduleRun.findUniqueOrThrow({ where: { id: result.runId } });
    expect(run.deliveries).toContainEqual(email);
  });

  it('a half-set SMTP configuration is not_configured too, naming what is missing', async () => {
    process.env.SMTP_HOST = 'smtp.example.com';
    const schedule = await makeSchedule();
    const result = await runSchedule(schedule.id, clientId);
    expect(result.deliveries.find((d) => d.channel === 'email')).toMatchObject({
      status: 'not_configured',
      detail: `${EMAIL_NOT_CONFIGURED}: SMTP_FROM not set`,
    });
    expect(await prisma.reportEmailDelivery.count({ where: { clientId } })).toBe(0);
  });

  it('a schedule with no usable address records no_subscribers', async () => {
    jsonMailer();
    const schedule = await makeSchedule({ recipients: ['https://hooks.example.com/x'] });
    const result = await runSchedule(schedule.id, clientId);
    expect(result.deliveries.find((d) => d.channel === 'email')).toEqual({
      channel: 'email',
      status: 'no_subscribers',
      targets: [],
      emailDeliveryIds: [],
      detail: 'Skipped entries that are not email addresses: https://hooks.example.com/x',
    });
  });

  it('a transport error is retried on the webhook schedule, then gives up after MAX_ATTEMPTS', async () => {
    jest.spyOn(console, 'error').mockImplementation(() => undefined);
    failingMailer();
    const schedule = await makeSchedule();
    const result = await runSchedule(schedule.id, clientId);
    await settleInFlightReportEmails();

    // Queued, not failed: the run itself is fine and the email is retrying.
    expect(result.deliveries.find((d) => d.channel === 'email')).toMatchObject({ status: 'queued' });
    let [row] = await emailRows(result.runId);
    expect(row).toMatchObject({
      status: 'failed_retrying',
      attempts: 1,
      lastError: 'SMTP 421: Connection closed',
      deliveredAt: null,
    });
    expect(row.nextAttemptAt!.getTime() - row.lastAttemptAt!.getTime()).toBe(RETRY_DELAYS_MS[0]);
    // Not due before its delay.
    expect(await processDueReportEmails(new Date(row.nextAttemptAt!.getTime() - 1000))).toBe(0);

    for (let attempt = 2; attempt <= MAX_ATTEMPTS; attempt += 1) {
      expect(await processDueReportEmails(new Date(row.nextAttemptAt!.getTime() + 1))).toBe(1);
      [row] = await emailRows(result.runId);
      expect(row.attempts).toBe(attempt);
      if (attempt < MAX_ATTEMPTS) {
        expect(row.status).toBe('failed_retrying');
        expect(row.nextAttemptAt!.getTime() - row.lastAttemptAt!.getTime()).toBe(RETRY_DELAYS_MS[attempt - 1]);
      }
    }
    expect(row).toMatchObject({ status: 'gave_up', attempts: MAX_ATTEMPTS, nextAttemptAt: null });
    // A give-up is final: nothing more is claimed, however late.
    expect(await processDueReportEmails(new Date(Date.now() + 7 * DAY_MS))).toBe(0);
  });

  it('a retry that succeeds is recorded as delivered', async () => {
    failingMailer();
    const schedule = await makeSchedule();
    const result = await runSchedule(schedule.id, clientId);
    await settleInFlightReportEmails();
    let [row] = await emailRows(result.runId);
    expect(row.status).toBe('failed_retrying');

    const mail = jsonMailer();
    expect(await processDueReportEmails(new Date(row.nextAttemptAt!.getTime() + 1))).toBe(1);
    [row] = await emailRows(result.runId);
    expect(row).toMatchObject({ status: 'succeeded', attempts: 2, lastError: null, csvAttached: true });
    expect(row.deliveredAt).not.toBeNull();
    expect(mail.sent()).toHaveLength(1);
  });

  it('email switched off after a delivery was queued gives up with the reason, not forever', async () => {
    jest.spyOn(console, 'warn').mockImplementation(() => undefined);
    failingMailer();
    const schedule = await makeSchedule();
    const result = await runSchedule(schedule.id, clientId);
    await settleInFlightReportEmails();
    let [row] = await emailRows(result.runId);

    setReportMailTransport(null);
    expect(await processDueReportEmails(new Date(row.nextAttemptAt!.getTime() + 1))).toBe(1);
    [row] = await emailRows(result.runId);
    expect(row).toMatchObject({ status: 'gave_up', attempts: 1, nextAttemptAt: null, lastError: EMAIL_OFF });
  });

  it("keeps tenants apart: each client's emails carry only its own run and rows", async () => {
    linksOn();
    const mail = jsonMailer();
    const mine = await makeSchedule({ recipients: ['mine@example.com'] });
    const theirs = await makeSchedule({ clientId: otherClientId, recipients: ['theirs@example.com'] });

    expect(await processDueSchedules(new Date())).toBe(2);
    await settleInFlightReportEmails();

    const myRun = await prisma.reportScheduleRun.findFirstOrThrow({ where: { scheduleId: mine.id } });
    const theirRun = await prisma.reportScheduleRun.findFirstOrThrow({ where: { scheduleId: theirs.id } });
    const myRows = await prisma.reportEmailDelivery.findMany({ where: { clientId } });
    const theirRows = await prisma.reportEmailDelivery.findMany({ where: { clientId: otherClientId } });
    expect(myRows.map((r) => [r.recipient, r.runId])).toEqual([['mine@example.com', myRun.id]]);
    expect(theirRows.map((r) => [r.recipient, r.runId])).toEqual([['theirs@example.com', theirRun.id]]);

    const toMine = mail.sent().find((m) => m.to === 'mine@example.com')!;
    const toTheirs = mail.sent().find((m) => m.to === 'theirs@example.com')!;
    expect(toMine.subject).toContain('RSE-Visits for RSE-Client');
    expect(toMine.attachments).toHaveLength(1);
    expect(toMine.headers).toEqual({ 'X-TradeIQ-Report-Run': myRun.id });
    // The other client has no visits: nothing of the first client's reaches it.
    expect(toTheirs.subject).toContain('RSE-Other Visits for RSE-Other');
    expect(toTheirs.attachments).toBeUndefined();
    expect(toTheirs.text).toContain('Rows:      0');
    expect(toTheirs.text).toContain('(UTC, daily)');
    expect(toTheirs.headers).toEqual({ 'X-TradeIQ-Report-Run': theirRun.id });

    // The delivery log is tenant-scoped.
    const auth = { Authorization: `Bearer ${managerToken}` };
    const own = await request(app).get(`/report-schedules/${mine.id}/runs/${myRun.id}/email-deliveries`).set(auth);
    expect(own.status).toBe(200);
    expect(own.body.data.map((d: { recipient: string; status: string }) => [d.recipient, d.status])).toEqual([
      ['mine@example.com', 'succeeded'],
    ]);
    const cross = await request(app)
      .get(`/report-schedules/${theirs.id}/runs/${theirRun.id}/email-deliveries`)
      .set(auth);
    expect(cross.status).toBe(404);
  });

  it('the report.generated webhook payload carries the signed link, which downloads without a token', async () => {
    linksOn();
    await prisma.webhook.create({
      data: { clientId, url: 'https://hooks.example.com/reports', event: REPORT_GENERATED_EVENT, secret: 'whsec' },
    });
    const schedule = await makeSchedule();

    await processDueSchedules(new Date());
    await settleInFlightDeliveries();

    const run = await prisma.reportScheduleRun.findFirstOrThrow({ where: { scheduleId: schedule.id } });
    const [delivery] = await prisma.webhookDelivery.findMany({ where: { clientId } });
    const payload = (delivery.payload as { payload: Record<string, unknown> }).payload;

    // Every field subscribers already read is unchanged; the link is additive.
    const csvPath = `/report-schedules/${schedule.id}/runs/${run.id}/csv`;
    expect(payload).toMatchObject({ runId: run.id, csvPath, csvUrl: `${API}${csvPath}` });
    expect(payload.csvDownloadExpiresAt).toBe(new Date(run.generatedAt.getTime() + REPORT_LINK_TTL_MS).toISOString());
    const url = new URL(payload.csvDownloadUrl as string);
    expect(url.origin).toBe(API);
    expect(url.pathname).toMatch(/^\/report-downloads\/[\w-]+\.[\w-]+$/);

    const res = await request(app).get(url.pathname);
    expect(res.status).toBe(200);
    const { csv } = await runCsvForClient(schedule.id, run.id, clientId);
    expect(res.text).toBe(csv);
  });
});

describe('composeReportEmail (#66)', () => {
  const base: ReportEmailInput = {
    reportName: 'Visits',
    reportType: 'visits',
    clientName: 'Acme',
    timeZone: TZ,
    cadence: 'weekly',
    trigger: 'scheduled',
    dueAt: new Date('2026-09-15T06:00:00.000Z'),
    generatedAt: new Date('2026-09-15T06:30:00.000Z'),
    rowCount: 3,
    csv: 'a,b\n1,2\n3,4\n5,6',
    link: { url: `${API}/report-downloads/tok.sig`, expiresAt: new Date('2026-09-22T06:30:00.000Z') },
  };

  it('names the report, client, period and generated time in the client timezone', () => {
    const email = composeReportEmail(base);
    expect(email.subject).toBe('TradeIQ report: Visits for Acme, 8 Sep 2026 – 15 Sep 2026');
    expect(email.text).toContain('Report:    Visits (visits)');
    expect(email.text).toContain('Client:    Acme');
    expect(email.text).toContain('Period:    8 Sep 2026 08:00 – 15 Sep 2026 08:00 (Africa/Johannesburg, weekly)');
    expect(email.text).toContain('Generated: 15 Sep 2026 08:30 (Africa/Johannesburg)');
    expect(email.text).toContain('Run:       scheduled');
    expect(email.text).toContain(`Download the CSV (link expires 22 Sep 2026 08:30): ${API}/report-downloads/tok.sig`);
    expect(email.attachment).toEqual({
      filename: 'visits-2026-09-15.csv',
      content: base.csv,
      contentType: 'text/csv; charset=utf-8',
    });
  });

  it('the local date, not the UTC one, when the period ends across midnight', () => {
    const email = composeReportEmail({
      ...base,
      cadence: 'daily',
      dueAt: new Date('2026-09-14T23:00:00.000Z'),
      generatedAt: new Date('2026-09-14T23:01:00.000Z'),
    });
    expect(email.subject).toBe('TradeIQ report: Visits for Acme, 14 Sep 2026 – 15 Sep 2026');
    expect(email.text).toContain('Period:    14 Sep 2026 01:00 – 15 Sep 2026 01:00 (Africa/Johannesburg, daily)');
    expect(email.attachment?.filename).toBe('visits-2026-09-15.csv');
  });

  it('attaches up to the cap exactly, counted in bytes, and links only past it', () => {
    const atCap = composeReportEmail({ ...base, csv: 'x'.repeat(MAX_CSV_ATTACHMENT_BYTES) });
    expect(atCap.attachment).not.toBeNull();
    // 'é' is two bytes: half the cap in characters is one byte over it.
    const overInBytes = composeReportEmail({ ...base, csv: `${'é'.repeat(MAX_CSV_ATTACHMENT_BYTES / 2)}x` });
    expect(overInBytes.attachment).toBeNull();
    expect(overInBytes.text).toContain('over the 5.0 MB attachment limit');
    expect(overInBytes.text).toContain(`${API}/report-downloads/tok.sig`);
  });

  it('over the cap with links not configured, it says no link could be included', () => {
    const email = composeReportEmail({ ...base, link: null, csv: 'x'.repeat(MAX_CSV_ATTACHMENT_BYTES + 1) });
    expect(email.attachment).toBeNull();
    expect(email.text).toContain('No download link could be included');
  });

  it('an empty report attaches nothing and says so', () => {
    const email = composeReportEmail({ ...base, rowCount: 0, csv: '' });
    expect(email.attachment).toBeNull();
    expect(email.text).toContain('The report has no rows, so no CSV is attached.');
  });

  it('escapes names in HTML and keeps them to one line in the subject', () => {
    const email = composeReportEmail({
      ...base,
      reportName: '<b>Q3 & "more"</b>\r\nBcc: victim@example.com',
      clientName: "O'Brien <Ltd>",
    });
    expect(email.subject).not.toMatch(/[\r\n]/);
    expect(email.html).not.toContain('<b>Q3');
    expect(email.html).toContain('&lt;b&gt;Q3 &amp; &quot;more&quot;&lt;/b&gt;');
    expect(email.html).toContain('O&#39;Brien &lt;Ltd&gt;');
  });

  it('falls back to the default timezone for an unknown zone', () => {
    const email = composeReportEmail({ ...base, timeZone: 'Mars/Olympus' });
    expect(email.text).toContain('(Africa/Johannesburg, weekly)');
  });
});

describe('SMTP configuration (#66)', () => {
  it('unset is unconfigured', () => {
    expect(readSmtpConfig({})).toEqual({ state: 'unconfigured', reason: 'SMTP_HOST and SMTP_FROM are not set' });
    expect(readSmtpConfig({ SMTP_HOST: '  ', SMTP_FROM: '' })).toMatchObject({ state: 'unconfigured' });
  });

  it('defaults to STARTTLS on 587, and implicit TLS on 465', () => {
    expect(readSmtpConfig({ SMTP_HOST: 'smtp.example.com', SMTP_FROM: 'r@example.com' })).toEqual({
      state: 'configured',
      config: { host: 'smtp.example.com', port: 587, secure: false, user: undefined, pass: undefined, from: 'r@example.com' },
    });
    expect(readSmtpConfig({ SMTP_HOST: 'h.example.com', SMTP_FROM: 'r@example.com', SMTP_SECURE: 'true' })).toMatchObject({
      config: { port: 465, secure: true },
    });
    expect(readSmtpConfig({ SMTP_HOST: 'h.example.com', SMTP_FROM: 'r@example.com', SMTP_PORT: '465' })).toMatchObject({
      config: { port: 465, secure: true },
    });
    expect(
      readSmtpConfig({
        SMTP_HOST: 'h.example.com',
        SMTP_FROM: 'TradeIQ Reports <r@example.com>',
        SMTP_PORT: '2525',
        SMTP_SECURE: 'FALSE',
        SMTP_USER: 'apikey',
        SMTP_PASS: 'p@ss ',
      }),
    ).toMatchObject({ config: { port: 2525, secure: false, user: 'apikey', pass: 'p@ss ' } });
  });

  it('refuses a partial or malformed configuration, without echoing values', () => {
    const cases: Array<[NodeJS.ProcessEnv, string]> = [
      [{ SMTP_HOST: 'h.example.com' }, 'SMTP_FROM not set'],
      [{ SMTP_FROM: 'r@example.com', SMTP_PASS: 'hunter2-secret' }, 'SMTP_HOST not set'],
      [{ SMTP_HOST: 'h', SMTP_FROM: 'not an address' }, 'SMTP_FROM is not an email address (or "Name <address>")'],
      [{ SMTP_HOST: 'h', SMTP_FROM: 'r@example.com', SMTP_PORT: 'abc' }, 'SMTP_PORT must be a port number'],
      [{ SMTP_HOST: 'h', SMTP_FROM: 'r@example.com', SMTP_PORT: '70000' }, 'SMTP_PORT must be a port number'],
      [{ SMTP_HOST: 'h', SMTP_FROM: 'r@example.com', SMTP_SECURE: 'yes' }, 'SMTP_SECURE must be true or false'],
      [
        { SMTP_HOST: 'h', SMTP_FROM: 'r@example.com', SMTP_PASS: 'hunter2-secret' },
        'SMTP_USER and SMTP_PASS must be set together',
      ],
    ];
    for (const [env, reason] of cases) {
      const state = readSmtpConfig(env);
      expect(state).toEqual({ state: 'invalid', reason });
      expect(JSON.stringify(state)).not.toContain('hunter2');
    }
  });
});

describe('validateRecipients (#66)', () => {
  it('trims, de-duplicates case-insensitively, and keeps the first spelling', () => {
    expect(validateRecipients([' Ops@Example.com', 'ops@example.com', 'lead@example.com'])).toEqual({
      ok: true,
      recipients: ['Ops@Example.com', 'lead@example.com'],
    });
  });

  it('refuses anything that is not a list of email addresses', () => {
    for (const value of [undefined, 'ops@example.com', [], [42], ['ops@example.com', 'https://hooks.example.com']]) {
      expect(validateRecipients(value).ok).toBe(false);
    }
    expect(validateRecipients(['a@example.com', 'bad', 'a,b@example.com'])).toEqual({
      ok: false,
      error: `recipients must be a non-empty array of at most ${MAX_EMAIL_RECIPIENTS} email addresses; not an email address: bad, a,b@example.com`,
    });
    const tooMany = Array.from({ length: MAX_EMAIL_RECIPIENTS + 1 }, (_, i) => `r${i}@example.com`);
    expect(validateRecipients(tooMany).ok).toBe(false);
  });
});

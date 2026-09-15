import { createTransport, SendMailOptions, Transporter } from 'nodemailer';
import { Prisma, WebhookDeliveryStatus } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';
import {
  DEFAULT_CLIENT_TIME_ZONE,
  formatLocalDate,
  formatLocalDateTime,
  isValidTimeZone,
  localCalendarDate,
} from '../../lib/clientTime';
import { NotFoundError } from '../../middleware/errorHandler';
import { generateReport, rowsToCsv } from '../reports/reports.service';
import { MAX_ATTEMPTS, retryDelayAfter } from '../webhooks/webhooks.service';
import { cadencePeriodMs } from './reportschedules.cadence';
import { reportLinkSecret, publicApiBase, signedReportLink, SignedReportLink } from './reportschedules.links';
import type {
  ReportDeliveryChannel,
  ReportDeliveryOutcome,
} from './reportschedules.delivery';

/**
 * Email delivery for scheduled reports (#66), over plain SMTP so any provider
 * works: Google Workspace, Microsoft 365, Amazon SES, Resend and so on.
 *
 * **Off until configured.** With no SMTP_HOST/SMTP_FROM the channel records
 * `not_configured` on the run, with the reason, and queues nothing — so there
 * is nothing to fail silently and nothing to retry forever. A half-set or
 * malformed configuration is treated the same way and said so at startup.
 *
 * **The webhook pipeline's semantics, not a second set.** One row per
 * recipient in `report_email_deliveries`, created leased and attempted in the
 * background straight away; a failed attempt waits on the same RETRY_DELAYS_MS
 * schedule, gives up after the same MAX_ATTEMPTS, and is claimed by the worker
 * with the same `FOR UPDATE SKIP LOCKED` lease. What differs is only the
 * transport.
 *
 * **Rebuilt on every attempt.** The row stores no message: each attempt
 * regenerates the run's CSV bounded to its `generatedAt` (as the CSV endpoint
 * does) and composes the email then. The CSV is attached when it is under
 * MAX_CSV_ATTACHMENT_BYTES; otherwise the email carries only the signed link.
 */

export const EMAIL_NOT_CONFIGURED = 'Email delivery not configured';

/**
 * Largest CSV attached to an email, in bytes of the CSV itself.
 *
 * Base64 inflates an attachment by a third, so 5 MB becomes ~6.7 MB on the
 * wire — inside Amazon SES's 10 MB message limit, the tightest of the common
 * providers (Google Workspace and Microsoft 365 allow 25 MB+), with room for
 * the body. Past that a mailbox would bounce it, and a large attachment on a
 * daily schedule fills inboxes too; the signed link serves any size.
 */
export const MAX_CSV_ATTACHMENT_BYTES = 5 * 1024 * 1024;

/** Most recipients a schedule may hold. A report is not a mailing list. */
export const MAX_EMAIL_RECIPIENTS = 50;

/**
 * SMTP timeouts. nodemailer's defaults wait up to two minutes for a connection
 * and ten for socket inactivity; a hung server would then hold a worker slot
 * for most of a claim lease. The socket allowance covers uploading a
 * full-size attachment over a slow link.
 */
const SMTP_CONNECTION_TIMEOUT_MS = 10_000;
const SMTP_GREETING_TIMEOUT_MS = 10_000;
const SMTP_SOCKET_TIMEOUT_MS = 60_000;

/**
 * How long a claimed row is hidden from other processors. An attempt
 * regenerates a report and uploads it, so this is longer than a webhook's.
 */
export const EMAIL_CLAIM_LEASE_MS = 5 * 60_000;

const MAX_ERROR_LENGTH = 500;

const ATTEMPTABLE: WebhookDeliveryStatus[] = ['pending', 'failed_retrying'];

// ── Recipients ──────────────────────────────────────────────────────────────

/**
 * A practical address check, not RFC 5322: one `@`, a dotted domain, no
 * spaces, and nothing that could split or extend an address header (`<>`,
 * commas, semicolons, quotes). Anything this lets through that a server
 * refuses fails that one recipient's delivery, visibly, in its log.
 */
const EMAIL_ADDRESS = /^[^\s@<>()[\],;:"\\]+@[^\s@<>()[\],;:"\\]+\.[^\s@<>()[\],;:"\\]+$/;

export function isEmailAddress(value: unknown): value is string {
  return typeof value === 'string' && value.length <= 254 && EMAIL_ADDRESS.test(value);
}

export type RecipientsValidation =
  | { ok: true; recipients: string[] }
  | { ok: false; error: string };

/**
 * Validates a schedule's recipients on write: 1–MAX_EMAIL_RECIPIENTS email
 * addresses. Entries are trimmed and de-duplicated case-insensitively, keeping
 * the first spelling.
 */
export function validateRecipients(value: unknown): RecipientsValidation {
  const error = `recipients must be a non-empty array of at most ${MAX_EMAIL_RECIPIENTS} email addresses`;
  if (!Array.isArray(value) || value.length === 0) return { ok: false, error };
  if (!value.every((r) => typeof r === 'string')) return { ok: false, error };
  const { valid, invalid } = splitRecipients(value as string[]);
  if (invalid.length > 0) {
    return { ok: false, error: `${error}; not an email address: ${invalid.slice(0, 5).join(', ')}` };
  }
  if (valid.length === 0 || valid.length > MAX_EMAIL_RECIPIENTS) return { ok: false, error };
  return { ok: true, recipients: valid };
}

/** Trimmed, de-duplicated addresses, and the stored entries that are not ones. */
export function splitRecipients(recipients: readonly string[]): { valid: string[]; invalid: string[] } {
  const valid: string[] = [];
  const invalid: string[] = [];
  const seen = new Set<string>();
  for (const raw of recipients) {
    const entry = raw.trim();
    if (!isEmailAddress(entry)) {
      if (entry) invalid.push(entry);
      continue;
    }
    const key = entry.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    valid.push(entry);
  }
  return { valid, invalid };
}

// ── Configuration ───────────────────────────────────────────────────────────

export interface SmtpConfig {
  host: string;
  port: number;
  secure: boolean;
  user?: string;
  pass?: string;
  from: string;
}

export type SmtpConfigState =
  | { state: 'configured'; config: SmtpConfig }
  | { state: 'unconfigured'; reason: string }
  | { state: 'invalid'; reason: string };

const SMTP_VARS = ['SMTP_HOST', 'SMTP_PORT', 'SMTP_SECURE', 'SMTP_USER', 'SMTP_PASS', 'SMTP_FROM'] as const;

/** `Name <addr@example.com>` or a bare address. */
function isFromHeader(value: string): boolean {
  const angled = /^[^<>\r\n]*<([^<>\r\n]+)>$/.exec(value);
  return isEmailAddress(angled ? angled[1].trim() : value);
}

/**
 * Reads SMTP_* from the environment. Unset (every variable empty) is
 * `unconfigured`: email is simply off. Anything partly set or malformed is
 * `invalid`, with a reason that names variables but never echoes a value.
 */
export function readSmtpConfig(env: NodeJS.ProcessEnv = process.env): SmtpConfigState {
  const get = (name: (typeof SMTP_VARS)[number]) => env[name]?.trim() || undefined;
  if (SMTP_VARS.every((name) => get(name) === undefined)) {
    return { state: 'unconfigured', reason: 'SMTP_HOST and SMTP_FROM are not set' };
  }

  const host = get('SMTP_HOST');
  const from = get('SMTP_FROM');
  const missing = [!host && 'SMTP_HOST', !from && 'SMTP_FROM'].filter(Boolean);
  if (missing.length > 0) {
    return { state: 'invalid', reason: `${missing.join(' and ')} not set` };
  }
  if (!isFromHeader(from!)) {
    return { state: 'invalid', reason: 'SMTP_FROM is not an email address (or "Name <address>")' };
  }

  const secureRaw = get('SMTP_SECURE')?.toLowerCase();
  if (secureRaw !== undefined && secureRaw !== 'true' && secureRaw !== 'false') {
    return { state: 'invalid', reason: 'SMTP_SECURE must be true or false' };
  }

  const portRaw = get('SMTP_PORT');
  let port: number;
  if (portRaw === undefined) {
    // 465 is implicit TLS; 587 is submission with STARTTLS.
    port = secureRaw === 'true' ? 465 : 587;
  } else {
    port = Number(portRaw);
    if (!/^\d+$/.test(portRaw) || port < 1 || port > 65535) {
      return { state: 'invalid', reason: 'SMTP_PORT must be a port number' };
    }
  }
  const secure = secureRaw === undefined ? port === 465 : secureRaw === 'true';

  const user = get('SMTP_USER');
  // Not trimmed: a password may legitimately end in whitespace.
  const pass = env.SMTP_PASS || undefined;
  if (Boolean(user) !== Boolean(pass)) {
    return { state: 'invalid', reason: 'SMTP_USER and SMTP_PASS must be set together' };
  }

  return { state: 'configured', config: { host: host!, port, secure, user, pass, from: from! } };
}

export function createSmtpTransport(config: SmtpConfig): Transporter {
  return createTransport({
    host: config.host,
    port: config.port,
    secure: config.secure,
    // Never send credentials in the clear: when authenticating over a
    // STARTTLS port, refuse a server that does not offer TLS rather than
    // falling back to plaintext. An unauthenticated local relay (a dev mail
    // catcher) is allowed without it.
    requireTLS: !config.secure && Boolean(config.user),
    ...(config.user ? { auth: { user: config.user, pass: config.pass } } : {}),
    connectionTimeout: SMTP_CONNECTION_TIMEOUT_MS,
    greetingTimeout: SMTP_GREETING_TIMEOUT_MS,
    socketTimeout: SMTP_SOCKET_TIMEOUT_MS,
  });
}

type Mailer = { ok: true; from: string; transporter: Transporter } | { ok: false; reason: string };

let transportOverride: { from: string; transporter: Transporter } | null = null;
let cachedTransport: { key: string; transporter: Transporter } | null = null;

/**
 * Replaces the SMTP transport — for tests, which pass a nodemailer JSON or
 * custom transport so nothing touches the network. `null` restores the
 * environment's configuration.
 */
export function setReportMailTransport(override: { from: string; transporter: Transporter } | null): void {
  transportOverride = override;
}

/** The transport to send with, or why there is none. Built once per config. */
export function reportMailer(env: NodeJS.ProcessEnv = process.env): Mailer {
  if (transportOverride) return { ok: true, ...transportOverride };
  const state = readSmtpConfig(env);
  if (state.state !== 'configured') {
    return { ok: false, reason: `${EMAIL_NOT_CONFIGURED}: ${state.reason}` };
  }
  const key = JSON.stringify(state.config);
  if (!cachedTransport || cachedTransport.key !== key) {
    cachedTransport = { key, transporter: createSmtpTransport(state.config) };
  }
  return { ok: true, from: state.config.from, transporter: cachedTransport.transporter };
}

/**
 * Logs, once at startup, whether report email and signed links are on — and
 * if not, why. Never a password; the SMTP user is reduced to whether one is
 * set. When SMTP is configured it also checks the server answers and accepts
 * the login, in the background, so a wrong password shows at deploy time
 * rather than as a column of failed deliveries the next morning.
 */
export function logReportEmailConfig(env: NodeJS.ProcessEnv = process.env): void {
  const state = readSmtpConfig(env);
  const links = reportLinkSecret(env);
  const base = publicApiBase(env);
  const linkState = !base
    ? 'off (PUBLIC_API_URL is not set)'
    : links.ok
      ? `on (${base}, valid 7 days)`
      : `off (${links.reason})`;

  if (state.state === 'unconfigured') {
    console.log(`[report-email] off: ${state.reason}. Signed CSV links: ${linkState}.`);
    return;
  }
  if (state.state === 'invalid') {
    console.warn(
      `[report-email] off, SMTP configuration is invalid: ${state.reason}. ` +
        `Scheduled reports will record email as not_configured. Signed CSV links: ${linkState}.`,
    );
    return;
  }

  const { host, port, secure, user, from } = state.config;
  console.log(
    `[report-email] on: host=${host} port=${port} secure=${secure} auth=${user ? 'yes' : 'no'} ` +
      `from=${from}. Signed CSV links: ${linkState}.`,
  );
  if (!links.ok || !base) {
    console.warn(
      '[report-email] reports over the attachment cap will be emailed without a download link ' +
        'until PUBLIC_API_URL and REPORT_LINK_SECRET are both set.',
    );
  }
  const mailer = reportMailer(env);
  if (mailer.ok) {
    mailer.transporter.verify().then(
      () => console.log('[report-email] SMTP server reachable and accepted the login'),
      (err: unknown) => console.warn(`[report-email] SMTP check failed: ${describeError(err)}`),
    );
  }
}

// ── The message ─────────────────────────────────────────────────────────────

export interface ReportEmailInput {
  reportName: string;
  reportType: string;
  clientName: string;
  timeZone: string;
  cadence: string;
  trigger: string;
  /** The due time a scheduled run fired for; null for a manual run. */
  dueAt: Date | null;
  generatedAt: Date;
  rowCount: number;
  csv: string;
  link: SignedReportLink | null;
}

export interface ComposedReportEmail {
  subject: string;
  text: string;
  html: string;
  attachment: { filename: string; content: string; contentType: string } | null;
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function oneLine(value: string): string {
  return value.replace(/[\r\n\t]+/g, ' ').trim();
}

function megabytes(bytes: number): string {
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function fileSlug(value: string): string {
  const slug = value
    .normalize('NFKD')
    .replace(/[^A-Za-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .toLowerCase()
    .slice(0, 60);
  return slug || 'report';
}

/**
 * The email for one run. Pure, so every wording and the attach-or-link rule are
 * testable without SMTP or a database.
 *
 * The period is the schedule's cadence window ending at the run's due time (or
 * at generation, for a run-now), shown in the client's timezone (#309). It
 * names the window the schedule covers; the rows themselves follow the saved
 * report's own filters, up to the generated time, and the body says so.
 */
export function composeReportEmail(input: ReportEmailInput): ComposedReportEmail {
  const tz = isValidTimeZone(input.timeZone) ? input.timeZone : DEFAULT_CLIENT_TIME_ZONE;
  const end = input.dueAt ?? input.generatedAt;
  const start = new Date(end.getTime() - cadencePeriodMs(input.cadence));
  const reportName = oneLine(input.reportName);
  const clientName = oneLine(input.clientName);
  const cadence = input.cadence === 'weekly' ? 'weekly' : 'daily';

  const periodShort = `${formatLocalDate(start, tz)} – ${formatLocalDate(end, tz)}`;
  const period = `${formatLocalDateTime(start, tz)} – ${formatLocalDateTime(end, tz)} (${tz}, ${cadence})`;
  const generated = `${formatLocalDateTime(input.generatedAt, tz)} (${tz})`;

  const csvBytes = Buffer.byteLength(input.csv, 'utf8');
  const attach = input.rowCount > 0 && csvBytes > 0 && csvBytes <= MAX_CSV_ATTACHMENT_BYTES;

  let delivery: string;
  if (input.rowCount === 0 || csvBytes === 0) {
    delivery = 'The report has no rows, so no CSV is attached.';
  } else if (attach) {
    delivery = 'The report is attached as a CSV file.';
  } else {
    delivery =
      `The CSV is ${megabytes(csvBytes)}, over the ${megabytes(MAX_CSV_ATTACHMENT_BYTES)} ` +
      'attachment limit, so it is not attached.';
  }
  const linkLine = input.link
    ? `Download the CSV (link expires ${formatLocalDateTime(input.link.expiresAt, tz)}): ${input.link.url}`
    : attach || input.rowCount === 0
      ? null
      : 'No download link could be included: signed links are not set up on this server. ' +
        'A TradeIQ manager or admin can download the run from the API.';

  const subject = oneLine(`TradeIQ report: ${reportName} for ${clientName}, ${periodShort}`);

  const facts: Array<[string, string]> = [
    ['Report', `${reportName} (${input.reportType})`],
    ['Client', clientName],
    ['Period', period],
    ['Generated', generated],
    ['Rows', String(input.rowCount)],
    ['Run', input.trigger === 'manual' ? 'run now' : 'scheduled'],
  ];
  const note =
    "Rows follow the saved report's filters and include records up to the generated time.";

  const text = [
    `${reportName} for ${clientName}`,
    '',
    ...facts.map(([label, value]) => `${`${label}:`.padEnd(11)}${value}`),
    '',
    delivery,
    ...(linkLine ? [linkLine] : []),
    '',
    note,
    '',
    'Sent by TradeIQ because this address is a recipient of a scheduled report.',
  ].join('\n');

  const linkHtml = input.link
    ? `<p><a href="${escapeHtml(input.link.url)}">Download the CSV</a> (link expires ${escapeHtml(
        formatLocalDateTime(input.link.expiresAt, tz),
      )})</p>`
    : linkLine
      ? `<p>${escapeHtml(linkLine)}</p>`
      : '';
  const html = [
    `<p><strong>${escapeHtml(reportName)}</strong> for ${escapeHtml(clientName)}</p>`,
    '<table cellpadding="4" cellspacing="0">',
    ...facts.map(
      ([label, value]) => `<tr><td><strong>${escapeHtml(label)}</strong></td><td>${escapeHtml(value)}</td></tr>`,
    ),
    '</table>',
    `<p>${escapeHtml(delivery)}</p>`,
    linkHtml,
    `<p>${escapeHtml(note)}</p>`,
    '<p style="color:#666">Sent by TradeIQ because this address is a recipient of a scheduled report.</p>',
  ]
    .filter(Boolean)
    .join('\n');

  return {
    subject,
    text,
    html,
    attachment: attach
      ? {
          // The period's last local date, as in the subject.
          filename: `${fileSlug(reportName)}-${localCalendarDate(end, tz).toISOString().slice(0, 10)}.csv`,
          content: input.csv,
          contentType: 'text/csv; charset=utf-8',
        }
      : null,
  };
}

// ── Delivery ────────────────────────────────────────────────────────────────

/** Attempts started in this process and not yet finished (see webhooks.service). */
const inFlight = new Set<Promise<void>>();

function track(work: Promise<void>): void {
  inFlight.add(work);
  void work.finally(() => inFlight.delete(work));
}

/** Resolves once every email attempt started in this process has finished. */
export async function settleInFlightReportEmails(): Promise<void> {
  while (inFlight.size > 0) {
    await Promise.allSettled([...inFlight]);
  }
}

function describeError(err: unknown): string {
  const message = err instanceof Error ? err.message : String(err);
  const code = (err as { responseCode?: unknown })?.responseCode;
  const full = typeof code === 'number' && !message.includes(String(code)) ? `SMTP ${code}: ${message}` : message;
  return full.length > MAX_ERROR_LENGTH ? `${full.slice(0, MAX_ERROR_LENGTH - 1)}…` : full;
}

/**
 * One CSV per run however many recipients are attempted at once: a run's
 * first attempts all start together, and each would otherwise regenerate the
 * whole report.
 */
const csvInFlight = new Map<string, Promise<string>>();

function runCsv(run: { id: string; clientId: string; generatedAt: Date; reportDefinitionId: string }) {
  let pending = csvInFlight.get(run.id);
  if (!pending) {
    pending = generateReport(run.reportDefinitionId, run.clientId, { asOf: run.generatedAt })
      .then((report) => rowsToCsv(report.rows))
      .finally(() => csvInFlight.delete(run.id));
    csvInFlight.set(run.id, pending);
  }
  return pending;
}

/**
 * Creates one delivery row per recipient for a run, already leased, and starts
 * each first attempt in the background. Throws if the rows cannot be written.
 */
export async function enqueueReportEmails(
  clientId: string,
  runId: string,
  recipients: readonly string[],
): Promise<string[]> {
  if (recipients.length === 0) return [];
  const leaseUntil = new Date(Date.now() + EMAIL_CLAIM_LEASE_MS);
  const rows = await prisma.reportEmailDelivery.createManyAndReturn({
    data: recipients.map((recipient) => ({
      runId,
      clientId,
      recipient,
      status: 'pending' as const,
      nextAttemptAt: leaseUntil,
    })),
    select: { id: true },
  });
  for (const row of rows) {
    track(attemptReportEmail(row.id));
  }
  return rows.map((row) => row.id);
}

/**
 * Makes one attempt at an email delivery and records the outcome, exactly as
 * `attemptDelivery` does for a webhook: guarded on `attempts` so overlapping
 * processors cannot record twice, retried on RETRY_DELAYS_MS, given up after
 * MAX_ATTEMPTS. Never throws.
 *
 * Email switched off since the row was queued gives up at once, with the
 * reason — like a paused webhook, it is a deliberate state rather than a
 * failing server, and retrying would only fail the same way for eight hours.
 */
export async function attemptReportEmail(id: string, now: () => Date = () => new Date()): Promise<void> {
  try {
    const delivery = await prisma.reportEmailDelivery.findUnique({
      where: { id },
      include: {
        run: {
          include: {
            schedule: {
              select: {
                cadence: true,
                reportDefinitionId: true,
                reportDefinition: { select: { name: true, type: true } },
                client: { select: { name: true, timezone: true } },
              },
            },
          },
        },
      },
    });
    if (!delivery || !ATTEMPTABLE.includes(delivery.status)) return;

    const mailer = reportMailer();
    if (!mailer.ok) {
      await prisma.reportEmailDelivery.updateMany({
        where: { id, attempts: delivery.attempts },
        data: { status: 'gave_up', nextAttemptAt: null, lastError: mailer.reason },
      });
      console.warn(`Report email ${id} not sent: ${mailer.reason}`);
      return;
    }

    const attempt = delivery.attempts + 1;
    const { run } = delivery;
    let outcome: { ok: true; csvAttached: boolean } | { ok: false; error: string };
    try {
      const csv = await runCsv({
        id: run.id,
        clientId: run.clientId,
        generatedAt: run.generatedAt,
        reportDefinitionId: run.schedule.reportDefinitionId,
      });
      const message = composeReportEmail({
        reportName: run.schedule.reportDefinition.name,
        reportType: run.schedule.reportDefinition.type,
        clientName: run.schedule.client.name,
        timeZone: run.schedule.client.timezone,
        cadence: run.schedule.cadence,
        trigger: run.trigger,
        dueAt: run.dueAt,
        generatedAt: run.generatedAt,
        rowCount: run.rowCount,
        csv,
        link: signedReportLink({
          clientId: run.clientId,
          scheduleId: run.scheduleId,
          runId: run.id,
          generatedAt: run.generatedAt,
        }),
      });
      const mail: SendMailOptions = {
        from: mailer.from,
        to: delivery.recipient,
        subject: message.subject,
        text: message.text,
        html: message.html,
        headers: { 'X-TradeIQ-Report-Run': run.id },
        ...(message.attachment ? { attachments: [message.attachment] } : {}),
      };
      await mailer.transporter.sendMail(mail);
      outcome = { ok: true, csvAttached: message.attachment !== null };
    } catch (err) {
      outcome = { ok: false, error: describeError(err) };
    }

    const at = now();
    let data: Prisma.ReportEmailDeliveryUpdateManyMutationInput;
    if (outcome.ok) {
      data = {
        status: 'succeeded',
        attempts: attempt,
        lastError: null,
        nextAttemptAt: null,
        lastAttemptAt: at,
        deliveredAt: at,
        csvAttached: outcome.csvAttached,
      };
    } else {
      const status = attempt >= MAX_ATTEMPTS ? 'gave_up' : 'failed_retrying';
      data = {
        status,
        attempts: attempt,
        lastError: outcome.error,
        nextAttemptAt: status === 'gave_up' ? null : new Date(at.getTime() + retryDelayAfter(attempt)),
        lastAttemptAt: at,
      };
      if (status === 'gave_up') {
        console.error(`Report email ${id} (run ${run.id}) gave up after ${attempt} attempts: ${outcome.error}`);
      }
    }
    await prisma.reportEmailDelivery.updateMany({ where: { id, attempts: delivery.attempts }, data });
  } catch (err) {
    console.error(`Report email ${id} could not be attempted:`, err);
  }
}

/** Claims due email deliveries (same lease scheme as `claimDueDeliveries`). */
export async function claimDueReportEmails(now: Date, limit: number): Promise<string[]> {
  const rows = await prisma.$queryRaw<Array<{ id: string }>>`
    UPDATE "report_email_deliveries"
    SET "next_attempt_at" = ${new Date(now.getTime() + EMAIL_CLAIM_LEASE_MS).toISOString()}::timestamp
    WHERE "id" IN (
      SELECT "id" FROM "report_email_deliveries"
      WHERE "status" IN ('pending', 'failed_retrying')
        AND "next_attempt_at" <= ${now.toISOString()}::timestamp
      ORDER BY "next_attempt_at"
      LIMIT ${limit}
      FOR UPDATE SKIP LOCKED
    )
    RETURNING "id"
  `;
  return rows.map((row) => row.id);
}

/** Claims a batch of due email deliveries and attempts each. Returns how many. */
export async function processDueReportEmails(now: Date = new Date(), limit = 5): Promise<number> {
  const ids = await claimDueReportEmails(now, limit);
  await Promise.all(ids.map((id) => attemptReportEmail(id)));
  return ids.length;
}

/** A run's email delivery log. Tenant-scoped: another client's run is a 404. */
export async function listEmailDeliveriesForRun(input: {
  scheduleId: string;
  runId: string;
  clientId: string;
  limit: number;
  cursor?: string;
}) {
  const run = await prisma.reportScheduleRun.findFirst({
    where: { id: input.runId, scheduleId: input.scheduleId, clientId: input.clientId },
    select: { id: true },
  });
  if (!run) {
    throw new NotFoundError('Report run not found');
  }
  const rows = await prisma.reportEmailDelivery.findMany({
    where: { runId: run.id, clientId: input.clientId },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });
  return buildPage(rows, input.limit);
}

// ── The channel ─────────────────────────────────────────────────────────────

export const emailDeliveryChannel: ReportDeliveryChannel = {
  name: 'email',
  async deliver({ clientId, recipients, payload }): Promise<ReportDeliveryOutcome> {
    const mailer = reportMailer();
    if (!mailer.ok) {
      return { channel: 'email', status: 'not_configured', targets: [...recipients], detail: mailer.reason };
    }

    const { valid, invalid } = splitRecipients(recipients);
    const skipped = invalid.length > 0 ? `Skipped entries that are not email addresses: ${invalid.join(', ')}` : null;
    if (valid.length === 0) {
      return {
        channel: 'email',
        status: 'no_subscribers',
        targets: [],
        emailDeliveryIds: [],
        detail: skipped ?? 'The schedule has no email recipients',
      };
    }

    const ids = await enqueueReportEmails(clientId, payload.runId, valid);
    return {
      channel: 'email',
      status: 'queued',
      targets: valid,
      emailDeliveryIds: ids,
      ...(skipped ? { detail: skipped } : {}),
    };
  },
};

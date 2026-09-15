import { ReportScheduleRun, WebhookDeliveryStatus } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';
import type { ReportDeliveryOutcome, ReportDeliveryStatus } from './reportschedules.delivery';
import { signedReportLink } from './reportschedules.links';
import { findScheduleForClient } from './reportschedules.service';

/**
 * A schedule's run history (#66), for the manager console.
 *
 * A run stores only what each channel did when it was handed the report
 * (`deliveries`). What happened next lives on the delivery rows: webhook
 * deliveries (named by id in the webhook outcome) and one email delivery per
 * recipient. This joins the two into a per-run summary, so the console can
 * say "delivered", "still sending" or "failed" without one request per run.
 */

/**
 * Where a run's delivery stands, across every channel.
 *
 * - `delivering`: some webhook or email delivery is still queued or retrying.
 * - `delivered`: at least one delivery succeeded and none failed.
 * - `partial`: some deliveries succeeded and some failed.
 * - `failed`: deliveries or a channel failed, and nothing succeeded.
 * - `not_sent`: nothing was queued anywhere (no subscribed webhook, email not
 *   configured, no recipients). `reason` says why.
 */
export type RunStatus = 'delivering' | 'delivered' | 'partial' | 'failed' | 'not_sent';

export interface RunWebhookSummary {
  /** The channel's outcome when the run was delivered; null if none recorded. */
  status: ReportDeliveryStatus | null;
  delivered: number;
  failed: number;
  pending: number;
}

export interface RunEmailSummary {
  status: ReportDeliveryStatus | null;
  sent: number;
  failed: number;
  /** Queued or retrying. */
  pending: number;
  /** Recipients not emailed because SMTP was not configured for the run. */
  notConfigured: number;
}

export interface RunDeliverySummary {
  webhook: RunWebhookSummary;
  email: RunEmailSummary;
}

/** One webhook delivery of a run, as its log shows it. */
export interface RunWebhookResult {
  id: string;
  webhookId: string;
  url: string;
  status: WebhookDeliveryStatus;
  attempts: number;
  lastStatusCode: number | null;
  lastError: string | null;
  lastAttemptAt: Date | null;
  nextAttemptAt: Date | null;
  deliveredAt: Date | null;
}

export interface ReportRunHistoryItem {
  id: string;
  scheduleId: string;
  trigger: string;
  status: RunStatus;
  dueAt: Date | null;
  generatedAt: Date;
  rowCount: number;
  createdAt: Date;
  reason: string | null;
  summary: RunDeliverySummary;
  deliveries: ReportDeliveryOutcome[];
  webhookDeliveries: RunWebhookResult[];
  csvDownloadUrl: string | null;
  csvDownloadExpiresAt: Date | null;
}

type StatusCounts = Partial<Record<WebhookDeliveryStatus, number>>;

/**
 * The stored outcomes, read defensively: `deliveries` is a JSON column, so an
 * entry without a channel is skipped and a missing `targets` reads as none.
 */
function outcomesOf(run: Pick<ReportScheduleRun, 'deliveries'>): ReportDeliveryOutcome[] {
  const raw: unknown = run.deliveries;
  if (!Array.isArray(raw)) return [];
  const outcomes: ReportDeliveryOutcome[] = [];
  for (const entry of raw as unknown[]) {
    if (typeof entry !== 'object' || entry === null) continue;
    const o = entry as Partial<ReportDeliveryOutcome>;
    if (typeof o.channel !== 'string' || typeof o.status !== 'string') continue;
    outcomes.push({ ...o, channel: o.channel, status: o.status, targets: Array.isArray(o.targets) ? o.targets : [] });
  }
  return outcomes;
}

function plural(n: number, one: string, many: string): string {
  return `${n} ${n === 1 ? one : many}`;
}

/**
 * The summary, status and reason of one run, from its stored outcomes and the
 * current state of its delivery rows. Pure, so every combination is testable
 * without a database.
 */
export function summariseRun(
  outcomes: readonly ReportDeliveryOutcome[],
  webhookCounts: StatusCounts,
  emailCounts: StatusCounts,
): { status: RunStatus; reason: string | null; summary: RunDeliverySummary } {
  const webhookOutcome = outcomes.find((o) => o.channel === 'webhook') ?? null;
  const emailOutcome = outcomes.find((o) => o.channel === 'email') ?? null;

  const pendingOf = (c: StatusCounts) => (c.pending ?? 0) + (c.failed_retrying ?? 0);
  const summary: RunDeliverySummary = {
    webhook: {
      status: webhookOutcome?.status ?? null,
      delivered: webhookCounts.succeeded ?? 0,
      failed: webhookCounts.gave_up ?? 0,
      pending: pendingOf(webhookCounts),
    },
    email: {
      status: emailOutcome?.status ?? null,
      sent: emailCounts.succeeded ?? 0,
      failed: emailCounts.gave_up ?? 0,
      pending: pendingOf(emailCounts),
      notConfigured: emailOutcome?.status === 'not_configured' ? emailOutcome.targets.length : 0,
    },
  };

  const reasons: string[] = [];
  for (const outcome of outcomes) {
    if (outcome.status !== 'queued' && outcome.detail) reasons.push(outcome.detail);
  }
  if (summary.webhook.failed > 0) {
    reasons.push(`${plural(summary.webhook.failed, 'webhook delivery', 'webhook deliveries')} gave up after retries`);
  }
  if (summary.email.failed > 0) {
    reasons.push(`${plural(summary.email.failed, 'email', 'emails')} could not be sent`);
  }
  if (outcomes.length === 0) reasons.push('No delivery was recorded for this run');

  const pending = summary.webhook.pending + summary.email.pending;
  const channelFailures = outcomes.filter((o) => o.status === 'failed').length;
  const failures = summary.webhook.failed + summary.email.failed + channelFailures;
  const successes = summary.webhook.delivered + summary.email.sent;

  let status: RunStatus;
  if (pending > 0) status = 'delivering';
  else if (failures > 0 && successes > 0) status = 'partial';
  else if (failures > 0) status = 'failed';
  else if (successes > 0) status = 'delivered';
  else status = 'not_sent';

  return { status, reason: reasons.length > 0 ? reasons.join('; ') : null, summary };
}

/**
 * A schedule's runs, newest first, paged. Tenant-scoped: another client's
 * schedule is a 404.
 *
 * Each run carries its delivery summary and webhook results, and the signed
 * CSV link while it still works (null when links are not configured, or once
 * the link has expired). Delivery rows for a whole page are read in two
 * queries, not one per run.
 */
export async function listRunsForSchedule(input: {
  scheduleId: string;
  clientId: string;
  limit: number;
  cursor?: string;
  now?: Date;
  env?: NodeJS.ProcessEnv;
}): Promise<{ data: ReportRunHistoryItem[]; nextCursor: string | null }> {
  await findScheduleForClient(input.scheduleId, input.clientId);

  const rows = await prisma.reportScheduleRun.findMany({
    where: { scheduleId: input.scheduleId, clientId: input.clientId },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });
  const page = buildPage(rows, input.limit);
  if (page.data.length === 0) return { data: [], nextCursor: page.nextCursor };

  const outcomesByRun = new Map(page.data.map((run) => [run.id, outcomesOf(run)]));
  const webhookIds = [...outcomesByRun.values()].flatMap((outcomes) =>
    outcomes.flatMap((o) => (o.channel === 'webhook' ? (o.webhookDeliveryIds ?? []) : [])),
  );

  const [webhookRows, emailGroups] = await Promise.all([
    webhookIds.length === 0
      ? Promise.resolve([])
      : prisma.webhookDelivery.findMany({
          // Scoped by tenant as well as id: the ids come from a stored JSON column.
          where: { id: { in: webhookIds }, clientId: input.clientId },
          select: {
            id: true,
            webhookId: true,
            status: true,
            attempts: true,
            lastStatusCode: true,
            lastError: true,
            lastAttemptAt: true,
            nextAttemptAt: true,
            deliveredAt: true,
            webhook: { select: { url: true } },
          },
        }),
    prisma.reportEmailDelivery.groupBy({
      by: ['runId', 'status'],
      where: { runId: { in: page.data.map((run) => run.id) }, clientId: input.clientId },
      _count: { _all: true },
    }),
  ]);

  const webhookById = new Map(webhookRows.map((row) => [row.id, row]));
  const emailCountsByRun = new Map<string, StatusCounts>();
  for (const group of emailGroups) {
    const counts = emailCountsByRun.get(group.runId) ?? {};
    counts[group.status] = group._count._all;
    emailCountsByRun.set(group.runId, counts);
  }

  const now = input.now ?? new Date();
  const data = page.data.map((run): ReportRunHistoryItem => {
    const outcomes = outcomesByRun.get(run.id)!;
    // A webhook deleted since the run takes its delivery rows with it; those
    // are simply no longer shown or counted.
    const webhookDeliveries: RunWebhookResult[] = outcomes
      .flatMap((o) => (o.channel === 'webhook' ? (o.webhookDeliveryIds ?? []) : []))
      .map((id) => webhookById.get(id))
      .filter((row): row is NonNullable<typeof row> => row !== undefined)
      .map(({ webhook, ...row }) => ({ ...row, url: webhook.url }));

    const webhookCounts: StatusCounts = {};
    for (const row of webhookDeliveries) {
      webhookCounts[row.status] = (webhookCounts[row.status] ?? 0) + 1;
    }
    const { status, reason, summary } = summariseRun(
      outcomes,
      webhookCounts,
      emailCountsByRun.get(run.id) ?? {},
    );

    const link = signedReportLink(
      { clientId: run.clientId, scheduleId: run.scheduleId, runId: run.id, generatedAt: run.generatedAt },
      input.env,
    );
    const live = link && link.expiresAt.getTime() > now.getTime() ? link : null;

    return {
      id: run.id,
      scheduleId: run.scheduleId,
      trigger: run.trigger,
      status,
      dueAt: run.dueAt,
      generatedAt: run.generatedAt,
      rowCount: run.rowCount,
      createdAt: run.createdAt,
      reason,
      summary,
      deliveries: outcomes,
      webhookDeliveries,
      csvDownloadUrl: live?.url ?? null,
      csvDownloadExpiresAt: live?.expiresAt ?? null,
    };
  });

  return { data, nextCursor: page.nextCursor };
}

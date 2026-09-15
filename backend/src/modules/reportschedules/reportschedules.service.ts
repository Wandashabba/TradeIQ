import { Prisma, ReportSchedule, ReportScheduleRun } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';
import { NotFoundError } from '../../middleware/errorHandler';
import { findReportForClient, generateReport, rowsToCsv } from '../reports/reports.service';
import { firstRunAt, nextRunAfter, rescheduleForCadence } from './reportschedules.cadence';
import {
  deliveredTargets,
  deliverReport,
  ReportDeliveryOutcome,
  ReportGeneratedPayload,
} from './reportschedules.delivery';

// The cadences a schedule may fire on. Free-text at the schema level; this is
// the runtime allow-list.
export const CADENCES = ['daily', 'weekly'] as const;
export type Cadence = (typeof CADENCES)[number];

export function isCadence(value: unknown): value is Cadence {
  return typeof value === 'string' && (CADENCES as readonly string[]).includes(value);
}

// A non-empty array of string recipients (emails/webhook targets).
export function isRecipients(value: unknown): value is string[] {
  return Array.isArray(value) && value.length > 0 && value.every((r) => typeof r === 'string');
}

export interface CreateScheduleInput {
  clientId: string;
  reportDefinitionId: string;
  cadence: Cadence;
  recipients: string[];
}

export async function createSchedule(
  input: CreateScheduleInput,
  now: Date = new Date(),
): Promise<ReportSchedule> {
  // The report definition must belong to the caller's client (404 otherwise).
  await findReportForClient(input.reportDefinitionId, input.clientId);
  return prisma.reportSchedule.create({
    data: {
      clientId: input.clientId,
      reportDefinitionId: input.reportDefinitionId,
      cadence: input.cadence,
      recipients: input.recipients as Prisma.InputJsonValue,
      // A new schedule first fires one period from now (reportschedules.cadence.ts).
      nextRunAt: firstRunAt(input.cadence, now),
    },
  });
}

export async function listSchedules(input: {
  clientId: string;
  limit: number;
  cursor?: string;
}) {
  const rows = await prisma.reportSchedule.findMany({
    where: { clientId: input.clientId },
    include: { reportDefinition: { select: { name: true } } },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });

  return buildPage(rows, input.limit);
}

export async function findScheduleForClient(id: string, clientId: string): Promise<ReportSchedule> {
  const schedule = await prisma.reportSchedule.findFirst({ where: { id, clientId } });
  if (!schedule) {
    throw new NotFoundError('Report schedule not found');
  }
  return schedule;
}

export interface UpdateScheduleInput {
  active?: boolean;
  cadence?: Cadence;
  recipients?: string[];
}

/**
 * The `nextRunAt` an update leaves behind, or `undefined` to leave it alone.
 *
 * Pausing clears it (nothing fires); resuming schedules the next run one
 * period from now rather than firing for the time spent paused; a cadence
 * change on an active schedule keeps the previous due time's place.
 */
export function nextRunAtAfterUpdate(
  current: Pick<ReportSchedule, 'active' | 'cadence' | 'nextRunAt'>,
  input: UpdateScheduleInput,
  now: Date,
): Date | null | undefined {
  const active = input.active ?? current.active;
  const cadence = input.cadence ?? current.cadence;
  if (!active) return null;
  if (!current.active) return firstRunAt(cadence, now);
  if (cadence !== current.cadence) {
    return rescheduleForCadence(current.cadence, cadence, current.nextRunAt, now);
  }
  // Active with no due time (should not happen): put it back on a cadence.
  if (!current.nextRunAt) return firstRunAt(cadence, now);
  return undefined;
}

export async function updateSchedule(
  id: string,
  clientId: string,
  input: UpdateScheduleInput,
  now: Date = new Date(),
): Promise<ReportSchedule> {
  // Tenant check first — a cross-tenant id must 404, not update.
  const current = await findScheduleForClient(id, clientId);
  const nextRunAt = nextRunAtAfterUpdate(current, input, now);
  return prisma.reportSchedule.update({
    where: { id },
    data: {
      ...(input.active !== undefined ? { active: input.active } : {}),
      ...(input.cadence !== undefined ? { cadence: input.cadence } : {}),
      ...(input.recipients !== undefined
        ? { recipients: input.recipients as Prisma.InputJsonValue }
        : {}),
      ...(nextRunAt !== undefined ? { nextRunAt } : {}),
    },
  });
}

export async function deleteSchedule(id: string, clientId: string): Promise<void> {
  // Tenant check first — a cross-tenant id must 404, not delete. Runs cascade.
  await findScheduleForClient(id, clientId);
  await prisma.reportSchedule.delete({ where: { id } });
}

// ── Runs (#66) ──────────────────────────────────────────────────────────────

export type RunTrigger = 'scheduled' | 'manual';

export interface ScheduleRunResult {
  schedule: ReportSchedule;
  runId: string;
  trigger: RunTrigger;
  generatedAt: string;
  rowCount: number;
  /**
   * Where the report was actually queued: the URLs of the webhooks a
   * `report.generated` delivery was created for. No longer an echo of the
   * recipients — an empty list means nothing was sent. Queued is not yet
   * delivered; each delivery's outcome is in the webhook's delivery log.
   */
  deliveredTo: string[];
  /** Every channel's outcome, including email's `not_configured`. */
  deliveries: ReportDeliveryOutcome[];
}

/** Where a run's CSV is served from on this API. */
export function runCsvPath(scheduleId: string, runId: string): string {
  return `/report-schedules/${scheduleId}/runs/${runId}/csv`;
}

/** `path` on the public API origin, when `PUBLIC_API_URL` is configured. */
function publicApiUrl(path: string): string | null {
  const base = process.env.PUBLIC_API_URL?.trim();
  return base ? `${base.replace(/\/+$/, '')}${path}` : null;
}

function isUniqueViolation(err: unknown): boolean {
  return err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002';
}

interface ExecutedRun {
  run: ReportScheduleRun;
  deliveries: ReportDeliveryOutcome[];
}

/**
 * The one code path both "run now" and the worker take: generate the linked
 * report, record the run, deliver it through every channel, record what each
 * channel did.
 *
 * The run is recorded before delivery so the payload can carry its id. Returns
 * null when a scheduled run for `dueAt` is already recorded — another processor
 * fired this due time — so it is not delivered twice.
 */
async function executeRun(
  schedule: ReportSchedule,
  trigger: RunTrigger,
  dueAt: Date | null,
): Promise<ExecutedRun | null> {
  // Tenant-scoped by the schedule's own client.
  const report = await generateReport(schedule.reportDefinitionId, schedule.clientId);

  let run: ReportScheduleRun;
  try {
    run = await prisma.reportScheduleRun.create({
      data: {
        scheduleId: schedule.id,
        clientId: schedule.clientId,
        trigger,
        dueAt,
        generatedAt: new Date(report.generatedAt),
        rowCount: report.rowCount,
        deliveries: [],
      },
    });
  } catch (err) {
    if (dueAt && isUniqueViolation(err)) return null;
    throw err;
  }

  const csvPath = runCsvPath(schedule.id, run.id);
  const payload: ReportGeneratedPayload = {
    scheduleId: schedule.id,
    reportId: report.definition.id,
    reportName: report.definition.name,
    reportType: report.definition.type,
    runId: run.id,
    trigger,
    generatedAt: report.generatedAt,
    rowCount: report.rowCount,
    csvPath,
    csvUrl: publicApiUrl(csvPath),
  };
  const deliveries = await deliverReport({
    clientId: schedule.clientId,
    recipients: isRecipients(schedule.recipients) ? schedule.recipients : [],
    payload,
  });

  run = await prisma.reportScheduleRun.update({
    where: { id: run.id },
    data: { deliveries: deliveries as unknown as Prisma.InputJsonValue },
  });
  return { run, deliveries };
}

/** "Run now": generate and deliver immediately. Does not move `nextRunAt`. */
export async function runSchedule(id: string, clientId: string): Promise<ScheduleRunResult> {
  const schedule = await findScheduleForClient(id, clientId);
  // A manual run has no due time, so it is never a duplicate.
  const { run, deliveries } = (await executeRun(schedule, 'manual', null))!;
  const updated = await prisma.reportSchedule.update({
    where: { id },
    data: { lastRunAt: run.generatedAt },
  });

  return {
    schedule: updated,
    runId: run.id,
    trigger: 'manual',
    generatedAt: run.generatedAt.toISOString(),
    rowCount: run.rowCount,
    deliveredTo: deliveredTargets(deliveries),
    deliveries,
  };
}

/**
 * A run's CSV, regenerated from its schedule's report definition and bounded to
 * the run's `generatedAt`. Tenant-scoped: another client's run is a 404.
 *
 * Regenerated rather than stored: a report has no row cap, and keeping a copy
 * per run would duplicate a tenant's data once a day per schedule. The bound
 * keeps records created after the run out; values of records that existed then
 * are as they are now.
 */
export async function runCsvForClient(
  scheduleId: string,
  runId: string,
  clientId: string,
): Promise<{ run: ReportScheduleRun; csv: string }> {
  const run = await prisma.reportScheduleRun.findFirst({
    where: { id: runId, scheduleId, clientId },
    include: { schedule: { select: { reportDefinitionId: true } } },
  });
  if (!run) {
    throw new NotFoundError('Report run not found');
  }
  const report = await generateReport(run.schedule.reportDefinitionId, clientId, {
    asOf: run.generatedAt,
  });
  return { run, csv: rowsToCsv(report.rows) };
}

// ── The scheduler (#66) ─────────────────────────────────────────────────────

/**
 * How long a claimed schedule is hidden from other workers. It must comfortably
 * exceed a run — generating an unfiltered report is the slow part. A run that
 * throws (or a process that dies mid-run) leaves the claim to lapse, and the
 * schedule is simply claimed and tried again after this.
 */
export const SCHEDULE_CLAIM_LEASE_MS = 10 * 60_000;

export interface ClaimedSchedule {
  id: string;
  /** The `nextRunAt` the claim was made against: the due time being fired. */
  dueAt: Date;
}

/**
 * Atomically claims up to `limit` due, active, unclaimed schedules and leases
 * them, returning each with the due time it was claimed for.
 *
 * `FOR UPDATE SKIP LOCKED` makes this safe across backend instances: two
 * concurrent claims lock disjoint rows instead of both reading the same due
 * schedule, and the lease written in the same statement hides the row from
 * every later claim. `nextRunAt` itself is left alone until the run finishes,
 * so a run that never finishes loses nothing — the due time is still there.
 */
export async function claimDueSchedules(now: Date, limit: number): Promise<ClaimedSchedule[]> {
  // Timestamps go as ISO text cast to `timestamp` — the columns are `timestamp
  // without time zone` holding UTC (same reasoning as claimDueDeliveries).
  const rows = await prisma.$queryRaw<Array<{ id: string; due_at: Date }>>`
    UPDATE "report_schedules" AS s
    SET "claimed_until" = ${new Date(now.getTime() + SCHEDULE_CLAIM_LEASE_MS).toISOString()}::timestamp
    FROM (
      SELECT "id", "next_run_at" FROM "report_schedules"
      WHERE "active" = true
        AND "next_run_at" <= ${now.toISOString()}::timestamp
        AND ("claimed_until" IS NULL OR "claimed_until" <= ${now.toISOString()}::timestamp)
      ORDER BY "next_run_at"
      LIMIT ${limit}
      FOR UPDATE SKIP LOCKED
    ) AS due
    WHERE s."id" = due."id"
    RETURNING s."id", due."next_run_at" AS "due_at"
  `;
  return rows.map((row) => ({ id: row.id, dueAt: row.due_at }));
}

export type FireOutcome = 'fired' | 'already_fired' | 'skipped' | 'failed';

/**
 * Fires one claimed schedule for the due time it was claimed for, then moves
 * `nextRunAt` to the next slot after now — which is what makes a catch-up fire
 * once (see `nextRunAfter`).
 *
 * The reschedule is guarded on `nextRunAt` still being the claimed due time and
 * the schedule still active: a pause, resume or cadence change made while the
 * report was generating wins, rather than being overwritten. Never throws.
 */
export async function fireClaimedSchedule(
  claim: ClaimedSchedule,
  now: () => Date = () => new Date(),
): Promise<FireOutcome> {
  try {
    const schedule = await prisma.reportSchedule.findUnique({ where: { id: claim.id } });
    if (!schedule) return 'skipped';
    if (!schedule.active || schedule.nextRunAt?.getTime() !== claim.dueAt.getTime()) {
      // Paused or rescheduled between the claim and now: nothing is due.
      await prisma.reportSchedule.updateMany({
        where: { id: schedule.id },
        data: { claimedUntil: null },
      });
      return 'skipped';
    }

    const executed = await executeRun(schedule, 'scheduled', claim.dueAt);

    await prisma.reportSchedule.updateMany({
      where: { id: schedule.id, active: true, nextRunAt: claim.dueAt },
      data: { nextRunAt: nextRunAfter(schedule.cadence, claim.dueAt, now()) },
    });
    await prisma.reportSchedule.updateMany({
      where: { id: schedule.id },
      data: {
        claimedUntil: null,
        ...(executed ? { lastRunAt: executed.run.generatedAt } : {}),
      },
    });
    return executed ? 'fired' : 'already_fired';
  } catch (err) {
    // The claim is left to lapse, so the due time is retried after the lease.
    console.error(`Report schedule ${claim.id} could not be fired:`, err);
    return 'failed';
  }
}

/** Claims a batch of due schedules and fires each in turn. Returns how many. */
export async function processDueSchedules(now: Date = new Date(), limit = 5): Promise<number> {
  const claims = await claimDueSchedules(now, limit);
  // One at a time: each run generates a whole report, and a batch of them in
  // parallel would compete with live traffic for the connection pool.
  for (const claim of claims) {
    await fireClaimedSchedule(claim);
  }
  return claims.length;
}

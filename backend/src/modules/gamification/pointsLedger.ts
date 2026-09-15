import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';

/**
 * The points ledger (#124): one row per points-earning event, so a leaderboard
 * number has a history behind it.
 *
 * The leaderboard formula is unchanged from the computed-per-request version:
 *
 *   points = mean(scorecard weightedTotal) + 5 x tasks closed + 2 x visits submitted
 *
 * Two of its terms are events with a fixed value and become plain entries. The
 * third is a *mean*, which no sum of per-event amounts can reproduce — a low
 * score lowers it. So a scorecard entry earns 0 points on its own and carries
 * the `score` it contributes to that mean, and the leaderboard adds the mean of
 * the in-window scores to the in-window sum. Showing "+78 for a scorecard"
 * would be a number the board never actually added.
 */

export const POINTS_PER_VISIT_SUBMITTED = 2;
export const POINTS_PER_TASK_CLOSED = 5;

export type PointsReason = 'visit_submitted' | 'task_closed' | 'scorecard';
export type PointsSourceType = 'visit' | 'task' | 'scorecard';

export interface LedgerEvent {
  clientId: string;
  agentId: string;
  points: number;
  reason: PointsReason;
  sourceType: PointsSourceType;
  sourceId: string;
  score: number | null;
  occurredAt: Date;
}

/** A submitted visit. Dated by check-in, the timestamp the board has always windowed visits by. */
export function visitSubmittedEvent(visit: {
  id: string;
  clientId: string;
  agentId: string;
  checkinTs: Date;
}): LedgerEvent {
  return {
    clientId: visit.clientId,
    agentId: visit.agentId,
    points: POINTS_PER_VISIT_SUBMITTED,
    reason: 'visit_submitted',
    sourceType: 'visit',
    sourceId: visit.id,
    score: null,
    occurredAt: visit.checkinTs,
  };
}

/**
 * A closed task, credited to its owner. `closedAt` is when the closure was
 * recorded; Task has no closure timestamp of its own, so the backfill passes
 * `createdAt` (the earliest the closure could have happened).
 */
export function taskClosedEvent(
  task: { id: string; ownerId: string },
  clientId: string,
  closedAt: Date,
): LedgerEvent {
  return {
    clientId,
    agentId: task.ownerId,
    points: POINTS_PER_TASK_CLOSED,
    reason: 'task_closed',
    sourceType: 'task',
    sourceId: task.id,
    score: null,
    occurredAt: closedAt,
  };
}

/** A visit's scorecard, credited to the visit's agent. See the module note on why points are 0. */
export function scorecardEvent(
  scorecard: { id: string; weightedTotal: number; createdAt: Date },
  visit: { clientId: string; agentId: string },
): LedgerEvent {
  return {
    clientId: visit.clientId,
    agentId: visit.agentId,
    points: 0,
    reason: 'scorecard',
    sourceType: 'scorecard',
    sourceId: scorecard.id,
    score: scorecard.weightedTotal,
    occurredAt: scorecard.createdAt,
  };
}

/**
 * Inserts events, skipping any already recorded (unique on sourceType,
 * sourceId, reason). Returns how many rows were new. An existing row keeps its
 * original `occurredAt`: re-closing a closed task does not move its date.
 */
export async function writeLedgerEvents(events: LedgerEvent[]): Promise<number> {
  if (events.length === 0) {
    return 0;
  }
  const { count } = await prisma.pointsLedgerEntry.createMany({
    data: events,
    skipDuplicates: true,
  });
  return count;
}

/**
 * Runs a ledger write without letting it fail the action that earned the
 * points — the visit, task or scorecard is already persisted, and the backfill
 * can fill any entry a failed write missed. Mirrors submitVisit's other hooks.
 */
export async function recordPointsBestEffort(
  what: string,
  write: () => Promise<unknown>,
): Promise<void> {
  try {
    await write();
  } catch (err) {
    console.error(`Points ledger write failed for ${what}:`, err);
  }
}

export async function recordVisitSubmitted(visit: {
  id: string;
  clientId: string;
  agentId: string;
  checkinTs: Date;
}): Promise<void> {
  await writeLedgerEvents([visitSubmittedEvent(visit)]);
}

/** Records a task closure. Idempotent: closing an already-closed task adds nothing. */
export async function recordTaskClosed(taskId: string, closedAt: Date = new Date()): Promise<void> {
  const task = await prisma.task.findUnique({
    where: { id: taskId },
    select: { id: true, ownerId: true, outlet: { select: { clientId: true } } },
  });
  if (!task) {
    return;
  }
  await writeLedgerEvents([taskClosedEvent(task, task.outlet.clientId, closedAt)]);
}

/**
 * A task moved out of `closed`. The formula only ever rewarded closures that
 * stand, so the closure's entry is removed; closing it again records a fresh
 * one dated to that closure.
 */
export async function voidTaskClosed(taskId: string): Promise<void> {
  await prisma.pointsLedgerEntry.deleteMany({
    where: { sourceType: 'task', sourceId: taskId, reason: 'task_closed' },
  });
}

/**
 * Records a scorecard, or refreshes its score when the scorecard was
 * regenerated — one scorecard per visit, and the board averages its current
 * score, so the entry follows it.
 */
export async function recordScorecard(
  scorecard: { id: string; weightedTotal: number; createdAt: Date },
  visit: { clientId: string; agentId: string },
): Promise<void> {
  const event = scorecardEvent(scorecard, visit);
  await prisma.pointsLedgerEntry.upsert({
    where: {
      sourceType_sourceId_reason: {
        sourceType: event.sourceType,
        sourceId: event.sourceId,
        reason: event.reason,
      },
    },
    create: event,
    update: { score: event.score },
  });
}

// ── Reads ─────────────────────────────────────────────────────────────────

export interface PointsLedgerEntryView {
  id: string;
  points: number;
  reason: string;
  sourceType: string;
  sourceId: string;
  score: number | null;
  occurredAt: Date;
  /** The outlet the source happened at, when it can still be resolved. */
  outletName: string | null;
}

export interface ListLedgerEntriesInput {
  clientId: string;
  agentId: string;
  from?: Date;
  to?: Date;
  limit: number;
  cursor?: string;
}

/** An agent's ledger, newest first, keyset-paginated. */
export async function listLedgerEntries(
  input: ListLedgerEntriesInput,
): Promise<{ data: PointsLedgerEntryView[]; nextCursor: string | null }> {
  const occurredAt =
    input.from || input.to
      ? { ...(input.from ? { gte: input.from } : {}), ...(input.to ? { lte: input.to } : {}) }
      : undefined;

  const rows = await prisma.pointsLedgerEntry.findMany({
    where: {
      clientId: input.clientId,
      agentId: input.agentId,
      ...(occurredAt ? { occurredAt } : {}),
    },
    // `id` breaks ties between entries at the same instant; its direction must
    // match occurredAt's (see alerts.service.ts on keyset cursors).
    orderBy: [{ occurredAt: 'desc' }, { id: 'desc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
    select: {
      id: true,
      points: true,
      reason: true,
      sourceType: true,
      sourceId: true,
      score: true,
      occurredAt: true,
    },
  });
  const page = buildPage(rows, input.limit);
  const outletNames = await outletNamesFor(input.clientId, page.data);

  return {
    data: page.data.map((row) => ({
      ...row,
      outletName: outletNames.get(`${row.sourceType}:${row.sourceId}`) ?? null,
    })),
    nextCursor: page.nextCursor,
  };
}

/** One query per source type present on the page, tenant-scoped, keyed `type:id`. */
async function outletNamesFor(
  clientId: string,
  rows: Array<{ sourceType: string; sourceId: string }>,
): Promise<Map<string, string>> {
  const idsOf = (type: string) =>
    [...new Set(rows.filter((r) => r.sourceType === type).map((r) => r.sourceId))];
  const visitIds = idsOf('visit');
  const taskIds = idsOf('task');
  const scorecardIds = idsOf('scorecard');

  const [visits, tasks, scorecards] = await Promise.all([
    visitIds.length
      ? prisma.visit.findMany({
          where: { id: { in: visitIds }, clientId },
          select: { id: true, outlet: { select: { name: true } } },
        })
      : [],
    taskIds.length
      ? prisma.task.findMany({
          where: { id: { in: taskIds }, outlet: { clientId } },
          select: { id: true, outlet: { select: { name: true } } },
        })
      : [],
    scorecardIds.length
      ? prisma.scorecard.findMany({
          where: { id: { in: scorecardIds }, visit: { clientId } },
          select: { id: true, visit: { select: { outlet: { select: { name: true } } } } },
        })
      : [],
  ]);

  const names = new Map<string, string>();
  for (const v of visits) names.set(`visit:${v.id}`, v.outlet.name);
  for (const t of tasks) names.set(`task:${t.id}`, t.outlet.name);
  for (const s of scorecards) names.set(`scorecard:${s.id}`, s.visit.outlet.name);
  return names;
}

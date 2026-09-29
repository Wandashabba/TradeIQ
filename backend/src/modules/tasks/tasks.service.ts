import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
import { computeSlaDueAt, TaskPriority } from '../../lib/slaClock';
import { buildPage } from '../../lib/pagination';
import { attachEvidencePhotoIds } from '../photos/photos.service';
import { pushTaskAssigned } from '../push/push.triggers';
import {
  recordPointsBestEffort,
  recordTaskClosed,
  voidTaskClosed,
} from '../gamification/pointsLedger';

export type TaskStatusInput = 'open' | 'in_progress' | 'closed';

export interface CreateTaskInput {
  clientId: string;
  callerUserId: string;
  outletId: string;
  findingType: string;
  requiredFix: string;
  priority: TaskPriority;
  visitId?: string;
  ownerId?: string;
}

export async function createTask(input: CreateTaskInput) {
  const outlet = await prisma.outlet.findFirst({
    where: { id: input.outletId, clientId: input.clientId },
    select: { id: true },
  });
  if (!outlet) {
    throw new NotFoundError('Outlet not found');
  }

  if (input.visitId) {
    const visit = await prisma.visit.findFirst({
      where: { id: input.visitId, clientId: input.clientId },
      select: { id: true },
    });
    if (!visit) {
      throw new NotFoundError('Visit not found');
    }
  }

  // The caller owns the task by default; an explicit ownerId must belong to
  // the caller's client.
  let ownerId = input.callerUserId;
  if (input.ownerId) {
    const owner = await prisma.user.findFirst({
      where: { id: input.ownerId, clientId: input.clientId },
      select: { id: true },
    });
    if (!owner) {
      throw new NotFoundError('Owner not found');
    }
    ownerId = input.ownerId;
  }

  const task = await prisma.task.create({
    data: {
      visitId: input.visitId,
      findingType: input.findingType,
      outletId: input.outletId,
      requiredFix: input.requiredFix,
      priority: input.priority,
      slaDueAt: computeSlaDueAt(input.priority, new Date()),
      ownerId,
    },
  });
  // #67: tell the owner when someone else assigned it. Fire-and-forget.
  pushTaskAssigned({ clientId: input.clientId, assignedById: input.callerUserId, task });
  return task;
}

/**
 * THE FOUR STATES A WORKLIST SHOWS, which are not the three the column holds.
 *
 * `status` is the enum in the database — `open`, `in_progress`, `closed`. It
 * is what a machine stored. `state` is what a manager sorts their day by, and
 * the two do not line up:
 *
 * * **`open`** is *not* `status = 'open'`. A task somebody has started is
 *   still outstanding, so it is `status <> 'closed'` — `open` and
 *   `in_progress` both.
 * * **`overdue`** is not a status at all. It is `status <> 'closed'` and a
 *   deadline that has passed, which no column records.
 * * **`done`** is `status = 'closed'`.
 * * **`all`** is the default and means the filter is not applied.
 *
 * The definitions are the app's, copied from `TasksView._slaStateFor` in
 * `app/lib/features/tasks/data/tasks_view.dart` rather than re-derived — a
 * second definition of "overdue" is two screens that disagree about the same
 * task. In particular the boundary is `slaDueAt <= now` (the app reads
 * `!now.isBefore(slaDueAt)`), so a task due at exactly this instant is
 * overdue on both sides of the wire.
 */
export type TaskStateInput = 'all' | 'open' | 'overdue' | 'done';

export const TASK_STATES: readonly TaskStateInput[] = ['all', 'open', 'overdue', 'done'];

/** The whole-set breakdown the worklist's chips and lead figure are made of. */
export interface TaskCounts {
  /** Every task in scope. */
  all: number;
  /** Outstanding: `status <> 'closed'`. */
  open: number;
  /** Outstanding and past its deadline. */
  overdue: number;
  /** Closed, verified or not. */
  done: number;
  /** Closed and not yet verified by a manager. */
  awaitingVerification: number;
}

export interface ListTasksInput {
  clientId: string;
  status?: TaskStatusInput;
  state?: TaskStateInput;
  priority?: TaskPriority;
  outletId?: string;
  limit: number;
  cursor?: string;
  /** The instant "overdue" is measured against. Injectable so a test owns time. */
  now?: Date;
}

/**
 * THE SCOPE THE COUNTS DESCRIBE, and the one place tenant scoping is written.
 *
 * Tasks carry no clientId of their own — tenant scope goes through the outlet
 * relation, and it is in this function rather than at two call sites because a
 * count that forgot it would answer how much work exists in somebody else's
 * account.
 *
 * It deliberately excludes the state filter. The chips are the state filter,
 * so a breakdown that had already applied it would print the selected chip's
 * own count four times. Every *other* narrowing — priority, outlet — is
 * included, because those do scope the universe the chips describe.
 */
function taskScope(input: Pick<ListTasksInput, 'clientId' | 'priority' | 'outletId'>) {
  return {
    outlet: { clientId: input.clientId },
    ...(input.priority ? { priority: input.priority } : {}),
    ...(input.outletId ? { outletId: input.outletId } : {}),
  };
}

/** The rows, as opposed to the universe: the scope plus the state filter. */
function taskRowWhere(input: ListTasksInput, now: Date) {
  const scope = taskScope(input);
  switch (input.state) {
    case 'open':
      return { ...scope, status: { not: 'closed' as const } };
    case 'overdue':
      return { ...scope, status: { not: 'closed' as const }, slaDueAt: { lte: now } };
    case 'done':
      return { ...scope, status: 'closed' as const };
    case 'all':
    case undefined:
      // `status` is the exact-enum filter and stays available to any caller
      // that wants one. The route refuses both at once.
      return { ...scope, ...(input.status ? { status: input.status } : {}) };
  }
}

/**
 * THE WHOLE-SET BREAKDOWN — two queries, both over [taskScope].
 *
 * Why it exists: `GET /tasks` served one page and a total, so the worklist
 * derived every figure on the screen from the fifty rows it had. On the dev
 * database that is fifty *closed* tasks — the page is ordered by deadline, and
 * 31,178 of 32,368 tasks are closed — so the screen read `Open 0 · Overdue 0 ·
 * Done 50` over an account holding 1,190 open tasks and 1,122 overdue ones,
 * and had to withhold its lead figure as an unknown because a zero over a cut
 * page is not a measured nought.
 *
 * Why two queries and not five: `groupBy` on (`status`, `closureVerified`)
 * answers open, in-progress, closed, awaiting-verification and the total in
 * one pass; only `overdue` needs its own, because it is a predicate on a
 * timestamp rather than a column value. Measured against the real seeded
 * database (32,368 tasks, one tenant) the pair costs **8.1–8.5 ms and
 * 7.4–10.3 ms** warm, against 1.8–3.5 ms for the page itself. It also
 * *replaces* the `count(where)` the cut-page total used to need, so the net
 * addition is one query.
 */
export async function countTaskStates(
  input: Pick<ListTasksInput, 'clientId' | 'priority' | 'outletId'>,
  now: Date,
): Promise<TaskCounts> {
  const scope = taskScope(input);
  const [groups, overdue] = await Promise.all([
    prisma.task.groupBy({
      by: ['status', 'closureVerified'],
      where: scope,
      _count: { _all: true },
    }),
    prisma.task.count({
      where: { ...scope, status: { not: 'closed' }, slaDueAt: { lte: now } },
    }),
  ]);

  // A measured zero is a zero: every field starts at 0 and is added to, so a
  // state with no rows answers 0 rather than going missing and being read as
  // "not counted". The client draws those two differently on purpose.
  const counts: TaskCounts = { all: 0, open: 0, overdue, done: 0, awaitingVerification: 0 };
  for (const group of groups) {
    const n = group._count._all;
    counts.all += n;
    if (group.status === 'closed') {
      counts.done += n;
      if (!group.closureVerified) counts.awaitingVerification += n;
    } else {
      counts.open += n;
    }
  }
  return counts;
}

export async function listTasks(input: ListTasksInput) {
  const now = input.now ?? new Date();
  const where = taskRowWhere(input, now);
  const [rows, counts] = await Promise.all([
    prisma.task.findMany({
      where,
      // `id` is the unique tiebreaker that makes the cursor deterministic when
      // two tasks share a slaDueAt — same reasoning as alerts.service.ts.
      //
      // COPYING THIS PATTERN: the tiebreaker's direction MUST match the primary
      // sort's direction (both `asc` here).
      orderBy: [{ slaDueAt: 'asc' }, { id: 'asc' }],
      take: input.limit + 1,
      ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
    }),
    countTaskStates(input, now),
  ]);
  const page = buildPage(rows, input.limit);
  // `total` is every task the filter matches, ignoring the cursor — see
  // listAlerts. It comes out of the breakdown now rather than out of a third
  // query, except where an exact-`status` filter was used, which the breakdown
  // does not split by.
  const total =
    input.status !== undefined
      ? page.nextCursor === null && !input.cursor
        ? page.data.length
        : await prisma.task.count({ where })
      : counts[input.state ?? 'all'];
  // evidencePhotoId (newest photo of the linked visit) — one batched query,
  // AFTER buildPage so the dropped probe row costs nothing and the cursor
  // (last kept row's id) is untouched.
  return {
    data: await attachEvidencePhotoIds(page.data),
    nextCursor: page.nextCursor,
    total,
    counts,
  };
}

export async function findTaskForClient(taskId: string, clientId: string) {
  const task = await prisma.task.findFirst({
    where: { id: taskId, outlet: { clientId } },
  });
  if (!task) {
    throw new NotFoundError('Task not found');
  }
  return task;
}

// A closure photo counts as verified only when a Photo row exists whose url
// matches and whose visit belongs to the caller's client (Photo -> visit ->
// clientId). This blocks closing a task with an arbitrary, unowned url.
export async function photoExistsForClient(url: string, clientId: string): Promise<boolean> {
  const photo = await prisma.photo.findFirst({
    where: { url, visit: { clientId } },
    select: { id: true },
  });
  return photo !== null;
}

export interface UpdateTaskInput {
  status?: TaskStatusInput;
  closurePhotoUrl?: string;
  closureVerified?: boolean;
}

export async function updateTask(taskId: string, input: UpdateTaskInput) {
  // Prisma treats undefined fields as "leave unchanged".
  const updated = await prisma.task.update({
    where: { id: taskId },
    data: {
      status: input.status,
      closurePhotoUrl: input.closurePhotoUrl,
      closureVerified: input.closureVerified,
    },
  });

  // Issue #124: a closure earns its owner points; a reopen takes them back
  // (the leaderboard only ever rewarded closures that stand). Best-effort, like
  // submitVisit's hooks — the task change is already persisted.
  if (input.status === 'closed') {
    await recordPointsBestEffort(`task ${updated.id} closure`, () => recordTaskClosed(updated.id));
  } else if (input.status !== undefined) {
    await recordPointsBestEffort(`task ${updated.id} reopen`, () => voidTaskClosed(updated.id));
  }

  return updated;
}

import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { mean, round2 } from '../../lib/kpiMath';
import { NotFoundError } from '../../middleware/errorHandler';
import { PointsLedgerEntryView, listLedgerEntries } from './pointsLedger';

/** Build a date-range filter, or undefined when no bounds are given. */
function dateRange(from?: Date, to?: Date): { gte?: Date; lte?: Date } | undefined {
  if (!from && !to) {
    return undefined;
  }
  return {
    ...(from ? { gte: from } : {}),
    ...(to ? { lte: to } : {}),
  };
}

export interface LeaderboardOptions {
  from?: Date;
  to?: Date;
}

export interface LeaderboardEntry {
  agentId: string;
  email: string;
  /** `null` when the agent was never given a name — show `email` instead. */
  displayName: string | null;
  visitsSubmitted: number;
  tasksClosed: number;
  avgScorecard: number;
  points: number;
  rank: number;
}

/**
 * Tenant-scoped field-agent leaderboard, read from the points ledger (#124).
 *
 * The formula is the one the board always had —
 * `mean(scorecard) + 5 x tasks closed + 2 x visits submitted` — now summed
 * from ledger entries whose `occurredAt` falls in the optional [from, to]
 * window (both bounds inclusive):
 *
 * - visits: `visit_submitted` entries, dated by the visit's checkinTs (as before);
 * - scorecards: `scorecard` entries, dated by the scorecard's createdAt (as
 *   before); their `score`s are averaged, their 0 points add nothing;
 * - tasks: `task_closed` entries, dated by the closure. **Changed:** closures
 *   used to be lifetime counts that ignored the window, because Task has no
 *   closure timestamp. The ledger has one, so a windowed board now counts only
 *   closures in the window. Unwindowed boards are unchanged.
 *
 * Any other entry (a future manual adjustment) adds its points to the total.
 * One aggregate query regardless of agent or event count.
 */
export async function computeLeaderboard(
  clientId: string,
  opts: LeaderboardOptions = {},
): Promise<LeaderboardEntry[]> {
  const occurredRange = dateRange(opts.from, opts.to);

  const agents = await prisma.user.findMany({
    where: { clientId, role: 'field_agent' },
    select: { id: true, email: true, displayName: true },
  });

  const agentIds = agents.map((a) => a.id);
  if (agentIds.length === 0) {
    return [];
  }

  const where: Prisma.PointsLedgerEntryWhereInput = {
    clientId,
    agentId: { in: agentIds },
    ...(occurredRange ? { occurredAt: occurredRange } : {}),
  };

  // Counts and integer point sums aggregate exactly in Postgres. The scorecard
  // mean does not: a float SUM read back through Prisma can land on a different
  // double than a JS sum, which flips round2 at a boundary (75.165 -> 75.17 vs
  // 75.16). So the scores are fetched and averaged with the same mean() the
  // computed board used — one row per in-window scorecard, as it fetched.
  const [groups, scoreRows] = await Promise.all([
    prisma.pointsLedgerEntry.groupBy({
      by: ['agentId', 'reason'],
      where,
      _count: { _all: true },
      _sum: { points: true },
    }),
    prisma.pointsLedgerEntry.findMany({
      where: { ...where, reason: 'scorecard' },
      select: { agentId: true, score: true },
    }),
  ]);

  interface Totals {
    visitsSubmitted: number;
    tasksClosed: number;
    points: number;
  }
  const totals = new Map<string, Totals>();
  for (const g of groups) {
    const t = totals.get(g.agentId) ?? { visitsSubmitted: 0, tasksClosed: 0, points: 0 };
    t.points += g._sum.points ?? 0;
    if (g.reason === 'visit_submitted') {
      t.visitsSubmitted += g._count._all;
    } else if (g.reason === 'task_closed') {
      t.tasksClosed += g._count._all;
    }
    totals.set(g.agentId, t);
  }
  const scoreLists = new Map<string, number[]>();
  for (const s of scoreRows) {
    const list = scoreLists.get(s.agentId) ?? [];
    list.push(s.score ?? 0);
    scoreLists.set(s.agentId, list);
  }

  const rows = agents.map((agent) => {
    const t = totals.get(agent.id);
    const visitsSubmitted = t?.visitsSubmitted ?? 0;
    const tasksClosed = t?.tasksClosed ?? 0;
    // mean([]) === 0 keeps an agent with no in-window scorecards at 0.
    const avgScorecard = mean(scoreLists.get(agent.id) ?? []);
    const points = round2(avgScorecard + (t?.points ?? 0));

    return {
      agentId: agent.id,
      email: agent.email,
      displayName: agent.displayName,
      visitsSubmitted,
      tasksClosed,
      avgScorecard,
      points,
    };
  });

  // Highest points first; email breaks ties for a stable, deterministic order.
  rows.sort((a, b) => b.points - a.points || a.email.localeCompare(b.email));

  return rows.map((row, index) => ({ ...row, rank: index + 1 }));
}

/**
 * The caller's own leaderboard entry. Field agents resolve to their computed
 * row; callers with no field activity (e.g. managers/admins, who never appear
 * on the leaderboard) get a zeroed entry ranked last.
 */
export async function getAgentLeaderboardEntry(
  clientId: string,
  userId: string,
  opts: LeaderboardOptions = {},
): Promise<LeaderboardEntry> {
  const leaderboard = await computeLeaderboard(clientId, opts);
  const own = leaderboard.find((entry) => entry.agentId === userId);
  if (own) {
    return own;
  }

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { email: true, displayName: true },
  });

  return {
    agentId: userId,
    email: user?.email ?? '',
    displayName: user?.displayName ?? null,
    visitsSubmitted: 0,
    tasksClosed: 0,
    avgScorecard: 0,
    points: 0,
    rank: leaderboard.length + 1,
  };
}

/** How many entries `/gamification/me` returns as "how I earned these". */
export const RECENT_ENTRIES_LIMIT = 20;

export interface AgentPointsHistory {
  agent: { agentId: string; email: string; displayName: string | null };
  data: PointsLedgerEntryView[];
  nextCursor: string | null;
}

/**
 * One field agent's ledger entries for a manager, newest first. 404 when the
 * id is not a field agent of the caller's client — another tenant's agent is
 * indistinguishable from one that does not exist.
 */
export async function getAgentPointsHistory(input: {
  clientId: string;
  agentId: string;
  from?: Date;
  to?: Date;
  limit: number;
  cursor?: string;
}): Promise<AgentPointsHistory> {
  const agent = await prisma.user.findFirst({
    where: { id: input.agentId, clientId: input.clientId, role: 'field_agent' },
    select: { id: true, email: true, displayName: true },
  });
  if (!agent) {
    throw new NotFoundError('Agent not found');
  }
  const page = await listLedgerEntries(input);
  return {
    agent: { agentId: agent.id, email: agent.email, displayName: agent.displayName },
    ...page,
  };
}

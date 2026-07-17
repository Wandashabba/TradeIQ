import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { mean } from '../../lib/kpiMath';

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

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
  visitsSubmitted: number;
  tasksClosed: number;
  avgScorecard: number;
  points: number;
  rank: number;
}

/**
 * Tenant-scoped field-agent leaderboard, computed from existing visit,
 * scorecard and task data (no dedicated gamification tables).
 *
 * The optional [from, to] window filters submitted visits by `checkinTs` and
 * scorecards by `createdAt`. Task closures are lifetime counts (Tasks carry no
 * comparable in-window activity timestamp in the contract) and are unaffected
 * by the window.
 */
export async function computeLeaderboard(
  clientId: string,
  opts: LeaderboardOptions = {},
): Promise<LeaderboardEntry[]> {
  const checkinRange = dateRange(opts.from, opts.to);
  const createdRange = dateRange(opts.from, opts.to);

  const agents = await prisma.user.findMany({
    where: { clientId, role: 'field_agent' },
    select: { id: true, email: true },
  });

  const agentIds = agents.map((a) => a.id);
  if (agentIds.length === 0) {
    return [];
  }

  const visitWhere: Prisma.VisitWhereInput = {
    clientId,
    agentId: { in: agentIds },
    status: 'submitted',
    ...(checkinRange ? { checkinTs: checkinRange } : {}),
  };

  // Constant query count regardless of agent count: two groupBy aggregates
  // plus one scoped scorecard fetch, joined in JS below. Scorecard has no
  // agentId scalar (it links via visit.agentId), so it cannot be grouped by
  // Prisma groupBy — fetch narrowly and reduce.
  const [visitGroups, taskGroups, scorecardRows] = await Promise.all([
    prisma.visit.groupBy({ by: ['agentId'], where: visitWhere, _count: { _all: true } }),
    prisma.task.groupBy({
      by: ['ownerId'],
      where: { ownerId: { in: agentIds }, status: 'closed', outlet: { clientId } },
      _count: { _all: true },
    }),
    prisma.scorecard.findMany({
      where: {
        visit: { clientId, agentId: { in: agentIds } },
        ...(createdRange ? { createdAt: createdRange } : {}),
      },
      select: { weightedTotal: true, visit: { select: { agentId: true } } },
    }),
  ]);

  const visitCount = new Map(visitGroups.map((g) => [g.agentId, g._count._all]));
  const taskCount = new Map(taskGroups.map((g) => [g.ownerId, g._count._all]));
  const scoreLists = new Map<string, number[]>();
  for (const s of scorecardRows) {
    const id = s.visit.agentId;
    const list = scoreLists.get(id) ?? [];
    list.push(s.weightedTotal);
    scoreLists.set(id, list);
  }

  const rows = agents.map((agent) => {
    const visitsSubmitted = visitCount.get(agent.id) ?? 0;
    const tasksClosed = taskCount.get(agent.id) ?? 0;
    // avgScorecard via mean() (sum/n in JS) replaces the old per-agent Postgres
    // AVG; weightedTotal is a Float, so these match to round2 for real data.
    // mean([]) === 0 preserves the old `?? 0` empty-window behavior.
    const avgScorecard = mean(scoreLists.get(agent.id) ?? []);
    const points = round2(avgScorecard + tasksClosed * 5 + visitsSubmitted * 2);

    return {
      agentId: agent.id,
      email: agent.email,
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
    select: { email: true },
  });

  return {
    agentId: userId,
    email: user?.email ?? '',
    visitsSubmitted: 0,
    tasksClosed: 0,
    avgScorecard: 0,
    points: 0,
    rank: leaderboard.length + 1,
  };
}

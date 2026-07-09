import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';

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

  const rows = await Promise.all(
    agents.map(async (agent) => {
      const visitWhere: Prisma.VisitWhereInput = {
        clientId,
        agentId: agent.id,
        status: 'submitted',
      };
      if (checkinRange) {
        visitWhere.checkinTs = checkinRange;
      }

      const scorecardWhere: Prisma.ScorecardWhereInput = {
        visit: { clientId, agentId: agent.id },
      };
      if (createdRange) {
        scorecardWhere.createdAt = createdRange;
      }

      const [visitsSubmitted, tasksClosed, scorecardAgg] = await Promise.all([
        prisma.visit.count({ where: visitWhere }),
        prisma.task.count({
          where: { ownerId: agent.id, status: 'closed', outlet: { clientId } },
        }),
        prisma.scorecard.aggregate({
          where: scorecardWhere,
          _avg: { weightedTotal: true },
        }),
      ]);

      const avgScorecard = round2(scorecardAgg._avg.weightedTotal ?? 0);
      const points = round2(avgScorecard + tasksClosed * 5 + visitsSubmitted * 2);

      return {
        agentId: agent.id,
        email: agent.email,
        visitsSubmitted,
        tasksClosed,
        avgScorecard,
        points,
      };
    }),
  );

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

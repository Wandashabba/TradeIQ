import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { mean, round2 } from '../../lib/kpiMath';
import { campaignWindow } from '../campaigns/campaignWindow';
import { rankStandings } from './contestRules';

/**
 * A contest's standings (#124).
 *
 * **Window.** Ledger entries whose `occurredAt` falls inside the contest's
 * inclusive local calendar days in Client.timezone — `[start of startDate,
 * start of the day after endDate)` as instants, exactly the campaign window
 * (#324). So an entry at 15:00 local on the end day counts, and one at 00:30
 * local the next day does not.
 *
 * **Points.** The leaderboard formula over the entries that count:
 * `mean(scorecard score) + sum(points)`. With no event-type filter an agent's
 * contest points therefore equal their leaderboard points over the same
 * window. A filter keeps only the listed reasons; the scorecard mean is added
 * only when `scorecard` is among them (a scorecard entry's own points are 0).
 *
 * **Who is on the board.** Field agents of the tenant — only those assigned to
 * the territory when the contest is scoped to one — who are either:
 * - active (`User.active`), even on 0 points, so an agent sees where they
 *   stand before earning anything; or
 * - deactivated but earned counted points in the window, so an ended
 *   contest's result does not change when someone leaves the company.
 * Deactivated agents with nothing in the window are left off.
 *
 * **Ties.** Competition ranking — see `rankStandings`.
 */

export interface ContestScope {
  clientId: string;
  startDate: Date;
  endDate: Date;
  territoryId: string | null;
  eventTypes: string[];
}

export interface ContestStanding {
  rank: number;
  agentId: string;
  email: string;
  /** `null` when the agent was never given a name — show `email` instead. */
  displayName: string | null;
  points: number;
  visitsSubmitted: number;
  tasksClosed: number;
  avgScorecard: number;
}

export async function computeContestStandings(
  contest: ContestScope,
  timeZone: string,
): Promise<ContestStanding[]> {
  const window = campaignWindow(contest.startDate, contest.endDate, timeZone);

  const inScope: Prisma.UserWhereInput = {
    clientId: contest.clientId,
    role: 'field_agent',
    ...(contest.territoryId ? { territories: { some: { territoryId: contest.territoryId } } } : {}),
  };
  const filtered = contest.eventTypes.length > 0;
  const countsScorecards = !filtered || contest.eventTypes.includes('scorecard');

  const where: Prisma.PointsLedgerEntryWhereInput = {
    clientId: contest.clientId,
    occurredAt: { gte: window.from, lt: window.to },
    ...(filtered ? { reason: { in: contest.eventTypes } } : {}),
    agent: inScope,
  };

  // Counts and integer sums aggregate exactly in Postgres; scores are fetched
  // and averaged with the same mean() the leaderboard uses (see
  // gamification.service.ts on why a float SUM is not used).
  const [groups, scoreRows] = await Promise.all([
    prisma.pointsLedgerEntry.groupBy({
      by: ['agentId', 'reason'],
      where,
      _count: { _all: true },
      _sum: { points: true },
    }),
    countsScorecards
      ? prisma.pointsLedgerEntry.findMany({
          where: { ...where, reason: 'scorecard' },
          select: { agentId: true, score: true },
        })
      : Promise.resolve([] as Array<{ agentId: string; score: number | null }>),
  ]);

  const earners = [...new Set(groups.map((g) => g.agentId))];
  const agents = await prisma.user.findMany({
    where: {
      ...inScope,
      OR: [{ active: true }, ...(earners.length > 0 ? [{ id: { in: earners } }] : [])],
    },
    select: { id: true, email: true, displayName: true },
  });

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
    const avgScorecard = mean(scoreLists.get(agent.id) ?? []);
    return {
      agentId: agent.id,
      email: agent.email,
      displayName: agent.displayName,
      points: round2(avgScorecard + (t?.points ?? 0)),
      visitsSubmitted: t?.visitsSubmitted ?? 0,
      tasksClosed: t?.tasksClosed ?? 0,
      avgScorecard,
    };
  });

  return rankStandings(rows);
}

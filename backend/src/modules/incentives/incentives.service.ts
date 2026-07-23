import { prisma } from '../../lib/prisma';
import { mean } from '../../lib/kpiMath';
import { NotFoundError } from '../../middleware/errorHandler';
import { buildPage } from '../../lib/pagination';

/** The performance metrics an incentive scheme can reward against. */
export type IncentiveMetric = 'scorecard' | 'tasks_closed' | 'visits';

export const INCENTIVE_METRICS: readonly IncentiveMetric[] = ['scorecard', 'tasks_closed', 'visits'];

export function isIncentiveMetric(value: unknown): value is IncentiveMetric {
  return typeof value === 'string' && (INCENTIVE_METRICS as readonly string[]).includes(value);
}

export interface CreateSchemeInput {
  clientId: string;
  name: string;
  metric: IncentiveMetric;
  threshold: number;
  rewardPoints: number;
  rewardDetail?: string;
}

export async function createScheme(input: CreateSchemeInput) {
  return prisma.incentiveScheme.create({
    data: {
      clientId: input.clientId,
      name: input.name,
      metric: input.metric,
      threshold: input.threshold,
      rewardPoints: input.rewardPoints,
      rewardDetail: input.rewardDetail,
    },
  });
}

export interface ListSchemesInput {
  clientId: string;
  limit: number;
  cursor?: string;
}

export async function listSchemes(input: ListSchemesInput) {
  const rows = await prisma.incentiveScheme.findMany({
    where: { clientId: input.clientId },
    // `id` is the unique tiebreaker that makes the cursor deterministic when
    // two schemes share a createdAt — same reasoning as alerts.service.ts.
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });
  return buildPage(rows, input.limit);
}

/** Tenant-scoped lookup; throws NotFoundError so the caller can't reach across clients. */
export async function findSchemeForClient(schemeId: string, clientId: string) {
  const scheme = await prisma.incentiveScheme.findFirst({
    where: { id: schemeId, clientId },
  });
  if (!scheme) {
    throw new NotFoundError('Incentive scheme not found');
  }
  return scheme;
}

export interface UpdateSchemeInput {
  name?: string;
  threshold?: number;
  rewardPoints?: number;
  rewardDetail?: string;
  active?: boolean;
}

export async function updateScheme(schemeId: string, input: UpdateSchemeInput) {
  // Prisma treats undefined fields as "leave unchanged".
  return prisma.incentiveScheme.update({
    where: { id: schemeId },
    data: {
      name: input.name,
      threshold: input.threshold,
      rewardPoints: input.rewardPoints,
      rewardDetail: input.rewardDetail,
      active: input.active,
    },
  });
}

export async function deleteScheme(schemeId: string): Promise<void> {
  await prisma.incentiveScheme.delete({ where: { id: schemeId } });
}

export interface EarnedIncentive {
  schemeId: string;
  schemeName: string;
  metric: IncentiveMetric;
  agentId: string;
  email: string;
  metricValue: number;
  rewardPoints: number;
}

/**
 * Computes, per ACTIVE scheme, which of the client's field agents meet the
 * scheme's threshold and awards each qualifying agent the scheme's points.
 *
 * Metric values reuse the same aggregation approach as the leaderboard:
 *   - scorecard    → mean of the agent's Scorecard.weightedTotal (via visit)
 *   - tasks_closed → count of Tasks the agent owns with status 'closed'
 *   - visits       → count of the agent's submitted visits
 *
 * Returns a flat array of one row per (active scheme, qualifying agent) pair.
 * Zero-safe: no schemes or no agents yields an empty array.
 */
export async function computeEarnedIncentives(clientId: string): Promise<EarnedIncentive[]> {
  const [schemes, agents] = await Promise.all([
    prisma.incentiveScheme.findMany({
      where: { clientId, active: true },
      orderBy: { createdAt: 'desc' },
    }),
    prisma.user.findMany({
      where: { clientId, role: 'field_agent' },
      select: { id: true, email: true },
    }),
  ]);

  const agentIds = agents.map((a) => a.id);
  if (schemes.length === 0 || agentIds.length === 0) {
    return [];
  }

  // There are only three distinct metrics, so each is computed ONCE per agent
  // (constant query count) rather than once per (scheme, agent) pair. Every
  // scheme's threshold is then evaluated against these maps in memory. Mirrors
  // the leaderboard's groupBy + narrow scorecard fetch: Scorecard has no
  // agentId scalar (it links via visit.agentId), so it cannot be groupBy'd —
  // fetch narrowly and reduce into per-agent lists.
  const [visitGroups, taskGroups, scorecardRows] = await Promise.all([
    prisma.visit.groupBy({
      by: ['agentId'],
      where: { clientId, agentId: { in: agentIds }, status: 'submitted' },
      _count: { _all: true },
    }),
    prisma.task.groupBy({
      by: ['ownerId'],
      where: { ownerId: { in: agentIds }, status: 'closed', outlet: { clientId } },
      _count: { _all: true },
    }),
    prisma.scorecard.findMany({
      where: { visit: { clientId, agentId: { in: agentIds } } },
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

  // mean() is round2(sum/n) with mean([]) === 0, matching the old per-agent
  // round2(_avg.weightedTotal ?? 0): same rows agree to round2.
  function metricValueFor(metric: IncentiveMetric, agentId: string): number {
    if (metric === 'scorecard') {
      return mean(scoreLists.get(agentId) ?? []);
    }
    if (metric === 'tasks_closed') {
      return taskCount.get(agentId) ?? 0;
    }
    return visitCount.get(agentId) ?? 0; // 'visits'
  }

  // Preserve the exact row order of the old nested loop: scheme-outer (schemes
  // in createdAt-desc order), agent-inner (agents in findMany order).
  const earned: EarnedIncentive[] = [];
  for (const scheme of schemes) {
    const metric = scheme.metric as IncentiveMetric;
    for (const agent of agents) {
      const value = metricValueFor(metric, agent.id);
      if (value >= scheme.threshold) {
        earned.push({
          schemeId: scheme.id,
          schemeName: scheme.name,
          metric,
          agentId: agent.id,
          email: agent.email,
          metricValue: value,
          rewardPoints: scheme.rewardPoints,
        });
      }
    }
  }

  return earned;
}

import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';

/** The performance metrics an incentive scheme can reward against. */
export type IncentiveMetric = 'scorecard' | 'tasks_closed' | 'visits';

export const INCENTIVE_METRICS: readonly IncentiveMetric[] = ['scorecard', 'tasks_closed', 'visits'];

export function isIncentiveMetric(value: unknown): value is IncentiveMetric {
  return typeof value === 'string' && (INCENTIVE_METRICS as readonly string[]).includes(value);
}

function round2(value: number): number {
  return Math.round(value * 100) / 100;
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

export async function listSchemes(clientId: string) {
  return prisma.incentiveScheme.findMany({
    where: { clientId },
    orderBy: { createdAt: 'desc' },
  });
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

  const earned: EarnedIncentive[] = [];

  for (const scheme of schemes) {
    const metric = scheme.metric as IncentiveMetric;

    const values = await Promise.all(
      agents.map(async (agent) => {
        let metricValue: number;
        if (metric === 'scorecard') {
          const agg = await prisma.scorecard.aggregate({
            where: { visit: { clientId, agentId: agent.id } },
            _avg: { weightedTotal: true },
          });
          metricValue = round2(agg._avg.weightedTotal ?? 0);
        } else if (metric === 'tasks_closed') {
          metricValue = await prisma.task.count({
            where: { ownerId: agent.id, status: 'closed', outlet: { clientId } },
          });
        } else {
          metricValue = await prisma.visit.count({
            where: { clientId, agentId: agent.id, status: 'submitted' },
          });
        }
        return { agent, metricValue };
      }),
    );

    for (const { agent, metricValue } of values) {
      if (metricValue >= scheme.threshold) {
        earned.push({
          schemeId: scheme.id,
          schemeName: scheme.name,
          metric,
          agentId: agent.id,
          email: agent.email,
          metricValue,
          rewardPoints: scheme.rewardPoints,
        });
      }
    }
  }

  return earned;
}

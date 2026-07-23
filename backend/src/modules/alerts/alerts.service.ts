import { Alert, Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
import { dispatchWebhookEvent } from '../webhooks/webhooks.service';
import { buildPage } from '../../lib/pagination';

// The fixed set of metrics an AlertRule may target. Kept in one place so the
// route validation and the evaluator agree on what's supported.
export const ALERT_METRICS = ['out_of_stock', 'price_deviation', 'low_scorecard'] as const;
export type AlertMetric = (typeof ALERT_METRICS)[number];

export function isAlertMetric(value: unknown): value is AlertMetric {
  return typeof value === 'string' && (ALERT_METRICS as readonly string[]).includes(value);
}

// Fallbacks used when a rule leaves `threshold` unset.
const DEFAULT_PRICE_DEVIATION_THRESHOLD = 10;
const DEFAULT_SCORECARD_THRESHOLD = 60;

export interface CreateAlertRuleInput {
  clientId: string;
  name: string;
  metric: AlertMetric;
  threshold?: number;
  severity?: string;
}

export async function createAlertRule(input: CreateAlertRuleInput) {
  return prisma.alertRule.create({
    data: {
      clientId: input.clientId,
      name: input.name,
      metric: input.metric,
      threshold: input.threshold,
      // undefined lets the schema default ('normal') apply.
      severity: input.severity,
    },
  });
}

export async function listAlertRules(clientId: string) {
  return prisma.alertRule.findMany({
    where: { clientId },
    orderBy: { createdAt: 'desc' },
  });
}

export interface UpdateAlertRuleInput {
  active?: boolean;
  threshold?: number;
  severity?: string;
}

export async function updateAlertRule(
  ruleId: string,
  clientId: string,
  input: UpdateAlertRuleInput,
) {
  const rule = await prisma.alertRule.findFirst({
    where: { id: ruleId, clientId },
    select: { id: true },
  });
  if (!rule) {
    throw new NotFoundError('Alert rule not found');
  }
  // Prisma treats undefined fields as "leave unchanged".
  return prisma.alertRule.update({
    where: { id: ruleId },
    data: {
      active: input.active,
      threshold: input.threshold,
      severity: input.severity,
    },
  });
}

export interface EvaluateVisitInput {
  clientId: string;
  visitId: string;
}

export async function evaluateVisit(input: EvaluateVisitInput): Promise<Alert[]> {
  const visit = await prisma.visit.findFirst({
    where: { id: input.visitId, clientId: input.clientId },
    select: { id: true, outletId: true },
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }

  const rules = await prisma.alertRule.findMany({
    where: { clientId: input.clientId, active: true },
    orderBy: { createdAt: 'desc' },
  });

  // At most one active rule drives each metric; if several exist, the newest
  // (first, given the desc order) wins so evaluation stays deterministic.
  const ruleByMetric = new Map<string, (typeof rules)[number]>();
  for (const rule of rules) {
    if (!ruleByMetric.has(rule.metric)) {
      ruleByMetric.set(rule.metric, rule);
    }
  }

  const alertsToCreate: Prisma.AlertUncheckedCreateInput[] = [];

  const outOfStockRule = ruleByMetric.get('out_of_stock');
  if (outOfStockRule) {
    const stockRows = await prisma.visitStock.findMany({
      where: { visitId: visit.id, unitsAvailable: 0 },
      select: { skuId: true },
    });
    for (const row of stockRows) {
      alertsToCreate.push({
        clientId: input.clientId,
        ruleId: outOfStockRule.id,
        visitId: visit.id,
        outletId: visit.outletId,
        metric: 'out_of_stock',
        message: `SKU ${row.skuId} is out of stock`,
        severity: outOfStockRule.severity,
      });
    }
  }

  const priceRule = ruleByMetric.get('price_deviation');
  if (priceRule) {
    const threshold = priceRule.threshold ?? DEFAULT_PRICE_DEVIATION_THRESHOLD;
    const pricingRows = await prisma.visitPricing.findMany({
      where: { visitId: visit.id },
      select: { skuId: true, deviationPct: true },
    });
    for (const row of pricingRows) {
      if (Math.abs(row.deviationPct) > threshold) {
        alertsToCreate.push({
          clientId: input.clientId,
          ruleId: priceRule.id,
          visitId: visit.id,
          outletId: visit.outletId,
          metric: 'price_deviation',
          message: `SKU ${row.skuId} price deviates ${row.deviationPct}% (threshold ${threshold}%)`,
          severity: priceRule.severity,
        });
      }
    }
  }

  const scorecardRule = ruleByMetric.get('low_scorecard');
  if (scorecardRule) {
    const threshold = scorecardRule.threshold ?? DEFAULT_SCORECARD_THRESHOLD;
    const scorecard = await prisma.scorecard.findUnique({
      where: { visitId: visit.id },
      select: { weightedTotal: true },
    });
    if (scorecard && scorecard.weightedTotal < threshold) {
      alertsToCreate.push({
        clientId: input.clientId,
        ruleId: scorecardRule.id,
        visitId: visit.id,
        outletId: visit.outletId,
        metric: 'low_scorecard',
        message: `Scorecard ${scorecard.weightedTotal} is below threshold ${threshold}`,
        severity: scorecardRule.severity,
      });
    }
  }

  if (alertsToCreate.length === 0) {
    return [];
  }

  // One transaction so a partial batch of alerts is never persisted.
  const created = await prisma.$transaction(
    alertsToCreate.map((data) => prisma.alert.create({ data })),
  );

  // Issue #38: fire best-effort to any webhooks the client has subscribed to
  // this event. dispatchWebhookEvent never throws (swallows delivery errors),
  // so awaiting is safe and avoids open-handle warnings.
  if (created.length > 0) {
    await dispatchWebhookEvent(input.clientId, 'alert.raised', {
      visitId: input.visitId,
      count: created.length,
      alertIds: created.map((a) => a.id),
    });
  }

  return created;
}

export interface ListAlertsInput {
  clientId: string;
  acknowledged?: boolean;
  severity?: string;
  limit: number;
  cursor?: string;
}

export async function listAlerts(input: ListAlertsInput) {
  const rows = await prisma.alert.findMany({
    where: {
      clientId: input.clientId,
      ...(input.acknowledged !== undefined ? { acknowledged: input.acknowledged } : {}),
      ...(input.severity !== undefined ? { severity: input.severity } : {}),
    },
    // `id` is the unique tiebreaker that makes the cursor deterministic when
    // two alerts share a createdAt — same reasoning as agents.service.ts.
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });
  return buildPage(rows, input.limit);
}

export async function acknowledgeAlert(alertId: string, clientId: string) {
  const alert = await prisma.alert.findFirst({
    where: { id: alertId, clientId },
    select: { id: true },
  });
  if (!alert) {
    throw new NotFoundError('Alert not found');
  }
  return prisma.alert.update({
    where: { id: alertId },
    data: { acknowledged: true },
  });
}

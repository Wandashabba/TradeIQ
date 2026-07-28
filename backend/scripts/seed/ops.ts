import { addDays } from './calendar';
import { OutletSeed, UserSeed } from './catalog';
import { makeRng, pick } from './rng';
import { GeneratedVisit } from './visits';

/**
 * Tasks, alerts and incentives — the "live problem tail".
 *
 * These are generated FROM the visit history rather than sprinkled on top, so a
 * manager who drills from an alert into its outlet finds the low scores and
 * stockouts that justify it. A demo where the alerts and the data disagree is
 * worse than one with no alerts.
 *
 * Closure photos are real base64 JPEGs (#209), supplied by the caller so this
 * module stays synchronous and pure.
 */

export interface GeneratedTask {
  id: string;
  visitId: string | null;
  findingType: string;
  outletId: string;
  requiredFix: string;
  // The TaskPriority enum is exactly critical | high | normal. There is no
  // 'low' — do not add one here without a migration.
  priority: 'critical' | 'high' | 'normal';
  slaDueAt: Date;
  ownerId: string;
  status: 'open' | 'closed';
  closurePhotoUrl?: string;
  closureVerified: boolean;
  createdAt: Date;
}

export interface GeneratedAlert {
  id: string;
  ruleId: string;
  visitId: string | null;
  outletId: string | null;
  metric: string;
  message: string;
  severity: string;
  acknowledged: boolean;
  createdAt: Date;
}

export interface GeneratedIncentiveScheme {
  id: string;
  name: string;
  metric: string;
  threshold: number;
  rewardPoints: number;
  rewardDetail: string;
  active: boolean;
}

export interface OpsBundle {
  tasks: GeneratedTask[];
  alerts: GeneratedAlert[];
  incentiveSchemes: GeneratedIncentiveScheme[];
}

export interface BuildOpsInput {
  anchor: Date;
  visits: GeneratedVisit[];
  outlets: OutletSeed[];
  agents: UserSeed[];
  /**
   * Real JPEG data URL for closed tasks' closure evidence. Required, not
   * optional: a default would let a placeholder string satisfy the test that is
   * supposed to prove #209 is fixed.
   */
  closurePhotoUrl: string;
}

export const ALERT_RULE_IDS = {
  outOfStock: 'demo-alert-rule-oos',
  priceDeviation: 'demo-alert-rule-price',
  lowScorecard: 'demo-alert-rule-score',
} as const;

const RECENT_WINDOW_DAYS = 21;

export function buildOps(input: BuildOpsInput): OpsBundle {
  const { anchor, visits, agents, closurePhotoUrl } = input;
  const rng = makeRng(555000111);

  const tasks: GeneratedTask[] = [];
  const alerts: GeneratedAlert[] = [];

  const recentCutoff = addDays(anchor, -RECENT_WINDOW_DAYS);
  let taskCounter = 0;
  let alertCounter = 0;

  for (const visit of visits) {
    const isRecent = visit.checkinTs.getTime() >= recentCutoff.getTime();
    const owner = pick(rng, agents);

    const stockout = visit.stock.find((row) => row.unitsAvailable === 0);
    const badPrice = visit.pricing.find((row) => row.deviationPct > 10);

    // Historic findings are closed (the loop worked); recent ones on problem
    // outlets stay open and overdue (there is still something to do).
    if (stockout) {
      taskCounter += 1;
      const closed = !isRecent || !visit.isProblemOutlet;
      tasks.push({
        id: `demo-task-${String(taskCounter).padStart(4, '0')}`,
        visitId: visit.id,
        findingType: 'out_of_stock',
        outletId: visit.outletId,
        requiredFix: 'Replenish the out-of-stock SKU from back-stock and confirm shelf facings.',
        priority: visit.isProblemOutlet ? 'critical' : 'high',
        slaDueAt: addDays(visit.checkinTs, 3),
        ownerId: owner.id,
        status: closed ? 'closed' : 'open',
        closurePhotoUrl: closed ? closurePhotoUrl : undefined,
        closureVerified: closed,
        createdAt: visit.checkinTs,
      });
    }

    if (badPrice) {
      taskCounter += 1;
      const closed = !isRecent;
      tasks.push({
        id: `demo-task-${String(taskCounter).padStart(4, '0')}`,
        visitId: visit.id,
        findingType: 'price_deviation',
        outletId: visit.outletId,
        requiredFix: 'Reprint the shelf tag to match the master price list and photograph it.',
        priority: 'normal',
        slaDueAt: addDays(visit.checkinTs, 5),
        ownerId: owner.id,
        status: closed ? 'closed' : 'open',
        closurePhotoUrl: closed ? closurePhotoUrl : undefined,
        closureVerified: closed,
        createdAt: visit.checkinTs,
      });
    }

    // Only recent exceptions raise alerts — a manager's alert list should be
    // actionable, not an archive.
    if (!isRecent) continue;

    if (stockout) {
      alertCounter += 1;
      alerts.push({
        id: `demo-alert-${String(alertCounter).padStart(4, '0')}`,
        ruleId: ALERT_RULE_IDS.outOfStock,
        visitId: visit.id,
        outletId: visit.outletId,
        metric: 'out_of_stock',
        message: 'Out of stock detected on a core SKU.',
        severity: visit.isProblemOutlet ? 'critical' : 'high',
        acknowledged: !visit.isProblemOutlet,
        createdAt: visit.checkinTs,
      });
    }

    if (visit.scorecard.weightedTotal < 60) {
      alertCounter += 1;
      alerts.push({
        id: `demo-alert-${String(alertCounter).padStart(4, '0')}`,
        ruleId: ALERT_RULE_IDS.lowScorecard,
        visitId: visit.id,
        outletId: visit.outletId,
        metric: 'low_scorecard',
        message: `Execution score ${visit.scorecard.weightedTotal} is below the red threshold.`,
        severity: 'high',
        acknowledged: false,
        createdAt: visit.checkinTs,
      });
    }

    if (badPrice) {
      alertCounter += 1;
      alerts.push({
        id: `demo-alert-${String(alertCounter).padStart(4, '0')}`,
        ruleId: ALERT_RULE_IDS.priceDeviation,
        visitId: visit.id,
        outletId: visit.outletId,
        metric: 'price_deviation',
        message: `Shelf price is ${badPrice.deviationPct}% above master.`,
        severity: 'normal',
        acknowledged: rng() < 0.5,
        createdAt: visit.checkinTs,
      });
    }
  }

  const incentiveSchemes: GeneratedIncentiveScheme[] = [
    {
      id: 'demo-incentive-1',
      name: 'Q3 Perfect Store Push',
      metric: 'scorecard',
      threshold: 80,
      rewardPoints: 500,
      rewardDetail: 'R500 airtime voucher for every store scored 80+.',
      active: true,
    },
    {
      id: 'demo-incentive-2',
      name: 'Close the Loop',
      metric: 'tasks_closed',
      threshold: 20,
      rewardPoints: 250,
      rewardDetail: 'R250 for 20 verified task closures in a month.',
      active: true,
    },
  ];

  return { tasks, alerts, incentiveSchemes };
}

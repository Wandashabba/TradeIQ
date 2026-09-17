import { computeSlaDueAt } from '../../src/lib/slaClock';
import { addMinutes } from './calendar';
import { OutletSeed, SKUS } from './catalog';
import { chance } from './rng';
import { AgentProfile, CHRONIC_OOS_TERRITORY_CODE, CHRONIC_OOS_SKU_ID } from './scenario';
import { CORE_STOCK_SKU_IDS, CapturedVisit } from './visits';

/**
 * Tasks, alerts and incentives — the "live problem tail".
 *
 * Generated FROM each visit's capture rather than sprinkled on top, so a
 * manager who drills from an alert or a task into its outlet finds the stockout,
 * the overpriced shelf or the red scorecard that raised it. A demo where the
 * alerts and the data disagree is worse than one with no alerts.
 *
 * SLAs use the product's own clock (`slaClock.ts`: critical 24h, high 72h,
 * normal 7 days). There is no `closedAt` column, so a task that was closed
 * LATE is one whose SLA breach was announced (`slaBreachNotifiedAt` set) and
 * which is now closed; a task closed on time has none. Every open task already
 * past its SLA is marked announced too, so the running server's breach sweep
 * (#67) does not push a burst of "overdue" notifications for seeded history.
 */

export interface TaskRow {
  id: string;
  visitId: string;
  findingType: string;
  outletId: string;
  requiredFix: string;
  // The TaskPriority enum is exactly critical | high | normal. There is no
  // 'low' — do not add one here without a migration.
  priority: 'critical' | 'high' | 'normal';
  slaDueAt: Date;
  ownerId: string;
  status: 'open' | 'in_progress' | 'closed';
  closurePhotoUrl: string | null;
  closureVerified: boolean;
  createdAt: Date;
  slaBreachNotifiedAt: Date | null;
}

export interface AlertRow {
  id: string;
  ruleId: string;
  visitId: string | null;
  outletId: string;
  metric: string;
  message: string;
  severity: string;
  acknowledged: boolean;
  createdAt: Date;
}

export interface IncentiveSchemeRow {
  id: string;
  name: string;
  metric: string;
  threshold: number;
  rewardPoints: number;
  rewardDetail: string;
  active: boolean;
}

export const ALERT_RULE_IDS = {
  outOfStock: 'demo-alert-rule-oos',
  priceDeviation: 'demo-alert-rule-price',
  lowScorecard: 'demo-alert-rule-score',
  slaBreach: 'demo-alert-rule-sla',
} as const;

/** Closure evidence is kept for recent closures only — base64 in Postgres is not free. */
export const CLOSURE_PHOTO_DAYS = 30;
/** Alerts are raised for this recent window only: an alert list is a to-do list, not an archive. */
export const ALERT_WINDOW_DAYS = 45;
const LOW_SCORE_TASK_THRESHOLD = 55;
/** The low-score alert rule's own threshold (index.ts writes it on the rule). */
export const LOW_SCORE_ALERT_THRESHOLD = 60;
const PRICE_TASK_THRESHOLD_PCT = 10;

const DAY_MS = 86_400_000;
const SKU_NAME = new Map(SKUS.map((s) => [s.id, s.name]));

export interface FindingsInput {
  captured: CapturedVisit;
  outlet: OutletSeed;
  ownerProfile: AgentProfile;
  isProblemOutlet: boolean;
  /** Local midnight of the anchor day, as an instant: "now" for statuses. */
  now: Date;
  closurePhotoUrl: string;
  nextTaskId: () => string;
  nextAlertId: () => string;
}

export function findingsForVisit(
  rng: () => number,
  input: FindingsInput,
): { tasks: TaskRow[]; alerts: AlertRow[] } {
  const { captured, outlet, ownerProfile, now } = input;
  const visit = captured.visit;
  const tasks: TaskRow[] = [];
  const alerts: AlertRow[] = [];
  const raisedAt = addMinutes(visit.submittedAtClient, 1);
  const ageDays = (now.getTime() - raisedAt.getTime()) / DAY_MS;
  const alerting = ageDays <= ALERT_WINDOW_DAYS;

  const openTask = (
    findingType: string,
    priority: TaskRow['priority'],
    requiredFix: string,
    stubborn: boolean,
  ) => {
    const slaDueAt = computeSlaDueAt(priority, raisedAt);
    // Anything from the first year and a bit has long since been dealt with,
    // whoever owned it; the backlog a manager sees is recent.
    const closeRate = ageDays > 240 ? 0.995 : ownerProfile.closeRate * (stubborn ? 0.7 : 1);
    const closed = ageDays > 14 ? chance(rng, closeRate) : chance(rng, closeRate * Math.min(1, ageDays / 5));
    const dueHasPassed = slaDueAt.getTime() < now.getTime();
    let slaBreachNotifiedAt: Date | null = null;
    let status: TaskRow['status'];
    if (closed) {
      status = 'closed';
      const late = dueHasPassed && !chance(rng, ownerProfile.onTimeRate * (stubborn ? 0.4 : 1));
      if (late) slaBreachNotifiedAt = addMinutes(slaDueAt, 5);
    } else {
      status = chance(rng, 0.3) ? 'in_progress' : 'open';
      if (dueHasPassed) slaBreachNotifiedAt = addMinutes(slaDueAt, 5);
    }
    const task: TaskRow = {
      id: input.nextTaskId(),
      visitId: visit.id,
      findingType,
      outletId: outlet.id,
      requiredFix,
      priority,
      slaDueAt,
      ownerId: visit.agentId,
      status,
      closurePhotoUrl: closed && ageDays <= CLOSURE_PHOTO_DAYS ? input.closurePhotoUrl : null,
      closureVerified: closed && chance(rng, 0.92),
      createdAt: raisedAt,
      slaBreachNotifiedAt,
    };
    tasks.push(task);

    if (alerting && status !== 'closed' && slaBreachNotifiedAt && slaBreachNotifiedAt.getTime() < now.getTime()) {
      alerts.push({
        id: input.nextAlertId(),
        ruleId: ALERT_RULE_IDS.slaBreach,
        visitId: visit.id,
        outletId: outlet.id,
        metric: 'sla_breach',
        message: `Task "${requiredFix}" at ${outlet.name} is past its ${priority} SLA.`,
        severity: 'high',
        acknowledged: acknowledged(rng, (now.getTime() - slaBreachNotifiedAt.getTime()) / DAY_MS),
        createdAt: slaBreachNotifiedAt,
      });
    }
  };

  // Out of stock on a core line.
  const oos = captured.stock.find(
    (row) => row.unitsAvailable === 0 && (CORE_STOCK_SKU_IDS as readonly string[]).includes(row.skuId),
  );
  if (oos) {
    const chronic = outlet.territoryId === CHRONIC_OOS_TERRITORY_CODE && oos.skuId === CHRONIC_OOS_SKU_ID;
    const priority = input.isProblemOutlet || chronic ? 'critical' : 'high';
    const skuName = SKU_NAME.get(oos.skuId) ?? oos.skuId;
    openTask('out_of_stock', priority, `Replenish ${skuName} from back-stock or raise an urgent order, then confirm facings.`, chronic);
    if (alerting) {
      alerts.push({
        id: input.nextAlertId(),
        ruleId: ALERT_RULE_IDS.outOfStock,
        visitId: visit.id,
        outletId: outlet.id,
        metric: 'out_of_stock',
        message: `${skuName} out of stock at ${outlet.name}` +
          (oos.daysOutOfStock > 0 ? ` (${oos.daysOutOfStock} days).` : '.'),
        severity: priority,
        acknowledged: acknowledged(rng, ageDays),
        createdAt: raisedAt,
      });
    }
  }

  // Shelf price above the master price list.
  const badPrice = captured.pricing
    .filter((row) => row.deviationPct > PRICE_TASK_THRESHOLD_PCT)
    .sort((a, b) => b.deviationPct - a.deviationPct)[0];
  if (badPrice) {
    const skuName = SKU_NAME.get(badPrice.skuId) ?? badPrice.skuId;
    openTask('price_deviation', 'normal', `Reprint the ${skuName} shelf tag to RRP R${badPrice.priceMaster.toFixed(2)} and photograph it.`, false);
    if (alerting) {
      alerts.push({
        id: input.nextAlertId(),
        ruleId: ALERT_RULE_IDS.priceDeviation,
        visitId: visit.id,
        outletId: outlet.id,
        metric: 'price_deviation',
        message: `${skuName} at ${outlet.name} priced R${badPrice.priceActual.toFixed(2)}, ${badPrice.deviationPct}% above RRP.`,
        severity: 'normal',
        acknowledged: acknowledged(rng, ageDays),
        createdAt: raisedAt,
      });
    }
  }

  // A red visit: an alert below the rule's threshold, a task when it is badly red.
  const total = captured.scorecard.weightedTotal;
  if (total < LOW_SCORE_TASK_THRESHOLD) {
    openTask('low_scorecard', 'high', 'Rebuild the carbonates bay to planogram and restore POSM.', false);
  }
  if (total < LOW_SCORE_ALERT_THRESHOLD) {
    if (alerting) {
      alerts.push({
        id: input.nextAlertId(),
        ruleId: ALERT_RULE_IDS.lowScorecard,
        visitId: visit.id,
        outletId: outlet.id,
        metric: 'low_scorecard',
        message: `Execution score ${captured.scorecard.weightedTotal} at ${outlet.name} is below the red threshold.`,
        severity: 'high',
        acknowledged: acknowledged(rng, ageDays),
        createdAt: raisedAt,
      });
    }
  }

  return { tasks, alerts };
}

/** Old alerts have mostly been seen; this week's mostly have not. */
function acknowledged(rng: () => number, ageDays: number): boolean {
  return ageDays > 7 ? chance(rng, 0.85) : chance(rng, 0.2);
}

export const INCENTIVE_SCHEMES: IncentiveSchemeRow[] = [
  {
    id: 'demo-incentive-1',
    name: 'Perfect Store Push',
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
  {
    id: 'demo-incentive-3',
    name: 'Full Coverage',
    metric: 'visits',
    threshold: 110,
    rewardPoints: 300,
    rewardDetail: 'R300 fuel card for 110 submitted visits in a month.',
    active: false,
  },
];

import { addCalendarDays } from '../../src/lib/clientTime';
import { addMonths, localInstant } from './calendar';
import { SKUS, TERRITORIES } from './catalog';
import { makeRng } from './rng';
import { STANDOUT_AGENT_ID, STRUGGLING_AGENT_ID } from './scenario';
import { monthKeyOf } from './history';
import { SalesPlan } from './orders';
import { World } from './world';

/**
 * Monthly sell-in targets (#119), set from the plan the history generator
 * accumulated — what each planned stop was expected to order before anything
 * went right or wrong. So targets are met or missed for the reasons the data
 * was built around, not at random.
 *
 * Coverage is deliberately uneven, because "no target" is an answer the
 * assistant has to be able to give (a null target is not a target of zero):
 * - client-wide: 16 of the 20 SKUs; four never have one;
 * - territory: the six biggest SKUs, every territory except North West;
 * - outlet: the two cola lines at key accounts, for the last twelve months;
 * - the oldest month of history has no targets at all (targets started later).
 *
 * The schema allows one scope per row and never both territory and outlet
 * (`sales_targets_single_scope`); uniqueness is the COALESCE expression index.
 * Rows here are unique on (sku, month, scope) by construction.
 */

export interface SalesTargetRow {
  id: string;
  skuId: string;
  month: Date;
  territoryId: string | null;
  outletId: string | null;
  targetUnits: number;
  createdById: string;
  createdAt: Date;
  updatedAt: Date;
}

export const SKUS_WITHOUT_CLIENT_TARGET = ['demo-sku-9', 'demo-sku-12', 'demo-sku-16', 'demo-sku-19'];
export const TERRITORY_TARGET_SKUS = ['demo-sku-1', 'demo-sku-2', 'demo-sku-3', 'demo-sku-4', 'demo-sku-5', 'demo-sku-17'];
export const TERRITORIES_WITHOUT_TARGETS = ['NW'];
export const OUTLET_TARGET_SKUS = ['demo-sku-1', 'demo-sku-2'];
export const OUTLET_TARGET_MONTHS = 12;
const KEY_ACCOUNTS_PER_TERRITORY = 3;

/**
 * What a normal month delivers against the raw plan: stops skipped, days off
 * and cancelled orders take about a tenth off. Targets assume it, so an
 * ordinary territory lands close to 100% and the planted stories stand out.
 */
const EXPECTED_EXECUTION = 0.9;

export function buildSalesTargets(world: World, plan: SalesPlan): SalesTargetRow[] {
  const rng = makeRng(119119);
  const rows: SalesTargetRow[] = [];
  const managers = ['demo-user-mgr-1', 'demo-user-mgr-2'];

  const keyAccounts = keyAccountOutletIds(world);

  let month = addMonths(world.historyStart, 1);
  let counter = 0;
  while (month.getTime() <= world.anchorMonth.getTime()) {
    const key = monthKeyOf(month);
    const setBy = managers[counter % 2]!;
    const createdAt = localInstant(addCalendarDays(month, -5), 10 * 60, world.timeZone);
    const push = (skuId: string, territoryId: string | null, outletId: string | null, planned: number, spread: number) => {
      const factor = EXPECTED_EXECUTION * (1 + (rng() * 2 - 1) * spread);
      rows.push({
        id: `demo-target-${String(rows.length + 1).padStart(5, '0')}`,
        skuId,
        month,
        territoryId,
        outletId,
        targetUnits: Math.max(1, Math.round(planned * factor)),
        createdById: setBy,
        createdAt,
        updatedAt: createdAt,
      });
    };

    for (const sku of SKUS) {
      if (SKUS_WITHOUT_CLIENT_TARGET.includes(sku.id)) continue;
      const planned = plan.client.get(`${key}|${sku.id}`) ?? 0;
      // Client-wide targets are stretched or eased per SKU: some are met, some missed.
      if (planned > 0) push(sku.id, null, null, planned, 0.1);
    }

    for (const territory of TERRITORIES) {
      if (TERRITORIES_WITHOUT_TARGETS.includes(territory.code)) continue;
      for (const skuId of TERRITORY_TARGET_SKUS) {
        const planned = plan.territory.get(`${key}|${territory.code}|${skuId}`) ?? 0;
        if (planned > 0) push(skuId, territory.id, null, planned, 0.04);
      }
    }

    if (month.getTime() > addMonths(world.anchorMonth, -OUTLET_TARGET_MONTHS).getTime()) {
      for (const outletId of keyAccounts) {
        for (const skuId of OUTLET_TARGET_SKUS) {
          const planned = plan.outlet.get(`${key}|${outletId}|${skuId}`) ?? 0;
          if (planned > 0) push(skuId, null, outletId, planned, 0.04);
        }
      }
    }

    month = addMonths(month, 1);
    counter += 1;
  }
  return rows;
}

/**
 * The biggest outlets per territory, plus every outlet on the standout and the
 * struggling agents' routes — so "is Kagiso hitting his numbers" has outlet
 * targets to answer from.
 */
export function keyAccountOutletIds(world: World): string[] {
  const ids = new Set<string>();
  for (const territory of TERRITORIES) {
    world.outlets
      .filter((o) => o.territoryId === territory.code)
      .sort((a, b) => b.acvWeight - a.acvWeight || a.code.localeCompare(b.code))
      .slice(0, KEY_ACCOUNTS_PER_TERRITORY)
      .forEach((o) => ids.add(o.id));
  }
  for (const agentId of [STANDOUT_AGENT_ID, STRUGGLING_AGENT_ID]) {
    for (const outlet of world.routes.get(agentId) ?? []) ids.add(outlet.id);
  }
  return [...ids].sort();
}

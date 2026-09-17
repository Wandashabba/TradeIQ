import { SKUS, TERRITORY_ID_BY_CODE } from './catalog';
import { FlatHistory, generateFlatHistory } from './historyFixture';
import {
  SKUS_WITHOUT_CLIENT_TARGET,
  SalesTargetRow,
  TERRITORIES_WITHOUT_TARGETS,
  buildSalesTargets,
} from './targets';

jest.setTimeout(120_000);

let H: FlatHistory;
let TARGETS: SalesTargetRow[];

beforeAll(() => {
  H = generateFlatHistory({ historyMonths: 14, outletFraction: 0.3 });
  H.generator.upcoming();
  TARGETS = buildSalesTargets(H.world, H.generator.plan);
});

describe('buildSalesTargets', () => {
  // `sales_targets_single_scope`: a target is client-wide, one territory, or one
  // outlet — never territory and outlet at once.
  it('never scopes a target to both a territory and an outlet', () => {
    for (const t of TARGETS) expect(t.territoryId !== null && t.outletId !== null).toBe(false);
  });

  // `sales_targets_scope_key`: unique on (client, sku, month, COALESCE(territory), COALESCE(outlet)).
  it('is unique on the COALESCE scope key the migration indexes', () => {
    const keys = TARGETS.map((t) => `${t.skuId}|${t.month.toISOString()}|${t.territoryId ?? ''}|${t.outletId ?? ''}`);
    expect(new Set(keys).size).toBe(keys.length);
  });

  // `sales_targets_month_first_day` and `target_units_non_negative`.
  it('stores months as their first day and units as positive integers', () => {
    for (const t of TARGETS) {
      expect(t.month.getUTCDate()).toBe(1);
      expect(t.month.getUTCHours()).toBe(0);
      expect(Number.isInteger(t.targetUnits)).toBe(true);
      expect(t.targetUnits).toBeGreaterThan(0);
    }
  });

  it('covers all three scopes, and leaves some SKUs and a territory with no target', () => {
    expect(TARGETS.some((t) => t.territoryId === null && t.outletId === null)).toBe(true);
    expect(TARGETS.some((t) => t.territoryId !== null)).toBe(true);
    expect(TARGETS.some((t) => t.outletId !== null)).toBe(true);
    const clientSkus = new Set(TARGETS.filter((t) => !t.territoryId && !t.outletId).map((t) => t.skuId));
    for (const skuId of SKUS_WITHOUT_CLIENT_TARGET) expect(clientSkus.has(skuId)).toBe(false);
    expect(clientSkus.size).toBe(SKUS.length - SKUS_WITHOUT_CLIENT_TARGET.length);
    for (const code of TERRITORIES_WITHOUT_TARGETS) {
      expect(TARGETS.some((t) => t.territoryId === TERRITORY_ID_BY_CODE[code])).toBe(false);
    }
  });

  it('sets targets for the current month too, and none for the first month of history', () => {
    const months = new Set(TARGETS.map((t) => t.month.getTime()));
    expect(months.has(H.world.anchorMonth.getTime())).toBe(true);
    expect(months.has(H.world.historyStart.getTime())).toBe(false);
  });

  it('is deterministic', () => {
    expect(buildSalesTargets(H.world, H.generator.plan).map((t) => t.targetUnits)).toEqual(
      TARGETS.map((t) => t.targetUnits),
    );
  });
});

import { HistoryGenerator, MonthBatch } from './history';
import { World, buildWorld } from './world';

/**
 * A whole generated history held in memory, for the seed's unit tests.
 *
 * The real seed never does this — it writes and drops one month at a time —
 * but asserting that a planted pattern exists needs every month side by side.
 * Kept out of the `*.test.ts` files so the three suites that need it build it
 * the same way.
 */

export const FIXTURE_ANCHOR = new Date('2026-09-17T00:00:00.000Z');
export const FIXTURE_HOME = { lat: -26.1076, lng: 28.0567, source: 'fallback' as const };
export const FIXTURE_CLOSURE_PHOTO = 'data:image/jpeg;base64,/9j/fixture';

export type FlatHistory = Omit<MonthBatch, 'month'> & { world: World; generator: HistoryGenerator };

export function generateFlatHistory(options: { outletFraction?: number; historyMonths?: number } = {}): FlatHistory {
  const world = buildWorld({
    anchor: FIXTURE_ANCHOR,
    home: FIXTURE_HOME,
    outletFraction: options.outletFraction ?? 1,
    historyMonths: options.historyMonths,
  });
  const generator = new HistoryGenerator(world, { closurePhotoUrl: FIXTURE_CLOSURE_PHOTO });
  const flat: FlatHistory = {
    world, generator,
    visits: [], stock: [], pricing: [], competitive: [], visibility: [], capability: [], scorecards: [],
    checkIns: [], photos: [], orders: [], orderLines: [], tasks: [], alerts: [], templateResponses: [],
    beatPlans: [], beatPlanStops: [],
  };
  for (let batch = generator.nextMonth(); batch !== null; batch = generator.nextMonth()) {
    for (const key of Object.keys(flat) as Array<keyof FlatHistory>) {
      const rows = (batch as unknown as Record<string, unknown>)[key];
      if (!Array.isArray(rows)) continue;
      // A loop, not push(...rows): a month has more stock rows than the
      // engine accepts as call arguments.
      const target = flat[key] as unknown[];
      for (const row of rows) target.push(row);
    }
  }
  return flat;
}

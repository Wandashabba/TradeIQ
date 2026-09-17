import { prisma } from '../src/lib/prisma';
import { refreshEconomicData } from '../src/modules/externalContext/economic.refresh';
import type { EconomicSource } from '../src/modules/externalContext/economic.series';

/**
 * Refreshes Ask TradeIQ's economic context by hand — the same work the API's
 * daily worker (economic.worker.ts) does.
 *
 *   npm run refresh-economic-context
 *   npm run refresh-economic-context -- fuel_prices
 *   npm run refresh-economic-context -- statssa_retail statssa_cpi
 *
 * Run it after editing `data/fuelPriceAdjustments.ts`, or to pick up a Stats SA
 * release before the next daily run. Safe to re-run: every write is an upsert.
 */
const SOURCES: readonly EconomicSource[] = ['statssa_retail', 'statssa_cpi', 'fuel_prices'];

async function main(): Promise<void> {
  const asked = process.argv.slice(2);
  const unknown = asked.filter((s) => !SOURCES.includes(s as EconomicSource));
  if (unknown.length) {
    throw new Error(`Unknown source(s): ${unknown.join(', ')}. Use: ${SOURCES.join(', ')}`);
  }
  const results = await refreshEconomicData({
    sources: asked.length ? (asked as EconomicSource[]) : undefined,
  });
  for (const r of results) {
    console.log(`${r.source}: ${r.ok ? `ok, ${r.written} figure(s), ${r.detail}` : `FAILED — ${r.detail}`}`);
  }
  if (results.some((r) => !r.ok)) process.exitCode = 1;
}

main()
  .catch((err) => {
    console.error(err instanceof Error ? err.message : err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());

import { readFileSync } from 'fs';
import { basename } from 'path';
import { prisma } from '../src/lib/prisma';
import {
  identifyStatsSaFile,
  refreshEconomicData,
  type ManualStatsSaFile,
  type StatsSaSource,
} from '../src/modules/externalContext/economic.refresh';
import type { EconomicSource } from '../src/modules/externalContext/economic.series';

/**
 * Refreshes Ask TradeIQ's economic context by hand — the same work the API's
 * daily worker (economic.worker.ts) does.
 *
 *   npm run refresh-economic-context
 *   npm run refresh-economic-context -- fuel_prices
 *   npm run refresh-economic-context -- statssa_retail statssa_cpi
 *   npm run refresh-economic-context -- --file ~/Downloads/<Stats SA zip> [--file …]
 *
 * Run it after editing `data/fuelPriceAdjustments.ts`, or to pick up a Stats SA
 * release before the next daily run. Safe to re-run: every write is an upsert.
 *
 * `--file` imports a release zip downloaded in a browser from Stats SA's
 * time-series page, for when its bot protection blocks the automatic download.
 * The file name says which series and month it is; only that source is run.
 */
const SOURCES: readonly EconomicSource[] = ['statssa_retail', 'statssa_cpi', 'fuel_prices'];

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const files: Partial<Record<StatsSaSource, ManualStatsSaFile>> = {};
  const asked: string[] = [];
  for (let i = 0; i < args.length; i += 1) {
    if (args[i] !== '--file') {
      asked.push(args[i]);
      continue;
    }
    const file = args[(i += 1)];
    if (!file) throw new Error('--file needs the path of a downloaded Stats SA zip.');
    const identified = identifyStatsSaFile(basename(file));
    if (!identified) {
      throw new Error(
        `Cannot tell which Stats SA release "${basename(file)}" is. Keep the name it downloaded with ` +
          '(it contains P6242.1 or P0141 and the six-digit month).',
      );
    }
    files[identified.source] = { body: readFileSync(file), month: identified.month };
  }

  const unknown = asked.filter((s) => !SOURCES.includes(s as EconomicSource));
  if (unknown.length) {
    throw new Error(`Unknown source(s): ${unknown.join(', ')}. Use: ${SOURCES.join(', ')}`);
  }
  const imported = Object.keys(files) as StatsSaSource[];
  const sources = [...new Set([...(asked as EconomicSource[]), ...imported])];
  const results = await refreshEconomicData({
    sources: sources.length ? sources : undefined,
    files,
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

import { prisma } from '../src/lib/prisma';
import {
  backfillPointsLedger,
  parseResumePoint,
} from '../src/modules/gamification/pointsLedgerBackfill';

/**
 * Writes points-ledger entries (#124) for visits, task closures and scorecards
 * recorded before the ledger existed. New events are written as they happen.
 *
 *   npm run backfill-points-ledger
 *   npm run backfill-points-ledger -- --batch 200
 *   npm run backfill-points-ledger -- --client <clientId>
 *   npm run backfill-points-ledger -- --resume tasks:<lastId>
 *
 *   --batch   source rows read per query (default 500)
 *   --client  one tenant only
 *   --resume  skip ahead to a point a progress line printed (phase:id)
 *
 * Safe to run at any time, as often as you like, and to kill: entries are unique
 * per (sourceType, sourceId, reason) and inserted with skip-on-conflict, so a
 * re-run inserts nothing twice. See src/modules/gamification/pointsLedgerBackfill.ts.
 */
async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const flag = (name: string): string | undefined => {
    const i = args.indexOf(`--${name}`);
    return i >= 0 ? args[i + 1] : undefined;
  };

  const batchRaw = flag('batch');
  let batchSize: number | undefined;
  if (batchRaw !== undefined) {
    batchSize = Number(batchRaw);
    if (!Number.isInteger(batchSize) || batchSize <= 0) {
      throw new Error(`--batch must be a positive integer, got "${batchRaw}"`);
    }
  }
  const resumeRaw = flag('resume');

  const started = Date.now();
  const result = await backfillPointsLedger({
    batchSize,
    clientId: flag('client'),
    resumeFrom: resumeRaw === undefined ? undefined : parseResumePoint(resumeRaw),
    log: (line) => console.log(line),
  });
  const seconds = Math.round((Date.now() - started) / 1000);
  const summary = Object.entries(result)
    .map(([phase, r]) => `${phase} ${r.written} new of ${r.scanned}`)
    .join(', ');
  console.log(`Done in ${seconds}s: ${summary}.`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());

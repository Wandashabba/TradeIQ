import { prisma } from '../src/lib/prisma';
import { RescoreFraudOptions, rescoreFraudScores } from '../src/modules/fraud/fraudRescore';

/**
 * Backfills and rescores `Visit.riskScore`, the stored fraud score that
 * GET /fraud/flagged filters and sorts on (#236).
 *
 *   npm run rescore-fraud                                  # every unscored submitted visit
 *   npm run rescore-fraud -- --client <clientId>           # one tenant's unscored visits
 *   npm run rescore-fraud -- --client <clientId> --all     # after changing its kpiThresholds
 *   npm run rescore-fraud -- --all --since 2026-09-01      # recent visits, after an engine change
 *   npm run rescore-fraud -- --all --scored-before <iso>   # resume a stopped --all run
 *
 *   --client         one tenant only
 *   --since          only visits checked in at or after this date
 *   --all            also rescore visits that already have a score
 *   --scored-before  with --all: the cutoff a stopped run logged when it started
 *   --batch          visits per batch (default 100)
 *
 * Safe to run at any time, as often as you like, and to kill: see
 * src/modules/fraud/fraudRescore.ts. It never overwrites a score taken after the
 * run started (a visit submitted meanwhile keeps its own). It runs outside the
 * migration on purpose: scoring reads each visit's history, and inside
 * `prisma migrate deploy` that would hold the deploy for as long as it takes.
 */
export function parseRescoreArgs(argv: string[]): RescoreFraudOptions {
  const options: RescoreFraudOptions = {};
  let index = 0;
  const valueOf = (flag: string): string => {
    const value = argv[index + 1];
    if (value === undefined || value.startsWith('--')) {
      throw new Error(`${flag} needs a value`);
    }
    index += 1;
    return value;
  };
  const dateOf = (flag: string): Date => {
    const raw = valueOf(flag);
    if (Number.isNaN(Date.parse(raw))) {
      throw new Error(`${flag} must be an ISO-8601 date, got "${raw}"`);
    }
    return new Date(raw);
  };

  for (; index < argv.length; index += 1) {
    const flag = argv[index];
    switch (flag) {
      case '--client':
        options.clientId = valueOf(flag);
        break;
      case '--since':
        options.since = dateOf(flag);
        break;
      case '--all':
        options.all = true;
        break;
      case '--scored-before':
        options.scoredBefore = dateOf(flag);
        break;
      case '--batch': {
        const raw = valueOf(flag);
        if (!/^[1-9]\d*$/.test(raw)) {
          throw new Error(`--batch must be a positive integer, got "${raw}"`);
        }
        options.batchSize = Number(raw);
        break;
      }
      default:
        // A typo such as --clinet must not silently widen the run to every tenant.
        throw new Error(
          `Unknown option "${flag}". Options: --client <id>, --since <date>, --all, ` +
            '--scored-before <date>, --batch <n>',
        );
    }
  }

  if (options.scoredBefore && !options.all) {
    throw new Error('--scored-before only applies with --all; without it, scored visits are already skipped');
  }
  return options;
}

async function main(): Promise<void> {
  const options = parseRescoreArgs(process.argv.slice(2));
  const started = Date.now();
  const result = await rescoreFraudScores({ ...options, log: (line) => console.log(line) });
  const seconds = Math.round((Date.now() - started) / 1000);
  console.log(
    `Done in ${seconds}s: ${result.written} scored, ${result.kept} kept a newer score, ` +
      `${result.scanned} examined.`,
  );
}

if (require.main === module) {
  main()
    .catch((err) => {
      console.error(err);
      process.exitCode = 1;
    })
    .finally(() => prisma.$disconnect());
}

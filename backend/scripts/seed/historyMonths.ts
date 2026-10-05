import { HISTORY_MONTHS } from './calendar';

/**
 * How many months of history this run should build.
 *
 * ## Why this is tunable at all
 *
 * The `full` profile means 24 months, because that is what makes "same period
 * last year" answerable for every month-to-date and trailing-twelve-month
 * question the dashboard asks. On a developer's machine that is the right
 * default and it stays the default here.
 *
 * It does not fit everywhere. The hosted demo runs on a Supabase Free project,
 * which caps the database at 500 MB, and 24 months measures **1013 MB** — the
 * weight is visit history and everything hanging off it (`visit_stock` 200 MB,
 * `points_ledger_entries` 172 MB, `visits` 108 MB, `visit_pricing` 100 MB,
 * `order_lines` 100 MB). Seeding it there fills the project and the seed fails
 * partway, which is worse than not seeding: a half-built world reads as a
 * broken app rather than an empty one.
 *
 * The existing `test` profile is not the answer. It cuts history to 3 months
 * AND outlets to a sixth, because it exists to finish inside a jest timeout.
 * A demo wants every outlet and every territory — the floor is meant to look
 * populated — and only less history behind them. So the knob is history alone,
 * and it composes with whichever profile is running rather than replacing it.
 *
 * ## Why it validates rather than clamps
 *
 * A typo here is silent for six minutes and then produces the wrong world. A
 * value that is not a positive integer is a mistake, not a preference, so it
 * throws before anything is deleted — the same order `resolveSeedPassword`
 * follows, and for the same reason: a production seed that is going to fail
 * must fail while the existing data is still intact.
 */
export function resolveHistoryMonths(
  profileDefault: number,
  env: NodeJS.ProcessEnv = process.env,
): number {
  const raw = env.SEED_HISTORY_MONTHS?.trim();
  if (!raw) return profileDefault;

  // Number() rather than parseInt: parseInt('6months') is 6, and a value that
  // nearly parses is exactly the typo this is meant to catch.
  const months = Number(raw);
  if (!Number.isInteger(months) || months < 1) {
    throw new Error(
      `SEED_HISTORY_MONTHS is "${raw}", which is not a whole number of months. ` +
        'Set it to a positive integer, or leave it unset for the profile default ' +
        `of ${profileDefault}.`,
    );
  }

  if (months > HISTORY_MONTHS) {
    throw new Error(
      `SEED_HISTORY_MONTHS is ${months}, beyond the ${HISTORY_MONTHS} months the ` +
        'seed plans a calendar for. Nothing would exist in the extra months, so ' +
        'this is a mistake rather than a bigger world.',
    );
  }

  return months;
}

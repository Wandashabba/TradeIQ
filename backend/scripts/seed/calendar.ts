/**
 * Every timestamp in the demo seed derives from one anchor: the UTC start of
 * the day the seed was run.
 *
 * This deliberately replaces the old seed's rule ("no `Date.now()`/`new Date()`
 * with no args that would drift between runs"). That rule bought idempotency;
 * we trade it for a demo that does not rot — "today" always has stops and SLAs
 * are always believably due. The reproducibility it protected now comes from
 * the fixed-seed PRNG in `rng.ts` instead.
 */

const DAY_MS = 24 * 60 * 60 * 1000;

/** Weeks of history generated behind the anchor, inclusive of the anchor week. */
export const HISTORY_WEEKS = 12;

export function startOfUtcDay(date: Date): Date {
  return new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
}

/**
 * Monday 00:00 UTC of the week containing `date`. Must agree with
 * `bucketStart(date, 'week')` in the trends service — asserted in the tests.
 */
export function mondayOfWeek(date: Date): Date {
  const dayStart = startOfUtcDay(date);
  // getUTCDay: 0=Sun..6=Sat. Days since Monday: Mon->0 .. Sun->6.
  const daysSinceMonday = (dayStart.getUTCDay() + 6) % 7;
  return new Date(dayStart.getTime() - daysSinceMonday * DAY_MS);
}

/** `weeks` Monday starts ending with the anchor's own week, oldest first. */
export function weekStarts(anchor: Date, weeks: number): Date[] {
  const latest = mondayOfWeek(anchor);
  const result: Date[] = [];
  for (let i = weeks - 1; i >= 0; i -= 1) {
    result.push(new Date(latest.getTime() - i * 7 * DAY_MS));
  }
  return result;
}

export function addDays(date: Date, days: number): Date {
  return new Date(date.getTime() + days * DAY_MS);
}

export function addHours(date: Date, hours: number): Date {
  return new Date(date.getTime() + hours * 60 * 60 * 1000);
}

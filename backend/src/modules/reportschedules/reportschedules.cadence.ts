/**
 * When a report schedule next fires (#66). Pure functions of a cadence and a
 * few instants, so every rule here is unit-testable without a clock or a DB.
 *
 * The rules:
 *
 * - **Fixed periods.** Daily is every 24 hours and weekly every 7 days, counted
 *   from the previous DUE time — not from when a run happened to finish — so
 *   the time of day a schedule fires does not creep later with every slow run.
 * - **UTC.** A "day" is 24 hours of UTC, so a schedule keeps its UTC time of
 *   day. There is no local calendar or DST handling until per-client
 *   timezones land (#309); until then "daily at 09:00" means 09:00 UTC.
 * - **Created or resumed:** the first run is one period from now.
 * - **Paused:** no next run (`nextRunAt` is null) and nothing fires.
 * - **Missed runs catch up once.** If the server was down across several due
 *   times, the schedule fires ONCE when a worker next polls, and the next run
 *   after that is the first due time on the original grid still in the future.
 *   A week of downtime therefore sends one daily report, not seven.
 * - **Run now** does not move `nextRunAt`: a manual run is extra, not a
 *   replacement for the scheduled one.
 */

export const DAY_MS = 24 * 60 * 60 * 1000;

const PERIOD_MS: Record<string, number> = {
  daily: DAY_MS,
  weekly: 7 * DAY_MS,
};

/** A cadence's period. Unknown cadences (the column is free text) are daily. */
export function cadencePeriodMs(cadence: string): number {
  return PERIOD_MS[cadence] ?? DAY_MS;
}

/** The first due time of a schedule created, or resumed, at `now`. */
export function firstRunAt(cadence: string, now: Date): Date {
  return new Date(now.getTime() + cadencePeriodMs(cadence));
}

/**
 * The due time that follows `dueAt`, skipping every slot at or before `now`.
 *
 * This is what makes a catch-up fire once: after firing for a due time that is
 * days old, the next run is the first slot on the same grid strictly after
 * `now`, never another stale slot that would fire again on the very next poll.
 */
export function nextRunAfter(cadence: string, dueAt: Date, now: Date): Date {
  const period = cadencePeriodMs(cadence);
  const next = dueAt.getTime() + period;
  if (next > now.getTime()) return new Date(next);
  const missed = Math.floor((now.getTime() - next) / period) + 1;
  return new Date(next + missed * period);
}

/**
 * The next due time after an active schedule's cadence changes.
 *
 * The previous due time (the one `nextRunAt` replaced) keeps its place and the
 * new period is counted from it, so a weekly schedule that last fired on Monday
 * at 09:00 and becomes daily fires at the next 09:00 still to come. With no
 * current `nextRunAt` to work from, it is one new period from now.
 */
export function rescheduleForCadence(
  oldCadence: string,
  newCadence: string,
  nextRunAt: Date | null,
  now: Date,
): Date {
  if (!nextRunAt) return firstRunAt(newCadence, now);
  const lastDue = new Date(nextRunAt.getTime() - cadencePeriodMs(oldCadence));
  return nextRunAfter(newCadence, lastDue, now);
}

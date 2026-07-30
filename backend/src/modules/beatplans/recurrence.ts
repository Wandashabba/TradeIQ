import { ValidationError } from '../../middleware/errorHandler';

/**
 * How a beat plan repeats.
 *
 * Deliberately a small closed set rather than an RFC-5545 `rrule` string. An
 * rrule parser brings a dependency and a surface area (BYSETPOS, EXDATE,
 * timezone-aware UNTIL) that a journey plan does not need, and every one of
 * those features would be a way to generate occurrences nobody can explain.
 */
export type Frequency = 'daily' | 'weekly';

export interface Recurrence {
  frequency: Frequency;
  /** Every N days, or every N weeks. */
  interval: number;
  /**
   * Weekly only: which days to land on, 0 = Sunday through 6 = Saturday, in the
   * UTC calendar. Empty/absent means "the same weekday as the start date".
   */
  daysOfWeek?: number[];
  /** Inclusive last date an occurrence may fall on. */
  until: Date;
}

/**
 * The most occurrences one series may materialise.
 *
 * Occurrences are real rows, because `BeatPlanStop.visited` is per-occurrence
 * state — there is nowhere to record "today's third stop was visited" against a
 * rule computed on read. Real rows mean a bound is not optional: a daily plan
 * with `until` set five years out would otherwise write ~1800 plans and ~18000
 * stops from one request.
 */
export const MAX_OCCURRENCES = 120;

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/** Midnight UTC on the same calendar day as `d`. */
function startOfUtcDay(d: Date): Date {
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
}

/**
 * Every date a series lands on, ascending, starting at `start`.
 *
 * Dates are computed in **UTC whole days**, deliberately. A beat plan is a
 * calendar commitment ("Tuesdays"), not an instant, and stepping by
 * milliseconds across a DST boundary in a local zone silently shifts a plan a
 * day either way. `scheduledDate` is stored as the UTC midnight of the intended
 * day for the same reason.
 *
 * Throws rather than returning a truncated list when the rule would exceed
 * [MAX_OCCURRENCES]: silently generating 120 of an intended 400 would leave a
 * manager believing a year was scheduled when three months were.
 */
export function expandOccurrences(start: Date, rule: Recurrence): Date[] {
  const first = startOfUtcDay(start);
  const last = startOfUtcDay(rule.until);

  if (last < first) {
    throw new ValidationError('recurrence.until must be on or after scheduledDate');
  }
  if (!Number.isInteger(rule.interval) || rule.interval < 1) {
    throw new ValidationError('recurrence.interval must be a positive integer');
  }

  const dates: Date[] = [];

  if (rule.frequency === 'daily') {
    for (let d = first; d <= last; d = new Date(d.getTime() + rule.interval * MS_PER_DAY)) {
      dates.push(d);
      if (dates.length > MAX_OCCURRENCES) break;
    }
  } else {
    // Weekly. An empty daysOfWeek means "the weekday the series starts on",
    // which is what a manager picking a date and saying "weekly" means.
    const days = rule.daysOfWeek?.length ? [...new Set(rule.daysOfWeek)].sort() : [first.getUTCDay()];
    for (const day of days) {
      if (!Number.isInteger(day) || day < 0 || day > 6) {
        throw new ValidationError('recurrence.daysOfWeek must contain integers 0-6');
      }
    }

    // Anchor to the Sunday of the start week, then step whole weeks. Stepping
    // per-day and filtering would visit ~7x more candidates for the same answer.
    const weekStart = new Date(first.getTime() - first.getUTCDay() * MS_PER_DAY);
    for (
      let w = weekStart;
      w <= last;
      w = new Date(w.getTime() + rule.interval * 7 * MS_PER_DAY)
    ) {
      for (const day of days) {
        const d = new Date(w.getTime() + day * MS_PER_DAY);
        // The first week can contain days before the start date — a Tuesday
        // series created on a Wednesday must not back-date Tuesday.
        if (d < first || d > last) continue;
        dates.push(d);
      }
      if (dates.length > MAX_OCCURRENCES) break;
    }
    dates.sort((a, b) => a.getTime() - b.getTime());
  }

  if (dates.length > MAX_OCCURRENCES) {
    throw new ValidationError(
      `This recurrence would create more than ${MAX_OCCURRENCES} plans. ` +
        'Shorten the window with recurrence.until, or widen the interval.',
    );
  }
  if (dates.length === 0) {
    throw new ValidationError('This recurrence produces no dates');
  }

  return dates;
}

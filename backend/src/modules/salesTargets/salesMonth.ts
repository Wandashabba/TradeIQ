import { addCalendarDays, localCalendarDate, startOfLocalDay } from '../../lib/clientTime';

/**
 * A target month as local calendar days in the client's timezone (#119).
 *
 * `SalesTarget.month` is a **calendar date** — the first of the month at UTC
 * midnight, the convention `clientTime.ts` describes — never an instant. Which
 * orders belong to it is decided the way `campaigns/campaignWindow.ts` decides a
 * campaign's days: every local calendar day of the month, inclusive, as the
 * half-open instant range `[from, to)` from the instant the 1st begins locally
 * to the instant the 1st of the next month begins locally.
 *
 * So for a Johannesburg client (UTC+2) September 2026 runs from
 * 2026-08-31T22:00Z to 2026-09-30T22:00Z, and an order at 2026-09-30T23:30Z —
 * the last UTC day of the month — is 1 October locally and counts toward
 * October.
 */
export interface MonthWindow {
  /** The month as `YYYY-MM`, the wire format. */
  key: string;
  /** First day of the month as a calendar date (UTC midnight). */
  month: Date;
  /** Inclusive lower bound: the instant the 1st begins in the client's zone. */
  from: Date;
  /** Exclusive upper bound: the instant the next month's 1st begins. */
  to: Date;
}

const MONTH_KEY = /^(\d{4})-(0[1-9]|1[0-2])(?:-01)?$/;

/**
 * Parses `YYYY-MM` (or `YYYY-MM-01`, which a spreadsheet tends to produce) into
 * the month's first day as a calendar date. Anything else — another day of the
 * month, a full timestamp, `2026-13` — is `undefined`: a target for "the month
 * of 15 September" invites the question of which zone that 15th was in.
 */
export function parseMonth(value: unknown): Date | undefined {
  if (typeof value !== 'string') return undefined;
  const match = MONTH_KEY.exec(value.trim());
  if (!match) return undefined;
  const year = Number(match[1]);
  if (year < 2000 || year > 2100) return undefined;
  return new Date(Date.UTC(year, Number(match[2]) - 1, 1));
}

/** `YYYY-MM` for a calendar date. */
export function monthKey(month: Date): string {
  return `${month.getUTCFullYear()}-${String(month.getUTCMonth() + 1).padStart(2, '0')}`;
}

/** The first day of the month after `month`. Calendar dates only. */
export function nextMonth(month: Date): Date {
  return new Date(Date.UTC(month.getUTCFullYear(), month.getUTCMonth() + 1, 1));
}

/** The whole month of local days in `timeZone`. */
export function monthWindow(month: Date, timeZone: string): MonthWindow {
  const first = new Date(Date.UTC(month.getUTCFullYear(), month.getUTCMonth(), 1));
  return {
    key: monthKey(first),
    month: first,
    from: startOfLocalDay(first, timeZone),
    to: startOfLocalDay(nextMonth(first), timeZone),
  };
}

/**
 * How many months a single window is allowed to span before it is refused.
 *
 * Ten years. A reporting period longer than that is a typo or a probe, not a
 * question, and the loop below needs a stop that does not depend on the caller
 * having passed a sane `to`.
 */
const MAX_WHOLE_MONTHS = 120;

/**
 * The whole calendar months `[from, to)` covers **exactly**, or `null` when it
 * covers none (#337).
 *
 * A target is set per month, so a figure may only be measured against one when
 * the window is one or more complete months of the client's own calendar. This
 * is the test for that, and it is deliberately all-or-nothing: `from` must be
 * the instant the 1st begins locally, and `to` must be the instant some later
 * 1st begins. Month-to-date, last week and a custom range ending mid-month all
 * return `null`, and their callers report units with no target rather than
 * prorating one — a prorated target is a number nobody set, and it would be
 * quoted in a meeting as though somebody had.
 *
 * Boundaries are compared as instants because that is what the caller resolved
 * them to; a Johannesburg September is `[31 Aug 22:00Z, 30 Sep 22:00Z)` and
 * nothing an hour either side of those is September.
 */
export function wholeMonthsIn(from: Date, to: Date, timeZone: string): Date[] | null {
  if (!(to > from)) return null;

  const first = localMonthOf(from, timeZone);
  if (startOfLocalDay(first, timeZone).getTime() !== from.getTime()) return null;

  const months: Date[] = [];
  let month = first;
  while (months.length < MAX_WHOLE_MONTHS) {
    months.push(month);
    const boundary = startOfLocalDay(nextMonth(month), timeZone);
    if (boundary.getTime() === to.getTime()) return months;
    if (boundary.getTime() > to.getTime()) return null;
    month = nextMonth(month);
  }
  return null;
}

/** The month the local calendar date of `instant` falls in. */
export function localMonthOf(instant: Date, timeZone: string): Date {
  const day = localCalendarDate(instant, timeZone);
  return new Date(Date.UTC(day.getUTCFullYear(), day.getUTCMonth(), 1));
}

/**
 * The last `days` complete local days before the local day `now` falls on, as
 * calendar dates oldest first, plus the instant range they cover. Today is left
 * out because it is still filling up: a half-day of orders read as a whole day
 * would drag every forecast down each morning.
 */
export function trailingLocalDays(
  now: Date,
  days: number,
  timeZone: string,
): { dates: Date[]; from: Date; to: Date } {
  const today = localCalendarDate(now, timeZone);
  const first = addCalendarDays(today, -days);
  const dates = Array.from({ length: days }, (_, i) => addCalendarDays(first, i));
  return { dates, from: startOfLocalDay(first, timeZone), to: startOfLocalDay(today, timeZone) };
}

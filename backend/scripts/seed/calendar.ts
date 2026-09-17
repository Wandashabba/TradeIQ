import {
  DEFAULT_CLIENT_TIME_ZONE,
  addCalendarDays,
  isoWeekdayOfCalendarDate,
  localCalendarDate,
  startOfLocalDay,
} from '../../src/lib/clientTime';

/**
 * Every timestamp in the demo seed derives from one anchor: the client's local
 * calendar date on the day the seed was run (or `SEED_ANCHOR_DATE`).
 *
 * This deliberately replaces the old seed's rule ("no `Date.now()`/`new Date()`
 * with no args that would drift between runs"). That rule bought idempotency;
 * we trade it for a demo that does not rot — "today" always has stops and SLAs
 * are always believably due. The reproducibility it protected now comes from
 * the fixed-seed PRNG in `rng.ts`, plus `SEED_ANCHOR_DATE` for anyone who needs
 * a byte-identical dataset on a different day (the Ask TradeIQ test questions
 * quote figures from a pinned anchor).
 *
 * Two representations, never mixed — the `clientTime.ts` convention:
 * - a *calendar date* is a `Date` at UTC midnight of that date;
 * - an *instant* is a real moment, produced only by {@link localInstant}, which
 *   goes through `startOfLocalDay` so a Johannesburg 08:00 is 06:00Z.
 */

// Calendar-date arithmetic below is UTC epoch arithmetic: exactly 86,400,000 ms
// per day, which is only ever applied to UTC-midnight calendar dates.
const DAY_MS = 24 * 60 * 60 * 1000;

/** The zone the seed plans in when the client row does not say otherwise. */
export const SEED_TIME_ZONE = DEFAULT_CLIENT_TIME_ZONE;

/**
 * Whole calendar months of history before the anchor's own month. With the
 * partial current month on top, a September anchor covers the September two
 * years earlier — so "same period last year" has a full year behind it for
 * every month-to-date and trailing-twelve-month question.
 */
export const HISTORY_MONTHS = 24;

export function startOfUtcDay(date: Date): Date {
  return new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
}

/**
 * Monday 00:00 UTC of the week containing `date`. Must agree with
 * `bucketStart(date, 'week')` in the trends service — asserted in the tests.
 *
 * This duplicates `bucketStart`'s rule rather than importing it, deliberately:
 * `trends.service.ts` imports `lib/prisma`, which constructs a `PrismaClient`
 * at module load. Importing it here would drag a live database client into a
 * module that must stay pure and testable without one. The parity test gives
 * equivalent protection against drift — do not "fix" this by importing.
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

export function addMinutes(date: Date, minutes: number): Date {
  return new Date(date.getTime() + minutes * 60 * 1000);
}

/**
 * The seed's "today" as a calendar date. `SEED_ANCHOR_DATE=YYYY-MM-DD` pins it,
 * so a dataset — and every figure quoted from it — can be rebuilt exactly on a
 * later day. Otherwise it is the client's own local date right now, never the
 * UTC one: between 22:00Z and midnight Johannesburg is already tomorrow.
 */
export function resolveAnchorDate(
  env: NodeJS.ProcessEnv = process.env,
  now: Date = new Date(),
  timeZone: string = SEED_TIME_ZONE,
): Date {
  const raw = env.SEED_ANCHOR_DATE;
  if (raw === undefined || raw === '') {
    return localCalendarDate(now, timeZone);
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(raw)) {
    throw new Error(`SEED_ANCHOR_DATE must be YYYY-MM-DD, got "${raw}"`);
  }
  const date = new Date(`${raw}T00:00:00.000Z`);
  if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== raw) {
    throw new Error(`SEED_ANCHOR_DATE is not a real calendar date: "${raw}"`);
  }
  return date;
}

/** First of the month containing a calendar date. */
export function monthStart(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), 1));
}

/** A first-of-month calendar date `months` later (negative for earlier). */
export function addMonths(month: Date, months: number): Date {
  return new Date(Date.UTC(month.getUTCFullYear(), month.getUTCMonth() + months, 1));
}

/** Days in the month of a calendar date. */
export function daysInMonth(month: Date): number {
  return new Date(Date.UTC(month.getUTCFullYear(), month.getUTCMonth() + 1, 0)).getUTCDate();
}

/**
 * A calendar date `day` days into `month` (1-based), clamped to the month's
 * last day — so "the 31st" of a 30-day month is the 30th, not the 1st of the
 * next one.
 */
export function dayOfMonth(month: Date, day: number): Date {
  const clamped = Math.max(1, Math.min(day, daysInMonth(month)));
  return new Date(Date.UTC(month.getUTCFullYear(), month.getUTCMonth(), clamped));
}

/** Whole calendar days from `a` to `b` (calendar dates). */
export function calendarDaysBetween(a: Date, b: Date): number {
  return Math.round((b.getTime() - a.getTime()) / DAY_MS);
}

/**
 * South African public holidays that fall on a fixed date. Easter-linked days
 * are left out on purpose: they move, and a demo does not need them to read as
 * a real calendar.
 */
const FIXED_PUBLIC_HOLIDAYS = new Set([
  '01-01', // New Year's Day
  '03-21', // Human Rights Day
  '04-27', // Freedom Day
  '05-01', // Workers' Day
  '06-16', // Youth Day
  '08-09', // National Women's Day
  '09-24', // Heritage Day
  '12-16', // Day of Reconciliation
  '12-25', // Christmas Day
  '12-26', // Day of Goodwill
]);

export function isPublicHoliday(date: Date): boolean {
  return FIXED_PUBLIC_HOLIDAYS.has(date.toISOString().slice(5, 10));
}

/** Monday to Friday and not a public holiday: a day the field team works. */
export function isWorkday(date: Date): boolean {
  return isoWeekdayOfCalendarDate(date) <= 5 && !isPublicHoliday(date);
}

/** The workdays in `[from, to)`, as calendar dates, oldest first. */
export function workdaysBetween(from: Date, to: Date): Date[] {
  const days: Date[] = [];
  for (let day = from; day.getTime() < to.getTime(); day = addCalendarDays(day, 1)) {
    if (isWorkday(day)) days.push(day);
  }
  return days;
}

/** The last `count` workdays of a month — where month-end orders pile up. */
export function lastWorkdaysOfMonth(month: Date, count: number): Date[] {
  const days = workdaysBetween(month, addMonths(month, 1));
  return days.slice(-count);
}

/**
 * The instant `minutes` after local midnight of a calendar date, in `timeZone`.
 * Through `startOfLocalDay`, never raw UTC maths, so 08:00 in Johannesburg is
 * 06:00Z and a zone with DST would still land on its own wall clock.
 */
export function localInstant(calendarDate: Date, minutes: number, timeZone: string): Date {
  return new Date(startOfLocalDay(calendarDate, timeZone).getTime() + minutes * 60 * 1000);
}

/** How many (fractional) months before `anchor` a calendar date is. */
export function monthsAgo(date: Date, anchor: Date): number {
  return calendarDaysBetween(date, anchor) / 30.44;
}

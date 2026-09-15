/**
 * Calendar arithmetic in a client's own timezone (#309).
 *
 * Deliberately pure — no Prisma import — so a service can reason about "which
 * day" without a database, and so the seed and its tests can import it too.
 * The lookup of a client's zone lives in `clients.service.ts`.
 *
 * **Two representations, never mixed.**
 *
 * - A *calendar date* is carried as a `Date` at **UTC midnight** of that date.
 *   That is the convention `BeatPlan.scheduledDate` has always been stored in
 *   (the plan form sends `YYYY-MM-DD`), and the one trend `period` keys are
 *   emitted in. It is a label for a day, not the instant the day began; compare
 *   it only with other calendar dates.
 * - An *instant* is a real moment. The instant a local day begins in
 *   Johannesburg is 22:00Z the evening before, and that is what a `gte`/`lt`
 *   filter over `checkinTs` or `createdAt` needs.
 *
 * Day stepping is always done on calendar dates (exactly 86,400,000 ms in UTC),
 * never on instants — stepping an instant by 24h across a DST change lands an
 * hour off a local midnight.
 */

/** Where every client starts: the field teams this product was built for. */
export const DEFAULT_CLIENT_TIME_ZONE = 'Africa/Johannesburg';

const DAY_MS = 24 * 60 * 60 * 1000;

let knownZones: Set<string> | undefined;

/**
 * Whether `value` names a real IANA zone this runtime knows.
 *
 * Validated against `Intl.supportedValuesOf('timeZone')` rather than by trying
 * to construct a formatter: `Intl.DateTimeFormat` also accepts offsets like
 * `+02:00` and case-folds names, and storing either would put a value in the
 * database that no other system reads as a zone. The list holds canonical names
 * only, so an alias (`Asia/Calcutta`) is refused in favour of its canonical
 * form. `UTC` is accepted as well — it is a real IANA zone, and what this
 * backend used implicitly before #309 — but some runtimes omit it from the list.
 */
export function isValidTimeZone(value: unknown): value is string {
  if (typeof value !== 'string') return false;
  if (!knownZones) {
    knownZones = new Set([...Intl.supportedValuesOf('timeZone'), 'UTC']);
  }
  return knownZones.has(value);
}

const formatters = new Map<string, Intl.DateTimeFormat>();

function formatterFor(timeZone: string): Intl.DateTimeFormat {
  let formatter = formatters.get(timeZone);
  if (!formatter) {
    formatter = new Intl.DateTimeFormat('en-US', {
      timeZone,
      hourCycle: 'h23',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
    formatters.set(timeZone, formatter);
  }
  return formatter;
}

interface WallClock {
  year: number;
  month: number; // 1-12
  day: number;
  hour: number;
  minute: number;
  second: number;
}

function wallClock(instant: Date, timeZone: string): WallClock {
  const parts: Record<string, number> = {};
  for (const part of formatterFor(timeZone).formatToParts(instant)) {
    if (part.type !== 'literal') parts[part.type] = Number(part.value);
  }
  return {
    year: parts.year,
    month: parts.month,
    day: parts.day,
    hour: parts.hour,
    minute: parts.minute,
    second: parts.second,
  };
}

/** The calendar date `instant` falls on in `timeZone`, as UTC midnight of that date. */
export function localCalendarDate(instant: Date, timeZone: string): Date {
  const { year, month, day } = wallClock(instant, timeZone);
  return new Date(Date.UTC(year, month - 1, day));
}

/** A calendar date `days` later (negative for earlier). Calendar dates only. */
export function addCalendarDays(date: Date, days: number): Date {
  return new Date(date.getTime() + days * DAY_MS);
}

/** Monday of the week containing a calendar date. Calendar dates only. */
export function mondayOfCalendarWeek(date: Date): Date {
  // getUTCDay: 0=Sun..6=Sat. Days since Monday: Mon->0 .. Sun->6.
  return addCalendarDays(date, -((date.getUTCDay() + 6) % 7));
}

/** How far `timeZone`'s wall clock is ahead of UTC at `instant`, in ms. */
function offsetMs(instant: Date, timeZone: string): number {
  const w = wallClock(instant, timeZone);
  const asUtc = Date.UTC(w.year, w.month - 1, w.day, w.hour, w.minute, w.second);
  return asUtc - Math.floor(instant.getTime() / 1000) * 1000;
}

/**
 * The instant a calendar date begins in `timeZone`.
 *
 * Normally local 00:00. Where a DST change skips midnight itself (a few zones
 * spring forward at 00:00), it is the first instant that belongs to the date —
 * 01:00 local — so a `[start, next start)` range still covers the whole day and
 * nothing else.
 */
export function startOfLocalDay(calendarDate: Date, timeZone: string): Date {
  const guess = calendarDate.getTime();
  const before = offsetMs(new Date(guess), timeZone);
  const candidates = [guess - before];
  const after = offsetMs(new Date(guess - before), timeZone);
  if (after !== before) candidates.push(guess - after);

  const onDate = candidates
    .map((ms) => new Date(ms))
    .filter((instant) => localCalendarDate(instant, timeZone).getTime() === guess)
    .sort((a, b) => a.getTime() - b.getTime());
  return onDate[0] ?? new Date(candidates[0]);
}

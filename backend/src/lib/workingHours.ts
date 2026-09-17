import {
  addCalendarDays,
  isoWeekdayOfCalendarDate,
  localCalendarDate,
  localIsoWeekday,
  localMinuteOfDay,
  startOfLocalDay,
} from './clientTime';

/**
 * The hours a client's field team actually works (#153 T2).
 *
 * Background location tracking is the one capture in this product that runs
 * while nobody is looking at the phone, so it needs an outer boundary that is
 * not "whenever the app feels like it": a working day, between a start and an
 * end, counted in the client's own timezone (`Client.timezone`, #309). Outside
 * that window nothing is collected — not by the app, and not by the server if
 * the app sends it anyway.
 *
 * There is no shift model in this product, and this is deliberately not one.
 * It is a single window per client that every agent shares, because inventing
 * per-agent shifts to gate a tracking feature would be a much larger product
 * decision wearing a privacy control's clothes.
 *
 * Times are `HH:MM` on a 24-hour clock. Days are ISO-8601 weekday numbers,
 * 1 = Monday … 7 = Sunday, which is what `localIsoWeekday` returns.
 */

/** Where every client starts: a Monday-to-Friday 07:00–17:00 field day. */
export const DEFAULT_WORK_HOURS_START = '07:00';
export const DEFAULT_WORK_HOURS_END = '17:00';
export const DEFAULT_WORK_DAYS: readonly number[] = [1, 2, 3, 4, 5];

export interface WorkingHours {
  /** `HH:MM`, inclusive. */
  start: string;
  /** `HH:MM`, exclusive — see {@link isWithinWorkingHours}. */
  end: string;
  /** ISO weekdays, 1 = Monday … 7 = Sunday. Sorted and unique. */
  days: number[];
}

export const DEFAULT_WORKING_HOURS: WorkingHours = {
  start: DEFAULT_WORK_HOURS_START,
  end: DEFAULT_WORK_HOURS_END,
  days: [...DEFAULT_WORK_DAYS],
};

const MINUTES_PER_DAY = 24 * 60;
const HH_MM = /^([01]\d|2[0-3]):([0-5]\d)$/;

/**
 * `HH:MM` as minutes since local midnight, or undefined if it is not a
 * 24-hour time. Strict on purpose: `7:00`, `07:00:00` and `7am` are all
 * refused rather than guessed at, because this value ends up deciding whether
 * an agent is tracked.
 */
export function parseTimeOfDay(value: unknown): number | undefined {
  if (typeof value !== 'string') return undefined;
  const match = HH_MM.exec(value);
  if (!match) return undefined;
  return Number(match[1]) * 60 + Number(match[2]);
}

/** Minutes since midnight as `HH:MM`. */
export function formatTimeOfDay(minutes: number): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(Math.floor(minutes / 60))}:${pad(minutes % 60)}`;
}

export type WorkingHoursParse = { ok: true; value: WorkingHours } | { ok: false; error: string };

/**
 * Validates a partial edit of a client's working hours against what is
 * currently stored, and returns the whole window as it would be saved.
 *
 * Partial because `PATCH /clients/me` may send only `workHoursEnd`, and the
 * start-before-end rule has to be checked against the value that would
 * actually be in the row afterwards — not against the one field that changed.
 *
 * Refused:
 * - a time that is not `HH:MM`;
 * - a start at or after the end. An overnight window (22:00–06:00) would span
 *   two calendar days, and "which working day is this?" then has no answer
 *   that the retention summaries, which are per local day, could agree with.
 *   A client that genuinely works nights needs a real shift model, not this;
 * - an empty day list — that is "never", and switching background tracking off
 *   is what the consent notice is for, so an empty list here would be a second,
 *   silent kill switch that no agent can see;
 * - a day outside 1–7, or a repeat.
 */
export function validateWorkingHours(
  input: { start?: unknown; end?: unknown; days?: unknown },
  current: WorkingHours = DEFAULT_WORKING_HOURS,
): WorkingHoursParse {
  let startMinutes = parseTimeOfDay(current.start) ?? 0;
  let endMinutes = parseTimeOfDay(current.end) ?? MINUTES_PER_DAY - 1;
  let days = [...current.days];

  if (input.start !== undefined) {
    const parsed = parseTimeOfDay(input.start);
    if (parsed === undefined) {
      return { ok: false, error: 'workHoursStart must be a 24-hour time like 07:00' };
    }
    startMinutes = parsed;
  }
  if (input.end !== undefined) {
    const parsed = parseTimeOfDay(input.end);
    if (parsed === undefined) {
      return { ok: false, error: 'workHoursEnd must be a 24-hour time like 17:00' };
    }
    endMinutes = parsed;
  }
  if (startMinutes >= endMinutes) {
    return { ok: false, error: 'workHoursStart must be before workHoursEnd on the same day' };
  }

  if (input.days !== undefined) {
    if (!Array.isArray(input.days) || input.days.length === 0) {
      return { ok: false, error: 'workDays must be a non-empty array of weekday numbers, 1 (Monday) to 7 (Sunday)' };
    }
    const seen = new Set<number>();
    for (const day of input.days) {
      if (!Number.isInteger(day) || (day as number) < 1 || (day as number) > 7) {
        return { ok: false, error: 'workDays entries must be whole numbers from 1 (Monday) to 7 (Sunday)' };
      }
      if (seen.has(day as number)) {
        return { ok: false, error: `workDays lists day ${day} twice` };
      }
      seen.add(day as number);
    }
    days = [...seen].sort((a, b) => a - b);
  }

  return {
    ok: true,
    value: { start: formatTimeOfDay(startMinutes), end: formatTimeOfDay(endMinutes), days },
  };
}

/**
 * Reads a window off whatever a `Client` row holds, falling back to the
 * default for anything missing or malformed.
 *
 * Never throws. A client row that somehow holds nonsense must not become the
 * reason an ingest request 500s — it becomes the reason tracking falls back to
 * the conservative Mon–Fri 07:00–17:00 default.
 */
export function workingHoursOf(client: {
  workHoursStart?: string | null;
  workHoursEnd?: string | null;
  workDays?: number[] | null;
} | null): WorkingHours {
  const parsed = validateWorkingHours(
    {
      start: client?.workHoursStart ?? undefined,
      end: client?.workHoursEnd ?? undefined,
      days: client?.workDays === undefined || client?.workDays === null ? undefined : client.workDays,
    },
    DEFAULT_WORKING_HOURS,
  );
  return parsed.ok ? parsed.value : DEFAULT_WORKING_HOURS;
}

/**
 * The instant local `minutes`-past-midnight falls on for a calendar date.
 *
 * Built from the start of the local day rather than by adding an offset to
 * UTC, so it is right in any zone. The one correction pass covers a DST change
 * that lands between local midnight and the target time (the clock moves, so
 * midnight + 7h is no longer 07:00): the drift is measured in the zone and
 * added back. Where the target time does not exist at all — a spring-forward
 * that skips it — this settles on the first instant after the gap, which is
 * the first moment of the day that is inside the window.
 *
 * Africa/Johannesburg, where every current field team works, has no DST at
 * all; this exists so a client in a zone that does still gets a real 07:00.
 */
function instantAtLocalTime(calendarDate: Date, minutes: number, timeZone: string): Date {
  const dayStart = startOfLocalDay(calendarDate, timeZone);
  const guess = new Date(dayStart.getTime() + minutes * 60_000);
  const drift = minutes - localMinuteOfDay(guess, timeZone);
  if (drift === 0) return guess;
  // A real DST shift is an hour or two. Anything larger means the target time
  // is inside a skipped hour, and the guess already sits just past it.
  if (Math.abs(drift) > 180) return guess;
  const corrected = new Date(guess.getTime() + drift * 60_000);
  return localMinuteOfDay(corrected, timeZone) === minutes ? corrected : guess;
}

/**
 * Whether `instant` falls inside the client's working window, read on the
 * client's own wall clock.
 *
 * The window is **half-open, `[start, end)`** — a ping stamped exactly at
 * 17:00 is outside it. Every other range in this codebase (`startOfLocalDay`
 * to the next, the retention cutoff) is half-open for the same reason: two
 * adjacent windows must not both claim the same instant.
 */
export function isWithinWorkingHours(instant: Date, timeZone: string, hours: WorkingHours): boolean {
  if (!hours.days.includes(localIsoWeekday(instant, timeZone))) return false;
  const minute = localMinuteOfDay(instant, timeZone);
  const start = parseTimeOfDay(hours.start);
  const end = parseTimeOfDay(hours.end);
  if (start === undefined || end === undefined) return false;
  return minute >= start && minute < end;
}

export interface WorkingWindow {
  /** Whether the window is open at the instant this was computed. */
  open: boolean;
  /** When the current window closes. Null when it is not open. */
  closesAt: Date | null;
  /** When the next window opens. Null when one is already open. */
  opensAt: Date | null;
}

/**
 * The window around `instant`, as instants.
 *
 * The app needs to start and stop a foreground service on the edges of the
 * working day in a timezone that is not necessarily the phone's. Rather than
 * ship timezone rules to the device — where they would go stale, and where a
 * wrong device clock would move the boundary — the server resolves the edges
 * here and hands the app two instants to compare `now` against. The server
 * still checks every ping on arrival, so a phone with a bad clock or a stale
 * window cannot slip one through.
 *
 * Looks at most 8 days ahead, which always finds the next working day given a
 * non-empty day list, and returns null rather than looping if it somehow does
 * not.
 */
export function workingWindowAt(instant: Date, timeZone: string, hours: WorkingHours): WorkingWindow {
  const start = parseTimeOfDay(hours.start);
  const end = parseTimeOfDay(hours.end);
  if (start === undefined || end === undefined || hours.days.length === 0) {
    return { open: false, closesAt: null, opensAt: null };
  }

  const today = localCalendarDate(instant, timeZone);
  if (isWithinWorkingHours(instant, timeZone, hours)) {
    return { open: true, closesAt: instantAtLocalTime(today, end, timeZone), opensAt: null };
  }

  for (let ahead = 0; ahead <= 8; ahead += 1) {
    const date = addCalendarDays(today, ahead);
    // `date` is a CALENDAR DATE, so its weekday is read directly rather than
    // through the zone: UTC midnight of a Saturday is still Friday evening in
    // New York, and resolving it in the zone would name the day before and put
    // the window on the wrong day for every zone behind UTC.
    if (!hours.days.includes(isoWeekdayOfCalendarDate(date))) continue;
    const opensAt = instantAtLocalTime(date, start, timeZone);
    if (opensAt.getTime() > instant.getTime()) {
      return { open: false, closesAt: null, opensAt };
    }
  }
  return { open: false, closesAt: null, opensAt: null };
}

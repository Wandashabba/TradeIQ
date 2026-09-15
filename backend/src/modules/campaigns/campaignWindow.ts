import type { Prisma } from '@prisma/client';
import { addCalendarDays, localCalendarDate, startOfLocalDay } from '../../lib/clientTime';

/**
 * A campaign's window as whole calendar days in the client's timezone (#324).
 *
 * `Campaign.startDate` / `endDate` are **calendar dates**, not instants. The
 * campaign form sends `YYYY-MM-DD`, which is stored as UTC midnight of that
 * date — the same convention as `BeatPlan.scheduledDate` (see `clientTime.ts`).
 * Comparing a visit's `checkinTs` against those values as instants dropped the
 * whole final day (an `endDate` of 30 Sep was 30 Sep 00:00Z) and, outside UTC,
 * shifted the first day too.
 *
 * The window is inclusive of both dates, in `Client.timezone`: from the instant
 * `startDate` begins locally to the instant the day AFTER `endDate` begins
 * locally, half-open — `[from, to)`. Filters use `gte from` and `lt to`.
 *
 * **Stored values carrying a time component** (older rows, API callers that
 * sent a full ISO instant) are normalised by taking the **UTC calendar date** of
 * the stored value. That is the date a plain `YYYY-MM-DD` would have been
 * stored as, so it is exact for everything the app sends, and it needs no
 * guess about which zone a caller meant — it never consults the client's zone
 * to decide *which* date a stored value names, only *when* that date begins.
 * `2026-07-31T23:59:59Z` is therefore the calendar date 31 Jul.
 */
export interface LocalDayWindow {
  /** First calendar date covered, as UTC midnight of that date. */
  firstDay: Date;
  /** Whole local calendar days covered. 0 for an empty window. */
  days: number;
  /** Inclusive lower bound: the instant `firstDay` begins in the client's zone. */
  from: Date;
  /** Exclusive upper bound: the instant the day after the last day begins. */
  to: Date;
}

const DAY_MS = 24 * 60 * 60 * 1000;

/** The calendar date a stored `startDate` / `endDate` names: its UTC date. */
export function storedCampaignDate(stored: Date): Date {
  return new Date(Date.UTC(stored.getUTCFullYear(), stored.getUTCMonth(), stored.getUTCDate()));
}

function localDays(firstDay: Date, days: number, timeZone: string): LocalDayWindow {
  const from = startOfLocalDay(firstDay, timeZone);
  const to = days > 0 ? startOfLocalDay(addCalendarDays(firstDay, days), timeZone) : from;
  return { firstDay, days, from, to };
}

/**
 * The campaign's inclusive local-day window.
 *
 * An `endDate` before `startDate` (the API does not refuse one) is an empty
 * window rather than a negative one, so it matches nothing and its baseline is
 * empty too.
 */
export function campaignWindow(startDate: Date, endDate: Date, timeZone: string): LocalDayWindow {
  const firstDay = storedCampaignDate(startDate);
  const lastDay = storedCampaignDate(endDate);
  const days = Math.max(0, (lastDay.getTime() - firstDay.getTime()) / DAY_MS + 1);
  return localDays(firstDay, days, timeZone);
}

/**
 * The window immediately before the campaign, of the same number of local days.
 *
 * Equal length matters: comparing a 30-day campaign against a 7-day baseline
 * would show a 4x "lift" created entirely by arithmetic. Contiguous matters too
 * — a gap would let a seasonal dip sit unmeasured between the two. Length is
 * counted in local calendar days, not milliseconds, so a window that crosses a
 * DST change is still the same number of days (and one hour longer or shorter).
 */
export function baselineWindow(campaign: LocalDayWindow, timeZone: string): LocalDayWindow {
  return localDays(addCalendarDays(campaign.firstDay, -campaign.days), campaign.days, timeZone);
}

/**
 * A `where` fragment matching campaigns whose window contains `at` — that is,
 * whose date range includes the local calendar date `at` falls on.
 *
 * Exact under the UTC-date normalisation above, and still a plain indexable
 * comparison: a stored date is on or before local date D exactly when it is
 * earlier than D+1 00:00Z, and on or after D exactly when it is at least
 * D 00:00Z.
 */
export function campaignRunningAt(
  at: Date,
  timeZone: string,
): Pick<Prisma.CampaignWhereInput, 'startDate' | 'endDate'> {
  const day = localCalendarDate(at, timeZone);
  return {
    startDate: { lt: addCalendarDays(day, 1) },
    endDate: { gte: day },
  };
}

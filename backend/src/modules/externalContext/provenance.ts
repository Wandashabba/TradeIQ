/**
 * Outside context — calendar, weather and the economy — is **not tenant data**.
 *
 * Every figure these services return carries where it came from, so the
 * assistant can cite it and the app can list it as a source, and so nobody
 * mistakes a Stats SA percentage for something TradeIQ measured.
 *
 * `retrievedAt` is when WE read it: the moment a table row was verified by a
 * person, or the moment a feed was fetched. `publishedAt` is when the
 * publisher released it, and is `null` when the publisher does not say.
 */
export interface Provenance {
  sourceName: string;
  url: string;
  /** ISO date (`YYYY-MM-DD`) the publisher released it, when known. */
  publishedAt: string | null;
  /** ISO date or instant we retrieved or verified it. */
  retrievedAt: string;
}

/** Said once in every result, so the model reads it next to the numbers. */
export const OUTSIDE_DATA_NOTICE =
  'Outside context from public sources, not TradeIQ data. Label these figures as outside ' +
  'information, cite their source, and never add them into the client\'s own totals.';

/** `YYYY-MM-DD` of a UTC calendar date. */
export function isoDay(date: Date): string {
  return date.toISOString().slice(0, 10);
}

/** A `YYYY-MM-DD` string as UTC midnight. */
export function parseIsoDay(day: string): Date {
  return new Date(`${day}T00:00:00.000Z`);
}

/** Calendar days from `from` to `to`, both inclusive, as `YYYY-MM-DD`. */
export function eachDay(from: string, to: string): string[] {
  const days: string[] = [];
  for (let at = parseIsoDay(from); isoDay(at) <= to; at = new Date(at.getTime() + 86_400_000)) {
    days.push(isoDay(at));
  }
  return days;
}

/** The same calendar day a year earlier. 29 February becomes 28 February. */
export function sameDayLastYear(day: string): string {
  const year = Number(day.slice(0, 4)) - 1;
  const monthDay = day.slice(5) === '02-29' ? '02-28' : day.slice(5);
  return `${year}-${monthDay}`;
}

/** `YYYY-MM` months touched by an inclusive day range. */
export function monthsBetween(from: string, to: string): string[] {
  const months: string[] = [];
  let year = Number(from.slice(0, 4));
  let month = Number(from.slice(5, 7));
  const end = to.slice(0, 7);
  for (;;) {
    const key = `${year}-${String(month).padStart(2, '0')}`;
    if (key > end) break;
    months.push(key);
    month += 1;
    if (month > 12) {
      month = 1;
      year += 1;
    }
  }
  return months;
}

/** Last day of a `YYYY-MM` month, as a day-of-month number. */
export function daysInMonth(month: string): number {
  const year = Number(month.slice(0, 4));
  const index = Number(month.slice(5, 7));
  return new Date(Date.UTC(year, index, 0)).getUTCDate();
}

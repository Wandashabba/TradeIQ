import { DECLARED_HOLIDAYS } from './data/declaredHolidays';
import { isoDay } from './provenance';

/**
 * South African public holidays, computed per the Public Holidays Act 36 of
 * 1994. Pure: no clock, no network.
 *
 * - Schedule 1 fixes twelve holidays; two of them move with Easter.
 * - Section 2(1): whenever a public holiday falls on a Sunday, the Monday
 *   following is a public holiday.
 * - Section 2A lets the President declare extra days. Those are facts about a
 *   year that no rule produces, so they live in a dated table
 *   (`data/declaredHolidays.ts`) rather than here.
 *
 * The Act gives no second rollover: when Christmas Day falls on a Sunday the
 * Monday is already the Day of Goodwill, and a Tuesday holiday exists only if
 * one is declared (as 27 December 2022 was). This code adds no Tuesday.
 */

export const PUBLIC_HOLIDAYS_ACT_URL = 'https://www.gov.za/documents/public-holidays-act';
export const PUBLIC_HOLIDAYS_SOURCE = 'Public Holidays Act 36 of 1994';

export type HolidayKind = 'statutory' | 'sunday_rollover' | 'declared';

export interface PublicHoliday {
  date: string;
  name: string;
  kind: HolidayKind;
  /** For a rollover, the Sunday it rolled from. */
  observedFor?: string;
}

/** Easter Sunday (Gregorian), by the Meeus/Jones/Butcher algorithm. */
export function easterSunday(year: number): Date {
  const a = year % 19;
  const b = Math.floor(year / 100);
  const c = year % 100;
  const d = Math.floor(b / 4);
  const e = b % 4;
  const f = Math.floor((b + 8) / 25);
  const g = Math.floor((b - f + 1) / 3);
  const h = (19 * a + b - d - g + 15) % 30;
  const i = Math.floor(c / 4);
  const k = c % 4;
  const l = (32 + 2 * e + 2 * i - h - k) % 7;
  const m = Math.floor((a + 11 * h + 22 * l) / 451);
  const month = Math.floor((h + l - 7 * m + 114) / 31);
  const day = ((h + l - 7 * m + 114) % 31) + 1;
  return new Date(Date.UTC(year, month - 1, day));
}

const shift = (date: Date, days: number) => new Date(date.getTime() + days * 86_400_000);

/** Schedule 1 of the Act, before any Sunday rule. */
export function statutoryHolidays(year: number): PublicHoliday[] {
  const easter = easterSunday(year);
  const fixed = (month: number, day: number, name: string): PublicHoliday => ({
    date: isoDay(new Date(Date.UTC(year, month - 1, day))),
    name,
    kind: 'statutory',
  });
  return [
    fixed(1, 1, "New Year's Day"),
    fixed(3, 21, 'Human Rights Day'),
    { date: isoDay(shift(easter, -2)), name: 'Good Friday', kind: 'statutory' },
    { date: isoDay(shift(easter, 1)), name: 'Family Day', kind: 'statutory' },
    fixed(4, 27, 'Freedom Day'),
    fixed(5, 1, "Workers' Day"),
    fixed(6, 16, 'Youth Day'),
    fixed(8, 9, "National Women's Day"),
    fixed(9, 24, 'Heritage Day'),
    fixed(12, 16, 'Day of Reconciliation'),
    fixed(12, 25, 'Christmas Day'),
    fixed(12, 26, 'Day of Goodwill'),
  ];
}

/** Every public holiday in a year: statutory, Sunday rollovers and declared days, by date. */
export function publicHolidays(year: number): PublicHoliday[] {
  const statutory = statutoryHolidays(year);
  const taken = new Set(statutory.map((h) => h.date));
  const all = [...statutory];

  for (const holiday of statutory) {
    const date = new Date(`${holiday.date}T00:00:00.000Z`);
    if (date.getUTCDay() !== 0) continue;
    const monday = isoDay(shift(date, 1));
    // Christmas on a Sunday: the Monday is already Day of Goodwill. See above.
    if (taken.has(monday)) continue;
    taken.add(monday);
    all.push({
      date: monday,
      name: `${holiday.name} (observed)`,
      kind: 'sunday_rollover',
      observedFor: holiday.date,
    });
  }

  for (const declared of DECLARED_HOLIDAYS.entries) {
    if (!declared.date.startsWith(`${year}-`) || taken.has(declared.date)) continue;
    taken.add(declared.date);
    all.push({ date: declared.date, name: declared.name, kind: 'declared' });
  }

  return all.sort((a, b) => a.date.localeCompare(b.date));
}

/** Public holidays between two `YYYY-MM-DD` days, inclusive. */
export function publicHolidaysBetween(from: string, to: string): PublicHoliday[] {
  const out: PublicHoliday[] = [];
  for (let year = Number(from.slice(0, 4)); year <= Number(to.slice(0, 4)); year += 1) {
    out.push(...publicHolidays(year).filter((h) => h.date >= from && h.date <= to));
  }
  return out;
}

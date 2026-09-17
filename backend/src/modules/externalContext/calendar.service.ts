import { DECLARED_HOLIDAYS } from './data/declaredHolidays';
import { SASSA_PAYMENT_DATES } from './data/sassaPaymentDates';
import { SCHOOL_TERMS, type SchoolRegion } from './data/schoolTerms';
import {
  PUBLIC_HOLIDAYS_ACT_URL,
  PUBLIC_HOLIDAYS_SOURCE,
  publicHolidaysBetween,
  type PublicHoliday,
} from './holidays';
import {
  daysInMonth,
  eachDay,
  isoDay,
  monthsBetween,
  OUTSIDE_DATA_NOTICE,
  parseIsoDay,
  sameDayLastYear,
  type Provenance,
} from './provenance';

/**
 * The trading calendar around a period: what about the DATES could explain a
 * change, before anyone blames execution.
 *
 * Pure apart from the static tables it reads — no database, no network — so
 * the same period always gives the same answer, and a test pins it.
 */

export const PROVINCES = [
  'Eastern Cape',
  'Free State',
  'Gauteng',
  'KwaZulu-Natal',
  'Limpopo',
  'Mpumalanga',
  'Northern Cape',
  'North West',
  'Western Cape',
] as const;
export type Province = (typeof PROVINCES)[number];

/**
 * DBE's historical split, for years whose calendar differs by region: the four
 * coastal provinces, and the five inland ones. Most recent years have a single
 * national calendar, in which case this changes nothing.
 */
const COASTAL: ReadonlySet<Province> = new Set(['Eastern Cape', 'KwaZulu-Natal', 'Northern Cape', 'Western Cape']);

export function schoolRegionOf(province: Province | undefined): SchoolRegion | undefined {
  if (!province) return undefined;
  return COASTAL.has(province) ? 'coastal' : 'inland';
}

const WEEKDAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const weekdayOf = (day: string) => WEEKDAYS[parseIsoDay(day).getUTCDay()];

export interface SchoolSpan {
  kind: 'term' | 'school_holiday';
  label: string;
  region: SchoolRegion | 'national';
  from: string;
  to: string;
  daysInPeriod: number;
  sourceUrl: string;
}

export interface CalendarDaysSummary {
  days: number;
  weekendDays: number;
  publicHolidays: number;
  /** Weekdays that are not public holidays. */
  workingWeekdays: number;
  /** Days in a school holiday, or null when the school calendar for a year is not in the table. */
  schoolHolidayDays: number | null;
  paydayWindowDays: number;
}

export interface CalendarContext {
  notice: string;
  period: { from: string; to: string };
  province: Province | null;
  summary: CalendarDaysSummary;
  publicHolidays: Array<PublicHoliday & { weekday: string }>;
  school: {
    spans: SchoolSpan[];
    /** Years the period touches that the school table does not cover. */
    missingYears: number[];
  };
  paydayWindows: Array<{ month: string; from: string; to: string; daysInPeriod: number }>;
  paydayBasis: string;
  sassaGrantPayments: {
    months: Array<{
      month: string;
      olderPersons: string;
      disability: string;
      childAndOtherGrants: string;
      /** `news` when SASSA's own announcement could not be opened and a news report was used. */
      sourceKind: 'official' | 'news';
      note?: string;
    }>;
    /** Months in the period with no published dates in the table. Say so; never guess them. */
    missingMonths: string[];
  };
  sameDaysLastYear: {
    period: { from: string; to: string };
    summary: CalendarDaysSummary;
    publicHolidays: Array<{ date: string; name: string }>;
  };
  sources: Provenance[];
}

/** The payday window: the 25th to the last day of the month. */
export const PAYDAY_WINDOW_START_DAY = 25;

function schoolSpans(from: string, to: string, region: SchoolRegion | undefined) {
  const spans: SchoolSpan[] = [];
  const missingYears: number[] = [];
  const firstYear = Number(from.slice(0, 4));
  const lastYear = Number(to.slice(0, 4));

  // Terms from the year before, so the holiday that runs over New Year is found.
  const terms = SCHOOL_TERMS.entries
    .filter((t) => t.year >= firstYear - 1 && t.year <= lastYear + 1)
    .filter((t) => t.region === 'national' || region === undefined || t.region === region)
    .slice()
    .sort((a, b) => a.start.localeCompare(b.start) || a.region.localeCompare(b.region));

  for (let year = firstYear; year <= lastYear; year += 1) {
    if (!SCHOOL_TERMS.coveredYears.includes(year)) missingYears.push(year);
  }

  const overlap = (a: string, b: string) => {
    const start = a > from ? a : from;
    const end = b < to ? b : to;
    return start > end ? 0 : eachDay(start, end).length;
  };

  for (const term of terms) {
    const days = overlap(term.start, term.end);
    if (days > 0) {
      spans.push({
        kind: 'term',
        label: `Term ${term.term} ${term.year}`,
        region: term.region,
        from: term.start,
        to: term.end,
        daysInPeriod: days,
        sourceUrl: term.sourceUrl,
      });
    }
  }

  // Holidays are the gaps between consecutive terms of the same region.
  for (const reg of new Set(terms.map((t) => t.region))) {
    const ofRegion = terms.filter((t) => t.region === reg);
    // The first term in the table: the summer holiday certainly began by New Year's Day.
    const first = ofRegion[0];
    if (first && first.term === 1) {
      const end = isoDay(new Date(parseIsoDay(first.start).getTime() - 86_400_000));
      const days = overlap(`${first.year}-01-01`, end);
      if (days > 0) {
        spans.push({
          kind: 'school_holiday',
          label: `School holiday before term 1 ${first.year}`,
          region: reg,
          from: `${first.year}-01-01`,
          to: end,
          daysInPeriod: days,
          sourceUrl: first.sourceUrl,
        });
      }
    }
    for (let i = 0; i < ofRegion.length; i += 1) {
      const next = ofRegion[i + 1];
      // The last term in the table: its holiday certainly runs to New Year's
      // Eve, and claiming more than that would be a guess about next year.
      if (!next && ofRegion[i].term !== 4) continue;
      const start = isoDay(new Date(parseIsoDay(ofRegion[i].end).getTime() + 86_400_000));
      const end = next
        ? isoDay(new Date(parseIsoDay(next.start).getTime() - 86_400_000))
        : `${ofRegion[i].year}-12-31`;
      if (start > end) continue;
      const days = overlap(start, end);
      if (days > 0) {
        spans.push({
          kind: 'school_holiday',
          label: `School holiday after term ${ofRegion[i].term} ${ofRegion[i].year}`,
          region: reg,
          from: start,
          to: end,
          daysInPeriod: days,
          sourceUrl: ofRegion[i].sourceUrl,
        });
      }
    }
  }

  spans.sort((a, b) => a.from.localeCompare(b.from));
  return { spans, missingYears };
}

function summarise(from: string, to: string, region: SchoolRegion | undefined): {
  summary: CalendarDaysSummary;
  holidays: PublicHoliday[];
  spans: SchoolSpan[];
  missingYears: number[];
} {
  const days = eachDay(from, to);
  const holidays = publicHolidaysBetween(from, to);
  const holidayDays = new Set(holidays.map((h) => h.date));
  const weekend = days.filter((d) => [0, 6].includes(parseIsoDay(d).getUTCDay()));
  const { spans, missingYears } = schoolSpans(from, to, region);

  const schoolHolidayDays = new Set<string>();
  for (const span of spans.filter((s) => s.kind === 'school_holiday')) {
    for (const d of eachDay(span.from > from ? span.from : from, span.to < to ? span.to : to)) {
      schoolHolidayDays.add(d);
    }
  }

  return {
    summary: {
      days: days.length,
      weekendDays: weekend.length,
      publicHolidays: holidays.length,
      workingWeekdays: days.filter(
        (d) => ![0, 6].includes(parseIsoDay(d).getUTCDay()) && !holidayDays.has(d),
      ).length,
      schoolHolidayDays: missingYears.length ? null : schoolHolidayDays.size,
      paydayWindowDays: days.filter((d) => Number(d.slice(8, 10)) >= PAYDAY_WINDOW_START_DAY).length,
    },
    holidays,
    spans,
    missingYears,
  };
}

export class CalendarContextError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'CalendarContextError';
  }
}

/** Two years of days is already more calendar than one answer can use. */
export const MAX_CALENDAR_DAYS = 731;

export function getCalendarContext(input: {
  /** Inclusive calendar days. */
  from: string;
  to: string;
  province?: Province;
}): CalendarContext {
  const { from, to } = input;
  if (to < from) throw new CalendarContextError('The period ends before it starts.');
  if (eachDay(from, to).length > MAX_CALENDAR_DAYS) {
    throw new CalendarContextError('Calendar context covers at most two years at a time. Ask for a shorter period.');
  }
  const region = schoolRegionOf(input.province);
  const current = summarise(from, to, region);

  const paydayWindows = monthsBetween(from, to).flatMap((month) => {
    const start = `${month}-${PAYDAY_WINDOW_START_DAY}`;
    const end = `${month}-${String(daysInMonth(month)).padStart(2, '0')}`;
    const lo = start > from ? start : from;
    const hi = end < to ? end : to;
    return lo > hi ? [] : [{ month, from: start, to: end, daysInPeriod: eachDay(lo, hi).length }];
  });

  const months = monthsBetween(from, to);
  const sassaByMonth = new Map(SASSA_PAYMENT_DATES.entries.map((e) => [e.month, e]));
  const sassaMonths = months
    .map((m) => sassaByMonth.get(m))
    .filter((e): e is NonNullable<typeof e> => e !== undefined)
    .map((e) => ({
      month: e.month,
      olderPersons: e.olderPersons,
      disability: e.disability,
      childAndOtherGrants: e.childAndOtherGrants,
      sourceKind: e.sourceKind,
      ...(e.note ? { note: e.note } : {}),
    }));

  const lastYearFrom = sameDayLastYear(from);
  const lastYearTo = sameDayLastYear(to);
  const lastYear = summarise(lastYearFrom, lastYearTo, region);

  const sources: Provenance[] = [
    {
      sourceName: `${PUBLIC_HOLIDAYS_SOURCE}, sections 1-2`,
      url: PUBLIC_HOLIDAYS_ACT_URL,
      publishedAt: '1994-12-07',
      retrievedAt: DECLARED_HOLIDAYS.verifiedAt,
    },
  ];
  const declaredUsed = [...current.holidays, ...lastYear.holidays].filter((h) => h.kind === 'declared');
  for (const holiday of declaredUsed) {
    const entry = DECLARED_HOLIDAYS.entries.find((e) => e.date === holiday.date);
    if (entry) {
      sources.push({
        sourceName: `Declared public holiday: ${entry.name}`,
        url: entry.sourceUrl,
        publishedAt: entry.declaredOn ?? null,
        retrievedAt: DECLARED_HOLIDAYS.verifiedAt,
      });
    }
  }
  for (const url of new Set(current.spans.map((span) => span.sourceUrl))) {
    sources.push({
      sourceName: SCHOOL_TERMS.source,
      url,
      publishedAt: null,
      retrievedAt: SCHOOL_TERMS.verifiedAt,
    });
  }
  if (sassaMonths.length) {
    const urls = new Set(
      months.map((m) => sassaByMonth.get(m)).filter((e) => e !== undefined).map((e) => e!.sourceUrl),
    );
    for (const url of urls) {
      const entry = SASSA_PAYMENT_DATES.entries.find((e) => e.sourceUrl === url)!;
      sources.push({
        sourceName:
          entry.sourceKind === 'official'
            ? SASSA_PAYMENT_DATES.source
            : `News report of the ${SASSA_PAYMENT_DATES.source}`,
        url,
        publishedAt: entry.publishedAt ?? null,
        retrievedAt: SASSA_PAYMENT_DATES.verifiedAt,
      });
    }
  }

  return {
    notice: OUTSIDE_DATA_NOTICE,
    period: { from, to },
    province: input.province ?? null,
    summary: current.summary,
    publicHolidays: current.holidays.map((h) => ({ ...h, weekday: weekdayOf(h.date) })),
    school: { spans: current.spans, missingYears: current.missingYears },
    paydayWindows,
    paydayBasis:
      'A convention, not a published date: most salaries in South Africa are paid around the 25th, ' +
      'and spending runs high from then to month-end. When the 25th falls on a weekend many ' +
      'employers pay on the Friday before.',
    sassaGrantPayments: {
      months: sassaMonths,
      missingMonths: months.filter((m) => !sassaByMonth.has(m)),
    },
    sameDaysLastYear: {
      period: { from: lastYearFrom, to: lastYearTo },
      summary: lastYear.summary,
      publicHolidays: lastYear.holidays.map((h) => ({ date: h.date, name: h.name })),
    },
    sources,
  };
}

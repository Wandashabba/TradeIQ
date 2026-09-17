import { DECLARED_HOLIDAYS } from './declaredHolidays';
import { FUEL_PRICE_ADJUSTMENTS } from './fuelPriceAdjustments';
import { SASSA_PAYMENT_DATES } from './sassaPaymentDates';
import { SCHOOL_TERMS } from './schoolTerms';
import type { DataTable } from './types';

/**
 * The static context tables go stale on a calendar, not on a code change. These
 * tests make that visible in CI: in January, a table without the new year fails
 * here, before an answer quietly says "no school holidays" for a year nobody
 * typed in.
 */
const CURRENT_YEAR = new Date().getUTCFullYear();
const ISO_DAY = /^\d{4}-\d{2}-\d{2}$/;

const tables: Array<[string, DataTable<unknown>]> = [
  ['declared holidays', DECLARED_HOLIDAYS],
  ['school terms', SCHOOL_TERMS],
  ['SASSA payment dates', SASSA_PAYMENT_DATES],
  ['fuel price adjustments', FUEL_PRICE_ADJUSTMENTS],
];

describe.each(tables)('the %s table', (_name, table) => {
  it('covers the current year', () => {
    expect(table.coveredYears).toContain(CURRENT_YEAR);
  });

  it('says where it came from and when it was checked', () => {
    expect(table.source.length).toBeGreaterThan(10);
    expect(table.sourceUrl).toMatch(/^https:\/\//);
    expect(table.verifiedAt).toMatch(ISO_DAY);
    expect(table.version).toMatch(/^\d{4}-\d{2}-\d{2}\.\d+$/);
  });
});

describe('school terms', () => {
  it('has four ordered, non-overlapping terms for every covered year and region', () => {
    for (const year of SCHOOL_TERMS.coveredYears) {
      const regions = new Set(SCHOOL_TERMS.entries.filter((t) => t.year === year).map((t) => t.region));
      expect(regions.size).toBeGreaterThan(0);
      if (regions.has('national')) expect(regions.size).toBe(1);
      for (const region of regions) {
        const terms = SCHOOL_TERMS.entries
          .filter((t) => t.year === year && t.region === region)
          .sort((a, b) => a.term - b.term);
        expect(terms.map((t) => t.term)).toEqual([1, 2, 3, 4]);
        for (const [i, term] of terms.entries()) {
          expect(term.start).toMatch(ISO_DAY);
          expect(term.start.startsWith(`${year}-`)).toBe(true);
          expect(term.end > term.start).toBe(true);
          if (i > 0) expect(term.start > terms[i - 1].end).toBe(true);
          expect(term.sourceUrl).toMatch(/^https:\/\//);
        }
      }
    }
  });
});

describe('SASSA payment dates', () => {
  it('has all twelve months of every covered year', () => {
    const months = new Set(SASSA_PAYMENT_DATES.entries.map((e) => e.month));
    for (const year of SASSA_PAYMENT_DATES.coveredYears) {
      for (let m = 1; m <= 12; m += 1) {
        expect(months).toContain(`${year}-${String(m).padStart(2, '0')}`);
      }
    }
  });

  it('pays each month in order, inside that month, on weekdays, with a source', () => {
    const seen = new Set<string>();
    for (const entry of SASSA_PAYMENT_DATES.entries) {
      expect(seen.has(entry.month)).toBe(false);
      seen.add(entry.month);
      const days = [entry.olderPersons, entry.disability, entry.childAndOtherGrants];
      for (const day of days) {
        expect(day.startsWith(`${entry.month}-`)).toBe(true);
        expect([0, 6]).not.toContain(new Date(`${day}T00:00:00Z`).getUTCDay());
      }
      expect([...days].sort()).toEqual(days);
      expect(entry.sourceUrl).toMatch(/^https:\/\//);
    }
  });
});

describe('declared holidays', () => {
  it('lists each date once, in order, inside a covered year', () => {
    const dates = DECLARED_HOLIDAYS.entries.map((e) => e.date);
    expect([...new Set(dates)].sort()).toEqual(dates);
    for (const entry of DECLARED_HOLIDAYS.entries) {
      expect(entry.date).toMatch(ISO_DAY);
      expect(DECLARED_HOLIDAYS.coveredYears).toContain(Number(entry.date.slice(0, 4)));
    }
  });
});

describe('fuel price adjustments', () => {
  it('has one row per month from January of each covered year, effective on the first Wednesday', () => {
    const months = FUEL_PRICE_ADJUSTMENTS.entries.map((e) => e.month);
    expect([...new Set(months)].sort()).toEqual(months);
    for (const year of FUEL_PRICE_ADJUSTMENTS.coveredYears) expect(months).toContain(`${year}-01`);
    for (const entry of FUEL_PRICE_ADJUSTMENTS.entries) {
      const effective = new Date(`${entry.effectiveDate}T00:00:00Z`);
      expect(entry.effectiveDate.startsWith(entry.month)).toBe(true);
      expect(effective.getUTCDay()).toBe(3);
      expect(effective.getUTCDate()).toBeLessThanOrEqual(7);
      expect(entry.announcedOn <= entry.effectiveDate).toBe(true);
      expect(entry.sourceUrl).toMatch(/^https:\/\//);
    }
  });
});

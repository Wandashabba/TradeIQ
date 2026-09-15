import { localMonthOf, monthKey, monthWindow, nextMonth, parseMonth, trailingLocalDays } from './salesMonth';

describe('salesMonth', () => {
  describe('parseMonth', () => {
    it('reads YYYY-MM and YYYY-MM-01 as the first of the month at UTC midnight', () => {
      expect(parseMonth('2026-09')?.toISOString()).toBe('2026-09-01T00:00:00.000Z');
      expect(parseMonth(' 2026-12-01 ')?.toISOString()).toBe('2026-12-01T00:00:00.000Z');
    });

    it('refuses other days, instants, bad months and non-strings', () => {
      for (const bad of ['2026-9', '2026-13', '2026-09-15', '2026-09-01T00:00:00Z', 'Sept', '', '1999-01']) {
        expect(parseMonth(bad)).toBeUndefined();
      }
      expect(parseMonth(202609)).toBeUndefined();
      expect(parseMonth(undefined)).toBeUndefined();
    });
  });

  it('formats and steps months, across a year end', () => {
    const dec = parseMonth('2026-12')!;
    expect(monthKey(dec)).toBe('2026-12');
    expect(monthKey(nextMonth(dec))).toBe('2027-01');
  });

  it('is the local days of the month in Johannesburg: 22:00Z the evening before, both ends', () => {
    const window = monthWindow(parseMonth('2026-09')!, 'Africa/Johannesburg');
    expect(window.key).toBe('2026-09');
    expect(window.from.toISOString()).toBe('2026-08-31T22:00:00.000Z');
    expect(window.to.toISOString()).toBe('2026-09-30T22:00:00.000Z');
  });

  it('puts 23:30Z on the last UTC day of September into October for a Johannesburg client', () => {
    const lateOrder = new Date('2026-09-30T23:30:00.000Z');
    expect(monthKey(localMonthOf(lateOrder, 'Africa/Johannesburg'))).toBe('2026-10');
    expect(monthKey(localMonthOf(lateOrder, 'UTC'))).toBe('2026-09');
  });

  it('follows DST: a New York month begins at 04:00Z in summer and 05:00Z in winter', () => {
    const window = monthWindow(parseMonth('2026-10')!, 'America/New_York');
    expect(window.from.toISOString()).toBe('2026-10-01T04:00:00.000Z');
    expect(window.to.toISOString()).toBe('2026-11-01T04:00:00.000Z');
    const nov = monthWindow(parseMonth('2026-11')!, 'America/New_York');
    expect(nov.to.toISOString()).toBe('2026-12-01T05:00:00.000Z');
  });

  it('trailing local days end before today and start at local midnight', () => {
    const { dates, from, to } = trailingLocalDays(new Date('2026-09-15T23:30:00.000Z'), 3, 'Africa/Johannesburg');
    // 23:30Z on the 15th is already the 16th in Johannesburg.
    expect(dates.map((d) => d.toISOString().slice(0, 10))).toEqual(['2026-09-13', '2026-09-14', '2026-09-15']);
    expect(from.toISOString()).toBe('2026-09-12T22:00:00.000Z');
    expect(to.toISOString()).toBe('2026-09-15T22:00:00.000Z');
  });
});

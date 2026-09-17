import {
  localMonthOf,
  monthKey,
  monthWindow,
  nextMonth,
  parseMonth,
  trailingLocalDays,
  wholeMonthsIn,
} from './salesMonth';

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

  describe('wholeMonthsIn (#337)', () => {
    const JHB = 'Africa/Johannesburg';
    const keys = (from: Date, to: Date, zone = JHB) =>
      wholeMonthsIn(from, to, zone)?.map(monthKey) ?? null;

    it('reads an exact month window as that one month', () => {
      const sep = monthWindow(parseMonth('2026-09')!, JHB);
      expect(keys(sep.from, sep.to)).toEqual(['2026-09']);
    });

    it('reads a run of months, across a year end', () => {
      const from = monthWindow(parseMonth('2026-11')!, JHB).from;
      const to = monthWindow(parseMonth('2027-01')!, JHB).to;
      expect(keys(from, to)).toEqual(['2026-11', '2026-12', '2027-01']);
    });

    it('refuses a window that starts or ends mid-month — month-to-date included', () => {
      const sep = monthWindow(parseMonth('2026-09')!, JHB);
      // Month-to-date: the 1st to the 16th. A target covers the whole month and
      // nothing here may prorate it.
      expect(keys(sep.from, new Date('2026-09-15T22:00:00.000Z'))).toBeNull();
      // Starts on the 2nd.
      expect(keys(new Date('2026-09-01T22:00:00.000Z'), sep.to)).toBeNull();
      // An hour either side of a real boundary is not the boundary.
      expect(keys(sep.from, new Date('2026-09-30T21:00:00.000Z'))).toBeNull();
      expect(keys(sep.from, new Date('2026-09-30T23:00:00.000Z'))).toBeNull();
    });

    it('refuses an empty or backwards window', () => {
      const sep = monthWindow(parseMonth('2026-09')!, JHB);
      expect(keys(sep.from, sep.from)).toBeNull();
      expect(keys(sep.to, sep.from)).toBeNull();
    });

    it('is decided in the client\'s zone, not UTC', () => {
      // The instants that bound a Johannesburg September are 22:00Z either
      // side, and to a UTC client those are the middle of a day.
      const sep = monthWindow(parseMonth('2026-09')!, JHB);
      expect(keys(sep.from, sep.to, 'UTC')).toBeNull();
      const utc = monthWindow(parseMonth('2026-09')!, 'UTC');
      expect(keys(utc.from, utc.to, 'UTC')).toEqual(['2026-09']);
      expect(keys(utc.from, utc.to)).toBeNull();
    });

    it('follows DST, where the two ends are not the same offset', () => {
      const oct = monthWindow(parseMonth('2026-10')!, 'America/New_York');
      expect(keys(oct.from, oct.to, 'America/New_York')).toEqual(['2026-10']);
      const nov = monthWindow(parseMonth('2026-11')!, 'America/New_York');
      expect(keys(oct.from, nov.to, 'America/New_York')).toEqual(['2026-10', '2026-11']);
    });

    it('refuses a window longer than the ten years it will walk', () => {
      const from = monthWindow(parseMonth('2026-01')!, JHB).from;
      const to = monthWindow(parseMonth('2046-01')!, JHB).to;
      expect(keys(from, to)).toBeNull();
    });
  });

  it('trailing local days end before today and start at local midnight', () => {
    const { dates, from, to } = trailingLocalDays(new Date('2026-09-15T23:30:00.000Z'), 3, 'Africa/Johannesburg');
    // 23:30Z on the 15th is already the 16th in Johannesburg.
    expect(dates.map((d) => d.toISOString().slice(0, 10))).toEqual(['2026-09-13', '2026-09-14', '2026-09-15']);
    expect(from.toISOString()).toBe('2026-09-12T22:00:00.000Z');
    expect(to.toISOString()).toBe('2026-09-15T22:00:00.000Z');
  });
});

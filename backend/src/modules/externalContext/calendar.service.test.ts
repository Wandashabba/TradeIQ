import { CalendarContextError, getCalendarContext, schoolRegionOf } from './calendar.service';

describe('getCalendarContext', () => {
  it('finds the Women\'s Day long weekend in August 2026 and compares it with last year', () => {
    const ctx = getCalendarContext({ from: '2026-08-01', to: '2026-08-31' });
    expect(ctx.publicHolidays.map((h) => [h.date, h.weekday, h.kind])).toEqual([
      ['2026-08-09', 'Sunday', 'statutory'],
      ['2026-08-10', 'Monday', 'sunday_rollover'],
    ]);
    expect(ctx.summary).toEqual({
      days: 31,
      weekendDays: 10,
      publicHolidays: 2,
      workingWeekdays: 20,
      schoolHolidayDays: 0,
      paydayWindowDays: 7,
    });
    // 9 August 2025 was a Saturday: one holiday, no Monday off.
    expect(ctx.sameDaysLastYear.period).toEqual({ from: '2025-08-01', to: '2025-08-31' });
    expect(ctx.sameDaysLastYear.publicHolidays).toEqual([{ date: '2025-08-09', name: "National Women's Day" }]);
    expect(ctx.notice).toMatch(/not TradeIQ data/);
  });

  it('shows the Easter shift that makes April 2026 and April 2025 unlike each other', () => {
    const ctx = getCalendarContext({ from: '2026-04-01', to: '2026-04-30' });
    expect(ctx.publicHolidays.map((h) => h.name)).toEqual(['Good Friday', 'Family Day', 'Freedom Day']);
    expect(ctx.school.spans.find((s) => s.kind === 'school_holiday')).toMatchObject({
      from: '2026-03-28',
      to: '2026-04-07',
      daysInPeriod: 7,
    });
    expect(ctx.sameDaysLastYear.publicHolidays.map((h) => h.date)).toEqual([
      '2025-04-18',
      '2025-04-21',
      '2025-04-27',
      '2025-04-28',
    ]);
  });

  it('counts the school holiday days and cites the gazette for each year', () => {
    const ctx = getCalendarContext({ from: '2026-09-20', to: '2026-10-10' });
    const holiday = ctx.school.spans.find((s) => s.kind === 'school_holiday')!;
    expect(holiday).toMatchObject({ from: '2026-09-24', to: '2026-10-05', daysInPeriod: 12 });
    expect(ctx.summary.schoolHolidayDays).toBe(12);
    expect(ctx.sources.some((s) => /2026%20School%20Calendar/.test(s.url))).toBe(true);
  });

  it('includes the declared 2026 election holiday, with its declaration as a source', () => {
    const ctx = getCalendarContext({ from: '2026-11-01', to: '2026-11-07' });
    expect(ctx.publicHolidays.map((h) => [h.date, h.kind])).toEqual([['2026-11-04', 'declared']]);
    expect(ctx.sources.map((s) => s.url)).toContain(
      'https://www.gov.za/news/media-statements/president-cyril-ramaphosa-declares-election-day',
    );
    expect(ctx.sassaGrantPayments.months[0].note).toMatch(/may move/);
  });

  it('lists payday windows per month, clipped to the period', () => {
    const ctx = getCalendarContext({ from: '2026-01-27', to: '2026-02-26' });
    expect(ctx.paydayWindows).toEqual([
      { month: '2026-01', from: '2026-01-25', to: '2026-01-31', daysInPeriod: 5 },
      { month: '2026-02', from: '2026-02-25', to: '2026-02-28', daysInPeriod: 2 },
    ]);
    expect(ctx.paydayBasis).toMatch(/convention/);
  });

  it('gives SASSA dates for months it has, and names the months it does not rather than guessing', () => {
    const ctx = getCalendarContext({ from: '2024-12-01', to: '2025-01-31' });
    expect(ctx.sassaGrantPayments.months.map((m) => m.month)).toEqual(['2025-01']);
    expect(ctx.sassaGrantPayments.missingMonths).toEqual(['2024-12']);
    const later = getCalendarContext({ from: '2027-04-01', to: '2027-04-30' });
    expect(later.sassaGrantPayments).toEqual({ months: [], missingMonths: ['2027-04'] });
  });

  it('reports school years the table does not cover instead of claiming zero holiday days', () => {
    const ctx = getCalendarContext({ from: '2028-03-01', to: '2028-03-31' });
    expect(ctx.school.missingYears).toEqual([2028]);
    expect(ctx.summary.schoolHolidayDays).toBeNull();
  });

  it('treats the December holiday after the last gazetted term as running to year end only', () => {
    const ctx = getCalendarContext({ from: '2027-12-20', to: '2028-01-05' });
    const holiday = ctx.school.spans.find((s) => s.kind === 'school_holiday')!;
    expect(holiday).toMatchObject({ from: '2027-12-09', to: '2027-12-31', daysInPeriod: 12 });
    expect(ctx.school.missingYears).toEqual([2028]);
  });

  it('rejects an inverted or over-long period', () => {
    expect(() => getCalendarContext({ from: '2026-02-01', to: '2026-01-01' })).toThrow(CalendarContextError);
    expect(() => getCalendarContext({ from: '2020-01-01', to: '2026-01-01' })).toThrow(CalendarContextError);
  });

  it('maps provinces to the DBE inland/coastal split', () => {
    expect(schoolRegionOf('Western Cape')).toBe('coastal');
    expect(schoolRegionOf('Gauteng')).toBe('inland');
    expect(schoolRegionOf(undefined)).toBeUndefined();
  });
});

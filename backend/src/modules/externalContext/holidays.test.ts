import { easterSunday, publicHolidays, publicHolidaysBetween, statutoryHolidays } from './holidays';
import { DECLARED_HOLIDAYS } from './data/declaredHolidays';

const dates = (year: number) => publicHolidays(year).map((h) => `${h.date} ${h.name}`);

describe('easterSunday', () => {
  it.each([
    [2019, '2019-04-21'],
    [2022, '2022-04-17'],
    [2024, '2024-03-31'],
    [2025, '2025-04-20'],
    [2026, '2026-04-05'],
    [2027, '2027-03-28'],
    [2038, '2038-04-25'],
  ])('%i → %s', (year, expected) => {
    expect(easterSunday(year).toISOString().slice(0, 10)).toBe(expected);
  });
});

describe('publicHolidays', () => {
  it('lists the twelve statutory days of the Act', () => {
    expect(statutoryHolidays(2025)).toHaveLength(12);
  });

  it('computes 2024, including Youth Day rolling from Sunday to Monday and the election day', () => {
    expect(dates(2024)).toEqual([
      "2024-01-01 New Year's Day",
      '2024-03-21 Human Rights Day',
      '2024-03-29 Good Friday',
      '2024-04-01 Family Day',
      '2024-04-27 Freedom Day',
      "2024-05-01 Workers' Day",
      '2024-05-29 General elections',
      '2024-06-16 Youth Day',
      '2024-06-17 Youth Day (observed)',
      "2024-08-09 National Women's Day",
      '2024-09-24 Heritage Day',
      '2024-12-16 Day of Reconciliation',
      '2024-12-25 Christmas Day',
      '2024-12-26 Day of Goodwill',
    ]);
  });

  it('computes 2026, with Women\'s Day rolling from Sunday 9 August to Monday 10 August', () => {
    const holidays = publicHolidays(2026);
    const observed = holidays.filter((h) => h.kind === 'sunday_rollover');
    expect(observed).toEqual([
      {
        date: '2026-08-10',
        name: "National Women's Day (observed)",
        kind: 'sunday_rollover',
        observedFor: '2026-08-09',
      },
    ]);
    expect(holidays.find((h) => h.name === 'Good Friday')?.date).toBe('2026-04-03');
    expect(holidays.find((h) => h.name === 'Family Day')?.date).toBe('2026-04-06');
  });

  it('computes 2025, where Freedom Day fell on a Sunday', () => {
    expect(publicHolidays(2025).filter((h) => h.kind === 'sunday_rollover').map((h) => h.date)).toEqual([
      '2025-04-28',
    ]);
    expect(publicHolidays(2025).find((h) => h.name === 'Good Friday')?.date).toBe('2025-04-18');
  });

  it('rolls New Year and Workers\' Day forward in the years they fall on a Sunday', () => {
    expect(publicHolidays(2023).map((h) => h.date)).toContain('2023-01-02');
    expect(publicHolidays(2022).map((h) => h.date)).toContain('2022-05-02');
  });

  it('adds no automatic Tuesday when Christmas falls on a Sunday — only the declared one', () => {
    // 2022: 25 Dec is Sunday, 26 Dec is already Day of Goodwill. The 27th
    // exists only because it was declared.
    const december = publicHolidays(2022).filter((h) => h.date >= '2022-12-24');
    expect(december.map((h) => [h.date, h.kind])).toEqual([
      ['2022-12-25', 'statutory'],
      ['2022-12-26', 'statutory'],
      ['2022-12-27', 'declared'],
    ]);
    // 2033 has the same shape and no declaration in the table.
    expect(publicHolidays(2033).filter((h) => h.date >= '2033-12-24').map((h) => h.date)).toEqual([
      '2033-12-25',
      '2033-12-26',
    ]);
  });

  it('never lists a date twice and always sorts by date', () => {
    for (let year = 2016; year <= 2030; year += 1) {
      const list = publicHolidays(year).map((h) => h.date);
      expect(new Set(list).size).toBe(list.length);
      expect([...list].sort()).toEqual(list);
    }
  });

  it('filters a range across a year boundary', () => {
    expect(publicHolidaysBetween('2025-12-20', '2026-01-05').map((h) => h.date)).toEqual([
      '2025-12-25',
      '2025-12-26',
      '2026-01-01',
    ]);
  });
});

describe('the declared-holiday table', () => {
  it('carries its source and verification date on every entry', () => {
    expect(DECLARED_HOLIDAYS.verifiedAt).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    for (const entry of DECLARED_HOLIDAYS.entries) {
      expect(entry.date).toMatch(/^\d{4}-\d{2}-\d{2}$/);
      expect(entry.sourceUrl).toMatch(/^https:\/\//);
    }
  });
});

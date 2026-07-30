import { expandOccurrences, MAX_OCCURRENCES } from './recurrence';

const iso = (dates: Date[]) => dates.map((d) => d.toISOString().slice(0, 10));

// 2026-07-07 is a Tuesday.
const TUESDAY = new Date('2026-07-07T00:00:00.000Z');

describe('expandOccurrences', () => {
  it('repeats daily, inclusive of the start and the until date', () => {
    const dates = expandOccurrences(TUESDAY, {
      frequency: 'daily',
      interval: 1,
      until: new Date('2026-07-10T00:00:00.000Z'),
    });

    expect(iso(dates)).toEqual(['2026-07-07', '2026-07-08', '2026-07-09', '2026-07-10']);
  });

  it('honours a daily interval greater than one', () => {
    const dates = expandOccurrences(TUESDAY, {
      frequency: 'daily',
      interval: 3,
      until: new Date('2026-07-14T00:00:00.000Z'),
    });

    expect(iso(dates)).toEqual(['2026-07-07', '2026-07-10', '2026-07-13']);
  });

  it('defaults a weekly series to the weekday it starts on', () => {
    const dates = expandOccurrences(TUESDAY, {
      frequency: 'weekly',
      interval: 1,
      until: new Date('2026-07-28T00:00:00.000Z'),
    });

    expect(iso(dates)).toEqual(['2026-07-07', '2026-07-14', '2026-07-21', '2026-07-28']);
  });

  it('lands on every named weekday', () => {
    // Monday (1) and Thursday (4), starting Tuesday — so the first Monday is
    // the FOLLOWING week, but that week's Thursday is only two days away.
    const dates = expandOccurrences(TUESDAY, {
      frequency: 'weekly',
      interval: 1,
      daysOfWeek: [1, 4],
      until: new Date('2026-07-17T00:00:00.000Z'),
    });

    expect(iso(dates)).toEqual(['2026-07-09', '2026-07-13', '2026-07-16']);
  });

  it('never back-dates a day earlier in the starting week', () => {
    // A Monday series created on a Tuesday must not produce the Monday that
    // has already passed.
    const dates = expandOccurrences(TUESDAY, {
      frequency: 'weekly',
      interval: 1,
      daysOfWeek: [1],
      until: new Date('2026-07-20T00:00:00.000Z'),
    });

    expect(iso(dates)).toEqual(['2026-07-13', '2026-07-20']);
    expect(iso(dates)).not.toContain('2026-07-06');
  });

  it('steps whole weeks when the interval is greater than one', () => {
    const dates = expandOccurrences(TUESDAY, {
      frequency: 'weekly',
      interval: 2,
      until: new Date('2026-08-04T00:00:00.000Z'),
    });

    expect(iso(dates)).toEqual(['2026-07-07', '2026-07-21', '2026-08-04']);
  });

  it('treats a same-day until as a single occurrence', () => {
    const dates = expandOccurrences(TUESDAY, {
      frequency: 'weekly',
      interval: 1,
      until: TUESDAY,
    });

    expect(iso(dates)).toEqual(['2026-07-07']);
  });

  it('ignores the time of day — a plan is a calendar day, not an instant', () => {
    // Stepping by milliseconds from a late-evening start would drift the whole
    // series if the arithmetic were not normalised to UTC midnight.
    const dates = expandOccurrences(new Date('2026-07-07T23:45:00.000Z'), {
      frequency: 'daily',
      interval: 1,
      until: new Date('2026-07-09T00:15:00.000Z'),
    });

    expect(iso(dates)).toEqual(['2026-07-07', '2026-07-08', '2026-07-09']);
  });

  it('deduplicates a repeated weekday', () => {
    const dates = expandOccurrences(TUESDAY, {
      frequency: 'weekly',
      interval: 1,
      daysOfWeek: [2, 2],
      until: new Date('2026-07-14T00:00:00.000Z'),
    });

    expect(iso(dates)).toEqual(['2026-07-07', '2026-07-14']);
  });

  it('rejects an until before the start date', () => {
    expect(() =>
      expandOccurrences(TUESDAY, {
        frequency: 'daily',
        interval: 1,
        until: new Date('2026-07-01T00:00:00.000Z'),
      }),
    ).toThrow('until must be on or after');
  });

  it('rejects a non-positive interval', () => {
    expect(() =>
      expandOccurrences(TUESDAY, {
        frequency: 'daily',
        interval: 0,
        until: new Date('2026-07-14T00:00:00.000Z'),
      }),
    ).toThrow('interval must be a positive integer');
  });

  it('rejects a weekday outside 0-6', () => {
    expect(() =>
      expandOccurrences(TUESDAY, {
        frequency: 'weekly',
        interval: 1,
        daysOfWeek: [7],
        until: new Date('2026-07-14T00:00:00.000Z'),
      }),
    ).toThrow('daysOfWeek must contain integers 0-6');
  });

  it('throws rather than silently truncating an over-long series', () => {
    // Truncating would leave a manager believing a year was scheduled when
    // only part of it was — the failure mode worth being loud about.
    expect(() =>
      expandOccurrences(TUESDAY, {
        frequency: 'daily',
        interval: 1,
        until: new Date('2031-07-07T00:00:00.000Z'),
      }),
    ).toThrow(`more than ${MAX_OCCURRENCES} plans`);
  });

  it('allows exactly the maximum', () => {
    const until = new Date(TUESDAY.getTime() + (MAX_OCCURRENCES - 1) * 24 * 60 * 60 * 1000);
    const dates = expandOccurrences(TUESDAY, { frequency: 'daily', interval: 1, until });

    expect(dates).toHaveLength(MAX_OCCURRENCES);
  });
});

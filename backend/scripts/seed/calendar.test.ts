import { bucketStart } from '../../src/modules/trends/trends.service';
import {
  addMonths,
  dayOfMonth,
  isWorkday,
  lastWorkdaysOfMonth,
  localInstant,
  resolveAnchorDate,
  startOfUtcDay,
  mondayOfWeek,
  weekStarts,
  addDays,
  addHours,
} from './calendar';

const WED = new Date('2026-07-15T13:45:12.000Z'); // a Wednesday

describe('startOfUtcDay', () => {
  it('truncates to UTC midnight', () => {
    expect(startOfUtcDay(WED).toISOString()).toBe('2026-07-15T00:00:00.000Z');
  });
});

describe('mondayOfWeek', () => {
  it('returns the Monday of the containing week', () => {
    expect(mondayOfWeek(WED).toISOString()).toBe('2026-07-13T00:00:00.000Z');
  });

  it('treats Sunday as the end of its week, not the start', () => {
    const sunday = new Date('2026-07-19T23:00:00.000Z');
    expect(mondayOfWeek(sunday).toISOString()).toBe('2026-07-13T00:00:00.000Z');
  });

  // The guard that matters: if /trends ever changes its week boundary, this
  // fails rather than the seed silently generating a history the dashboard
  // buckets differently. Trends bucket in the client's timezone (#309); the
  // seed's calendar is UTC, and its daytime check-ins fall on the same date in
  // both, so parity is asserted in UTC and at a SAST mid-morning.
  it('agrees with the trends service bucketing rule', () => {
    for (let day = 0; day < 30; day += 1) {
      const date = addDays(new Date('2026-06-01T09:30:00.000Z'), day);
      expect(mondayOfWeek(date).toISOString()).toBe(
        bucketStart(date, 'week', 'UTC').toISOString(),
      );
      expect(mondayOfWeek(date).toISOString()).toBe(
        bucketStart(date, 'week', 'Africa/Johannesburg').toISOString(),
      );
    }
  });
});

const WEEKS = 12;

describe('weekStarts', () => {
  it('returns the requested number of distinct Mondays, oldest first', () => {
    const weeks = weekStarts(WED, WEEKS);
    expect(weeks).toHaveLength(WEEKS);
    expect(new Set(weeks.map((w) => w.toISOString())).size).toBe(WEEKS);
    for (let i = 1; i < weeks.length; i += 1) {
      expect(weeks[i]!.getTime()).toBeGreaterThan(weeks[i - 1]!.getTime());
    }
  });

  it('ends with the anchor week, so the chart runs up to today', () => {
    const weeks = weekStarts(WED, WEEKS);
    expect(weeks[weeks.length - 1]!.toISOString()).toBe(
      mondayOfWeek(WED).toISOString(),
    );
  });

  // #204: one bucket is exactly the bug. Three is the ticket's floor.
  it('spans well beyond the three weekly buckets #204 requires', () => {
    expect(weekStarts(WED, WEEKS).length).toBeGreaterThanOrEqual(3);
  });
});

describe('addDays / addHours', () => {
  it('does not mutate its input', () => {
    const original = new Date(WED);
    addDays(WED, 5);
    addHours(WED, 5);
    expect(WED.toISOString()).toBe(original.toISOString());
  });

  it('adds the requested offset', () => {
    expect(addDays(WED, 2).toISOString()).toBe('2026-07-17T13:45:12.000Z');
    expect(addHours(WED, 2).toISOString()).toBe('2026-07-15T15:45:12.000Z');
  });
});

describe('resolveAnchorDate', () => {
  it('uses the client\'s local date, not the UTC one', () => {
    // 23:30Z on 16 September is already the 17th in Johannesburg.
    const now = new Date('2026-09-16T23:30:00.000Z');
    expect(resolveAnchorDate({}, now, 'Africa/Johannesburg').toISOString()).toBe('2026-09-17T00:00:00.000Z');
    expect(resolveAnchorDate({}, now, 'UTC').toISOString()).toBe('2026-09-16T00:00:00.000Z');
  });

  it('is pinned by SEED_ANCHOR_DATE, so a dataset can be rebuilt on a later day', () => {
    expect(resolveAnchorDate({ SEED_ANCHOR_DATE: '2026-09-17' }, new Date('2030-01-01T00:00:00Z')).toISOString())
      .toBe('2026-09-17T00:00:00.000Z');
  });

  it('refuses a malformed or impossible date rather than seeding the wrong years', () => {
    expect(() => resolveAnchorDate({ SEED_ANCHOR_DATE: '17/09/2026' })).toThrow('SEED_ANCHOR_DATE');
    expect(() => resolveAnchorDate({ SEED_ANCHOR_DATE: '2026-02-30' })).toThrow('SEED_ANCHOR_DATE');
  });
});

describe('month helpers', () => {
  it('steps months across a year boundary', () => {
    expect(addMonths(new Date('2026-01-01T00:00:00Z'), -2).toISOString()).toBe('2025-11-01T00:00:00.000Z');
  });

  it('clamps a day past the end of the month to its last day', () => {
    expect(dayOfMonth(new Date('2026-06-01T00:00:00Z'), 31).toISOString()).toBe('2026-06-30T00:00:00.000Z');
  });
});

describe('isWorkday', () => {
  it('excludes weekends and fixed public holidays', () => {
    expect(isWorkday(new Date('2026-09-17T00:00:00Z'))).toBe(true); // Thursday
    expect(isWorkday(new Date('2026-09-19T00:00:00Z'))).toBe(false); // Saturday
    expect(isWorkday(new Date('2026-09-24T00:00:00Z'))).toBe(false); // Heritage Day, a Thursday
  });

  it('finds the last working days of a month for the month-end spike', () => {
    const days = lastWorkdaysOfMonth(new Date('2026-08-01T00:00:00Z'), 3).map((d) => d.toISOString().slice(0, 10));
    expect(days).toEqual(['2026-08-27', '2026-08-28', '2026-08-31']);
  });
});

describe('localInstant', () => {
  it('reads minutes on the client\'s wall clock', () => {
    const day = new Date('2026-09-17T00:00:00Z');
    expect(localInstant(day, 8 * 60, 'Africa/Johannesburg').toISOString()).toBe('2026-09-17T06:00:00.000Z');
  });
});

import { bucketStart } from '../../src/modules/trends/trends.service';
import {
  HISTORY_WEEKS,
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

describe('weekStarts', () => {
  it('returns HISTORY_WEEKS distinct Mondays, oldest first', () => {
    const weeks = weekStarts(WED, HISTORY_WEEKS);
    expect(weeks).toHaveLength(HISTORY_WEEKS);
    expect(new Set(weeks.map((w) => w.toISOString())).size).toBe(HISTORY_WEEKS);
    for (let i = 1; i < weeks.length; i += 1) {
      expect(weeks[i]!.getTime()).toBeGreaterThan(weeks[i - 1]!.getTime());
    }
  });

  it('ends with the anchor week, so the chart runs up to today', () => {
    const weeks = weekStarts(WED, HISTORY_WEEKS);
    expect(weeks[weeks.length - 1]!.toISOString()).toBe(
      mondayOfWeek(WED).toISOString(),
    );
  });

  // #204: one bucket is exactly the bug. Three is the ticket's floor.
  it('spans well beyond the three weekly buckets #204 requires', () => {
    expect(weekStarts(WED, HISTORY_WEEKS).length).toBeGreaterThanOrEqual(3);
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

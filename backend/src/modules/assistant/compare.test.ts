import {
  comparisonRanges,
  compareToSchema,
  describeComparison,
  numericDeltas,
  periodCompareToSchema,
  type CompareTo,
} from './compare';
import { resolvePeriod, type Period } from './period';
import { z } from 'zod';
import { toGeminiSchema } from './providers/geminiSchema';

const MTD: Period = { kind: 'mtd' };
const YTD: Period = { kind: 'ytd' };
const TODAY: Period = { kind: 'today' };
const PREVIOUS: CompareTo = { kind: 'previous_period' };
const LAST_YEAR: CompareTo = { kind: 'same_period_last_year' };
const SAST = 'Africa/Johannesburg';

/** Both windows as ISO strings, so an expectation reads as the dates it means. */
function iso(period: Period, compareTo: CompareTo, now: string, timeZone = SAST) {
  const ranges = comparisonRanges(period, compareTo, new Date(now), timeZone);
  return {
    current: [ranges.current.from.toISOString(), ranges.current.to.toISOString()],
    comparison: [ranges.comparison.from.toISOString(), ranges.comparison.to.toISOString()],
    label: ranges.label,
    note: ranges.note,
  };
}

describe('comparison windows — like for like (#365)', () => {
  // A Johannesburg day starts at 22:00Z the evening before, so every boundary
  // below is 22:00Z: local midnight, not UTC midnight.

  it('compares month to date with the same complete days of last month', () => {
    // The case that reported "down 12%" for a ~1% change: on 17 Sep the old
    // window was 1–17 Sep (today still at zero) against 15–31 Aug (month-end
    // spike). Now both sides are days 1–16.
    const w = iso(MTD, PREVIOUS, '2026-09-17T12:00:00+02:00');
    expect(w.current).toEqual(['2026-08-31T22:00:00.000Z', '2026-09-16T22:00:00.000Z']);
    expect(w.comparison).toEqual(['2026-07-31T22:00:00.000Z', '2026-08-16T22:00:00.000Z']);
    expect(w.label).toBe('the same days last month');
    expect(w.note).toBeUndefined();
  });

  it('clamps to the end of a shorter previous month', () => {
    // 31 March: 1–30 Mar against all of February, and not a day of March.
    const w = iso(MTD, PREVIOUS, '2026-03-31T12:00:00+02:00');
    expect(w.current).toEqual(['2026-02-28T22:00:00.000Z', '2026-03-30T22:00:00.000Z']);
    expect(w.comparison).toEqual(['2026-01-31T22:00:00.000Z', '2026-02-28T22:00:00.000Z']);
  });

  it('counts a leap-year February in full', () => {
    // 30 Mar 2028: 1–29 Mar against all 29 days of February 2028.
    const w = iso(MTD, PREVIOUS, '2028-03-30T12:00:00+02:00');
    expect(w.comparison).toEqual(['2028-01-31T22:00:00.000Z', '2028-02-29T22:00:00.000Z']);
  });

  it('on the 1st, compares all of last month with the month before, and says so', () => {
    // No complete days yet. An empty window would come back as a silent −100%
    // or n/a, so the whole previous month is shown, labelled and explained.
    const w = iso(MTD, PREVIOUS, '2026-09-01T09:00:00+02:00');
    expect(w.current).toEqual(['2026-07-31T22:00:00.000Z', '2026-08-31T22:00:00.000Z']);
    expect(w.comparison).toEqual(['2026-06-30T22:00:00.000Z', '2026-07-31T22:00:00.000Z']);
    expect(w.label).toBe('the month before');
    expect(w.note).toMatch(/all of August 2026, compared with all of July 2026/);

    const lastYear = iso(MTD, LAST_YEAR, '2026-09-01T09:00:00+02:00');
    expect(lastYear.current).toEqual(w.current);
    expect(lastYear.comparison).toEqual(['2025-07-31T22:00:00.000Z', '2025-08-31T22:00:00.000Z']);
    expect(lastYear.label).toBe('the same month last year');
    expect(lastYear.note).toMatch(/all of August 2026, compared with all of August 2025/);
  });

  it('on 1 January, month to date wraps back across the year', () => {
    const w = iso(MTD, PREVIOUS, '2027-01-01T09:00:00+02:00');
    expect(w.current).toEqual(['2026-11-30T22:00:00.000Z', '2026-12-31T22:00:00.000Z']);
    expect(w.comparison).toEqual(['2026-10-31T22:00:00.000Z', '2026-11-30T22:00:00.000Z']);
  });

  it('compares year to date with the same calendar days last year', () => {
    const w = iso(YTD, PREVIOUS, '2026-09-17T12:00:00+02:00');
    expect(w.current).toEqual(['2025-12-31T22:00:00.000Z', '2026-09-16T22:00:00.000Z']);
    expect(w.comparison).toEqual(['2024-12-31T22:00:00.000Z', '2025-09-16T22:00:00.000Z']);
    expect(w.label).toBe('the same days last year');
    // For a year to date, both bases are the same window.
    expect(iso(YTD, LAST_YEAR, '2026-09-17T12:00:00+02:00').comparison).toEqual(w.comparison);
  });

  it('on 1 January, compares all of last year with the year before, and says so', () => {
    const w = iso(YTD, PREVIOUS, '2027-01-01T09:00:00+02:00');
    expect(w.current).toEqual(['2025-12-31T22:00:00.000Z', '2026-12-31T22:00:00.000Z']);
    expect(w.comparison).toEqual(['2024-12-31T22:00:00.000Z', '2025-12-31T22:00:00.000Z']);
    expect(w.label).toBe('the year before');
    expect(w.note).toMatch(/all of 2026, compared with all of 2025/);
  });

  it('handles leap day: 1 Jan–28 Feb 2028 meets all of Jan and Feb 2027', () => {
    // On 29 Feb 2028 the complete days are 1 Jan–28 Feb; last year that is
    // 1 Jan–28 Feb 2027 — its whole February.
    const w = iso(YTD, PREVIOUS, '2028-02-29T12:00:00+02:00');
    expect(w.current).toEqual(['2027-12-31T22:00:00.000Z', '2028-02-28T22:00:00.000Z']);
    expect(w.comparison).toEqual(['2026-12-31T22:00:00.000Z', '2027-02-28T22:00:00.000Z']);

    const month = iso(MTD, LAST_YEAR, '2028-02-29T12:00:00+02:00');
    expect(month.current).toEqual(['2028-01-31T22:00:00.000Z', '2028-02-28T22:00:00.000Z']);
    expect(month.comparison).toEqual(['2027-01-31T22:00:00.000Z', '2027-02-28T22:00:00.000Z']);
  });

  it('trims month to date to complete days on both sides against last year too', () => {
    // Calendar-shifted, not 365 days back: "March vs March" stays March across
    // a leap year, and the practitioner's vocabulary is months.
    const w = iso(MTD, LAST_YEAR, '2026-09-17T12:00:00+02:00');
    expect(w.current).toEqual(['2026-08-31T22:00:00.000Z', '2026-09-16T22:00:00.000Z']);
    expect(w.comparison).toEqual(['2025-08-31T22:00:00.000Z', '2025-09-16T22:00:00.000Z']);
  });

  it('shifts last year on the client calendar, keeping local midnights (#309)', () => {
    // New York: 15 Mar 2027 is EDT (-4), and so is 15 Mar 2026; 1 Mar is EST
    // (-5) in both. Each boundary must be local midnight in ITS offset.
    const ny = iso(MTD, LAST_YEAR, '2027-03-15T12:00:00Z', 'America/New_York');
    expect(ny.current).toEqual(['2027-03-01T05:00:00.000Z', '2027-03-15T04:00:00.000Z']);
    expect(ny.comparison).toEqual(['2026-03-01T05:00:00.000Z', '2026-03-15T04:00:00.000Z']);
  });

  it('compares today so far with yesterday up to the same clock time', () => {
    const w = iso(TODAY, PREVIOUS, '2026-09-17T12:00:00+02:00');
    expect(w.current).toEqual(['2026-09-16T22:00:00.000Z', '2026-09-17T10:00:00.000Z']);
    expect(w.comparison).toEqual(['2026-09-15T22:00:00.000Z', '2026-09-16T10:00:00.000Z']);
    expect(w.label).toBe('yesterday, up to the same time');

    const lastYear = iso(TODAY, LAST_YEAR, '2026-09-17T12:00:00+02:00');
    expect(lastYear.comparison).toEqual(['2025-09-16T22:00:00.000Z', '2025-09-17T10:00:00.000Z']);
  });

  it('matches the clock time, not the elapsed time, across a DST change', () => {
    // 8 Mar 2026 10:30 in New York is EDT (14:30Z); 7 Mar 10:30 was EST
    // (15:30Z). Stepping back 24 hours would land at 09:30 on the 7th.
    const w = iso(TODAY, PREVIOUS, '2026-03-08T14:30:00Z', 'America/New_York');
    expect(w.comparison).toEqual(['2026-03-07T05:00:00.000Z', '2026-03-07T15:30:00.000Z']);
  });

  it('keeps whole-day periods as the equally long run of days just before', () => {
    const now = '2026-09-17T12:00:00+02:00';
    expect(iso({ kind: 'yesterday' }, PREVIOUS, now).comparison).toEqual([
      '2026-09-14T22:00:00.000Z',
      '2026-09-15T22:00:00.000Z',
    ]);
    // Thursday 17 Sep: last week is Mon 7–Sun 13 Sep, the week before 31 Aug–6 Sep.
    const week = iso({ kind: 'previous_week' }, PREVIOUS, now);
    expect(week.current).toEqual(['2026-09-06T22:00:00.000Z', '2026-09-13T22:00:00.000Z']);
    expect(week.comparison).toEqual(['2026-08-30T22:00:00.000Z', '2026-09-06T22:00:00.000Z']);
    const august = iso({ kind: 'custom', from: '2026-08-01', to: '2026-08-31' }, PREVIOUS, now);
    expect(august.comparison).toEqual(['2026-06-30T22:00:00.000Z', '2026-07-31T22:00:00.000Z']);
    expect(iso({ kind: 'custom', from: '2026-08-01', to: '2026-08-31' }, LAST_YEAR, now).comparison)
      .toEqual(['2025-07-31T22:00:00.000Z', '2025-08-31T22:00:00.000Z']);
  });

  it('keeps the plain window when comparing territories', () => {
    // Moving both place and time would produce a difference nobody can read,
    // and with nothing moved in time a partial today is shared by both sides.
    const now = new Date('2026-09-17T12:00:00+02:00');
    const ranges = comparisonRanges(MTD, { kind: 'territory', id: 't1' }, now, SAST);
    expect(ranges.current).toEqual(resolvePeriod(MTD, now, SAST));
    expect(ranges.comparison).toEqual(ranges.current);
  });

  it('labels each basis in the vocabulary the user already uses', () => {
    expect(describeComparison(MTD, PREVIOUS)).toBe('the same days last month');
    expect(describeComparison(MTD, LAST_YEAR)).toMatch(/last year/);
    expect(describeComparison({ kind: 'previous_week' }, PREVIOUS)).toBe('the week before');
    expect(describeComparison({ kind: 'previous_week' }, LAST_YEAR)).toBe('last week last year');
  });
});

describe('comparison basis', () => {
  it('rejects a basis the pillar tools cannot honour', () => {
    // The plan also names agent and sku. The pillar services take neither, and
    // declaring them would have the model promise the user a comparison it
    // cannot produce.
    expect(compareToSchema.safeParse({ kind: 'agent', id: 'a1' }).success).toBe(false);
    expect(compareToSchema.safeParse({ kind: 'territory', id: 't1' }).success).toBe(true);
  });

  it('requires an id for a territory comparison', () => {
    // The exclusivity a discriminated union would have expressed, enforced by a
    // refinement instead — the union shape serialises as `oneOf`, which Gemini
    // has no equivalent for and geminiSchema.ts refuses outright.
    expect(compareToSchema.safeParse({ kind: 'territory' }).success).toBe(false);
  });

  it('offers a trend only the bases a time series can honour', () => {
    // `trends.service.ts` has no territory narrowing, so a trend that accepted
    // one would answer with the whole business twice and label it a comparison.
    expect(periodCompareToSchema.safeParse({ kind: 'previous_period' }).success).toBe(true);
    expect(periodCompareToSchema.safeParse({ kind: 'same_period_last_year' }).success).toBe(true);
    expect(periodCompareToSchema.safeParse({ kind: 'territory', id: 't1' }).success).toBe(false);
  });

  it('declares a schema Gemini will actually accept', () => {
    // The regression this shape exists to prevent: a discriminated union here
    // made every tool declaration unconvertible, so the whole roster failed to
    // reach the provider — not just the comparison.
    const declaration = toGeminiSchema(
      z.toJSONSchema(z.object({ compareTo: compareToSchema.optional() }), { io: 'input' }),
    );

    expect(declaration.properties?.compareTo.type).toBe('OBJECT');
    expect(JSON.stringify(declaration)).not.toContain('oneOf');
  });
});

describe('numeric deltas', () => {
  it('reports absolute and percentage movement on shared numeric fields', () => {
    const deltas = numericDeltas({ osaPct: 93.1, visits: 120 }, { osaPct: 88.0, visits: 100 });

    expect(deltas).toEqual({
      osaPct: { absolute: 5.1, pct: 5.8 },
      visits: { absolute: 20, pct: 20 },
    });
  });

  it('reports null rather than a number when the baseline is zero', () => {
    // "Up from nothing" has no percentage. Infinity, 0 and 100 would each be a
    // different lie, and a chart axis will plot any of them without complaint.
    const deltas = numericDeltas({ stockouts: 4 }, { stockouts: 0 });

    expect(deltas).toEqual({ stockouts: { absolute: 4, pct: null } });
  });

  it('handles a fall as readily as a rise', () => {
    const deltas = numericDeltas({ osaPct: 80 }, { osaPct: 100 });

    expect(deltas).toEqual({ osaPct: { absolute: -20, pct: -20 } });
  });

  it('skips fields that are not numeric on both sides', () => {
    // A tool result carries rows and flags too. Differencing those generically
    // is what produces nonsense like NaN on an axis.
    const deltas = numericDeltas(
      { osaPct: 90, rows: [1, 2], truncated: false, name: 'x' },
      { osaPct: 80, rows: [3], truncated: true, name: 'y' },
    );

    expect(deltas).toEqual({ osaPct: { absolute: 10, pct: 12.5 } });
  });

  it('returns undefined when there is nothing numeric to compare', () => {
    // Better than an empty object: the caller omits the key entirely, so a
    // client never renders an empty delta column.
    expect(numericDeltas({ rows: [] }, { rows: [] })).toBeUndefined();
    expect(numericDeltas([1, 2], [3])).toBeUndefined();
  });

  it('skips non-finite values rather than propagating them', () => {
    // NaN in a delta poisons every axis it touches, silently.
    expect(numericDeltas({ a: Number.NaN }, { a: 1 })).toBeUndefined();
    expect(numericDeltas({ a: Number.POSITIVE_INFINITY }, { a: 1 })).toBeUndefined();
  });
});

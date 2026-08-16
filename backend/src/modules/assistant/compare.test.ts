import {
  comparisonWindow,
  compareToSchema,
  describeComparison,
  numericDeltas,
} from './compare';
import type { Period } from './period';
import { z } from 'zod';
import { toGeminiSchema } from './providers/geminiSchema';

const NOW = new Date('2026-08-16T12:00:00Z');
const MTD: Period = { kind: 'mtd' };

describe('comparison basis', () => {
  it('measures the previous period over an equally long window ending where this one starts', () => {
    // The same definition the dashboard's KPI tiles use. If chat and the
    // console disagreed about what "previous" means, the same metric would
    // carry two different deltas in one product.
    const window = comparisonWindow(MTD, { kind: 'previous_period' }, NOW);

    // MTD on the 16th resolves to 1 Aug 00:00 → 17 Aug 00:00 — end-exclusive,
    // so the whole of the 16th is inside it. That is 16 days, and the window
    // before it is the 16 days ending where this one starts.
    expect(window.to.toISOString()).toBe('2026-08-01T00:00:00.000Z');
    expect(window.from.toISOString()).toBe('2026-07-16T00:00:00.000Z');
  });

  it('shifts last year by the calendar, not by 365 days', () => {
    // "March vs March" has to stay March across a leap year. Subtracting a
    // fixed number of days drifts the month, and the practitioner's vocabulary
    // is months.
    const window = comparisonWindow(MTD, { kind: 'same_period_last_year' }, NOW);

    expect(window.from.toISOString()).toBe('2025-08-01T00:00:00.000Z');
    expect(window.to.toISOString()).toBe('2025-08-17T00:00:00.000Z');
  });

  it('keeps the window when comparing territories', () => {
    // Moving both place and time would produce a difference nobody can read:
    // the user cannot tell which half moved.
    const current = comparisonWindow(MTD, { kind: 'territory', id: 't1' }, NOW);

    expect(current.from.toISOString()).toBe('2026-08-01T00:00:00.000Z');
    expect(current.to.toISOString()).toBe('2026-08-17T00:00:00.000Z');
  });

  it('labels each basis in the vocabulary the user already uses', () => {
    expect(describeComparison(MTD, { kind: 'previous_period' })).toMatch(/before this one/);
    expect(describeComparison(MTD, { kind: 'same_period_last_year' })).toMatch(/last year/);
  });

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

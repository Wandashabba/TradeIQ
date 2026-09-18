import { compactToolResult } from './compact';

/**
 * Compaction is a cost control that runs on every tool result, which makes it a
 * correctness risk on every tool result: anything it removes is a figure the
 * answer can no longer quote, and rule 1 forbids quoting a figure that is not in
 * a tool result. So most of what is asserted here is what compaction must NOT
 * touch.
 */

describe('compactToolResult', () => {
  describe('drops render-only fields', () => {
    it('removes coordinates the model cannot use', () => {
      const result = compactToolResult({
        worstOutlets: [
          { outletId: 'o-1', outletName: 'Corner Express', outOfStockLines: 16, lat: -29.85, lng: 30.99 },
        ],
      });
      expect(result).toEqual({
        worstOutlets: [{ outletId: 'o-1', outletName: 'Corner Express', outOfStockLines: 16 }],
      });
    });

    it('removes them at any depth, because a tool may nest them anywhere', () => {
      const result = compactToolResult({ point: { lat: -26.1, lng: 28.03, outlets: 40 } });
      expect(result).toEqual({ point: { outlets: 40 } });
    });

    it('leaves every other identifier alone', () => {
      // The list is closed and short on purpose. A near-miss key must survive,
      // or the next tool to return `latestVisit` loses it.
      const input = { latestVisit: '2026-09-01', flag: 'lng-running', language: 'en' };
      expect(compactToolResult(input)).toEqual(input);
    });
  });

  describe('keeps the figures an answer quotes', () => {
    it('never touches an integer', () => {
      const input = { sellInUnits: 481615, outOfStockLines: 1175, changePct: -8 };
      expect(compactToolResult(input)).toEqual(input);
    });

    it('rounds float noise but not the value', () => {
      expect(compactToolResult({ pct: 93.95999999999999 })).toEqual({ pct: 93.96 });
      expect(compactToolResult({ pct: 93.96 })).toEqual({ pct: 93.96 });
      expect(compactToolResult({ pct: -32.6 })).toEqual({ pct: -32.6 });
    });

    it('keeps nulls, because a null target is not a target of zero', () => {
      // Rule 9: "When a tool returns a null target, say no target is set for
      // that scope and month rather than reporting a miss." Dropping the null
      // to save four characters makes that rule unfollowable — the model cannot
      // tell "no target set" from "this tool does not report targets".
      const input = { targetUnits: null, attainmentPct: null, sellInUnits: 22346 };
      expect(compactToolResult(input)).toEqual(input);
    });

    it('keeps empty arrays, because "none" is an answer', () => {
      // `publicHolidays: []` is what answers "was there a public holiday?".
      const input = { publicHolidays: [], missingYears: [] };
      expect(compactToolResult(input)).toEqual(input);
    });

    it('keeps empty strings and false', () => {
      const input = { note: '', available: false, region: '' };
      expect(compactToolResult(input)).toEqual(input);
    });
  });

  describe('the far side of a comparison', () => {
    const comparison = (values: unknown) => ({
      onShelfAvailabilityPct: 93.96,
      worstOutlets: [{ outletId: 'a' }, { outletId: 'b' }, { outletId: 'c' }],
      comparison: { label: 'the same days last year', basis: { kind: 'same_period_last_year' }, values },
    });

    it('keeps its totals and cuts its rows to a marker', () => {
      const result = compactToolResult(
        comparison({
          onShelfAvailabilityPct: 94.31,
          outOfStockLines: 1124,
          worstOutlets: [{ outletId: 'x' }, { outletId: 'y' }, { outletId: 'z' }],
        }),
      ) as Record<string, never>;

      const values = (result.comparison as unknown as { values: Record<string, unknown> }).values;
      // Every scalar survives: these are what a delta is computed from.
      expect(values.onShelfAvailabilityPct).toBe(94.31);
      expect(values.outOfStockLines).toBe(1124);
      // The rows do not, and the model is told how many went.
      expect(values.worstOutlets).toEqual([{ outletId: 'x' }, { omitted: 2 }]);
    });

    it('leaves the rows on the current side completely alone', () => {
      const result = compactToolResult(comparison({ onShelfAvailabilityPct: 94.31 })) as {
        worstOutlets: unknown[];
      };
      expect(result.worstOutlets).toEqual([{ outletId: 'a' }, { outletId: 'b' }, { outletId: 'c' }]);
    });

    it('leaves the comparison label, basis and deltas alone', () => {
      const result = compactToolResult({
        comparison: {
          label: 'the same days last year',
          basis: { kind: 'same_period_last_year' },
          deltas: { sellInUnits: -4130, changePct: -0.85 },
          values: { sellInUnits: 485745 },
        },
      }) as { comparison: Record<string, unknown> };
      expect(result.comparison.label).toBe('the same days last year');
      expect(result.comparison.basis).toEqual({ kind: 'same_period_last_year' });
      expect(result.comparison.deltas).toEqual({ sellInUnits: -4130, changePct: -0.85 });
    });

    it('does not cut a field a tool happens to call `values`', () => {
      // No sibling `label`/`basis`, so this is not a comparison block. Cutting
      // it would silently truncate a list the user asked for.
      const input = { values: [1, 2, 3, 4, 5] };
      expect(compactToolResult(input)).toEqual(input);
    });

    it('does not cut `values` under a partial look-alike', () => {
      const input = { label: 'x', values: [1, 2, 3] };
      expect(compactToolResult(input)).toEqual(input);
    });
  });

  describe('is safe on anything a tool can return', () => {
    it.each([
      ['null', null],
      ['a bare number', 42],
      ['a bare string', 'hello'],
      ['a bare array', [1, 2, 3]],
      ['an empty object', {}],
      ['a boolean', true],
    ])('passes %s through unchanged', (_name, value) => {
      expect(compactToolResult(value)).toEqual(value);
    });

    it('always produces something that serialises to valid JSON', () => {
      const compacted = compactToolResult({
        total: 1 / 3,
        rows: [{ lat: 1, lng: 2, name: 'x' }],
        comparison: { label: 'l', basis: { kind: 'k' }, values: { rows: [1, 2, 3] } },
      });
      const json = JSON.stringify(compacted);
      expect(() => JSON.parse(json)).not.toThrow();
      expect(JSON.parse(json)).toEqual(compacted);
    });

    it('does not turn a rounded number into a string', () => {
      const json = JSON.stringify(compactToolResult({ pct: 1 / 3 }));
      expect(json).toBe('{"pct":0.33}');
    });

    it('leaves a non-finite number alone rather than emitting NaN as a figure', () => {
      // JSON.stringify writes `null` for these either way; what matters is that
      // `toFixed` is not called on one and the result stays serialisable.
      expect(JSON.stringify(compactToolResult({ a: NaN, b: Infinity }))).toBe(
        '{"a":null,"b":null}',
      );
    });
  });

  describe('actually saves what it claims to', () => {
    it('shrinks a realistic stock result substantially', () => {
      // Shaped like `getStockLevels`, which was the largest single result in the
      // measured turn: twenty outlets with coordinates, plus a full second list
      // for last year that nothing reads.
      const outlet = (i: number) => ({
        outletId: `demo-outlet-${i}`,
        outletName: `Corner Express Branch ${i}`,
        outOfStockLines: 16 - i,
        lat: -29.859531 + i,
        lng: 30.991196 + i,
      });
      const raw = {
        onShelfAvailabilityPct: 93.96,
        linesObserved: 19458,
        worstOutlets: Array.from({ length: 10 }, (_, i) => outlet(i)),
        comparison: {
          label: 'the same days last year',
          basis: { kind: 'same_period_last_year' },
          values: {
            onShelfAvailabilityPct: 94.31,
            worstOutlets: Array.from({ length: 10 }, (_, i) => outlet(i)),
          },
        },
      };
      const before = JSON.stringify(raw).length;
      const after = JSON.stringify(compactToolResult(raw)).length;
      expect(after).toBeLessThan(before * 0.6);
      // And the headline figures are all still there to quote.
      expect(JSON.stringify(compactToolResult(raw))).toContain('93.96');
      expect(JSON.stringify(compactToolResult(raw))).toContain('19458');
      expect(JSON.stringify(compactToolResult(raw))).toContain('94.31');
    });
  });
});

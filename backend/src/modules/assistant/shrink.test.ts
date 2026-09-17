import { shrinkToolResult, SHRUNK_NOTE } from './shrink';

describe('shrinkToolResult', () => {
  it('passes a result that fits through unchanged', () => {
    const value = { osaPct: 91.2, worstOutlets: [{ name: 'A' }] };
    expect(shrinkToolResult(value)).toBe(JSON.stringify(value));
  });

  it('cuts long lists to their head, marks what was omitted, and keeps every scalar', () => {
    const value = {
      linesObserved: 840_060,
      onShelfAvailabilityPct: 94.24,
      comparison: { deltas: { onShelfAvailabilityPct: -1.2 } },
      rows: Array.from({ length: 5_000 }, (_, i) => ({ outlet: `Outlet ${i}`, oos: 5_000 - i })),
    };
    const out = shrinkToolResult(value, 4_000);

    expect(out.length).toBeLessThanOrEqual(4_000);
    const parsed = JSON.parse(out);
    expect(parsed.shrunkNote).toBe(SHRUNK_NOTE);
    expect(parsed.linesObserved).toBe(840_060);
    expect(parsed.onShelfAvailabilityPct).toBe(94.24);
    expect(parsed.comparison).toEqual({ deltas: { onShelfAvailabilityPct: -1.2 } });
    // The head survives in order, and the marker says how much is missing.
    expect(parsed.rows[0]).toEqual({ outlet: 'Outlet 0', oos: 5_000 });
    const marker = parsed.rows[parsed.rows.length - 1];
    expect(marker.omitted).toBe(5_000 - (parsed.rows.length - 1));
  });

  it('cuts nested lists too', () => {
    const value = { comparison: { values: { rows: Array(3_000).fill({ n: 123_456 }) } } };
    const parsed = JSON.parse(shrinkToolResult(value, 2_000));
    const rows = parsed.comparison.values.rows;
    expect(rows[rows.length - 1]).toHaveProperty('omitted');
  });

  it('shortens long strings when cutting lists is not enough', () => {
    const value = { total: 3, notes: Array(3).fill('x'.repeat(10_000)) };
    const out = shrinkToolResult(value, 2_000);
    expect(out.length).toBeLessThanOrEqual(2_000);
    const parsed = JSON.parse(out);
    expect(parsed.total).toBe(3);
    expect(JSON.stringify(parsed)).toContain('characters omitted');
  });

  it("never overwrites a result's own note", () => {
    const parsed = JSON.parse(shrinkToolResult({ note: 'tool note', rows: Array(5_000).fill(1) }, 1_000));
    expect(parsed.note).toBe('tool note');
    expect(parsed.shrunkNote).toBe(SHRUNK_NOTE);
  });

  it('falls back to top-level scalars, and says which fields were dropped', () => {
    const wide = Object.fromEntries(Array.from({ length: 2_000 }, (_, i) => [`k${i}`, { v: i }]));
    const value = { visits: 140_010, detail: wide };
    const parsed = JSON.parse(shrinkToolResult(value, 1_000));
    expect(parsed.visits).toBe(140_010);
    expect(parsed.omittedFields).toEqual(['detail']);
  });

  it('always returns valid JSON, even for a top-level array', () => {
    const out = shrinkToolResult(Array(10_000).fill({ a: 'b' }), 500);
    const parsed = JSON.parse(out);
    expect(parsed.shrunkNote).toBe(SHRUNK_NOTE);
    expect(parsed.result[parsed.result.length - 1]).toHaveProperty('omitted');
  });
});

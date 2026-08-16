import { describeParams, paramsChangeNote } from './paramsNote';

describe('describeParams', () => {
  it('renders a params bag as compact key=value pairs, keys sorted', () => {
    // Sorted so the same params always render identically — a note whose text
    // depends on object key order is a note no test can pin.
    expect(
      describeParams({ territoryId: 'GP-01', period: { kind: 'ytd' } }),
    ).toBe('period=ytd, territoryId=GP-01');
  });

  it('keeps the dates of a custom period', () => {
    // "custom" on its own tells the model nothing, and the dates are the entire
    // reason the user picked it.
    expect(describeParams({ period: { kind: 'custom', from: '2026-01-01', to: '2026-03-31' } })).toBe(
      'period=custom(2026-01-01..2026-03-31)',
    );
  });

  it('carries the id of a scoped comparison', () => {
    expect(describeParams({ compareTo: { kind: 'territory', id: 'WC-02' } })).toBe(
      'compareTo=territory(WC-02)',
    );
  });

  it('summarises a long list rather than reprinting it', () => {
    // outlet_map takes up to 500 ids. A note is meant to cost a few tokens, and
    // the truncation has to be VISIBLE or the model reads a 3-outlet scope.
    const rendered = describeParams({ outletIds: ['a', 'b', 'c', 'd', 'e'] });

    expect(rendered).toBe('outletIds=[a, b, c, +2 more]');
  });

  it('omits absent values instead of printing them as settings', () => {
    // `territoryId=null` reads as "scoped to nothing"; the truth is "not
    // scoped", and those call for different answers.
    expect(describeParams({ period: { kind: 'mtd' }, territoryId: null })).toBe('period=mtd');
  });

  it('bounds a pathological params bag', () => {
    const rendered = describeParams({
      note: 'x'.repeat(1_000),
    });

    expect(rendered.length).toBeLessThanOrEqual(241);
    expect(rendered.endsWith('…')).toBe(true);
  });

  it('never throws on something that is not an object', () => {
    // It is fed a JSON column. A row written by an older build, or by hand, is
    // not a reason to lose the turn.
    expect(describeParams(null)).toBe('(none)');
    expect(describeParams([1, 2])).toBe('(none)');
    expect(describeParams({})).toBe('(none)');
  });
});

describe('paramsChangeNote', () => {
  it('is empty when nothing changed, so the caller can concatenate blindly', () => {
    expect(paramsChangeNote([])).toBe('');
  });

  it('states the artifact id, the current params, and who changed them', () => {
    const note = paramsChangeNote([
      { id: 'abc', type: 'trend_chart', params: { period: { kind: 'ytd' } } },
    ]);

    expect(note).toContain('[artifact:abc params → period=ytd]');
    // "The user" is load-bearing: without it the model reads the line as its
    // own earlier work and may put the view back where it was.
    expect(note).toContain('The user changed these views themselves');
    expect(note.endsWith('\n\n')).toBe(true);
  });

  it('lists every changed view on its own line', () => {
    const note = paramsChangeNote([
      { id: 'one', type: 'trend_chart', params: { period: { kind: 'mtd' } } },
      { id: 'two', type: 'pillar_metrics', params: { pillar: 'stock', period: { kind: 'ytd' } } },
    ]);

    expect(note).toContain('[artifact:one params → period=mtd]');
    expect(note).toContain('[artifact:two params → period=ytd, pillar=stock]');
  });
});

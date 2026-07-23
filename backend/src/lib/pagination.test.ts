import { parsePagination, buildPage, DEFAULT_LIMIT, MAX_LIMIT } from './pagination';

describe('parsePagination', () => {
  const req = (query: Record<string, unknown>) => ({ query } as any);

  it('defaults to DEFAULT_LIMIT and no cursor when nothing is supplied', () => {
    expect(parsePagination(req({}))).toEqual({ limit: DEFAULT_LIMIT, cursor: undefined });
  });

  it('accepts a valid limit and cursor', () => {
    expect(parsePagination(req({ limit: '25', cursor: 'abc' }))).toEqual({ limit: 25, cursor: 'abc' });
  });

  it('clamps a limit above the max down to MAX_LIMIT', () => {
    expect(parsePagination(req({ limit: '9999' })).limit).toBe(MAX_LIMIT);
  });

  it('throws on a non-integer limit', () => {
    expect(() => parsePagination(req({ limit: '1.5' }))).toThrow();
  });

  it('throws on a non-positive limit', () => {
    expect(() => parsePagination(req({ limit: '0' }))).toThrow();
  });

  it('throws on a non-numeric limit', () => {
    expect(() => parsePagination(req({ limit: 'abc' }))).toThrow();
  });
});

describe('buildPage', () => {
  it('returns all rows and a null cursor when fewer than limit+1 were fetched', () => {
    const rows = [{ id: 'a' }, { id: 'b' }];
    expect(buildPage(rows, 5)).toEqual({ data: rows, nextCursor: null });
  });

  it('drops the probe row and returns its predecessor id as the cursor when more exist', () => {
    // limit 2, fetched 3 (limit+1) → more pages exist
    const rows = [{ id: 'a' }, { id: 'b' }, { id: 'c' }];
    expect(buildPage(rows, 2)).toEqual({ data: [{ id: 'a' }, { id: 'b' }], nextCursor: 'b' });
  });

  it('returns an empty page and null cursor for no rows', () => {
    expect(buildPage([], 50)).toEqual({ data: [], nextCursor: null });
  });
});

import { Request } from 'express';
import { parsePagination, buildPage, DEFAULT_LIMIT, MAX_LIMIT } from './pagination';

describe('parsePagination', () => {
  // Only `query` is read by parsePagination, so a minimal cast is enough
  // and keeps eslint's no-explicit-any happy.
  const req = (query: Record<string, unknown>) => ({ query }) as unknown as Request;

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

  it('throws on a hex limit', () => {
    expect(() => parsePagination(req({ limit: '0x10' }))).toThrow();
  });

  it('throws on a scientific-notation limit', () => {
    expect(() => parsePagination(req({ limit: '1e3' }))).toThrow();
  });

  it('throws on a limit with surrounding whitespace', () => {
    expect(() => parsePagination(req({ limit: ' 5 ' }))).toThrow();
  });

  it('throws on a duplicated cursor query param (array)', () => {
    expect(() => parsePagination(req({ cursor: ['a', 'b'] }))).toThrow();
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

  it('throws a RangeError for a non-positive limit', () => {
    expect(() => buildPage([{ id: 'a' }], 0)).toThrow(RangeError);
  });

  it('returns a fresh array, not the caller-supplied reference, when nothing more exists', () => {
    const rows = [{ id: 'a' }, { id: 'b' }];
    expect(buildPage(rows, 5).data).not.toBe(rows);
  });
});

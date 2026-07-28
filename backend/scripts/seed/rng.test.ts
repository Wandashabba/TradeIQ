import { makeRng, intBetween, pick, jitter } from './rng';

describe('makeRng', () => {
  it('produces the same sequence for the same seed', () => {
    const a = makeRng(12345);
    const b = makeRng(12345);
    const seqA = [a(), a(), a(), a(), a()];
    const seqB = [b(), b(), b(), b(), b()];
    expect(seqA).toEqual(seqB);
  });

  it('produces a different sequence for a different seed', () => {
    const a = makeRng(1);
    const b = makeRng(2);
    expect([a(), a(), a()]).not.toEqual([b(), b(), b()]);
  });

  it('stays within [0, 1)', () => {
    const rng = makeRng(99);
    for (let i = 0; i < 1000; i += 1) {
      const value = rng();
      expect(value).toBeGreaterThanOrEqual(0);
      expect(value).toBeLessThan(1);
    }
  });
});

describe('intBetween', () => {
  it('is inclusive at both ends', () => {
    const rng = makeRng(7);
    const seen = new Set<number>();
    for (let i = 0; i < 500; i += 1) seen.add(intBetween(rng, 1, 3));
    expect([...seen].sort()).toEqual([1, 2, 3]);
  });
});

describe('pick', () => {
  it('always returns a member of the list', () => {
    const rng = makeRng(3);
    const items = ['a', 'b', 'c'];
    for (let i = 0; i < 100; i += 1) expect(items).toContain(pick(rng, items));
  });

  it('throws on an empty list rather than returning undefined', () => {
    expect(() => pick(makeRng(1), [])).toThrow('pick from empty list');
  });
});

describe('jitter', () => {
  it('stays within +/- magnitude', () => {
    const rng = makeRng(5);
    for (let i = 0; i < 500; i += 1) {
      const value = jitter(rng, 4);
      expect(Math.abs(value)).toBeLessThanOrEqual(4);
    }
  });
});

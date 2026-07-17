import { facingsTotal, mean, pct, round2 } from './kpiMath';

describe('round2', () => {
  it('rounds to 2 decimal places', () => {
    expect(round2(1.005)).toBe(1);
    expect(round2(33.3333)).toBe(33.33);
    expect(round2(66.6666)).toBe(66.67);
  });

  it('leaves whole numbers unchanged', () => {
    expect(round2(0)).toBe(0);
    expect(round2(100)).toBe(100);
  });
});

describe('pct', () => {
  it('computes a percentage of numerator over denominator', () => {
    expect(pct(1, 4)).toBe(25);
    expect(pct(2, 3)).toBe(66.67);
  });

  it('returns 0 on a zero denominator instead of NaN', () => {
    expect(pct(5, 0)).toBe(0);
    expect(pct(0, 0)).toBe(0);
  });

  it('does not clamp above 100 when the numerator exceeds the denominator', () => {
    expect(pct(150, 100)).toBe(150);
  });
});

describe('mean', () => {
  it('averages a list of values, rounded to 2 decimals', () => {
    expect(mean([1, 2, 3])).toBe(2);
    expect(mean([1, 2])).toBe(1.5);
    expect(mean([10, 20, 25])).toBe(18.33);
  });

  it('returns 0 for an empty list instead of NaN', () => {
    expect(mean([])).toBe(0);
  });
});

describe('facingsTotal', () => {
  it('reads a numeric total off a plain object', () => {
    expect(facingsTotal({ total: 12 })).toBe(12);
  });

  it('returns 0 when total is missing, non-numeric, or non-finite', () => {
    expect(facingsTotal({})).toBe(0);
    expect(facingsTotal({ total: '12' })).toBe(0);
    expect(facingsTotal({ total: NaN })).toBe(0);
    expect(facingsTotal({ total: Infinity })).toBe(0);
  });

  it('returns 0 for non-object, null, or array input', () => {
    expect(facingsTotal(null)).toBe(0);
    expect(facingsTotal(undefined)).toBe(0);
    expect(facingsTotal('nope')).toBe(0);
    expect(facingsTotal([1, 2])).toBe(0);
  });
});

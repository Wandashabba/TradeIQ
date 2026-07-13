import { kpiThreshold } from './kpiThresholds';

describe('kpiThreshold', () => {
  it('reads a configured numeric key', () => {
    expect(kpiThreshold({ stockoutUnits: 5 }, 'stockoutUnits', 0)).toBe(5);
    expect(kpiThreshold({ priceDeviationPct: 30 }, 'priceDeviationPct', 10)).toBe(30);
  });

  it('falls back when the key is absent', () => {
    expect(kpiThreshold({}, 'stockoutUnits', 0)).toBe(0);
    expect(kpiThreshold({ green: 80 }, 'priceDeviationPct', 10)).toBe(10);
  });

  it('falls back when the key is not a finite number', () => {
    expect(kpiThreshold({ stockoutUnits: '5' }, 'stockoutUnits', 0)).toBe(0);
    expect(kpiThreshold({ stockoutUnits: NaN }, 'stockoutUnits', 0)).toBe(0);
    expect(kpiThreshold({ stockoutUnits: Infinity }, 'stockoutUnits', 0)).toBe(0);
    expect(kpiThreshold({ stockoutUnits: null }, 'stockoutUnits', 0)).toBe(0);
  });

  it('falls back when the column itself is not a plain object', () => {
    expect(kpiThreshold(null, 'stockoutUnits', 0)).toBe(0);
    expect(kpiThreshold(undefined, 'stockoutUnits', 7)).toBe(7);
    expect(kpiThreshold([1, 2], 'stockoutUnits', 0)).toBe(0);
    expect(kpiThreshold('nope', 'stockoutUnits', 0)).toBe(0);
  });

  it('accepts zero as an explicit configured value', () => {
    expect(kpiThreshold({ priceDeviationPct: 0 }, 'priceDeviationPct', 10)).toBe(0);
  });
});

import {
  predictCoverageDays,
  coverageStatus,
  exponentialSmoothing,
  forecastDemand,
  forecastCoverageDays,
} from './forecast.service';

describe('predictCoverageDays', () => {
  it('divides units available by average daily velocity', () => {
    expect(predictCoverageDays({ unitsAvailable: 40, velocityAvg: 10 })).toBe(4);
  });

  it('returns Infinity when velocity is zero', () => {
    expect(predictCoverageDays({ unitsAvailable: 40, velocityAvg: 0 })).toBe(Infinity);
  });
});

describe('coverageStatus', () => {
  it('flags red when under 3 days', () => {
    expect(coverageStatus(2)).toBe('red');
  });

  it('flags amber when under 7 days', () => {
    expect(coverageStatus(5)).toBe('amber');
  });

  it('flags green otherwise', () => {
    expect(coverageStatus(10)).toBe('green');
  });
});

describe('exponentialSmoothing', () => {
  it('smooths [10, 20, 30] with alpha 0.5 to 22.5', () => {
    // s0=10; s1=0.5*20+0.5*10=15; s2=0.5*30+0.5*15=22.5
    expect(exponentialSmoothing([10, 20, 30], 0.5)).toBe(22.5);
  });

  it('returns 0 for an empty series', () => {
    expect(exponentialSmoothing([], 0.5)).toBe(0);
  });

  it('with alpha 1 tracks the latest observation', () => {
    expect(exponentialSmoothing([10, 20, 30], 1)).toBe(30);
  });

  it('seeds with the first value for a single-point series', () => {
    expect(exponentialSmoothing([42], 0.3)).toBe(42);
  });

  it('rejects alpha outside (0, 1]', () => {
    expect(() => exponentialSmoothing([1, 2], 0)).toThrow();
    expect(() => exponentialSmoothing([1, 2], 1.5)).toThrow();
  });
});

describe('forecastDemand', () => {
  it('forecasts the next-period demand via SES, rounded to 2 dp', () => {
    expect(forecastDemand([10, 20, 30])).toBe(22.5);
  });

  it('returns 0 for an empty history', () => {
    expect(forecastDemand([])).toBe(0);
  });

  it('honours a custom alpha', () => {
    expect(forecastDemand([10, 20, 30], { alpha: 1 })).toBe(30);
  });
});

describe('forecastCoverageDays', () => {
  it('divides units available by the smoothed demand estimate', () => {
    // forecastDemand([10,20,30]) = 22.5; 45 / 22.5 = 2
    expect(forecastCoverageDays({ unitsAvailable: 45, salesHistory: [10, 20, 30] })).toBe(2);
  });

  it('returns Infinity when forecast demand is zero', () => {
    expect(forecastCoverageDays({ unitsAvailable: 40, salesHistory: [0, 0, 0] })).toBe(Infinity);
  });

  it('returns Infinity for an empty history', () => {
    expect(forecastCoverageDays({ unitsAvailable: 40, salesHistory: [] })).toBe(Infinity);
  });
});

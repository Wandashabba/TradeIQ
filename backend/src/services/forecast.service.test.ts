import { predictCoverageDays, coverageStatus } from './forecast.service';

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

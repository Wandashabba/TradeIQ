import { computeRoi } from './roi';

describe('computeRoi', () => {
  it('measures incremental revenue against spend', () => {
    // 5000 attributed, 2000 already selling anyway, 1000 spent.
    // Incremental 3000; return (3000 - 1000) / 1000 = 200%.
    const roi = computeRoi({ attributedRevenue: 5000, baselineRevenue: 2000, spend: 1000 });

    expect(roi.incrementalRevenue).toBe(3000);
    expect(roi.roiPct).toBe(200);
    expect(roi.unmeasurable).toBeNull();
  });

  it('reports a negative return when the campaign cost more than it added', () => {
    const roi = computeRoi({ attributedRevenue: 1200, baselineRevenue: 1000, spend: 500 });

    expect(roi.incrementalRevenue).toBe(200);
    expect(roi.roiPct).toBe(-60);
  });

  it('does not let a campaign take credit for the pre-existing baseline', () => {
    // Sold exactly what it was already selling: zero incremental, so the whole
    // spend is a loss. A model without a baseline would call this a 400% return.
    const roi = computeRoi({ attributedRevenue: 2000, baselineRevenue: 2000, spend: 500 });

    expect(roi.incrementalRevenue).toBe(0);
    expect(roi.roiPct).toBe(-100);
  });

  it('goes negative when the campaign period sold LESS than the baseline', () => {
    const roi = computeRoi({ attributedRevenue: 800, baselineRevenue: 2000, spend: 400 });

    expect(roi.incrementalRevenue).toBe(-1200);
    expect(roi.roiPct).toBe(-400);
  });

  it('is unmeasurable, not zero, when no budget is recorded', () => {
    // 0% would read as "broke even"; infinity as "infinitely profitable".
    // Neither is a measurement of anything.
    const roi = computeRoi({ attributedRevenue: 5000, baselineRevenue: 1000, spend: null });

    expect(roi.roiPct).toBeNull();
    expect(roi.unmeasurable).toBe('no_budget');
    // The revenue figures are still real and still reported.
    expect(roi.incrementalRevenue).toBe(4000);
  });

  it('is unmeasurable on a zero budget rather than dividing by zero', () => {
    const roi = computeRoi({ attributedRevenue: 5000, baselineRevenue: 1000, spend: 0 });

    expect(roi.roiPct).toBeNull();
    expect(roi.unmeasurable).toBe('zero_budget');
    expect(Number.isFinite(roi.incrementalRevenue)).toBe(true);
  });

  it('rounds money to two places rather than leaking float noise', () => {
    const roi = computeRoi({ attributedRevenue: 10.1, baselineRevenue: 3.3, spend: 2 });

    // 10.1 - 3.3 is 6.800000000000001 in IEEE-754.
    expect(roi.incrementalRevenue).toBe(6.8);
    expect(roi.roiPct).toBe(240);
  });

  it('handles a campaign with no orders at all', () => {
    const roi = computeRoi({ attributedRevenue: 0, baselineRevenue: 0, spend: 750 });

    expect(roi.incrementalRevenue).toBe(0);
    expect(roi.roiPct).toBe(-100);
  });
});

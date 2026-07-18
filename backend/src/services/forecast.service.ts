// REAL logic (not a stub) — simple velocity-based coverage-days formula per
// the Phase 1 spec. Per-SKU ML demand forecasting is Phase 2+ (tracked in
// docs/architecture/stubs-and-interfaces.md).

import { round2 } from '../lib/kpiMath';

export function predictCoverageDays(input: { unitsAvailable: number; velocityAvg: number }): number {
  if (input.velocityAvg <= 0) return Infinity;
  return input.unitsAvailable / input.velocityAvg;
}

export type CoverageStatus = 'red' | 'amber' | 'green';

export function coverageStatus(coverageDays: number): CoverageStatus {
  if (coverageDays < 3) return 'red';
  if (coverageDays < 7) return 'amber';
  return 'green';
}

// ── Phase 2 upgrade: statistical demand forecasting ────────────────────────
//
// The Phase-1 `predictCoverageDays` above uses a single point estimate of
// velocity. Phase 2 replaces that point estimate with a genuine time-series
// method — Simple Exponential Smoothing (SES) over the SKU's realised sales
// history — so recent demand is weighted more heavily than stale observations
// while still using the whole series (not just the latest reading).

/**
 * Simple Exponential Smoothing (SES). Returns the smoothed forecast for the
 * next period: s_t = alpha*x_t + (1-alpha)*s_{t-1}, seeded with s_0 = series[0].
 *
 * @param series historical observations, oldest → newest.
 * @param alpha  smoothing factor in (0, 1]; higher = more reactive to recent data.
 * @returns the next-period forecast, or 0 for an empty series.
 */
export function exponentialSmoothing(series: number[], alpha = 0.5): number {
  if (!(alpha > 0 && alpha <= 1)) {
    throw new Error('alpha must be in the interval (0, 1]');
  }
  if (series.length === 0) return 0;
  let smoothed = series[0];
  for (let i = 1; i < series.length; i += 1) {
    smoothed = alpha * series[i] + (1 - alpha) * smoothed;
  }
  return smoothed;
}

/**
 * Forecast next-period demand from a sales history using SES. Never negative,
 * rounded to 2 decimal places.
 */
export function forecastDemand(salesHistory: number[], opts?: { alpha?: number }): number {
  const smoothed = exponentialSmoothing(salesHistory, opts?.alpha ?? 0.5);
  return round2(Math.max(0, smoothed));
}

/**
 * Coverage-days from a smoothed demand estimate. This is the Phase-2 successor
 * to `predictCoverageDays`: it replaces the point-velocity estimate with a
 * smoothed-demand estimate derived from the full sales history.
 *
 * @returns days of cover, or Infinity when forecast demand is zero/negative.
 */
export function forecastCoverageDays(input: {
  unitsAvailable: number;
  salesHistory: number[];
}): number {
  const predictedDailyDemand = forecastDemand(input.salesHistory);
  if (predictedDailyDemand <= 0) return Infinity;
  return round2(input.unitsAvailable / predictedDailyDemand);
}

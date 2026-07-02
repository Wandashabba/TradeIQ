// REAL logic (not a stub) — simple velocity-based coverage-days formula per
// the Phase 1 spec. Per-SKU ML demand forecasting is Phase 2+ (tracked in
// docs/architecture/stubs-and-interfaces.md).

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

export function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

/** Ratio helper that returns 0 (never NaN) on an empty denominator. */
export function pct(numerator: number, denominator: number): number {
  return denominator > 0 ? round2((100 * numerator) / denominator) : 0;
}

export function mean(values: number[]): number {
  return values.length > 0 ? round2(values.reduce((sum, v) => sum + v, 0) / values.length) : 0;
}

/**
 * On-shelf availability over a set of stock lines: 100 * (lines with stock) /
 * (lines that were COUNTED).
 *
 * `unitsAvailable === null` means nobody reached that SKU (#389), so such a
 * line leaves the ratio entirely — it is neither on the shelf nor off it. It
 * used to arrive as 0 and drag the percentage down as if the shelf were empty.
 *
 * Shared by the dashboard, the trends series and the per-visit scorecard for
 * the same reason `pct`/`facingsTotal` are shared: three copies of one formula
 * is how two tiles come to disagree (#93). The SQL aggregates that compute this
 * in Postgres (`trends.getAvailabilityTrend`, `pillars.getStockLevels`) carry
 * the matching `units_available IS NOT NULL` filter.
 */
export function onShelfAvailabilityPct(lines: { unitsAvailable: number | null }[]): number {
  const counted = lines.filter((line) => line.unitsAvailable !== null);
  return pct(counted.filter((line) => line.unitsAvailable! > 0).length, counted.length);
}

/** Safely read the `.total` field out of a facingsCount Json column. */
export function facingsTotal(value: unknown): number {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    return 0;
  }
  const total = (value as Record<string, unknown>).total;
  return typeof total === 'number' && Number.isFinite(total) ? total : 0;
}

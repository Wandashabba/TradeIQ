export function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

/** Ratio helper that returns 0 (never NaN) on an empty denominator. */
export function pct(numerator: number, denominator: number): number {
  return denominator > 0 ? round2((100 * numerator) / denominator) : 0;
}

/**
 * A mean from totals the caller already holds — the same division and rounding
 * {@link mean} does, for callers whose sum and count were produced by a SQL
 * aggregate rather than by folding an array in Node.
 *
 * `mean` is defined in terms of this rather than beside it, so there is one
 * implementation of "divide, round to 2, and call an empty set 0" and not two
 * that can drift (#93).
 *
 * The one difference it cannot remove: Postgres sums `double precision` in scan
 * order and `mean` sums in array order, so the two can disagree in the last
 * bits of a long float sum. `round2` hides that unless the mean lands within
 * ~1e-12 of a half-cent boundary.
 */
export function meanOf(sum: number, count: number): number {
  return count > 0 ? round2(sum / count) : 0;
}

export function mean(values: number[]): number {
  return meanOf(
    values.reduce((sum, v) => sum + v, 0),
    values.length,
  );
}

/**
 * On-shelf availability over a set of stock lines: 100 * (lines with stock) /
 * (lines that were COUNTED).
 *
 * `unitsAvailable === null` means nobody reached that SKU (#389), so such a
 * line leaves the ratio entirely — it is neither on the shelf nor off it. It
 * used to arrive as 0 and drag the percentage down as if the shelf were empty.
 *
 * Shared by the trends series and the per-visit scorecard for the same reason
 * `pct`/`facingsTotal` are shared: three copies of one formula is how two tiles
 * come to disagree (#93). The SQL aggregates that compute this in Postgres
 * (`dashboard.service`, `trends.getAvailabilityTrend`, `pillars.getStockLevels`)
 * count the two sides of the ratio in the database and hand them to `pct`, and
 * every one of them carries the matching `units_available IS NOT NULL` filter.
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

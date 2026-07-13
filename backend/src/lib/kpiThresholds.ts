/**
 * Read one numeric threshold from a client's `kpiThresholds` Json column
 * (editable at runtime via PATCH /clients/me), falling back to the built-in
 * default when the column or key is absent or not a finite number.
 */
export function kpiThreshold(kpiThresholds: unknown, key: string, fallback: number): number {
  if (typeof kpiThresholds !== 'object' || kpiThresholds === null || Array.isArray(kpiThresholds)) {
    return fallback;
  }
  const value = (kpiThresholds as Record<string, unknown>)[key];
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

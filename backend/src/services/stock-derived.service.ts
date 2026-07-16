// REAL logic (not a stub) — pure derivation of daysOutOfStock/velocityAvg from
// VisitStock history, replacing the field-agent-typed numbers the S2 stock-audit
// screen used to ask for (neither is observable at a shelf). See #112.

export interface StockHistoryRow {
  visitCheckinTs: Date;
  unitsAvailable: number;
}

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/**
 * Days since the most recent prior row with stock on hand. `history` must be
 * newest-first. No prior in-stock row → 0 (no history yet, not "out of stock
 * forever"). This is a visit-cadence approximation: exact for daily beats,
 * coarser for weekly ones — a week-cadence outlet reads "7 days out" even if
 * it ran out only 2 days before the visit.
 */
export function computeDaysOutOfStock(history: StockHistoryRow[], asOfCheckinTs: Date): number {
  const lastInStock = history.find((row) => row.unitsAvailable > 0);
  if (!lastInStock) return 0;
  const days = (asOfCheckinTs.getTime() - lastInStock.visitCheckinTs.getTime()) / MS_PER_DAY;
  return days > 0 ? Math.round(days) : 0;
}

/**
 * Average consumption per day across adjacent visit-pairs in `history`
 * (newest-first). A restock (units go up between visits) contributes 0 to
 * that interval rather than a negative rate. Fewer than 2 rows → 0.
 */
export function computeVelocityAvg(history: StockHistoryRow[]): number {
  const rates: number[] = [];
  for (let i = 0; i < history.length - 1; i += 1) {
    const newer = history[i];
    const older = history[i + 1];
    const daysBetween = (newer.visitCheckinTs.getTime() - older.visitCheckinTs.getTime()) / MS_PER_DAY;
    if (daysBetween <= 0) continue; // e.g. a same-visit re-submission — don't divide by zero
    const consumed = Math.max(0, older.unitsAvailable - newer.unitsAvailable);
    rates.push(consumed / daysBetween);
  }
  if (rates.length === 0) return 0;
  return Math.round((rates.reduce((sum, r) => sum + r, 0) / rates.length) * 100) / 100;
}

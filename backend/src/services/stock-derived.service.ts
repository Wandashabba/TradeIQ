// REAL logic (not a stub) — pure derivation of daysOutOfStock/velocityAvg from
// VisitStock history, replacing the field-agent-typed numbers the S2 stock-audit
// screen used to ask for (neither is observable at a shelf). See #112.

import { Prisma } from '@prisma/client';
import { prisma } from '../lib/prisma';

export interface StockHistoryRow {
  visitCheckinTs: Date;
  /**
   * Always a real count. Uncounted lines (`units_available IS NULL`, #389) are
   * dropped by {@link fetchStockHistoryForOutlet} before they get here: an
   * uncounted shelf is not evidence of a level, so it can neither anchor
   * days-out-of-stock nor imply consumption between two visits.
   */
  unitsAvailable: number;
}

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/**
 * Days since the most recent prior row with stock on hand. `history` must be
 * newest-first. No prior in-stock row → 0 (no history yet, not "out of stock
 * forever"). This is a visit-cadence approximation: exact for daily beats,
 * coarser for weekly ones — a week-cadence outlet reads "7 days out" even if
 * it ran out only 2 days before the visit.
 *
 * `lastInStockTs` is when this outlet last counted the SKU with stock on hand,
 * over its WHOLE history (see {@link fetchLastInStockForOutlet}). Pass it
 * whenever it is known. `history` is only the last five counts, so without it a
 * shelf that has been empty for longer than five visits finds no in-stock row
 * and reads 0 days — hiding exactly the chronic stock-outs a manager most needs
 * to see (#360). `null` means the SKU has never been counted in stock here.
 */
export function computeDaysOutOfStock(
  history: StockHistoryRow[],
  asOfCheckinTs: Date,
  lastInStockTs?: Date | null,
): number {
  const anchor =
    lastInStockTs !== undefined
      ? lastInStockTs
      : (history.find((row) => row.unitsAvailable > 0)?.visitCheckinTs ?? null);
  if (!anchor) return 0;
  const days = (asOfCheckinTs.getTime() - anchor.getTime()) / MS_PER_DAY;
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

const HISTORY_WINDOW = 5;

interface RankedStockRow {
  sku_id: string;
  units_available: number;
  checkin_ts: Date;
}

/**
 * One query for every SKU's stock history at this outlet, capped at the
 * last 5 VisitStock rows per SKU (newest-first) via a window function --
 * Postgres does the per-SKU capping, so this is a single bounded round trip
 * regardless of how much history the outlet has accumulated (#120; the
 * earlier fetch-all-then-slice-in-memory version had no bound on the initial
 * fetch, matching the pattern dashboard.service.ts's getDashboardByTerritory
 * uses for its own N+1 fix, #97, but without that fix's "small dataset"
 * assumption holding here as history grows).
 */
export async function fetchStockHistoryForOutlet(
  outletId: string,
  clientId: string,
): Promise<Map<string, StockHistoryRow[]>> {
  const rows = await prisma.$queryRaw<RankedStockRow[]>(
    Prisma.sql`
      SELECT sku_id, units_available, checkin_ts
      FROM (
        SELECT vs.sku_id, vs.units_available, v.checkin_ts,
          ROW_NUMBER() OVER (
            PARTITION BY vs.sku_id
            ORDER BY v.checkin_ts DESC, vs.created_at DESC
          ) AS rn
        FROM visit_stock vs
        JOIN visits v ON v.id = vs.visit_id
        WHERE v.outlet_id = ${outletId} AND v.client_id = ${clientId}
          -- An uncounted line is not a count (#389). Excluding it here rather
          -- than downstream keeps the five-row window meaning "the last five
          -- times anyone actually looked", so a half-finished visit cannot
          -- push real history out of the velocity window.
          AND vs.units_available IS NOT NULL
      ) ranked
      WHERE rn <= ${HISTORY_WINDOW}
      ORDER BY sku_id, checkin_ts DESC
    `,
  );

  const bySku = new Map<string, StockHistoryRow[]>();
  for (const row of rows) {
    const list = bySku.get(row.sku_id) ?? [];
    list.push({ visitCheckinTs: row.checkin_ts, unitsAvailable: row.units_available });
    bySku.set(row.sku_id, list);
  }
  return bySku;
}

interface LastInStockRow {
  sku_id: string;
  last_in_stock_ts: Date;
}

/**
 * When each SKU was last counted with stock on hand at this outlet, over the
 * outlet's entire history — the start of any out-of-stock run still going.
 *
 * Separate from {@link fetchStockHistoryForOutlet} on purpose: velocity needs
 * the last few adjacent counts and nothing older, while days-out-of-stock needs
 * one timestamp that may be any distance back (#360). One grouped query, so it
 * stays a single round trip however long the run has lasted. A SKU absent from
 * the map has never been in stock here.
 */
export async function fetchLastInStockForOutlet(
  outletId: string,
  clientId: string,
): Promise<Map<string, Date>> {
  const rows = await prisma.$queryRaw<LastInStockRow[]>(
    Prisma.sql`
      SELECT vs.sku_id, MAX(v.checkin_ts) AS last_in_stock_ts
      FROM visit_stock vs
      JOIN visits v ON v.id = vs.visit_id
      WHERE v.outlet_id = ${outletId} AND v.client_id = ${clientId}
        AND vs.units_available > 0
      GROUP BY vs.sku_id
    `,
  );
  return new Map(rows.map((row) => [row.sku_id, row.last_in_stock_ts]));
}

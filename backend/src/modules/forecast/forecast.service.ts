import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
import { forecastCoverageDays, forecastDemand } from '../../services/forecast.service';
import { getClientTimeZone } from '../clients/clients.service';
import { trailingLocalDays } from '../salesTargets/salesMonth';

/** Complete local days of sell-in the forecast looks back over. */
export const FORECAST_HISTORY_DAYS = 28;

export interface ForecastFilters {
  clientId: string;
  skuId: string;
  outletId?: string;
}

export interface SkuForecast {
  skuId: string;
  method: 'exponential_smoothing';
  /** Where `historyPoints` come from — see `getSkuForecast`. */
  historySource: 'sell_in_orders';
  historyDays: number;
  /** Units ordered per local calendar day, oldest first, zero-filled. */
  historyPoints: number[];
  forecastNextPeriod: number;
  forecastCoverageDays: number;
}

/**
 * Build a per-SKU demand forecast from the SKU's order-derived sell-in.
 *
 * ## Input series — changed in #119
 *
 * The series is **sell-in from orders**: for each of the last
 * {@link FORECAST_HISTORY_DAYS} complete local calendar days in
 * `Client.timezone`, the units of this SKU on the client's non-cancelled
 * orders placed that day (optionally at one outlet), oldest first. A day with
 * no orders is a real 0, not a gap — every order goes through TradeIQ, so an
 * absent order is an observed absence.
 *
 * It used to be the `salesActual` of every `VisitStock` row for the SKU. That
 * was a number agents typed at the shelf with no way to know it (#112); once
 * the S2 form stopped asking for it the series thinned to nothing, and each
 * point was "one visit" rather than a unit of time, so the smoothed figure had
 * no period. `VisitStock.salesActual` is no longer read here.
 *
 * Sell-in is what outlets ordered, not what shoppers bought, so this forecasts
 * ordering demand. Today is excluded because it is still filling up.
 *
 * Coverage-days still divides the latest observed on-shelf units (the one
 * thing an agent does count) by the forecast daily demand.
 */
export async function getSkuForecast(filters: ForecastFilters, now: Date = new Date()): Promise<SkuForecast> {
  const sku = await prisma.sku.findFirst({
    where: { id: filters.skuId, clientId: filters.clientId },
    select: { id: true },
  });
  if (!sku) {
    throw new NotFoundError('SKU not found');
  }

  const timeZone = await getClientTimeZone(filters.clientId);
  const { dates, from, to } = trailingLocalDays(now, FORECAST_HISTORY_DAYS, timeZone);

  const [daily, latestStock] = await Promise.all([
    // `created_at` is `timestamp without time zone` holding UTC: read it as UTC
    // first, then take its date on the client's wall clock.
    prisma.$queryRaw<Array<{ day: Date; units: bigint | number }>>`
      SELECT ((o."created_at" AT TIME ZONE 'UTC') AT TIME ZONE ${timeZone})::date AS "day",
        SUM(ol."quantity")::bigint AS "units"
      FROM "order_lines" ol
      JOIN "orders" o ON o."id" = ol."order_id"
      WHERE o."client_id" = ${filters.clientId}
        AND ol."sku_id" = ${filters.skuId}
        AND o."status" <> 'cancelled'
        AND o."created_at" >= ${from.toISOString()}::timestamp
        AND o."created_at" < ${to.toISOString()}::timestamp
        ${filters.outletId ? Prisma.sql`AND o."outlet_id" = ${filters.outletId}` : Prisma.empty}
      GROUP BY 1
    `,
    prisma.visitStock.findFirst({
      where: {
        skuId: filters.skuId,
        visit: {
          clientId: filters.clientId,
          ...(filters.outletId ? { outletId: filters.outletId } : {}),
        },
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      select: { unitsAvailable: true },
    }),
  ]);

  const unitsByDay = new Map(daily.map((row) => [row.day.toISOString().slice(0, 10), Number(row.units)]));
  const historyPoints = dates.map((date) => unitsByDay.get(date.toISOString().slice(0, 10)) ?? 0);

  return {
    skuId: filters.skuId,
    method: 'exponential_smoothing',
    historySource: 'sell_in_orders',
    historyDays: FORECAST_HISTORY_DAYS,
    historyPoints,
    forecastNextPeriod: forecastDemand(historyPoints),
    forecastCoverageDays: forecastCoverageDays({
      unitsAvailable: latestStock?.unitsAvailable ?? 0,
      salesHistory: historyPoints,
    }),
  };
}

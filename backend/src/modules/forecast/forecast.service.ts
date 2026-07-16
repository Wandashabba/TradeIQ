import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
import { forecastCoverageDays, forecastDemand } from '../../services/forecast.service';

export interface ForecastFilters {
  clientId: string;
  skuId: string;
  outletId?: string;
}

export interface SkuForecast {
  skuId: string;
  method: 'exponential_smoothing';
  historyPoints: number[];
  forecastNextPeriod: number;
  forecastCoverageDays: number;
}

/**
 * Build a per-SKU demand forecast from the SKU's realised sales history.
 *
 * The history series is the `salesActual` of every VisitStock row captured for
 * this SKU within the caller's client (optionally narrowed to a single outlet),
 * ordered oldest → newest. Coverage-days is projected from the smoothed demand
 * against the latest known on-shelf units.
 */
export async function getSkuForecast(filters: ForecastFilters): Promise<SkuForecast> {
  const sku = await prisma.sku.findFirst({
    where: { id: filters.skuId, clientId: filters.clientId },
    select: { id: true },
  });
  if (!sku) {
    throw new NotFoundError('SKU not found');
  }

  const rows = await prisma.visitStock.findMany({
    where: {
      skuId: filters.skuId,
      visit: {
        clientId: filters.clientId,
        ...(filters.outletId ? { outletId: filters.outletId } : {}),
      },
    },
    orderBy: { createdAt: 'asc' },
    select: { salesActual: true, unitsAvailable: true },
  });

  const historyPoints = rows
    .map((row) => row.salesActual)
    .filter((salesActual): salesActual is number => salesActual !== null);
  const latestUnitsAvailable = rows.length > 0 ? rows[rows.length - 1].unitsAvailable : 0;

  return {
    skuId: filters.skuId,
    method: 'exponential_smoothing',
    historyPoints,
    forecastNextPeriod: forecastDemand(historyPoints),
    forecastCoverageDays: forecastCoverageDays({
      unitsAvailable: latestUnitsAvailable,
      salesHistory: historyPoints,
    }),
  };
}

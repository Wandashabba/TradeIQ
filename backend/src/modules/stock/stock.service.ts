import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
import { predictCoverageDays } from '../../services/forecast.service';

export interface RecordStockInput {
  visitId: string;
  skuId: string;
  unitsAvailable: number;
  lastStockinDate: Date;
  daysOutOfStock: number;
  velocityAvg: number;
  salesActual: number;
  salesTarget: number;
  clientId: string;
}

export async function recordStock(input: RecordStockInput) {
  const [visit, sku] = await Promise.all([
    prisma.visit.findFirst({ where: { id: input.visitId, clientId: input.clientId } }),
    prisma.sku.findFirst({ where: { id: input.skuId, clientId: input.clientId } }),
  ]);
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }
  if (!sku) {
    throw new NotFoundError('Sku not found');
  }

  const coverageDaysPredicted = predictCoverageDays({
    unitsAvailable: input.unitsAvailable,
    velocityAvg: input.velocityAvg,
  });

  return prisma.visitStock.create({
    data: {
      visitId: input.visitId,
      skuId: input.skuId,
      unitsAvailable: input.unitsAvailable,
      lastStockinDate: input.lastStockinDate,
      daysOutOfStock: input.daysOutOfStock,
      velocityAvg: input.velocityAvg,
      coverageDaysPredicted,
      salesActual: input.salesActual,
      salesTarget: input.salesTarget,
    },
  });
}

import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
import { predictCoverageDays } from '../../services/forecast.service';

export interface StockItemInput {
  skuId: string;
  unitsAvailable: number;
  lastStockinDate: string; // ISO
  daysOutOfStock: number;
  velocityAvg: number;
  salesActual: number;
  salesTarget: number;
}

export interface RecordStockInput {
  visitId: string;
  clientId: string;
  items: StockItemInput[];
}

// predictCoverageDays returns Infinity when velocityAvg <= 0, which a Postgres
// Float column can't store — clamp it to 0 (route validation also guards this).
function coverageFor(item: StockItemInput): number {
  const coverage = predictCoverageDays({
    unitsAvailable: item.unitsAvailable,
    velocityAvg: item.velocityAvg,
  });
  return Number.isFinite(coverage) ? coverage : 0;
}

export async function listStockForVisit(visitId: string, clientId: string) {
  const visit = await prisma.visit.findFirst({ where: { id: visitId, clientId } });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }
  return prisma.visitStock.findMany({
    where: { visitId },
    orderBy: { createdAt: 'desc' },
  });
}

export async function recordStock(input: RecordStockInput) {
  const visit = await prisma.visit.findFirst({
    where: { id: input.visitId, clientId: input.clientId },
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }

  const skuIds = input.items.map((i) => i.skuId);
  const skus = await prisma.sku.findMany({
    where: { id: { in: skuIds }, clientId: input.clientId },
    select: { id: true },
  });
  const validSkuIds = new Set(skus.map((s) => s.id));
  const unknown = skuIds.find((id) => !validSkuIds.has(id));
  if (unknown) {
    throw new NotFoundError(`SKU not found: ${unknown}`);
  }

  return prisma.$transaction(
    input.items.map((item) =>
      prisma.visitStock.create({
        data: {
          visitId: input.visitId,
          skuId: item.skuId,
          unitsAvailable: item.unitsAvailable,
          lastStockinDate: new Date(item.lastStockinDate),
          daysOutOfStock: item.daysOutOfStock,
          velocityAvg: item.velocityAvg,
          coverageDaysPredicted: coverageFor(item),
          salesActual: item.salesActual,
          salesTarget: item.salesTarget,
        },
      }),
    ),
  );
}

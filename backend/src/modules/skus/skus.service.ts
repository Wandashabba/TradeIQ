import { prisma } from '../../lib/prisma';
import { computeDaysOutOfStock, computeVelocityAvg, fetchStockHistoryForOutlet } from '../../services/stock-derived.service';

export async function listSkusForClient(clientId: string, outletId: string) {
  const [skus, historyBySku] = await Promise.all([
    prisma.sku.findMany({ where: { clientId }, orderBy: { name: 'asc' } }),
    fetchStockHistoryForOutlet(outletId, clientId),
  ]);
  const asOf = new Date();
  return skus.map((sku) => {
    const history = historyBySku.get(sku.id) ?? [];
    return {
      ...sku,
      daysOutOfStock: computeDaysOutOfStock(history, asOf),
      velocityAvg: computeVelocityAvg(history),
    };
  });
}

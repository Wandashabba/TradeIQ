import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
import { predictCoverageDays } from '../../services/forecast.service';
import { computeSlaDueAt } from '../../lib/slaClock';
import { kpiThreshold } from '../../lib/kpiThresholds';

// Auto-task creation threshold for stock-outs (issue #47): an item with at
// most this many units counts as out of stock. Clients override the default
// via kpiThresholds.stockoutUnits (PATCH /clients/me, issue #46).
const DEFAULT_STOCKOUT_UNITS_THRESHOLD = 0;
const STOCKOUT_FINDING_TYPE = 'stockout';

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

  const rows = await prisma.$transaction(
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

  // Auto-create a follow-up Task for every out-of-stock SKU, mirroring the
  // risks module's flag -> task pattern (issue #47). Deduplicated by
  // (visitId, findingType, requiredFix) so re-submitting the section is
  // idempotent. Task creation is best-effort: a failure here must not fail the
  // already-persisted stock capture.
  await createStockoutTasks(input.visitId, input.clientId, visit.outletId, visit.agentId, input.items);

  return rows;
}

async function createStockoutTasks(
  visitId: string,
  clientId: string,
  outletId: string,
  agentId: string,
  items: StockItemInput[],
): Promise<void> {
  try {
    const client = await prisma.client.findUnique({
      where: { id: clientId },
      select: { kpiThresholds: true },
    });
    const unitsThreshold = kpiThreshold(
      client?.kpiThresholds,
      'stockoutUnits',
      DEFAULT_STOCKOUT_UNITS_THRESHOLD,
    );

    const stockouts = items.filter((item) => item.unitsAvailable <= unitsThreshold);
    if (stockouts.length === 0) return;

    const existing = await prisma.task.findMany({
      where: { visitId, findingType: STOCKOUT_FINDING_TYPE },
      select: { requiredFix: true },
    });
    const existingFixes = new Set(existing.map((t) => t.requiredFix));

    const now = new Date();
    for (const item of stockouts) {
      const requiredFix = `Restock SKU ${item.skuId}`;
      if (existingFixes.has(requiredFix)) continue; // dedup: skip already-open task
      await prisma.task.create({
        data: {
          visitId,
          findingType: STOCKOUT_FINDING_TYPE,
          outletId,
          requiredFix,
          priority: 'high',
          slaDueAt: computeSlaDueAt('high', now),
          ownerId: agentId,
        },
      });
      existingFixes.add(requiredFix); // guard against duplicate SKUs in one payload
    }
  } catch {
    // Swallow: stock capture already succeeded; task backfill is low-risk (#47).
  }
}

import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';
import { NotFoundError, ValidationError } from '../../middleware/errorHandler';
import { predictCoverageDays } from '../../services/forecast.service';
import {
  computeDaysOutOfStock,
  computeVelocityAvg,
  fetchStockHistoryForOutlet,
} from '../../services/stock-derived.service';
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
  salesActual?: number;
  salesTarget?: number;
}

export interface RecordStockInput {
  visitId: string;
  clientId: string;
  agentId: string;
  items: StockItemInput[];
}

// Shared between the route (a cheap, immediate 400 before any DB call) and
// recordStock itself (the actual enforcement point, so the invariant holds
// for any caller — script, admin tool, future bulk-import path — not just
// the one route that happens to exist today, #121). Kept as one function so
// the two call sites can't drift onto different definitions of "duplicate".
export const DUPLICATE_SKU_ID_MESSAGE = 'items[] must not contain duplicate skuId values';

export function hasDuplicateSkuIds(items: Pick<StockItemInput, 'skuId'>[]): boolean {
  const skuIds = items.map((item) => item.skuId);
  return new Set(skuIds).size !== skuIds.length;
}

// predictCoverageDays returns Infinity when velocityAvg <= 0, which a Postgres
// Float column can't store — clamp it to 0 (route validation also guards this).
function coverageFor(unitsAvailable: number, velocityAvg: number): number {
  const coverage = predictCoverageDays({ unitsAvailable, velocityAvg });
  return Number.isFinite(coverage) ? coverage : 0;
}

  // Bounded by one visit's children rather than a whole tenant, so this is
  // consistency work, not an OOM fix — but a caller should not have to know
  // which lists carry an envelope and which do not.
export async function listStockForVisit(
  visitId: string,
  clientId: string,
  page: { limit: number; cursor?: string },
) {
  const visit = await prisma.visit.findFirst({ where: { id: visitId, clientId } });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }
  const rows = await prisma.visitStock.findMany({
    where: { visitId },
    // Tiebreaker direction matches the primary sort — see alerts.service.ts.
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: page.limit + 1,
    ...(page.cursor ? { cursor: { id: page.cursor }, skip: 1 } : {}),
  });

  return buildPage(rows, page.limit);
}

export async function recordStock(input: RecordStockInput) {
  const visit = await prisma.visit.findFirst({
    where: { id: input.visitId, clientId: input.clientId, agentId: input.agentId },
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }

  if (hasDuplicateSkuIds(input.items)) {
    throw new ValidationError(DUPLICATE_SKU_ID_MESSAGE);
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

  // daysOutOfStock/velocityAvg are neither observable at a shelf nor
  // trustworthy when field-agent-typed — derive both server-side from the
  // outlet's VisitStock history instead (#112).
  const historyBySku = await fetchStockHistoryForOutlet(visit.outletId, input.clientId);

  const rows = await prisma.$transaction(
    input.items.map((item) => {
      const history = historyBySku.get(item.skuId) ?? [];
      const daysOutOfStock = computeDaysOutOfStock(history, visit.checkinTs);
      const velocityAvg = computeVelocityAvg(history);
      return prisma.visitStock.create({
        data: {
          visitId: input.visitId,
          skuId: item.skuId,
          unitsAvailable: item.unitsAvailable,
          lastStockinDate: new Date(item.lastStockinDate),
          daysOutOfStock,
          velocityAvg,
          coverageDaysPredicted: coverageFor(item.unitsAvailable, velocityAvg),
          salesActual: item.salesActual ?? null,
          salesTarget: item.salesTarget ?? null,
        },
      });
    }),
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

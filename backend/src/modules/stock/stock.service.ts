import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';
import { NotFoundError, ValidationError } from '../../middleware/errorHandler';
import { predictCoverageDays } from '../../services/forecast.service';
import {
  computeDaysOutOfStock,
  computeVelocityAvg,
  fetchLastInStockForOutlet,
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
  /**
   * Units on the shelf, or null when the agent never reached this SKU (#389).
   *
   * An omitted field is read as null for the same reason, so a part-finished
   * count is expressible either way. What it is NOT is 0: a counted 0 is a
   * finding and still raises the stock-out task below.
   */
  unitsAvailable: number | null;
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
//
// An uncounted line has no coverage to predict, and 0 would read as "no cover
// left", the loudest thing this figure can say. It is null instead (#389).
function coverageFor(unitsAvailable: number | null, velocityAvg: number): number | null {
  if (unitsAvailable === null) return null;
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

  // One normalisation, here, so "field absent" and "field null" cannot mean
  // different things further down: both are "not counted" (#389). Every check
  // below can then compare against `null` alone.
  const items: StockItemInput[] = input.items.map((item) => ({
    ...item,
    unitsAvailable: item.unitsAvailable ?? null,
  }));

  const skuIds = items.map((i) => i.skuId);
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
  //
  // Days out of stock anchors on the last in-stock count over the outlet's
  // whole history, not the five-count velocity window, so a chronic stock-out
  // keeps counting up instead of reading 0 (#360).
  const [historyBySku, lastInStockBySku] = await Promise.all([
    fetchStockHistoryForOutlet(visit.outletId, input.clientId),
    fetchLastInStockForOutlet(visit.outletId, input.clientId),
  ]);

  const rows = await prisma.$transaction(
    items.map((item) => {
      const history = historyBySku.get(item.skuId) ?? [];
      const daysOutOfStock = computeDaysOutOfStock(
        history,
        visit.checkinTs,
        lastInStockBySku.get(item.skuId) ?? null,
      );
      const velocityAvg = computeVelocityAvg(history);
      return prisma.visitStock.create({
        data: {
          visitId: input.visitId,
          skuId: item.skuId,
          unitsAvailable: item.unitsAvailable ?? null,
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
  await createStockoutTasks(input.visitId, input.clientId, visit.outletId, visit.agentId, items);

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

    // An uncounted SKU is not a stock-out (#389). Before nulls existed, a
    // part-finished count sent 0 for everything the agent had not reached and
    // this line opened a high-priority restock task for each of them — the
    // store was accused of being empty of things nobody had looked at.
    const stockouts = items.filter(
      (item) => item.unitsAvailable !== null && item.unitsAvailable <= unitsThreshold,
    );
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

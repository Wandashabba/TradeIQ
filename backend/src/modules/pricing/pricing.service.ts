import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
import { extractPriceFromPhoto } from '../../services/ocr.stub';
import { computeSlaDueAt } from '../../lib/slaClock';
import { kpiThreshold } from '../../lib/kpiThresholds';

// Auto-task creation threshold for shelf-price deviation (issue #47): a ±10%
// deviation is the default flag. Clients override the default via
// kpiThresholds.priceDeviationPct (PATCH /clients/me, issue #46).
const DEFAULT_PRICE_DEVIATION_THRESHOLD_PCT = 10;
const PRICE_DEVIATION_FINDING_TYPE = 'price_deviation';

export interface PricingItemInput {
  skuId: string;
  priceActual: number;
  promoActive: boolean;
  promoMaterialsDetected: Prisma.InputJsonValue;
  commsRating: number;
}

export interface RecordPricingInput {
  visitId: string;
  clientId: string;
  agentId: string;
  items: PricingItemInput[];
}

export async function listPricingForVisit(visitId: string, clientId: string) {
  const visit = await prisma.visit.findFirst({ where: { id: visitId, clientId } });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }
  return prisma.visitPricing.findMany({
    where: { visitId },
    orderBy: { createdAt: 'desc' },
  });
}

export async function recordPricing(input: RecordPricingInput) {
  const visit = await prisma.visit.findFirst({
    where: { id: input.visitId, clientId: input.clientId, agentId: input.agentId },
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }

  const skuIds = input.items.map((i) => i.skuId);
  const skus = await prisma.sku.findMany({
    where: { id: { in: skuIds }, clientId: input.clientId },
    select: { id: true, rrp: true },
  });
  const rrpBySkuId = new Map(skus.map((s) => [s.id, s.rrp]));
  const unknown = skuIds.find((id) => !rrpBySkuId.has(id));
  if (unknown) {
    throw new NotFoundError(`SKU not found: ${unknown}`);
  }

  const rows = await Promise.all(
    input.items.map(async (item) => {
      const priceMaster = rrpBySkuId.get(item.skuId) ?? 0;
      // Manual entry passthrough via the OCR stub (issue #10); real OCR price
      // extraction lands under issue #2.
      const priceActual = await extractPriceFromPhoto('', item.priceActual);
      const deviationPct = priceMaster > 0 ? ((priceActual - priceMaster) / priceMaster) * 100 : 0;
      return {
        visitId: input.visitId,
        skuId: item.skuId,
        priceActual,
        priceMaster,
        deviationPct,
        promoActive: item.promoActive,
        promoMaterialsDetected: item.promoMaterialsDetected,
        commsRating: item.commsRating,
      };
    }),
  );

  const created = await prisma.$transaction(rows.map((data) => prisma.visitPricing.create({ data })));

  // Auto-create a follow-up Task for every SKU whose shelf price deviates more
  // than the threshold from master, mirroring the risks module's flag -> task
  // pattern (issue #47). Deduplicated by (visitId, findingType, requiredFix) so
  // re-submitting the section is idempotent. Best-effort: a failure here must
  // not fail the already-persisted pricing capture.
  await createPriceDeviationTasks(input.visitId, input.clientId, visit.outletId, visit.agentId, rows);

  return created;
}

async function createPriceDeviationTasks(
  visitId: string,
  clientId: string,
  outletId: string,
  agentId: string,
  rows: Array<{ skuId: string; deviationPct: number }>,
): Promise<void> {
  try {
    const client = await prisma.client.findUnique({
      where: { id: clientId },
      select: { kpiThresholds: true },
    });
    const deviationThresholdPct = kpiThreshold(
      client?.kpiThresholds,
      'priceDeviationPct',
      DEFAULT_PRICE_DEVIATION_THRESHOLD_PCT,
    );

    const deviating = rows.filter((r) => Math.abs(r.deviationPct) > deviationThresholdPct);
    if (deviating.length === 0) return;

    const existing = await prisma.task.findMany({
      where: { visitId, findingType: PRICE_DEVIATION_FINDING_TYPE },
      select: { requiredFix: true },
    });
    const existingFixes = new Set(existing.map((t) => t.requiredFix));

    const now = new Date();
    for (const row of deviating) {
      const requiredFix = `Correct shelf price for SKU ${row.skuId} (deviation ${row.deviationPct}%)`;
      if (existingFixes.has(requiredFix)) continue; // dedup: skip already-open task
      await prisma.task.create({
        data: {
          visitId,
          findingType: PRICE_DEVIATION_FINDING_TYPE,
          outletId,
          requiredFix,
          priority: 'normal',
          slaDueAt: computeSlaDueAt('normal', now),
          ownerId: agentId,
        },
      });
      existingFixes.add(requiredFix); // guard against duplicate SKUs in one payload
    }
  } catch {
    // Swallow: pricing capture already succeeded; task backfill is low-risk (#47).
  }
}

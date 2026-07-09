import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
import { extractPriceFromPhoto } from '../../services/ocr.stub';

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
    where: { id: input.visitId, clientId: input.clientId },
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

  return prisma.$transaction(rows.map((data) => prisma.visitPricing.create({ data })));
}

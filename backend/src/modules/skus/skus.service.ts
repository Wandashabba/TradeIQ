import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';
import { computeDaysOutOfStock, computeVelocityAvg, fetchStockHistoryForOutlet } from '../../services/stock-derived.service';

interface PromoDiscount {
  discountType: string;
  discountValue: number;
  outletScope: unknown;
  skuScope: unknown;
}

function matchesScope(scope: unknown, key: 'outletCodes' | 'skuIds', value: string): boolean {
  if (scope === null || scope === undefined) return true; // no scope recorded -> applies to everything, by design
  if (typeof scope !== 'object') return false; // malformed (not an object) -> fail closed, don't guess
  const list = (scope as Record<string, unknown>)[key];
  if (!Array.isArray(list)) return false; // malformed (missing/wrong key) -> fail closed, don't guess
  return list.includes(value);
}

function computeEffectivePrice(rrp: number, promo: PromoDiscount | undefined): number {
  if (!promo) return rrp;
  if (promo.discountType === 'percent') {
    return Math.max(0, Math.round(rrp * (1 - promo.discountValue / 100) * 100) / 100);
  }
  if (promo.discountType === 'fixed') {
    return Math.max(0, Math.round((rrp - promo.discountValue) * 100) / 100);
  }
  return rrp; // unrecognized discountType -> no discount rather than guessing
}

export interface ListSkusForClientInput {
  clientId: string;
  outletId: string;
  limit: number;
  cursor?: string;
}

export async function listSkusForClient(input: ListSkusForClientInput) {
  const { clientId, outletId, limit, cursor } = input;
  const [rows, historyBySku, outlet, activePromos] = await Promise.all([
    prisma.sku.findMany({
      where: { clientId },
      // `id` is the unique tiebreaker that makes the cursor deterministic
      // when two SKUs share a name — same reasoning as alerts.service.ts.
      //
      // COPYING THIS PATTERN: the tiebreaker's direction MUST match the
      // primary sort's direction (both `asc` here).
      orderBy: [{ name: 'asc' }, { id: 'asc' }],
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    }),
    fetchStockHistoryForOutlet(outletId, clientId),
    prisma.outlet.findUnique({ where: { id: outletId }, select: { code: true } }),
    // Fetches every active promo for the client, then filters by outlet/SKU scope
    // in JS below — unlike #120's windowed stock-history fetch, this is a
    // conscious choice, not an oversight: clients run a handful of promos at a
    // time, so pushing JSON-array-containment into raw SQL isn't worth it yet.
    prisma.promoCalendar.findMany({
      where: {
        clientId,
        activeFrom: { lte: new Date() },
        activeTo: { gte: new Date() },
        discountType: { not: null },
        discountValue: { not: null },
      },
      select: { discountType: true, discountValue: true, outletScope: true, skuScope: true },
    }),
  ]);

  const { data: skus, nextCursor } = buildPage(rows, limit);

  const outletCode = outlet?.code;
  const asOf = new Date();

  const data = skus.map((sku) => {
    const history = historyBySku.get(sku.id) ?? [];
    const promo = outletCode
      ? (activePromos.find(
          (p) =>
            matchesScope(p.outletScope, 'outletCodes', outletCode) &&
            matchesScope(p.skuScope, 'skuIds', sku.id),
        ) as PromoDiscount | undefined)
      : undefined;
    return {
      ...sku,
      daysOutOfStock: computeDaysOutOfStock(history, asOf),
      velocityAvg: computeVelocityAvg(history),
      effectivePrice: computeEffectivePrice(sku.rrp, promo),
    };
  });

  return { data, nextCursor };
}

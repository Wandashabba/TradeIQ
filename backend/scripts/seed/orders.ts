import { addCalendarDays } from '../../src/lib/clientTime';
import { addMinutes, localInstant } from './calendar';
import { Channel, OutletSeed, SKUS, SKU_BASE_UNITS, SKU_LINE_PROBABILITY, TRADE_PRICE_FACTOR } from './catalog';
import { chance, gaussian, intBetween } from './rng';
import {
  CHRONIC_OOS_SELL_IN_FACTOR,
  CampaignSeed,
  growthFactor,
  isChronicOos,
  seasonality,
  territorySalesFactor,
} from './scenario';

/**
 * Sell-in: the orders agents capture in store (#36), with lines across the SKU
 * range, dated by the device's `capturedAt` (#338).
 *
 * Alongside the orders this keeps the *plan* — the units each planned stop was
 * expected to produce before anything went right or wrong. Sales targets
 * (`targets.ts`) are set from it, so a territory in decline misses its target
 * and a growing one beats it for the same reason a real plan would.
 */

const ORDER_PROBABILITY: Readonly<Record<Channel, number>> = {
  hypermarket: 0.8,
  wholesaler: 0.85,
  supermarket: 0.7,
  convenience: 0.55,
  forecourt: 0.5,
  spaza: 0.6,
};

const MONTH_END_ORDER_BOOST = 0.12;
const MONTH_END_QUANTITY_FACTOR = 1.6;
const QUANTITY_SIGMA = 0.35;
/** Scales a lognormal draw back to a mean of 1. */
const LOGNORMAL_MEAN_CORRECTION = Math.exp(-(QUANTITY_SIGMA ** 2) / 2);
const CANCEL_RATE = 0.025;
const OFFLINE_SYNC_RATE = 0.02;

export interface OrderRow {
  id: string;
  outletId: string;
  agentId: string;
  visitId: string;
  campaignId: string | null;
  status: 'submitted' | 'confirmed' | 'cancelled';
  total: number;
  capturedAt: Date;
  createdAt: Date;
}

export interface OrderLineRow {
  id: string;
  orderId: string;
  skuId: string;
  quantity: number;
  unitPrice: number;
}

/** Plan accumulators, keyed by month key (`YYYY-MM`). */
export class SalesPlan {
  readonly client = new Map<string, number>();
  readonly territory = new Map<string, number>();
  readonly outlet = new Map<string, number>();

  add(monthKey: string, outlet: OutletSeed, skuId: string, units: number): void {
    const bump = (map: Map<string, number>, key: string) => map.set(key, (map.get(key) ?? 0) + units);
    bump(this.client, `${monthKey}|${skuId}`);
    bump(this.territory, `${monthKey}|${outlet.territoryId}|${skuId}`);
    bump(this.outlet, `${monthKey}|${outlet.id}|${skuId}`);
  }
}

export interface StopContext {
  outlet: OutletSeed;
  day: Date;
  monthKey: string;
  monthsAgo: number;
  monthEnd: boolean;
}

function orderProbability(ctx: StopContext): number {
  const base = ORDER_PROBABILITY[ctx.outlet.channelType as Channel] ?? 0.6;
  return Math.min(0.95, base + (ctx.monthEnd ? MONTH_END_ORDER_BOOST : 0));
}

/** The units one planned stop was expected to order, by SKU, before any anomaly. */
export function planStop(plan: SalesPlan, ctx: StopContext): void {
  const pOrder = orderProbability(ctx);
  const common =
    pOrder *
    ctx.outlet.acvWeight *
    seasonality(ctx.day) *
    growthFactor(ctx.monthsAgo) *
    (ctx.monthEnd ? MONTH_END_QUANTITY_FACTOR : 1);
  for (const sku of SKUS) {
    plan.add(ctx.monthKey, ctx.outlet, sku.id, common * SKU_LINE_PROBABILITY[sku.id]! * SKU_BASE_UNITS[sku.id]!);
  }
}

export interface TakeOrderInput extends StopContext {
  orderId: string;
  visitId: string;
  agentId: string;
  agentSalesFactor: number;
  submittedAtClient: Date;
  campaign: CampaignSeed | null;
  anchor: Date;
  timeZone: string;
}

/** An order for a visit, or null when the outlet did not order this time. */
export function takeOrder(
  rng: () => number,
  input: TakeOrderInput,
): { order: OrderRow; lines: OrderLineRow[] } | null {
  if (!chance(rng, orderProbability(input))) return null;

  const { outlet, campaign } = input;
  const common =
    outlet.acvWeight *
    seasonality(input.day) *
    growthFactor(input.monthsAgo) *
    territorySalesFactor(outlet.territoryId, input.monthsAgo) *
    input.agentSalesFactor *
    (input.monthEnd ? MONTH_END_QUANTITY_FACTOR : 1);

  const lines: OrderLineRow[] = [];
  for (const sku of SKUS) {
    const inCampaign = campaign !== null && campaign.skuIds.includes(sku.id);
    let pLine = SKU_LINE_PROBABILITY[sku.id]!;
    if (inCampaign) pLine += (1 - pLine) * campaign!.basketPull;
    const chronic = isChronicOos(outlet.territoryId, sku.id, input.monthsAgo);
    if (chronic) pLine *= 0.6; // the distributor has none to deliver
    if (!chance(rng, pLine)) continue;

    const mean =
      SKU_BASE_UNITS[sku.id]! *
      common *
      (inCampaign ? campaign!.lift : 1) *
      (chronic ? CHRONIC_OOS_SELL_IN_FACTOR / 0.6 : 1);
    const quantity = Math.max(
      1,
      Math.round(mean * Math.exp(gaussian(rng) * QUANTITY_SIGMA) * LOGNORMAL_MEAN_CORRECTION),
    );
    const unitPrice =
      Math.round(sku.rrp * TRADE_PRICE_FACTOR * (inCampaign ? 1 - campaign!.discount : 1) * 100) / 100;
    lines.push({
      id: `${input.orderId}-l${lines.length + 1}`,
      orderId: input.orderId,
      skuId: sku.id,
      quantity,
      unitPrice,
    });
  }
  if (lines.length === 0) return null;

  // Taken on the device during the visit, a few minutes before it was submitted.
  const capturedAt = addMinutes(input.submittedAtClient, -intBetween(rng, 1, 4));
  let createdAt = new Date(capturedAt.getTime() + intBetween(rng, 5, 240) * 1000);
  if (chance(rng, OFFLINE_SYNC_RATE)) {
    // No signal in store: the outbox flushed the next morning (#338). The order
    // still belongs to the day — and the month — it was captured in.
    const nextDay = addCalendarDays(input.day, 1);
    createdAt =
      nextDay.getTime() < input.anchor.getTime()
        ? localInstant(nextDay, 7 * 60 + intBetween(rng, 0, 50), input.timeZone)
        : addMinutes(capturedAt, 180);
  }

  const ageDays = (input.anchor.getTime() - input.day.getTime()) / 86_400_000;
  const status = chance(rng, CANCEL_RATE) ? 'cancelled' : ageDays > 3 ? 'confirmed' : 'submitted';

  return {
    order: {
      id: input.orderId,
      outletId: outlet.id,
      agentId: input.agentId,
      visitId: input.visitId,
      campaignId: campaign?.id ?? null,
      status,
      total: Math.round(lines.reduce((sum, l) => sum + l.quantity * l.unitPrice, 0) * 100) / 100,
      capturedAt,
      createdAt,
    },
    lines,
  };
}

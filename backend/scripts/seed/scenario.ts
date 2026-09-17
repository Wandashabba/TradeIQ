import { addMonths, dayOfMonth } from './calendar';

/**
 * The planted story in the demo data — what Ask TradeIQ should be able to find.
 *
 * Every anomaly is a named constant here, and every generator reads its effect
 * through the small pure functions below, so the test-questions document
 * (`docs/testing/ask-tradeiq-questions.md`) and the generators cannot disagree
 * about who, where or when. Effects are sized to survive noise: a planted
 * pattern a manager has to squint at is not a test of the assistant.
 *
 * Time is expressed as fractional months before the anchor (`monthsAgo`), so a
 * decline is a steady slope rather than a step at a month boundary.
 */

// ── 1. A territory in steady decline over the last six months ────────────────
export const DECLINING_TERRITORY_CODE = 'EC-NMB';
export const DECLINE_MONTHS = 6;
/** Sell-in multiplier reached at the anchor (from 1.0 six months ago). */
export const DECLINE_SALES_FLOOR = 0.55;
/**
 * Points of latent execution quality lost by the anchor. The weighted scorecard
 * moves by roughly 60% of this (stock availability and pricing hold up), so the
 * territory's average score falls about ten points.
 */
export const DECLINE_SCORE_DROP = 17;

// ── 2. A chronic out-of-stock on the best seller, in one territory ───────────
export const CHRONIC_OOS_TERRITORY_CODE = 'KZN';
export const CHRONIC_OOS_SKU_ID = 'demo-sku-2'; // Kalahari Cola 2L, the best seller
export const CHRONIC_OOS_MONTHS = 4.5;
/**
 * Out of stock persists: once a store runs dry it mostly stays dry until the
 * distributor delivers, so the gap shows as weeks out (days-out-of-stock is
 * derived from consecutive counts), not as a coin flip per visit. Long-run
 * share of counts at zero is about 70%.
 */
export const CHRONIC_OOS_ENTER_PROBABILITY = 0.17;
export const CHRONIC_OOS_STAY_PROBABILITY = 0.93;
/** Sell-in multiplier on the SKU in that territory while it is out. */
export const CHRONIC_OOS_SELL_IN_FACTOR = 0.35;

// ── 3. A retailer chain pricing above RRP ────────────────────────────────────
// The chain's outlets are named in catalog.ts (PRICE_BREACH_CHAIN).
export const PRICE_BREACH_MONTHS = 6;
export const PRICE_BREACH_LINE_PROBABILITY = 0.8;

// ── 4. A fraud pattern ───────────────────────────────────────────────────────
export const FRAUD_AGENT_ID = 'demo-user-agent-14'; // Lwazi Mthembu, GP-EKU
export const FRAUD_MONTHS = 2.4; // about ten weeks

// ── 6. A standout agent and a struggling one ─────────────────────────────────
export const STANDOUT_AGENT_ID = 'demo-user-agent-9'; // Naledi Sithole, GP-TSH
export const STRUGGLING_AGENT_ID = 'demo-user-agent-44'; // Kagiso Molefe, MP
export const STRUGGLING_MONTHS = 7;

// ── 7. Year-on-year growth in one territory, decline in another ─────────────
export const YOY_GROWTH_TERRITORY_CODE = 'LP';
export const YOY_DECLINE_TERRITORY_CODE = 'FS';
export const YOY_GROWTH_FACTOR = 1.4;
export const YOY_DECLINE_FACTOR = 0.68;

export interface AgentProfile {
  /** Execution-score offset. */
  skill: number;
  /** Planned stops per working day. */
  plannedStops: number;
  /** Chance a planned stop is skipped. */
  skipRate: number;
  /** Sell-in multiplier on the agent's outlets. */
  salesFactor: number;
  /** Chance a finding's task is closed within its SLA, when it is closed at all. */
  onTimeRate: number;
  /** Chance a task older than a fortnight has been closed. */
  closeRate: number;
}

const DEFAULT_PROFILE: AgentProfile = {
  skill: 0, plannedStops: 6, skipRate: 0.07, salesFactor: 1, onTimeRate: 0.86, closeRate: 0.96,
};

/**
 * Per-agent behaviour at a point in time. Ordinary agents vary a little around
 * the default by a stable per-agent offset (`agentSeed`, 0-1) so the team does
 * not read as fifty clones.
 */
export function agentProfile(agentId: string, agentSeed: number, monthsAgo: number): AgentProfile {
  if (agentId === STANDOUT_AGENT_ID) {
    return { skill: 14, plannedStops: 7, skipRate: 0.01, salesFactor: 1.18, onTimeRate: 0.98, closeRate: 1 };
  }
  if (agentId === STRUGGLING_AGENT_ID) {
    return monthsAgo < STRUGGLING_MONTHS
      ? { skill: -24, plannedStops: 6, skipRate: 0.45, salesFactor: 0.7, onTimeRate: 0.35, closeRate: 0.6 }
      : { skill: -5, plannedStops: 6, skipRate: 0.12, salesFactor: 0.92, onTimeRate: 0.7, closeRate: 0.9 };
  }
  if (agentId === FRAUD_AGENT_ID && monthsAgo < FRAUD_MONTHS) {
    // Ghost visits: many stops, none skipped, suspiciously good paperwork.
    return { skill: 6, plannedStops: 11, skipRate: 0, salesFactor: 0.9, onTimeRate: 0.9, closeRate: 0.97 };
  }
  return {
    ...DEFAULT_PROFILE,
    skill: Math.round((agentSeed - 0.5) * 10),
    skipRate: 0.04 + agentSeed * 0.06,
    salesFactor: 0.94 + agentSeed * 0.12,
  };
}

/** Company-wide growth: about 6% a year, so older months sell a little less. */
export function growthFactor(monthsAgo: number): number {
  return Math.pow(1.06, -monthsAgo / 12);
}

/** Seasonality by calendar month (0 = January): the festive peak, the January dip. */
const SEASONALITY = [0.72, 0.88, 0.97, 0.98, 0.95, 0.93, 0.95, 0.98, 1.0, 1.03, 1.12, 1.45];

export function seasonality(calendarDate: Date): number {
  return SEASONALITY[calendarDate.getUTCMonth()]!;
}

/** The territory-level sell-in multiplier: the decline and the two YoY stories. */
export function territorySalesFactor(territoryCode: string, monthsAgo: number): number {
  if (territoryCode === DECLINING_TERRITORY_CODE && monthsAgo < DECLINE_MONTHS) {
    return 1 - (1 - DECLINE_SALES_FLOOR) * ((DECLINE_MONTHS - monthsAgo) / DECLINE_MONTHS);
  }
  if (territoryCode === YOY_GROWTH_TERRITORY_CODE) {
    return ramp(monthsAgo, 12.5, 10, 1, YOY_GROWTH_FACTOR);
  }
  if (territoryCode === YOY_DECLINE_TERRITORY_CODE) {
    return ramp(monthsAgo, 12.5, 10, 1, YOY_DECLINE_FACTOR);
  }
  return 1;
}

/** `before` until `startAgo` months ago, `after` from `endAgo`, linear between. */
function ramp(monthsAgo: number, startAgo: number, endAgo: number, before: number, after: number): number {
  if (monthsAgo >= startAgo) return before;
  if (monthsAgo <= endAgo) return after;
  const t = (startAgo - monthsAgo) / (startAgo - endAgo);
  return before + (after - before) * t;
}

/** Execution-score shift for the territory — the decline shows in the shelf too. */
export function territoryScoreShift(territoryCode: string, monthsAgo: number): number {
  if (territoryCode === DECLINING_TERRITORY_CODE && monthsAgo < DECLINE_MONTHS) {
    return -DECLINE_SCORE_DROP * ((DECLINE_MONTHS - monthsAgo) / DECLINE_MONTHS);
  }
  return 0;
}

/** Competitor promoter presence: 12% normally, climbing to ~65% in the declining territory. */
export function competitorPromoterRate(territoryCode: string, monthsAgo: number): number {
  if (territoryCode === DECLINING_TERRITORY_CODE && monthsAgo < DECLINE_MONTHS) {
    return 0.12 + 0.53 * ((DECLINE_MONTHS - monthsAgo) / DECLINE_MONTHS);
  }
  return 0.12;
}

/** Our facings multiplier: shelf space lost to the competitor in the declining territory. */
export function ourFacingsFactor(territoryCode: string, monthsAgo: number): number {
  if (territoryCode === DECLINING_TERRITORY_CODE && monthsAgo < DECLINE_MONTHS) {
    return 1 - 0.4 * ((DECLINE_MONTHS - monthsAgo) / DECLINE_MONTHS);
  }
  return 1;
}

/**
 * Company-wide execution quality: a slow climb over two years. The weighted
 * scorecard lands a few points above this (a fully stocked, correctly priced
 * shelf lifts availability and pricing), so the team averages high 60s to low
 * 70s — amber, improving — with room for a standout above and a red tail below.
 */
export function baseScore(monthsAgo: number, calendarDate: Date): number {
  const trend = 58 + 8 * (1 - Math.min(monthsAgo, 24) / 24);
  // Skeleton staff over the festive season.
  const month = calendarDate.getUTCMonth();
  const day = calendarDate.getUTCDate();
  const festive = (month === 11 && day >= 15) || (month === 0 && day <= 10);
  return trend - (festive ? 3 : 0);
}

export function isChronicOos(territoryCode: string, skuId: string, monthsAgo: number): boolean {
  return (
    territoryCode === CHRONIC_OOS_TERRITORY_CODE &&
    skuId === CHRONIC_OOS_SKU_ID &&
    monthsAgo < CHRONIC_OOS_MONTHS
  );
}

// ── 5. Campaigns — some worked, some did not ─────────────────────────────────

export interface CampaignSeed {
  id: string;
  name: string;
  objective: string;
  /** Calendar dates (UTC midnight), inclusive local days (#324). */
  startDate: Date;
  endDate: Date;
  budget: number;
  territoryCodes: readonly string[];
  outletCount: number;
  skuIds: readonly string[];
  /** Sell-in multiplier on the campaign SKUs at campaign outlets in the window. */
  lift: number;
  /** Chance a campaign SKU is added to an order that would not have had it. */
  basketPull: number;
  /** Execution while it runs: planogram floor and promo-live rate on pricing rows. */
  execution: 'excellent' | 'normal' | 'poor';
  /** The promo discount on campaign SKUs, as a share off trade price. */
  discount: number;
}

/**
 * Campaigns, placed relative to the anchor's month (M0) so a reseed on another
 * day keeps the same story. The windows never overlap for any outlet, and each
 * baseline window (the equal-length stretch before it) avoids the festive peak
 * and the January dip, so a lift or a flop is the campaign's own doing.
 */
export function campaignSeeds(anchorMonth: Date): CampaignSeed[] {
  const m = (offset: number, day: number) => dayOfMonth(addMonths(anchorMonth, offset), day);
  return [
    {
      id: 'demo-campaign-zero-launch',
      name: 'Kalahari Zero Winter Launch',
      objective: 'Launch Kalahari Zero into Gauteng key accounts with end-caps and a trade deal on the cola range.',
      startDate: m(-2, 6), endDate: m(-1, 16), budget: 400000,
      territoryCodes: ['GP', 'GP-TSH', 'GP-EKU'], outletCount: 60,
      skuIds: ['demo-sku-4', 'demo-sku-1', 'demo-sku-2'],
      lift: 1.5, basketPull: 0.45, execution: 'normal', discount: 0.08,
    },
    {
      id: 'demo-campaign-winter-warmer',
      name: 'Winter Warmer Hot Beverages',
      objective: 'Drive rooibos, coffee and rusks through coastal supermarkets with full POSM and promoters.',
      startDate: m(-4, 4), endDate: m(-3, 14), budget: 300000,
      territoryCodes: ['WC', 'WC-WIN', 'KZN', 'KZN-PMB'], outletCount: 50,
      skuIds: ['demo-sku-15', 'demo-sku-16', 'demo-sku-19'],
      lift: 1.0, basketPull: 0.02, execution: 'excellent', discount: 0.1,
    },
    {
      id: 'demo-campaign-festive-2025',
      name: 'Festive Cheer Carbonates',
      objective: 'Festive-season multibuy on the cola range across Gauteng and Durban.',
      startDate: m(-10, 17), endDate: m(-9, 31), budget: 600000,
      territoryCodes: ['GP', 'GP-TSH', 'KZN'], outletCount: 70,
      skuIds: ['demo-sku-1', 'demo-sku-2', 'demo-sku-3'],
      lift: 1.2, basketPull: 0.2, execution: 'normal', discount: 0.05,
    },
    {
      id: 'demo-campaign-braai-day',
      name: 'Braai Day Snack Attack',
      objective: 'Heritage Month snack and staples bundle in Cape Town and Johannesburg.',
      startDate: m(0, 1), endDate: m(0, 30), budget: 150000,
      territoryCodes: ['WC', 'GP'], outletCount: 45,
      skuIds: ['demo-sku-17', 'demo-sku-18', 'demo-sku-13'],
      lift: 1.3, basketPull: 0.35, execution: 'normal', discount: 0.06,
    },
    {
      id: 'demo-campaign-water-challenge',
      name: 'Mzansi Water Challenge',
      objective: 'Win the water fixture in Eastern Cape convenience and forecourt.',
      startDate: m(-13, 4), endDate: m(-12, 14), budget: 220000,
      territoryCodes: ['EC-NMB', 'EC-BCM'], outletCount: 40,
      skuIds: ['demo-sku-5', 'demo-sku-6'],
      lift: 1.04, basketPull: 0.03, execution: 'poor', discount: 0.05,
    },
    {
      id: 'demo-campaign-easter-2025',
      name: 'Easter Family Pack',
      objective: 'Juice and chocolate family bundle for the Easter weekend.',
      startDate: m(-17, 7), endDate: m(-17, 27), budget: 60000,
      territoryCodes: ['WC', 'WC-WIN'], outletCount: 40,
      skuIds: ['demo-sku-7', 'demo-sku-8', 'demo-sku-20'],
      lift: 1.9, basketPull: 0.5, execution: 'normal', discount: 0.07,
    },
    {
      id: 'demo-campaign-summer-refresh',
      name: 'Summer Refresh 2026',
      objective: 'Draft: summer water and juice push. Not yet approved.',
      startDate: m(2, 16), endDate: m(3, 31), budget: 200000,
      territoryCodes: ['KZN', 'KZN-PMB', 'EC-BCM'], outletCount: 30,
      skuIds: ['demo-sku-5', 'demo-sku-9'],
      lift: 1, basketPull: 0, execution: 'normal', discount: 0,
    },
  ];
}

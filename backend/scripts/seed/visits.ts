import { computeDaysOutOfStock, computeVelocityAvg, StockHistoryRow } from '../../src/services/stock-derived.service';
import { haversineDistanceMeters } from '../../src/lib/geofence';
import { predictCoverageDays } from '../../src/services/forecast.service';
import { addDays } from './calendar';
import { CHANNEL_SIZE, Channel, OutletSeed, PRICE_BREACH_CHAIN, SKUS, SKU_BASE_UNITS, SkuSeed } from './catalog';
import { chance, gaussian, intBetween, pick } from './rng';
import {
  AgentProfile,
  CampaignSeed,
  PRICE_BREACH_LINE_PROBABILITY,
  PRICE_BREACH_MONTHS,
  baseScore,
  competitorPromoterRate,
  isChronicOos,
  CHRONIC_OOS_ENTER_PROBABILITY,
  CHRONIC_OOS_STAY_PROBABILITY,
  ourFacingsFactor,
  territoryScoreShift,
} from './scenario';

/**
 * One visit's S1–S10 capture: stock, pricing, competition, visibility,
 * capability and the scorecard they add up to.
 *
 * Pure by design: plain rows with explicit ids and `createdAt`, so the whole
 * history can be asserted without a database. Every section row's `createdAt`
 * equals its visit's `checkinTs` — `/trends` buckets on each row's own
 * `createdAt`, and leaving it to `@default(now())` put every row in the
 * insert-time bucket (#204).
 *
 * Stock derived fields are computed exactly the way capture computes them
 * (`stock.service.ts` over `stock-derived.service.ts`): days out of stock and
 * velocity come from the outlet's own prior counts, not from a random number.
 */

/** The client's scorecard weights — the same object index.ts writes on the client. */
export const SCORECARD_WEIGHTS = {
  availability: 0.3,
  visibility: 0.25,
  display: 0.15,
  pricing: 0.1,
  salesCapability: 0.1,
  competitive: 0.1,
} as const;

const SCORE_FLOOR = 25;
const SCORE_CEILING = 98;
const PROBLEM_OUTLET_PENALTY = 22;

/** Counted on every visit: the carbonates core, where availability is judged. */
export const CORE_STOCK_SKU_IDS = ['demo-sku-1', 'demo-sku-2', 'demo-sku-4'] as const;
const ROTATING_STOCK_SKUS = SKUS.filter((s) => !(CORE_STOCK_SKU_IDS as readonly string[]).includes(s.id));
const ROTATING_PER_VISIT = 3;
/** Priced on every visit, plus one rotating line. */
const CORE_PRICE_SKU_IDS = ['demo-sku-1', 'demo-sku-2'];

const SKU_BY_ID = new Map(SKUS.map((s) => [s.id, s]));

const OOS_BASE: Readonly<Record<Channel, number>> = {
  hypermarket: 0.02,
  wholesaler: 0.02,
  supermarket: 0.035,
  convenience: 0.05,
  forecourt: 0.05,
  spaza: 0.07,
};
const PROBLEM_OUTLET_OOS = 0.25;

const COMPETITORS = [
  { sku: 'RivalCola 2L', ref: 33.99 },
  { sku: 'RivalCola 1L', ref: 23.99 },
  { sku: 'Storm Energy 440ml', ref: 19.99 },
  { sku: 'Pure Springs Water 500ml', ref: 9.49 },
  { sku: 'Golden Valley Juice 1L', ref: 27.99 },
  { sku: 'Crunchy Chips 125g', ref: 15.99 },
] as const;
const POSM_TYPES = ['shelf_strip', 'wobbler', 'poster', 'end_cap', 'floor_stand'];

export interface VisitRow {
  id: string;
  outletId: string;
  agentId: string;
  checkinTs: Date;
  checkinLat: number;
  checkinLng: number;
  checkinDistanceM: number;
  geofencePass: boolean;
  status: 'submitted';
  submittedAtClient: Date;
}

export interface StockRow {
  id: string;
  visitId: string;
  skuId: string;
  unitsAvailable: number;
  lastStockinDate: Date;
  daysOutOfStock: number;
  velocityAvg: number;
  coverageDaysPredicted: number;
  createdAt: Date;
}

export interface PricingRow {
  id: string;
  visitId: string;
  skuId: string;
  priceActual: number;
  priceMaster: number;
  deviationPct: number;
  promoActive: boolean;
  promoMaterialsDetected: Record<string, boolean>;
  commsRating: number;
  createdAt: Date;
}

export interface CompetitiveRow {
  id: string;
  visitId: string;
  competitorSku: string;
  competitorPrice: number;
  competitorPosmType: string;
  competitorPromoterPresent: boolean;
  facingsCount: number;
  geotag: { lat: number; lng: number };
  createdAt: Date;
}

export interface VisibilityRow {
  id: string;
  visitId: string;
  brandingElements: Record<string, boolean>;
  planogramCompliancePct: number;
  facingsCount: { total: number; byZone: { eye: number; reach: number; stoop: number } };
  highTrafficPass: boolean;
  cleanlinessScore: number;
  createdAt: Date;
}

export interface CapabilityRow {
  id: string;
  visitId: string;
  staffHeadcountConfirmed: number;
  repTrainingStatus: Record<string, boolean>;
  quizScore: number;
  createdAt: Date;
}

export interface ScorecardRow {
  id: string;
  visitId: string;
  dimensionScores: Record<string, number>;
  weightedTotal: number;
  ratingBand: string;
  createdAt: Date;
}

export interface CapturedVisit {
  visit: VisitRow;
  stock: StockRow[];
  pricing: PricingRow[];
  competitive: CompetitiveRow[];
  visibility: VisibilityRow;
  capability: CapabilityRow;
  scorecard: ScorecardRow;
}

/** As stock.service.ts stores it: Infinity (no measured velocity) becomes 0. */
function coverageFor(unitsAvailable: number, velocityAvg: number): number {
  const coverage = predictCoverageDays({ unitsAvailable, velocityAvg });
  return Number.isFinite(coverage) ? coverage : 0;
}

/** Matches the client's kpiThresholds: green >= 80, amber >= 60, else red. */
export function ratingBandFor(weightedTotal: number): string {
  if (weightedTotal >= 80) return 'green';
  if (weightedTotal >= 60) return 'amber';
  return 'red';
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function round1(value: number): number {
  return Math.round(value * 10) / 10;
}

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

/**
 * The running memory capture reads: each outlet's recent counts per SKU
 * (newest first, capped like the service's window), and how many times each
 * outlet has been visited — which rotates the SKUs counted.
 */
export class StockMemory {
  private readonly history = new Map<string, StockHistoryRow[]>();
  private readonly restocked = new Map<string, Date>();
  private readonly visitsByOutlet = new Map<string, number>();
  /** Last in-stock count per outlet|SKU over the whole run, like capture reads (#360). */
  private readonly inStockAt = new Map<string, Date>();

  historyFor(outletId: string, skuId: string): StockHistoryRow[] {
    return this.history.get(`${outletId}|${skuId}`) ?? [];
  }

  record(outletId: string, skuId: string, row: StockHistoryRow): void {
    const key = `${outletId}|${skuId}`;
    const list = [row, ...(this.history.get(key) ?? [])].slice(0, 5);
    this.history.set(key, list);
    if (row.unitsAvailable > 0) this.inStockAt.set(key, row.visitCheckinTs);
  }

  lastInStock(outletId: string, skuId: string): Date | null {
    return this.inStockAt.get(`${outletId}|${skuId}`) ?? null;
  }

  lastRestock(outletId: string, skuId: string): Date | undefined {
    return this.restocked.get(`${outletId}|${skuId}`);
  }

  setRestock(outletId: string, skuId: string, at: Date): void {
    this.restocked.set(`${outletId}|${skuId}`, at);
  }

  nextVisitIndex(outletId: string): number {
    const n = this.visitsByOutlet.get(outletId) ?? 0;
    this.visitsByOutlet.set(outletId, n + 1);
    return n;
  }
}

export interface CaptureInput {
  id: string;
  outlet: OutletSeed;
  agentId: string;
  day: Date;
  checkinTs: Date;
  submittedAtClient: Date;
  monthsAgo: number;
  profile: AgentProfile;
  outletOffset: number;
  isProblemOutlet: boolean;
  campaign: CampaignSeed | null;
  /** The ghost-visit agent inside the fraud window. */
  fraud: boolean;
}

/** A point `metres` from `origin` on a random bearing. */
export function offsetPoint(
  rng: () => number,
  origin: { lat: number; lng: number },
  metres: number,
): { lat: number; lng: number } {
  const bearing = rng() * 2 * Math.PI;
  const dLat = (metres * Math.cos(bearing)) / 111_320;
  const dLng = (metres * Math.sin(bearing)) / (111_320 * Math.cos((origin.lat * Math.PI) / 180));
  return {
    lat: Math.round((origin.lat + dLat) * 1e7) / 1e7,
    lng: Math.round((origin.lng + dLng) * 1e7) / 1e7,
  };
}

function outletSize(outlet: OutletSeed): number {
  return outlet.acvWeight || CHANNEL_SIZE[outlet.channelType as Channel] || 1;
}

export function captureVisit(rng: () => number, memory: StockMemory, input: CaptureInput): CapturedVisit {
  const { id, outlet, checkinTs, campaign, monthsAgo, fraud } = input;
  const channel = outlet.channelType as Channel;
  const size = outletSize(outlet);
  const territory = outlet.territoryId;
  const visitIndex = memory.nextVisitIndex(outlet.id);

  // ── Check-in position ────────────────────────────────────────────────────
  // Inside the 50 m fence by construction: a visit only exists once check-in
  // passed. Honest agents stand in the store; a few hug the fence edge. The
  // ghost-visit agent is always at the edge — a spoofed fix set just inside.
  const targetDistance = fraud
    ? 44 + rng() * 5
    : chance(rng, 0.05)
      ? 41 + rng() * 8
      : 2 + rng() * 36;
  const checkin = offsetPoint(rng, outlet, targetDistance);
  const checkinDistanceM = Math.round(haversineDistanceMeters(outlet, checkin) * 10) / 10;

  // ── Latent execution quality ─────────────────────────────────────────────
  let campaignShift = 0;
  if (campaign?.execution === 'excellent') campaignShift = 6;
  if (campaign?.execution === 'poor') campaignShift = -10;
  const quality = clamp(
    baseScore(monthsAgo, input.day) +
      input.profile.skill +
      input.outletOffset +
      territoryScoreShift(territory, monthsAgo) +
      campaignShift -
      (input.isProblemOutlet ? PROBLEM_OUTLET_PENALTY : 0) +
      gaussian(rng) * 5,
    SCORE_FLOOR,
    SCORE_CEILING,
  );

  // ── S2 stock ─────────────────────────────────────────────────────────────
  const rotating = Array.from(
    { length: ROTATING_PER_VISIT },
    (_, k) => ROTATING_STOCK_SKUS[(visitIndex * ROTATING_PER_VISIT + k) % ROTATING_STOCK_SKUS.length]!,
  );
  const stockSkus: SkuSeed[] = [...CORE_STOCK_SKU_IDS.map((sid) => SKU_BY_ID.get(sid)!), ...rotating];
  const qualityMultiplier = quality < 55 ? 1.8 : quality > 82 ? 0.6 : 1;

  const stock: StockRow[] = stockSkus.map((sku, index) => {
    const prior = memory.historyFor(outlet.id, sku.id);
    const par = Math.max(4, Math.round((SKU_BASE_UNITS[sku.id] ?? 10) * size * 1.6));
    const lastUnits = prior[0]?.unitsAvailable;
    let pOos = OOS_BASE[channel] * qualityMultiplier;
    if (input.isProblemOutlet) pOos = PROBLEM_OUTLET_OOS;
    if (isChronicOos(territory, sku.id, monthsAgo)) {
      pOos = lastUnits === 0 ? CHRONIC_OOS_STAY_PROBABILITY : CHRONIC_OOS_ENTER_PROBABILITY;
    }

    let units: number;
    if (fraud && lastUnits !== undefined && lastUnits > 0 && index < CORE_STOCK_SKU_IDS.length) {
      // Copied from the last visit rather than counted (#245).
      units = lastUnits;
    } else if (chance(rng, pOos)) {
      units = 0;
    } else {
      units = Math.max(1, Math.round(par * (0.15 + 0.85 * rng())));
    }

    // Exactly what stock capture stores (stock.service.ts, #112): both derived
    // fields come from the outlet's PRIOR counts of the SKU, not from this one.
    // Velocity reads the last five; days out of stock reads the last in-stock
    // count however far back it was, so a chronic gap keeps counting up rather
    // than resetting to 0 after five empty visits (#360).
    const current: StockHistoryRow = { visitCheckinTs: checkinTs, unitsAvailable: units };
    const daysOutOfStock = computeDaysOutOfStock(prior, checkinTs, memory.lastInStock(outlet.id, sku.id));
    const velocityAvg = computeVelocityAvg(prior);

    if (lastUnits === undefined || units > lastUnits) {
      memory.setRestock(outlet.id, sku.id, addDays(checkinTs, -(rng() * 2)));
    }
    memory.record(outlet.id, sku.id, current);
    const lastStockinDate =
      memory.lastRestock(outlet.id, sku.id) ?? addDays(checkinTs, -intBetween(rng, 3, 9));

    return {
      id: `${id}-s${index + 1}`,
      visitId: id,
      skuId: sku.id,
      unitsAvailable: units,
      lastStockinDate,
      daysOutOfStock,
      velocityAvg,
      coverageDaysPredicted: coverageFor(units, velocityAvg),
      createdAt: checkinTs,
    };
  });

  // ── S5 pricing ───────────────────────────────────────────────────────────
  const priceSkus = [
    ...CORE_PRICE_SKU_IDS.map((sid) => SKU_BY_ID.get(sid)!),
    ROTATING_STOCK_SKUS[visitIndex % ROTATING_STOCK_SKUS.length]!,
  ];
  const chainBreach = outlet.name.startsWith(`${PRICE_BREACH_CHAIN} `) && monthsAgo < PRICE_BREACH_MONTHS;
  const promoLiveRate = !campaign
    ? 0.08
    : campaign.execution === 'excellent'
      ? 0.96
      : campaign.execution === 'poor'
        ? 0.3
        : 0.72;

  const pricing: PricingRow[] = priceSkus.map((sku, index) => {
    const onPromo = campaign !== null && campaign.skuIds.includes(sku.id);
    let deviation: number;
    if (chainBreach && chance(rng, PRICE_BREACH_LINE_PROBABILITY)) {
      deviation = 11 + rng() * 11;
    } else if (onPromo) {
      deviation = -campaign!.discount * 100 + gaussian(rng);
    } else if (chance(rng, 0.015)) {
      deviation = 10.5 + rng() * 5.5;
    } else {
      deviation = clamp(0.8 + gaussian(rng) * 2.2, -6, 8);
    }
    deviation = round2(deviation);
    const promoActive = chance(rng, promoLiveRate);
    const posmRate = campaign ? promoLiveRate : 0.5;
    return {
      id: `${id}-p${index + 1}`,
      visitId: id,
      skuId: sku.id,
      priceActual: round2(sku.rrp * (1 + deviation / 100)),
      priceMaster: sku.rrp,
      deviationPct: deviation,
      promoActive,
      promoMaterialsDetected: {
        poster: chance(rng, posmRate),
        shelfStrip: chance(rng, posmRate),
        wobbler: chance(rng, posmRate * 0.8),
      },
      commsRating: clamp(Math.round(quality / 20 + gaussian(rng) * 0.8), 1, 5),
      createdAt: checkinTs,
    };
  });

  // ── S6 competition ───────────────────────────────────────────────────────
  const promoterRate = competitorPromoterRate(territory, monthsAgo);
  const shelfLoss = 1 - ourFacingsFactor(territory, monthsAgo); // 0 .. 0.4
  const competitiveCount = chance(rng, 0.45) ? 2 : 1;
  const competitive: CompetitiveRow[] = Array.from({ length: competitiveCount }, (_, index) => {
    // Where the rival is pushing, it is the rival cola that turns up first.
    const competitor = index === 0 && shelfLoss > 0 ? COMPETITORS[0] : pick(rng, COMPETITORS);
    const aggressive = competitor.sku.startsWith('RivalCola') ? shelfLoss * 0.3 : 0;
    return {
      id: `${id}-c${index + 1}`,
      visitId: id,
      competitorSku: competitor.sku,
      competitorPrice: round2(competitor.ref * (0.9 + rng() * 0.14) * (1 - aggressive)),
      competitorPosmType: pick(rng, POSM_TYPES),
      competitorPromoterPresent: chance(rng, promoterRate),
      facingsCount: intBetween(rng, 2, 9) + Math.round(shelfLoss * 20 * (index === 0 ? 1 : 0)),
      geotag: { lat: outlet.lat, lng: outlet.lng },
      createdAt: checkinTs,
    };
  });

  // ── S3/S4 visibility and display ─────────────────────────────────────────
  let planogram = clamp(quality + gaussian(rng) * 6, 20, 99);
  if (campaign?.execution === 'excellent') planogram = Math.max(planogram, 90 + rng() * 8);
  if (campaign?.execution === 'poor') planogram = Math.min(planogram, 45 + rng() * 15);
  planogram = round1(planogram);
  const ourFacings = Math.max(
    3,
    Math.round(Math.sqrt(size) * (14 + rng() * 16) * ourFacingsFactor(territory, monthsAgo)),
  );
  const eye = Math.round(ourFacings * 0.45);
  const reach = Math.round(ourFacings * 0.35);
  const brandingRate = quality / 100;
  const allPosm = campaign?.execution === 'excellent';
  const visibility: VisibilityRow = {
    id: `${id}-vis`,
    visitId: id,
    brandingElements: {
      poster: allPosm || chance(rng, brandingRate + 0.1),
      shelfStrip: allPosm || chance(rng, brandingRate),
      wobbler: allPosm || chance(rng, brandingRate - 0.2),
      endCap: allPosm || chance(rng, brandingRate - 0.3),
    },
    planogramCompliancePct: planogram,
    facingsCount: { total: ourFacings, byZone: { eye, reach, stoop: ourFacings - eye - reach } },
    highTrafficPass: chance(rng, brandingRate),
    cleanlinessScore: clamp(Math.round(quality / 20 + gaussian(rng) * 0.7), 1, 5),
    createdAt: checkinTs,
  };

  // ── S8 sales capability ──────────────────────────────────────────────────
  const quizScore = clamp(Math.round(quality + gaussian(rng) * 8), 10, 100);
  const capability: CapabilityRow = {
    id: `${id}-cap`,
    visitId: id,
    staffHeadcountConfirmed: Math.max(1, Math.round(size * 2 + intBetween(rng, 0, 3))),
    repTrainingStatus: {
      onboarded: true,
      planogramCertified: chance(rng, 0.5 + quality / 200),
      promoBriefed: chance(rng, brandingRate),
    },
    quizScore,
    createdAt: checkinTs,
  };

  // ── Scorecard: dimensions from what was captured, weighted as the client says
  const oosLines = stock.filter((row) => row.unitsAvailable === 0).length;
  const osaPct = (100 * (stock.length - oosLines)) / stock.length;
  // Promo prices sit below RRP on purpose; only overpricing costs points.
  const worstOverprice = Math.max(0, ...pricing.map((row) => row.deviationPct - 2));
  const competitorFacings = competitive.reduce((sum, row) => sum + row.facingsCount, 0);
  const shareOfShelf = ourFacings / (ourFacings + competitorFacings);

  const dimensionScores = {
    availability: round1(clamp(0.55 * osaPct + 0.45 * quality, 0, 100)),
    visibility: round1(clamp(planogram + gaussian(rng) * 3, 0, 100)),
    display: round1(clamp(quality + gaussian(rng) * 5, 0, 100)),
    pricing: round1(clamp(100 - 3.5 * worstOverprice, 0, 100)),
    competitive: round1(clamp(shareOfShelf * 80 + 20, 0, 100)),
    salesCapability: quizScore,
  };
  const weightedTotal = round1(
    Object.entries(SCORECARD_WEIGHTS).reduce(
      (sum, [dimension, weight]) => sum + weight * dimensionScores[dimension as keyof typeof dimensionScores],
      0,
    ),
  );

  return {
    visit: {
      id,
      outletId: outlet.id,
      agentId: input.agentId,
      checkinTs,
      checkinLat: checkin.lat,
      checkinLng: checkin.lng,
      checkinDistanceM,
      geofencePass: true,
      status: 'submitted',
      submittedAtClient: input.submittedAtClient,
    },
    stock,
    pricing,
    competitive,
    visibility,
    capability,
    scorecard: {
      id: `${id}-sc`,
      visitId: id,
      dimensionScores,
      weightedTotal,
      ratingBand: ratingBandFor(weightedTotal),
      createdAt: checkinTs,
    },
  };
}

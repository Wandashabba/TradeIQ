import { addDays, addHours, HISTORY_WEEKS, weekStarts } from './calendar';
import {
  OutletSeed,
  PROBLEM_OUTLET_CODES,
  SkuSeed,
  TERRITORY_CODE_BY_ID,
  UserSeed,
} from './catalog';
import { intBetween, jitter, makeRng, pick } from './rng';

/**
 * Generates the 12-week visit history and the improving execution-score curve.
 *
 * Pure by design: it returns plain objects with explicit `createdAt` values and
 * never touches Prisma, so the curve can be asserted without a database.
 *
 * Every Scorecard and VisitStock row carries an explicit `createdAt` equal to
 * its visit's `checkinTs`. That is the actual fix for #204 — `/trends` buckets
 * on each row's own `createdAt`, and leaving it to `@default(now())` put every
 * row in the insert-time bucket no matter how the visits were dated.
 */

const SCORE_START = 62;
const SCORE_END = 78;
const SCORE_FLOOR = 25;
const SCORE_CEILING = 98;
const PROBLEM_OUTLET_PENALTY = 24;
const VISITS_PER_AGENT_PER_WEEK = 5;

export interface StockRow {
  skuId: string;
  unitsAvailable: number;
  lastStockinDate: Date;
  daysOutOfStock: number;
  velocityAvg: number;
  coverageDaysPredicted: number;
  salesActual: number;
  salesTarget: number;
  createdAt: Date;
}

export interface PricingRow {
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
  competitorSku: string;
  competitorPrice: number;
  competitorPosmType: string;
  competitorPromoterPresent: boolean;
  facingsCount: number;
  geotag: { lat: number; lng: number };
  createdAt: Date;
}

export interface GeneratedVisit {
  id: string;
  outletId: string;
  outletCode: string;
  agentId: string;
  checkinTs: Date;
  checkinLat: number;
  checkinLng: number;
  checkinDistanceM: number;
  geofencePass: boolean;
  isProblemOutlet: boolean;
  stock: StockRow[];
  pricing: PricingRow[];
  competitive: CompetitiveRow[];
  visibility: {
    brandingElements: Record<string, boolean>;
    planogramCompliancePct: number;
    facingsCount: { total: number; byZone: { eye: number; reach: number; stoop: number } };
    highTrafficPass: boolean;
    cleanlinessScore: number;
    createdAt: Date;
  };
  capability: {
    staffHeadcountConfirmed: number;
    repTrainingStatus: Record<string, boolean>;
    quizScore: number;
    createdAt: Date;
  };
  scorecard: {
    dimensionScores: Record<string, number>;
    weightedTotal: number;
    ratingBand: string;
    createdAt: Date;
  };
}

export interface BuildVisitHistoryInput {
  anchor: Date;
  outlets: OutletSeed[];
  agents: UserSeed[];
  skus: SkuSeed[];
}

/** Matches the client's kpiThresholds: green >= 80, amber >= 60, else red. */
export function ratingBandFor(weightedTotal: number): string {
  if (weightedTotal >= 80) return 'green';
  if (weightedTotal >= 60) return 'amber';
  return 'red';
}

function clampScore(value: number): number {
  return Math.round(Math.min(SCORE_CEILING, Math.max(SCORE_FLOOR, value)) * 10) / 10;
}

const COMPETITORS = ['RivalCola 500ml', 'RivalCola 2L', 'Storm Energy 440ml', 'Pure Springs 1L'];
const POSM_TYPES = ['shelf_strip', 'wobbler', 'poster', 'end_cap'];

export function buildVisitHistory(input: BuildVisitHistoryInput): GeneratedVisit[] {
  const { anchor, outlets, agents, skus } = input;
  const rng = makeRng(987654321);
  const weeks = weekStarts(anchor, HISTORY_WEEKS);
  const problemCodes = new Set<string>(PROBLEM_OUTLET_CODES);

  // A fixed offset per outlet so outlets rank consistently week to week rather
  // than shuffling — a demo where the worst store changes every week reads as
  // noise, not as a business.
  const outletOffset = new Map<string, number>();
  for (const outlet of outlets) {
    outletOffset.set(outlet.id, jitter(rng, 8));
  }

  const visits: GeneratedVisit[] = [];
  let counter = 0;

  weeks.forEach((weekStart, weekIndex) => {
    const trend = SCORE_START + ((SCORE_END - SCORE_START) * weekIndex) / (HISTORY_WEEKS - 1);

    for (const agent of agents) {
      // `agent.territoryId` is a territory ID (it becomes a UserTerritory FK);
      // `outlet.territoryId` is a territory CODE. Comparing them directly
      // matched nothing and silently produced zero visits — the whole history
      // vanished with no error, which is what this lookup exists to prevent.
      const agentTerritoryCode = agent.territoryId
        ? TERRITORY_CODE_BY_ID[agent.territoryId]
        : undefined;
      const agentOutlets = outlets.filter((o) => o.territoryId === agentTerritoryCode);
      if (agentOutlets.length === 0) continue;

      for (let n = 0; n < VISITS_PER_AGENT_PER_WEEK; n += 1) {
        // Mon-Fri only; a visit on the anchor day itself is fine, but nothing
        // beyond it — a demo must never show a visit from the future.
        const dayOffset = n % 5;
        const checkinTs = addHours(addDays(weekStart, dayOffset), 8 + intBetween(rng, 0, 8));
        if (checkinTs.getTime() > anchor.getTime() + 24 * 60 * 60 * 1000) continue;

        const outlet = agentOutlets[(weekIndex + n) % agentOutlets.length]!;
        const isProblem = problemCodes.has(outlet.code);

        const total = clampScore(
          trend + (outletOffset.get(outlet.id) ?? 0) + jitter(rng, 4)
            - (isProblem ? PROBLEM_OUTLET_PENALTY : 0),
        );

        counter += 1;
        const id = `demo-visit-${String(counter).padStart(4, '0')}`;

        // Dimensions vary around the total so the scorecard breakdown does not
        // read as six identical numbers.
        const dimension = (): number => clampScore(total + jitter(rng, 6));
        const stockSkus = skus.slice(0, 6);

        visits.push({
          id,
          outletId: outlet.id,
          outletCode: outlet.code,
          agentId: agent.id,
          checkinTs,
          checkinLat: outlet.lat + jitter(rng, 0.0002),
          checkinLng: outlet.lng + jitter(rng, 0.0002),
          checkinDistanceM: Math.round(intBetween(rng, 3, 45)),
          geofencePass: true,
          isProblemOutlet: isProblem,
          stock: stockSkus.map((sku) => {
            // A low score means empty shelves — the two must agree or the demo
            // contradicts itself when a manager drills in.
            const stockedOut = isProblem && rng() < 0.4;
            return {
              skuId: sku.id,
              unitsAvailable: stockedOut ? 0 : intBetween(rng, 8, 90),
              lastStockinDate: addDays(checkinTs, -intBetween(rng, 1, 9)),
              daysOutOfStock: stockedOut ? intBetween(rng, 1, 5) : 0,
              velocityAvg: intBetween(rng, 30, 220) / 10,
              coverageDaysPredicted: intBetween(rng, 5, 90) / 10,
              salesActual: intBetween(rng, 600, 1400),
              salesTarget: 1200,
              createdAt: checkinTs,
            };
          }),
          pricing: skus.slice(0, 4).map((sku) => {
            const deviation = isProblem && rng() < 0.5
              ? intBetween(rng, 110, 240) / 10
              : intBetween(rng, 0, 40) / 10;
            const priceActual = Math.round(sku.rrp * (1 + deviation / 100) * 100) / 100;
            return {
              skuId: sku.id,
              priceActual,
              priceMaster: sku.rrp,
              deviationPct: Math.round(deviation * 100) / 100,
              promoActive: rng() < 0.35,
              promoMaterialsDetected: { poster: rng() < 0.6, shelfStrip: rng() < 0.5 },
              commsRating: intBetween(rng, 2, 5),
              createdAt: checkinTs,
            };
          }),
          competitive: [
            {
              competitorSku: pick(rng, COMPETITORS),
              competitorPrice: intBetween(rng, 1500, 3600) / 100,
              competitorPosmType: pick(rng, POSM_TYPES),
              competitorPromoterPresent: rng() < 0.25,
              facingsCount: intBetween(rng, 2, 9),
              geotag: { lat: outlet.lat, lng: outlet.lng },
              createdAt: checkinTs,
            },
          ],
          visibility: {
            brandingElements: {
              poster: rng() < 0.8,
              shelfStrip: rng() < 0.7,
              wobbler: rng() < 0.5,
              endCap: rng() < 0.4,
            },
            planogramCompliancePct: dimension(),
            facingsCount: {
              total: intBetween(rng, 12, 30),
              byZone: { eye: intBetween(rng, 4, 14), reach: intBetween(rng, 3, 9), stoop: intBetween(rng, 1, 6) },
            },
            highTrafficPass: !isProblem || rng() < 0.3,
            cleanlinessScore: intBetween(rng, isProblem ? 1 : 3, 5),
            createdAt: checkinTs,
          },
          capability: {
            staffHeadcountConfirmed: intBetween(rng, 2, 8),
            repTrainingStatus: {
              onboarded: true,
              planogramCertified: rng() < 0.7,
              promoBriefed: rng() < 0.6,
            },
            quizScore: Math.round(dimension()),
            createdAt: checkinTs,
          },
          scorecard: {
            dimensionScores: {
              availability: dimension(),
              visibility: dimension(),
              display: dimension(),
              pricing: dimension(),
              competitive: dimension(),
              salesCapability: dimension(),
            },
            weightedTotal: total,
            ratingBand: ratingBandFor(total),
            createdAt: checkinTs,
          },
        });
      }
    }
  });

  return visits;
}

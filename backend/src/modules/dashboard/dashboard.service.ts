import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { facingsTotal, mean, onShelfAvailabilityPct, pct } from '../../lib/kpiMath';

const PRICE_COMPLIANCE_TOLERANCE_PCT = 5;

/**
 * The published perfect-store banding, highest first. An outlet sits in the
 * first band whose `minScore` its score reaches — so 89.9 is 80–89, never
 * 90–100. The healthy band starts at 80 and below 70 is an execution gap.
 */
const SCORE_BANDS: ReadonlyArray<{ label: string; minScore: number }> = [
  { label: '90–100', minScore: 90 },
  { label: '80–89', minScore: 80 },
  { label: '70–79', minScore: 70 },
  { label: '60–69', minScore: 60 },
  { label: '<60', minScore: 0 },
];

export interface DashboardFilters {
  clientId: string;
  territoryId?: string;
  outletId?: string;
  from?: Date;
  to?: Date;
}

export interface DashboardSummary {
  kpis: {
    numericDistribution: number;
    weightedDistribution: number;
    osaPct: number;
    executionScore: number;
    priceCompliancePct: number;
    visibilityCompliancePct: number;
    shareOfShelf: number;
    perfectStoreRate: number;
  };
  /**
   * How many rows each KPI above was measured over (#387, #406).
   *
   * A tile reading 100% off two observations and a tile reading 100% off two
   * thousand look identical, and a console full of confident percentages built
   * on a handful of visits is the most expensive thing this product can show a
   * manager. The client draws its low-sample treatment from these.
   *
   * `null` means the KPI is not a ratio over observations and has no
   * denominator to report. It is never 0 for that case: a client reading a
   * missing sample size as 0 would mark every healthy tile as low-sample.
   *
   * Each key is the KPI's own denominator, not a nearby proxy — `shareOfShelf`
   * divides by facings, so its sample size is facings and not the row count of
   * the captures they came from.
   *
   * There is no `baselineSampleSizes` beside this: the endpoint reports ONE
   * window and returns no deltas, so there is no baseline that could be thin.
   * The assistant's tiles, which do compare windows, carry
   * `baselineSampleSize` per figure. If a comparison window is ever added here,
   * its counts belong next to this object.
   */
  sampleSizes: {
    numericDistribution: number | null;
    weightedDistribution: number | null;
    osaPct: number | null;
    executionScore: number | null;
    priceCompliancePct: number | null;
    visibilityCompliancePct: number | null;
    shareOfShelf: number | null;
    perfectStoreRate: number | null;
  };
  totals: {
    visits: number;
    outletsVisited: number;
    outletsTotal: number;
  };
  /**
   * How many outlets sit in each perfect-store band — the distribution the
   * console draws instead of an average, because a manager acts on how many
   * doors are in which band. Always all five bands, highest first.
   */
  scoreBands: ScoreBand[];
}

export interface ScoreBand {
  label: string;
  minScore: number;
  outlets: number;
}

/** The exact payload shape produced by the visit query's `include` below. */
type ScopedVisit = Prisma.VisitGetPayload<{
  include: {
    stock: true;
    visibility: true;
    pricing: true;
    competitive: true;
    scorecard: true;
  };
}>;

interface ScopedOutlet {
  id: string;
  acvWeight: number;
}

/**
 * All of the KPI math, pulled out of `getDashboardSummary` so the
 * single-scope endpoint and the per-territory rollup compute identically.
 * This file has a `#93` history of near-duplicate KPI bugs from formulas
 * drifting between copies — there must be exactly one implementation of this
 * math, not one per caller.
 */
function computeKpisFromScope(outlets: ScopedOutlet[], visits: ScopedVisit[]): DashboardSummary {
  const outletsTotal = outlets.length;
  const visitedOutletIds = new Set(visits.map((visit) => visit.outletId));
  const outletsVisited = visitedOutletIds.size;

  const stockRows = visits.flatMap((visit) => visit.stock);
  const pricingRows = visits.flatMap((visit) => visit.pricing);
  const visibilityRows = visits.flatMap((visit) => (visit.visibility ? [visit.visibility] : []));
  const scorecards = visits.flatMap((visit) => (visit.scorecard ? [visit.scorecard] : []));

  const numericDistribution = pct(outletsVisited, outletsTotal);

  // Weighted distribution: outlets weighted by their share of category turnover
  // (`Outlet.acvWeight`), so covering one hypermarket is not equivalent to
  // covering one kiosk.
  //
  // This used to be assigned `= numericDistribution` — two tiles on the console,
  // two different labels, always the same number (#93). Now it is a real figure.
  // With every weight left at its default of 1 the two metrics agree, and that
  // is honest: if no weights are supplied, every outlet genuinely does count the
  // same.
  const totalAcv = outlets.reduce((sum, outlet) => sum + outlet.acvWeight, 0);
  const visitedAcv = outlets
    .filter((outlet) => visitedOutletIds.has(outlet.id))
    .reduce((sum, outlet) => sum + outlet.acvWeight, 0);
  const weightedDistribution = pct(visitedAcv, totalAcv);

  const osaPct = onShelfAvailabilityPct(stockRows);

  const executionScore = mean(scorecards.map((scorecard) => scorecard.weightedTotal));

  const priceCompliancePct = pct(
    pricingRows.filter((row) => Math.abs(row.deviationPct) <= PRICE_COMPLIANCE_TOLERANCE_PCT).length,
    pricingRows.length,
  );

  const visibilityCompliancePct = mean(visibilityRows.map((row) => row.planogramCompliancePct));

  // Share of shelf: our facings against the competitors' facings.
  //
  // This used to divide by the *row count* of competitive captures — so a
  // competitor holding an entire shelf counted exactly the same as one holding a
  // single can, and the denominator measured how much data an agent typed rather
  // than what was on the shelf (#93). Competitor facings are now captured
  // (`VisitCompetitive.facingsCount`), so this is a real ratio.
  const ownFacings = visibilityRows.reduce((sum, row) => sum + facingsTotal(row.facingsCount), 0);
  const competitorFacings = visits.reduce(
    (sum, visit) => sum + visit.competitive.reduce((n, row) => n + row.facingsCount, 0),
    0,
  );
  const shareOfShelf = pct(ownFacings, ownFacings + competitorFacings);

  const perfectStoreRate = pct(
    scorecards.filter((scorecard) => scorecard.ratingBand === 'green').length,
    scorecards.length,
  );

  // Perfect-store distribution counts DOORS, not visits: an outlet visited
  // three times in the window is one outlet, so each counts once — at its most
  // recent scored visit, the state a manager would find if they went today.
  const latestScoreByOutlet = new Map<string, { at: number; score: number }>();
  for (const visit of visits) {
    if (!visit.scorecard) continue;
    const at = visit.checkinTs.getTime();
    const seen = latestScoreByOutlet.get(visit.outletId);
    if (!seen || at > seen.at) {
      latestScoreByOutlet.set(visit.outletId, { at, score: visit.scorecard.weightedTotal });
    }
  }
  const scoreBands: ScoreBand[] = SCORE_BANDS.map((band) => ({ ...band, outlets: 0 }));
  for (const { score } of latestScoreByOutlet.values()) {
    // A score below every floor (never expected, but not impossible from a
    // malformed weight set) lands in the lowest band rather than vanishing.
    const band = scoreBands.find((b) => score >= b.minScore) ?? scoreBands[scoreBands.length - 1]!;
    band.outlets += 1;
  }

  return {
    kpis: {
      numericDistribution,
      weightedDistribution,
      osaPct,
      executionScore,
      priceCompliancePct,
      visibilityCompliancePct,
      shareOfShelf,
      perfectStoreRate,
    },
    // Each one is the denominator the KPI beside it was actually divided by —
    // read off the same arrays, in the same function, so the two cannot drift
    // the way two copies of a formula did in #93.
    sampleSizes: {
      numericDistribution: outletsTotal,
      weightedDistribution: outletsTotal,
      // COUNTED stock lines only, matching `onShelfAvailabilityPct` (#389).
      osaPct: stockRows.filter((row) => row.unitsAvailable !== null).length,
      executionScore: scorecards.length,
      priceCompliancePct: pricingRows.length,
      visibilityCompliancePct: visibilityRows.length,
      shareOfShelf: ownFacings + competitorFacings,
      perfectStoreRate: scorecards.length,
    },
    totals: {
      visits: visits.length,
      outletsVisited,
      outletsTotal,
    },
    scoreBands,
  };
}

export async function getDashboardSummary(filters: DashboardFilters): Promise<DashboardSummary> {
  // filters.territoryId is a Territory.id (the client-facing contract), but
  // Outlet.territoryId is free-text storing Territory.code — never id (see
  // the doc comment on getDashboardByTerritory and on the Territory model in
  // schema.prisma). Resolve id -> code before filtering. A territoryId that
  // doesn't resolve (bogus id, or another client's territory) intentionally
  // matches nothing rather than accidentally matching everything.
  let territoryCode: string | undefined;
  if (filters.territoryId) {
    const territory = await prisma.territory.findFirst({
      where: { id: filters.territoryId, clientId: filters.clientId },
    });
    territoryCode = territory?.code ?? '__no-such-territory__';
  }

  // Outlet scope — the distribution denominator honours the same
  // territory/outlet filters as the visit scope.
  const outletWhere: Prisma.OutletWhereInput = { clientId: filters.clientId };
  if (territoryCode) {
    outletWhere.territoryId = territoryCode;
  }
  if (filters.outletId) {
    outletWhere.id = filters.outletId;
  }

  const visitWhere: Prisma.VisitWhereInput = { clientId: filters.clientId };
  if (territoryCode || filters.outletId) {
    visitWhere.outlet = {
      ...(territoryCode ? { territoryId: territoryCode } : {}),
      ...(filters.outletId ? { id: filters.outletId } : {}),
    };
  }
  if (filters.from || filters.to) {
    visitWhere.checkinTs = {
      ...(filters.from ? { gte: filters.from } : {}),
      ...(filters.to ? { lte: filters.to } : {}),
    };
  }

  const [outlets, visits] = await Promise.all([
    // The ACV weights are needed for weighted distribution, so select the rows
    // rather than just counting them.
    prisma.outlet.findMany({ where: outletWhere, select: { id: true, acvWeight: true } }),
    prisma.visit.findMany({
      where: visitWhere,
      include: {
        stock: true,
        visibility: true,
        pricing: true,
        competitive: true,
        scorecard: true,
      },
    }),
  ]);

  return computeKpisFromScope(outlets, visits);
}

export interface TerritoryDashboardSummary extends DashboardSummary {
  territoryId: string;
  territoryName: string;
}

/**
 * One query pair for every territory, instead of the N+1 pattern of calling
 * `getDashboardSummary` once per territory (#97). Also the source of truth
 * for the id/code join: `Outlet.territoryId` is a free-text column that
 * stores `Territory.code`, never `Territory.id` — see the doc comment on the
 * `Territory` model in schema.prisma. Matching on `territory.id` here would
 * silently zero out every KPI below, exactly as the original per-territory
 * bug did.
 */
export async function getDashboardByTerritory(filters: {
  clientId: string;
  from?: Date;
  to?: Date;
}): Promise<TerritoryDashboardSummary[]> {
  const territories = await prisma.territory.findMany({ where: { clientId: filters.clientId } });

  const visitWhere: Prisma.VisitWhereInput = { clientId: filters.clientId };
  if (filters.from || filters.to) {
    visitWhere.checkinTs = {
      ...(filters.from ? { gte: filters.from } : {}),
      ...(filters.to ? { lte: filters.to } : {}),
    };
  }

  const [outlets, visits] = await Promise.all([
    prisma.outlet.findMany({
      where: { clientId: filters.clientId },
      select: { id: true, acvWeight: true, territoryId: true },
    }),
    prisma.visit.findMany({
      where: visitWhere,
      include: {
        stock: true,
        visibility: true,
        pricing: true,
        competitive: true,
        scorecard: true,
      },
    }),
  ]);

  return territories.map((territory) => {
    // Outlets link to a territory by Outlet.territoryId equalling
    // Territory.code (a deliberate, pre-existing design), NOT Territory.id.
    const scopedOutlets = outlets.filter((outlet) => outlet.territoryId === territory.code);
    const scopedOutletIds = new Set(scopedOutlets.map((outlet) => outlet.id));
    const scopedVisits = visits.filter((visit) => scopedOutletIds.has(visit.outletId));

    return {
      territoryId: territory.id,
      territoryName: territory.name,
      ...computeKpisFromScope(scopedOutlets, scopedVisits),
    };
  });
}

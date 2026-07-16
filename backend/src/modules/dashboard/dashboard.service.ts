import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { facingsTotal, mean, pct } from '../../lib/kpiMath';

const PRICE_COMPLIANCE_TOLERANCE_PCT = 5;

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
  totals: {
    visits: number;
    outletsVisited: number;
    outletsTotal: number;
  };
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

  const osaPct = pct(
    stockRows.filter((row) => row.unitsAvailable > 0).length,
    stockRows.length,
  );

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
    totals: {
      visits: visits.length,
      outletsVisited,
      outletsTotal,
    },
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

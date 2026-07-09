import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';

const PRICE_COMPLIANCE_TOLERANCE_PCT = 5;

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

/** Ratio helper that returns 0 (never NaN) on an empty denominator. */
function pct(numerator: number, denominator: number): number {
  return denominator > 0 ? round2((100 * numerator) / denominator) : 0;
}

function mean(values: number[]): number {
  return values.length > 0 ? round2(values.reduce((sum, v) => sum + v, 0) / values.length) : 0;
}

/** Safely read the `.total` field out of the facingsCount Json column. */
function facingsTotal(value: Prisma.JsonValue): number {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    return 0;
  }
  const total = (value as Record<string, unknown>).total;
  return typeof total === 'number' && Number.isFinite(total) ? total : 0;
}

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

export async function getDashboardSummary(filters: DashboardFilters): Promise<DashboardSummary> {
  // Outlet scope — the distribution denominator honours the same
  // territory/outlet filters as the visit scope.
  const outletWhere: Prisma.OutletWhereInput = { clientId: filters.clientId };
  if (filters.territoryId) {
    outletWhere.territoryId = filters.territoryId;
  }
  if (filters.outletId) {
    outletWhere.id = filters.outletId;
  }

  const visitWhere: Prisma.VisitWhereInput = { clientId: filters.clientId };
  if (filters.territoryId || filters.outletId) {
    visitWhere.outlet = {
      ...(filters.territoryId ? { territoryId: filters.territoryId } : {}),
      ...(filters.outletId ? { id: filters.outletId } : {}),
    };
  }
  if (filters.from || filters.to) {
    visitWhere.checkinTs = {
      ...(filters.from ? { gte: filters.from } : {}),
      ...(filters.to ? { lte: filters.to } : {}),
    };
  }

  const [outletsTotal, visits] = await Promise.all([
    prisma.outlet.count({ where: outletWhere }),
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

  const outletsVisited = new Set(visits.map((visit) => visit.outletId)).size;

  const stockRows = visits.flatMap((visit) => visit.stock);
  const pricingRows = visits.flatMap((visit) => visit.pricing);
  const visibilityRows = visits.flatMap((visit) => (visit.visibility ? [visit.visibility] : []));
  const competitiveRowCount = visits.reduce((sum, visit) => sum + visit.competitive.length, 0);
  const scorecards = visits.flatMap((visit) => (visit.scorecard ? [visit.scorecard] : []));

  const numericDistribution = pct(outletsVisited, outletsTotal);

  // Phase-1 proxy: weighted distribution equals numeric distribution until we
  // have per-outlet sales volumes to weight by (Phase 2).
  const weightedDistribution = numericDistribution;

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

  // Phase-1 share-of-shelf proxy: our facings come from the visibility
  // capture's facingsCount.total, and each competitive row counts as a single
  // competitor facing. Real shelf-space measurement is a Phase-2 concern.
  const ownFacings = visibilityRows.reduce((sum, row) => sum + facingsTotal(row.facingsCount), 0);
  const shareOfShelf = pct(ownFacings, ownFacings + competitiveRowCount);

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

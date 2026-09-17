import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { mean, pct, round2 } from '../../lib/kpiMath';
import { personLabel } from '../../lib/personName';
import {
  getSellInPerformance,
  SELL_IN_BASIS,
  SELL_IN_LABEL,
  SELL_IN_METRIC,
  sellInUnitsByTerritoryCode,
  type SellInPerformance,
} from '../salesTargets/salesTargets.service';

/**
 * The assistant's semantic layer — one read-only aggregate per pillar.
 *
 * **Why a new service rather than additions to the pillar modules.** The design
 * rule is that tools wrap services and never write Prisma themselves, so these
 * queries had to live in *a* service. Putting them in `stock.service.ts`,
 * `visibility.service.ts` and so on would spread one cohesive change across six
 * files that other branches are actively editing — and a service file touched
 * by two branches is the semantic conflict that turns two green PRs into a red
 * `main`. These are also genuinely a different shape from what those modules
 * do: they capture and read *one visit*, and every function here summarises
 * *many*.
 *
 * The accuracy argument for the whole approach lives here too. A semantic layer
 * scores roughly 98% against roughly 90% for text-to-SQL — but the reason it
 * was chosen is the *failure mode*, not the delta. When a question falls
 * outside these functions the assistant refuses; a model writing SQL invents a
 * plausible number instead, and a plausible number goes into a meeting.
 *
 * Every function takes `clientId` and a half-open `[from, to)` window, and every
 * query filters on both. Tenancy is not assumed from the caller.
 */

export interface PillarWindow {
  clientId: string;
  from: Date;
  to: Date;
  /** A `Territory.id` — resolved to its code below. See the note on {@link territoryFilter}. */
  territoryId?: string;
}

/**
 * `Outlet.territoryId` stores the territory **code** as free text, not the id
 * (the #97 postmortem). The client-facing contract everywhere else is a
 * `Territory.id`, so it has to be resolved before filtering.
 *
 * An unresolvable id matches **nothing** rather than everything. Getting this
 * backwards is how a scoped question silently returns the whole tenant — which
 * reads as a working answer.
 */
async function territoryFilter(
  clientId: string,
  territoryId: string | undefined,
): Promise<{ territoryId?: string }> {
  if (!territoryId) return {};
  const territory = await prisma.territory.findFirst({
    where: { id: territoryId, clientId },
    select: { code: true },
  });
  return { territoryId: territory?.code ?? '__no-such-territory__' };
}

async function visitScope(input: PillarWindow): Promise<Prisma.VisitWhereInput> {
  const outlet = await territoryFilter(input.clientId, input.territoryId);
  return {
    clientId: input.clientId,
    checkinTs: { gte: input.from, lt: input.to },
    ...(Object.keys(outlet).length > 0 ? { outlet } : {}),
  };
}

/**
 * A cap on how many rows any one of these aggregates will read.
 *
 * At the ~190k visits/year this schema anticipates, an unbounded read is a slow
 * request that gets slower every month — the failure the pagination sweep
 * (#141) existed to remove. Every function that hits the ceiling reports
 * `truncated: true` rather than quietly returning a partial answer, because a
 * manager who cannot see something concludes it is not there.
 */
export const MAX_SCAN = 5_000;

/**
 * The sales pillar's figures are {@link SellInPerformance} — sell-in from
 * orders, against manager-set monthly targets (#119).
 *
 * Re-exported under the pillar's own name so the tool layer keeps importing one
 * semantic-layer type, and aliased rather than redefined so the two cannot
 * drift into disagreeing about a field.
 */
export type SalesPerformance = SellInPerformance;

/**
 * Sales — sell-in over the window, against the month's target (#337).
 *
 * **What changed, and why.** This used to sum `VisitStock.salesActual` and
 * `salesTarget`: two numbers an agent typed at the shelf. The S2 form stopped
 * asking for them in #112 — an agent standing in a store has no way to know
 * what the store sold — so the columns thinned to nothing and the assistant's
 * sales answers went with them. Nobody noticed, because an empty sum is `0`
 * and `0` reads as a real, bad month.
 *
 * The figures now come from the same place the console's attainment report
 * does: {@link getSellInPerformance} in `modules/salesTargets`, one grouped
 * query over non-cancelled order lines dated by `Order.capturedAt` (#338). The
 * assistant and the console therefore cannot quote different numbers for the
 * same month, which is the whole reason this delegates instead of querying.
 *
 * **Sell-in, and labelled as such.** These are units outlets *ordered through
 * TradeIQ*, never consumer sell-out — there is no POS feed in this product.
 * The result carries that statement in `basis` and the tool repeats it in its
 * description, because a model with an unlabelled "sales" number will call it
 * sales.
 */
export async function getSalesPerformance(input: PillarWindow): Promise<SalesPerformance> {
  return getSellInPerformance({
    clientId: input.clientId,
    from: input.from,
    to: input.to,
    ...(input.territoryId ? { territoryId: input.territoryId } : {}),
  });
}

export interface TerritorySellInRow {
  territoryId: string;
  territoryName: string;
  region: string | null;
  sellInUnits: number;
  comparisonSellInUnits: number;
  /** Signed, one decimal. Never computed against a zero baseline — see below. */
  changePct: number;
}

export interface TerritorySellInChange {
  metric: typeof SELL_IN_METRIC;
  metricLabel: typeof SELL_IN_LABEL;
  basis: string;
  timeZone: string;
  from: Date;
  to: Date;
  comparisonFrom: Date;
  comparisonTo: Date;
  /** The region filter applied, or null for every territory. */
  region: string | null;
  /** Sum over the territories in scope, current and comparison windows. */
  totalSellInUnits: number;
  comparisonTotalSellInUnits: number;
  /** Worst first: most negative change leads; ties by name. */
  territories: TerritorySellInRow[];
  /**
   * Territories left out because the comparison window had no sell-in, so a
   * percentage change does not exist. Listed rather than dropped silently, so
   * "Tembisa is missing" has an answer.
   */
  excludedNoComparison: { territoryId: string; territoryName: string; sellInUnits: number }[];
  note: string;
}

/**
 * Sales — sell-in change per territory, current window against a comparison
 * window. The one per-territory sell-in figure the assistant has.
 *
 * Both windows read {@link sellInUnitsByTerritoryCode}, i.e. the same grouped
 * order query as {@link getSalesPerformance} and the console's attainment
 * report, dated by `Order.capturedAt` (#338). Totals here therefore agree with
 * `getRateOfSale` for the same window.
 *
 * **No target, no attainment.** This compares two windows of sell-in; it does
 * not claim anything against a target, so rule 9 has nothing to gate.
 *
 * A territory with **no sell-in in the comparison window** has no percentage
 * change — "up from nothing" is not +100% or +∞ — so it is excluded from the
 * ranking and listed in `excludedNoComparison` instead. A territory that sold
 * before and nothing now is a real −100% and stays in.
 *
 * Tenant scoping: territories come from this client only, and the order query
 * filters on the client too — a code another tenant also uses resolves to
 * nothing here.
 */
export async function getTerritorySellInChange(input: {
  clientId: string;
  timeZone: string;
  current: { from: Date; to: Date };
  comparison: { from: Date; to: Date };
  region?: string;
}): Promise<TerritorySellInChange> {
  const territories = await prisma.territory.findMany({
    where: {
      clientId: input.clientId,
      ...(input.region ? { region: { equals: input.region, mode: 'insensitive' as const } } : {}),
    },
    select: { id: true, name: true, code: true, region: true },
    orderBy: { name: 'asc' },
  });

  // Sequential, like the pillar tools' comparisons: the same indexed query
  // twice, not a fan-out against a database also serving the console.
  const now = await sellInUnitsByTerritoryCode(input.clientId, input.current);
  const before = await sellInUnitsByTerritoryCode(input.clientId, input.comparison);

  const ranked: TerritorySellInRow[] = [];
  const excluded: TerritorySellInChange['excludedNoComparison'] = [];
  let total = 0;
  let comparisonTotal = 0;

  for (const territory of territories) {
    const sellInUnits = now.get(territory.code) ?? 0;
    const comparisonSellInUnits = before.get(territory.code) ?? 0;
    total += sellInUnits;
    comparisonTotal += comparisonSellInUnits;

    if (comparisonSellInUnits <= 0) {
      excluded.push({ territoryId: territory.id, territoryName: territory.name, sellInUnits });
      continue;
    }
    const change = Math.round(((sellInUnits - comparisonSellInUnits) / comparisonSellInUnits) * 1000) / 10;
    ranked.push({
      territoryId: territory.id,
      territoryName: territory.name,
      region: territory.region,
      sellInUnits,
      comparisonSellInUnits,
      changePct: Object.is(change, -0) ? 0 : change,
    });
  }

  ranked.sort((a, b) =>
    a.changePct === b.changePct
      ? a.territoryName.localeCompare(b.territoryName)
      : a.changePct - b.changePct,
  );

  return {
    metric: SELL_IN_METRIC,
    metricLabel: SELL_IN_LABEL,
    basis: SELL_IN_BASIS,
    timeZone: input.timeZone,
    from: input.current.from,
    to: input.current.to,
    comparisonFrom: input.comparison.from,
    comparisonTo: input.comparison.to,
    region: input.region ?? null,
    totalSellInUnits: total,
    comparisonTotalSellInUnits: comparisonTotal,
    territories: ranked,
    excludedNoComparison: excluded,
    note:
      'changePct is the change in sell-in units against the comparison window. Territories ' +
      'with no sell-in in the comparison window have no percentage change and are listed in ' +
      'excludedNoComparison instead of being ranked. No targets are involved.',
  };
}

export interface SkuMovementRow {
  skuId: string;
  skuName: string;
  category: string;
  unitsAvailable: number;
  velocityAvg: number;
  daysOutOfStock: number;
  observations: number;
}

/** Sales — per-SKU movement, worst coverage first. */
export async function getSkuMovement(
  input: PillarWindow & { limit?: number },
): Promise<{ rows: SkuMovementRow[]; truncated: boolean }> {
  const rows = await prisma.visitStock.findMany({
    where: { visit: await visitScope(input) },
    select: {
      skuId: true,
      unitsAvailable: true,
      velocityAvg: true,
      daysOutOfStock: true,
      sku: { select: { name: true, category: true } },
    },
    take: MAX_SCAN + 1,
  });

  const scanned = rows.slice(0, MAX_SCAN);
  const bySku = new Map<string, SkuMovementRow>();

  for (const row of scanned) {
    const existing = bySku.get(row.skuId);
    if (existing) {
      existing.unitsAvailable += row.unitsAvailable;
      existing.velocityAvg = round2(
        (existing.velocityAvg * existing.observations + row.velocityAvg) /
          (existing.observations + 1),
      );
      existing.daysOutOfStock = Math.max(existing.daysOutOfStock, row.daysOutOfStock);
      existing.observations += 1;
    } else {
      bySku.set(row.skuId, {
        skuId: row.skuId,
        skuName: row.sku.name,
        category: row.sku.category,
        unitsAvailable: row.unitsAvailable,
        velocityAvg: round2(row.velocityAvg),
        daysOutOfStock: row.daysOutOfStock,
        observations: 1,
      });
    }
  }

  // Worst first. A manager asking about movement is looking for the problem,
  // not for an alphabetical list.
  const sorted = [...bySku.values()].sort((a, b) => b.daysOutOfStock - a.daysOutOfStock);

  return { rows: sorted.slice(0, input.limit ?? 20), truncated: rows.length > MAX_SCAN };
}

export interface StockLevels {
  onShelfAvailabilityPct: number;
  linesObserved: number;
  outOfStockLines: number;
  outletsWithStockout: number;
  /**
   * Coordinates ride here so the `outlet_map` artifact can draw pins straight
   * from the tool result — the spec params carry only outlet ids, and the
   * client never re-fetches to render an inline card.
   */
  worstOutlets: {
    outletId: string;
    outletName: string;
    outOfStockLines: number;
    lat: number;
    lng: number;
  }[];
  truncated: boolean;
}

/** Stock — availability, and where it is worst. */
export async function getStockLevels(input: PillarWindow): Promise<StockLevels> {
  const rows = await prisma.visitStock.findMany({
    where: { visit: await visitScope(input) },
    select: {
      unitsAvailable: true,
      visit: {
        select: { outletId: true, outlet: { select: { name: true, lat: true, lng: true } } },
      },
    },
    take: MAX_SCAN + 1,
  });

  const scanned = rows.slice(0, MAX_SCAN);
  const outOfStock = scanned.filter((r) => r.unitsAvailable <= 0);

  const byOutlet = new Map<string, StockLevels['worstOutlets'][number]>();
  for (const row of outOfStock) {
    const key = row.visit.outletId;
    const existing = byOutlet.get(key);
    if (existing) existing.outOfStockLines += 1;
    else
      byOutlet.set(key, {
        outletId: key,
        outletName: row.visit.outlet.name,
        outOfStockLines: 1,
        lat: row.visit.outlet.lat,
        lng: row.visit.outlet.lng,
      });
  }

  return {
    onShelfAvailabilityPct: pct(scanned.length - outOfStock.length, scanned.length),
    linesObserved: scanned.length,
    outOfStockLines: outOfStock.length,
    outletsWithStockout: byOutlet.size,
    worstOutlets: [...byOutlet.values()]
      .sort((a, b) => b.outOfStockLines - a.outOfStockLines)
      .slice(0, 10),
    truncated: rows.length > MAX_SCAN,
  };
}

/** Safely read a facings JSON column's `.total`. Mirrors `kpiMath.facingsTotal`. */
function facingsOf(value: unknown): number {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return 0;
  const total = (value as Record<string, unknown>).total;
  return typeof total === 'number' && Number.isFinite(total) ? total : 0;
}

export interface ShareOfShelf {
  shareOfShelfPct: number;
  ourFacings: number;
  competitorFacings: number;
  observations: number;
  truncated: boolean;
}

/** Visibility — our facings against the competition's. */
export async function getShareOfShelf(input: PillarWindow): Promise<ShareOfShelf> {
  const scope = await visitScope(input);

  const [ours, theirs] = await Promise.all([
    prisma.visitVisibility.findMany({
      where: { visit: scope },
      select: { facingsCount: true },
      take: MAX_SCAN + 1,
    }),
    prisma.visitCompetitive.findMany({
      where: { visit: scope },
      // Counting rows instead of this column made a competitor holding a whole
      // shelf count the same as one holding a single can.
      select: { facingsCount: true },
      take: MAX_SCAN + 1,
    }),
  ]);

  const ourFacings = ours.slice(0, MAX_SCAN).reduce((sum, r) => sum + facingsOf(r.facingsCount), 0);
  const competitorFacings = theirs
    .slice(0, MAX_SCAN)
    .reduce((sum, r) => sum + r.facingsCount, 0);

  return {
    shareOfShelfPct: pct(ourFacings, ourFacings + competitorFacings),
    ourFacings,
    competitorFacings,
    observations: Math.min(ours.length, MAX_SCAN),
    truncated: ours.length > MAX_SCAN || theirs.length > MAX_SCAN,
  };
}

export interface VisibilityCompliance {
  planogramCompliancePct: number;
  cleanlinessScore: number;
  highTrafficPassPct: number;
  observations: number;
  truncated: boolean;
}

/** Visibility — planogram compliance and shelf quality. */
export async function getVisibilityCompliance(
  input: PillarWindow,
): Promise<VisibilityCompliance> {
  const rows = await prisma.visitVisibility.findMany({
    where: { visit: await visitScope(input) },
    select: { planogramCompliancePct: true, cleanlinessScore: true, highTrafficPass: true },
    take: MAX_SCAN + 1,
  });

  const scanned = rows.slice(0, MAX_SCAN);

  return {
    planogramCompliancePct: mean(scanned.map((r) => r.planogramCompliancePct)),
    cleanlinessScore: mean(scanned.map((r) => r.cleanlinessScore)),
    highTrafficPassPct: pct(scanned.filter((r) => r.highTrafficPass).length, scanned.length),
    observations: scanned.length,
    truncated: rows.length > MAX_SCAN,
  };
}

export interface CompetitorActivity {
  observations: number;
  distinctCompetitorSkus: number;
  promoterPresencePct: number;
  topCompetitors: {
    competitorSku: string;
    sightings: number;
    averagePrice: number;
    facings: number;
  }[];
  truncated: boolean;
}

/** Competition — who is on the shelf, at what price. */
export async function getCompetitorActivity(input: PillarWindow): Promise<CompetitorActivity> {
  const rows = await prisma.visitCompetitive.findMany({
    where: { visit: await visitScope(input) },
    select: {
      competitorSku: true,
      competitorPrice: true,
      competitorPromoterPresent: true,
      facingsCount: true,
    },
    take: MAX_SCAN + 1,
  });

  const scanned = rows.slice(0, MAX_SCAN);
  const bySku = new Map<string, { sightings: number; prices: number[]; facings: number }>();

  for (const row of scanned) {
    const entry = bySku.get(row.competitorSku) ?? { sightings: 0, prices: [], facings: 0 };
    entry.sightings += 1;
    entry.prices.push(row.competitorPrice);
    entry.facings += row.facingsCount;
    bySku.set(row.competitorSku, entry);
  }

  return {
    observations: scanned.length,
    distinctCompetitorSkus: bySku.size,
    promoterPresencePct: pct(
      scanned.filter((r) => r.competitorPromoterPresent).length,
      scanned.length,
    ),
    topCompetitors: [...bySku.entries()]
      .map(([competitorSku, entry]) => ({
        competitorSku,
        sightings: entry.sightings,
        averagePrice: mean(entry.prices),
        facings: entry.facings,
      }))
      .sort((a, b) => b.facings - a.facings)
      .slice(0, 10),
    truncated: rows.length > MAX_SCAN,
  };
}

export interface VisitSummary {
  visits: number;
  submitted: number;
  inProgress: number;
  outletsVisited: number;
  geofenceFailures: number;
  recent: {
    visitId: string;
    outletName: string;
    /** What to call the agent: their display name, or their email when they have none. */
    agentName: string;
    agentEmail: string;
    checkinTs: string;
    status: string;
  }[];
  truncated: boolean;
}

/** Execution — what was actually visited. */
export async function getVisitSummary(
  input: PillarWindow & { agentId?: string; outletId?: string },
): Promise<VisitSummary> {
  const scope = await visitScope(input);
  const rows = await prisma.visit.findMany({
    where: {
      ...scope,
      ...(input.agentId ? { agentId: input.agentId } : {}),
      ...(input.outletId ? { outletId: input.outletId } : {}),
    },
    select: {
      id: true,
      outletId: true,
      status: true,
      checkinTs: true,
      geofencePass: true,
      outlet: { select: { name: true } },
      agent: { select: { email: true, displayName: true } },
    },
    orderBy: [{ checkinTs: 'desc' }, { id: 'desc' }],
    take: MAX_SCAN + 1,
  });

  const scanned = rows.slice(0, MAX_SCAN);

  return {
    visits: scanned.length,
    submitted: scanned.filter((r) => r.status === 'submitted').length,
    inProgress: scanned.filter((r) => r.status === 'in_progress').length,
    outletsVisited: new Set(scanned.map((r) => r.outletId)).size,
    geofenceFailures: scanned.filter((r) => !r.geofencePass).length,
    recent: scanned.slice(0, 20).map((r) => ({
      visitId: r.id,
      outletName: r.outlet.name,
      agentName: personLabel(r.agent.displayName, r.agent.email),
      agentEmail: r.agent.email,
      checkinTs: r.checkinTs.toISOString(),
      status: r.status,
    })),
    truncated: rows.length > MAX_SCAN,
  };
}

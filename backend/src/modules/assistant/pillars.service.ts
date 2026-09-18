import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { pct, round2 } from '../../lib/kpiMath';
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

/**
 * The visit-level tenant, window and territory filter every aggregate below
 * shares, as a SQL fragment over `visits v`.
 *
 * It is the same predicate the Prisma relation filter used to build —
 * `v.client_id`, a half-open `[from, to)` on `checkin_ts`, and an outlet whose
 * `territory_id` (a code) matches — written once so no aggregate can scope
 * differently from its neighbours. Every value is a bound parameter.
 */
async function visitWhere(
  input: PillarWindow & { agentId?: string; outletId?: string },
): Promise<Prisma.Sql> {
  const outlet = await territoryFilter(input.clientId, input.territoryId);
  return Prisma.sql`v."client_id" = ${input.clientId}
    AND v."checkin_ts" >= ${input.from.toISOString()}::timestamp
    AND v."checkin_ts" < ${input.to.toISOString()}::timestamp
    ${
      outlet.territoryId !== undefined
        ? Prisma.sql`AND v."outlet_id" IN (SELECT o."id" FROM "outlets" o WHERE o."territory_id" = ${outlet.territoryId})`
        : Prisma.empty
    }
    ${input.agentId ? Prisma.sql`AND v."agent_id" = ${input.agentId}` : Prisma.empty}
    ${input.outletId ? Prisma.sql`AND v."outlet_id" = ${input.outletId}` : Prisma.empty}`;
}

/**
 * Every figure below is aggregated **in the database, over every row in
 * scope** (#359).
 *
 * These used to fetch at most 5,000 rows and sum them in memory. On a real
 * tenant that cap is about four working days of stock lines, so a
 * month-to-date or year-to-date answer was computed from an arbitrary slice
 * and quoted as if it were whole — rule 1's "invented figure" by another route.
 * Grouping in Postgres makes the row count irrelevant to correctness and
 * faster besides: only the aggregates cross the wire.
 *
 * Lists (worst outlets, top competitors, SKU rows, recent visits) are still
 * capped, because a model does not need 400 outlets to name the worst ten. The
 * cap applies to the list only — totals are computed before it — and a capped
 * list says so with `truncated: true` and the full count alongside.
 */
export const WORST_OUTLETS_LIMIT = 10;
export const TOP_COMPETITORS_LIMIT = 10;
export const RECENT_VISITS_LIMIT = 20;

/** Postgres `bigint`/`numeric` come back as BigInt/Decimal; every figure here is a JS number. */
function num(value: unknown): number {
  if (value === null || value === undefined) return 0;
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
}

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

export interface SkuMovement {
  /** Worst first: longest out of stock, then lowest stock on hand, then name. */
  rows: SkuMovementRow[];
  /** SKUs with any stock line in scope — `rows` is the first `limit` of these. */
  totalCount: number;
  /** True when `rows` is shorter than `totalCount`. Each row's figures are still whole. */
  truncated: boolean;
}

/** Sales — per-SKU movement, worst coverage first. */
export async function getSkuMovement(
  input: PillarWindow & { limit?: number },
): Promise<SkuMovement> {
  const limit = input.limit ?? 20;
  const rows = await prisma.$queryRaw<
    {
      sku_id: string;
      name: string;
      category: string;
      units: unknown;
      velocity_sum: unknown;
      days_out: unknown;
      observations: unknown;
      total_count: unknown;
    }[]
  >`
    WITH per_sku AS (
      -- observations is the SKU's sample size and units its total on
      -- shelf, so both count only lines that were actually counted (#389).
      -- SUM already skips NULL; the FILTER keeps the two consistent, so a SKU
      -- can never report more observations than counts behind its total.
      SELECT vs."sku_id",
        SUM(vs."units_available")::float8 AS units,
        SUM(vs."velocity_avg")::float8 AS velocity_sum,
        MAX(vs."days_out_of_stock") AS days_out,
        COUNT(*) FILTER (WHERE vs."units_available" IS NOT NULL)::int AS observations
      FROM "visit_stock" vs
      JOIN "visits" v ON v."id" = vs."visit_id"
      WHERE ${await visitWhere(input)}
      GROUP BY vs."sku_id"
      HAVING COUNT(*) FILTER (WHERE vs."units_available" IS NOT NULL) > 0
    )
    SELECT p."sku_id", s."name", s."category", p.units, p.velocity_sum, p.days_out,
      p.observations, COUNT(*) OVER ()::int AS total_count
    FROM per_sku p
    JOIN "skus" s ON s."id" = p."sku_id"
    ORDER BY p.days_out DESC, p.units ASC, s."name" ASC, p."sku_id" ASC
    LIMIT ${limit}
  `;

  const totalCount = rows.length > 0 ? num(rows[0].total_count) : 0;
  return {
    // Worst first. A manager asking about movement is looking for the problem,
    // not for an alphabetical list.
    rows: rows.map((row) => ({
      skuId: row.sku_id,
      skuName: row.name,
      category: row.category,
      unitsAvailable: num(row.units),
      velocityAvg: round2(num(row.velocity_sum) / Math.max(1, num(row.observations))),
      daysOutOfStock: num(row.days_out),
      observations: num(row.observations),
    })),
    totalCount,
    truncated: totalCount > rows.length,
  };
}

export interface StockLevels {
  onShelfAvailabilityPct: number;
  linesObserved: number;
  outOfStockLines: number;
  /** Every outlet with a stock-out in scope; `worstOutlets` is the top of these. */
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
  /** True when `worstOutlets` lists fewer outlets than `outletsWithStockout`. */
  truncated: boolean;
}

/** Stock — availability, and where it is worst. */
export async function getStockLevels(input: PillarWindow): Promise<StockLevels> {
  // One scan: per-outlet counts, with the whole-scope totals as window sums over
  // every outlet row *before* the limit applies. Outlets are ordered by
  // stock-outs, so any outlet with one sorts ahead of every outlet without, and
  // dropping the zero rows after the limit cannot lose a worse outlet.
  const rows = await prisma.$queryRaw<
    {
      outlet_id: string;
      name: string;
      lat: number;
      lng: number;
      oos: unknown;
      total_lines: unknown;
      total_oos: unknown;
      outlets_with_stockout: unknown;
    }[]
  >`
    WITH per_outlet AS (
      -- Counted lines only (#389): lines is the availability denominator and
      -- the sample size reported to the model, and a SKU nobody reached is
      -- neither on the shelf nor off it. '<= 0' already excludes NULL in SQL,
      -- so a stock-out still means a counted zero.
      SELECT v."outlet_id",
        COUNT(*) FILTER (WHERE vs."units_available" IS NOT NULL)::int AS lines,
        COUNT(*) FILTER (WHERE vs."units_available" <= 0)::int AS oos
      FROM "visit_stock" vs
      JOIN "visits" v ON v."id" = vs."visit_id"
      WHERE ${await visitWhere(input)}
      GROUP BY v."outlet_id"
    )
    SELECT p."outlet_id", o."name", o."lat", o."lng", p.oos,
      SUM(p.lines) OVER ()::float8 AS total_lines,
      SUM(p.oos) OVER ()::float8 AS total_oos,
      COUNT(*) FILTER (WHERE p.oos > 0) OVER ()::int AS outlets_with_stockout
    FROM per_outlet p
    JOIN "outlets" o ON o."id" = p."outlet_id"
    ORDER BY p.oos DESC, o."name" ASC, p."outlet_id" ASC
    LIMIT ${WORST_OUTLETS_LIMIT}
  `;

  const lines = num(rows[0]?.total_lines);
  const outOfStockLines = num(rows[0]?.total_oos);
  const outletsWithStockout = num(rows[0]?.outlets_with_stockout);
  const worst = rows.filter((row) => num(row.oos) > 0);

  return {
    onShelfAvailabilityPct: pct(lines - outOfStockLines, lines),
    linesObserved: lines,
    outOfStockLines,
    outletsWithStockout,
    worstOutlets: worst.map((row) => ({
      outletId: row.outlet_id,
      outletName: row.name,
      outOfStockLines: num(row.oos),
      lat: row.lat,
      lng: row.lng,
    })),
    truncated: outletsWithStockout > worst.length,
  };
}

/**
 * A facings JSON column's `.total`, in SQL. Mirrors `kpiMath.facingsTotal`: a
 * non-object column or a non-numeric total counts as 0 rather than failing.
 */
const OWN_FACINGS_SQL = Prisma.sql`CASE
  WHEN jsonb_typeof(vv."facings_count") = 'object'
    AND jsonb_typeof(vv."facings_count"->'total') = 'number'
  THEN (vv."facings_count"->>'total')::float8
  ELSE 0 END`;

export interface ShareOfShelf {
  shareOfShelfPct: number;
  ourFacings: number;
  competitorFacings: number;
  observations: number;
}

/** Visibility — our facings against the competition's. */
export async function getShareOfShelf(input: PillarWindow): Promise<ShareOfShelf> {
  const where = await visitWhere(input);

  const [ours] = await prisma.$queryRaw<{ facings: unknown; observations: unknown }[]>`
    SELECT COALESCE(SUM(${OWN_FACINGS_SQL}), 0)::float8 AS facings, COUNT(*)::int AS observations
    FROM "visit_visibility" vv
    JOIN "visits" v ON v."id" = vv."visit_id"
    WHERE ${where}
  `;
  // Summing this column rather than counting rows: counting made a competitor
  // holding a whole shelf count the same as one holding a single can.
  const [theirs] = await prisma.$queryRaw<{ facings: unknown }[]>`
    SELECT COALESCE(SUM(vc."facings_count"), 0)::float8 AS facings
    FROM "visit_competitive" vc
    JOIN "visits" v ON v."id" = vc."visit_id"
    WHERE ${where}
  `;

  const ourFacings = num(ours?.facings);
  const competitorFacings = num(theirs?.facings);

  return {
    shareOfShelfPct: pct(ourFacings, ourFacings + competitorFacings),
    ourFacings,
    competitorFacings,
    observations: num(ours?.observations),
  };
}

export interface VisibilityCompliance {
  planogramCompliancePct: number;
  cleanlinessScore: number;
  highTrafficPassPct: number;
  observations: number;
}

/** Visibility — planogram compliance and shelf quality. */
export async function getVisibilityCompliance(
  input: PillarWindow,
): Promise<VisibilityCompliance> {
  const [row] = await prisma.$queryRaw<
    { planogram: unknown; cleanliness: unknown; high_traffic: unknown; observations: unknown }[]
  >`
    SELECT COALESCE(SUM(vv."planogram_compliance_pct"), 0)::float8 AS planogram,
      COALESCE(SUM(vv."cleanliness_score"), 0)::float8 AS cleanliness,
      COUNT(*) FILTER (WHERE vv."high_traffic_pass")::int AS high_traffic,
      COUNT(*)::int AS observations
    FROM "visit_visibility" vv
    JOIN "visits" v ON v."id" = vv."visit_id"
    WHERE ${await visitWhere(input)}
  `;

  const observations = num(row?.observations);
  // `mean` over an empty set is 0, so the division is guarded the same way.
  const average = (sum: unknown) => (observations > 0 ? round2(num(sum) / observations) : 0);

  return {
    planogramCompliancePct: average(row?.planogram),
    cleanlinessScore: average(row?.cleanliness),
    highTrafficPassPct: pct(num(row?.high_traffic), observations),
    observations,
  };
}

export interface CompetitorActivity {
  observations: number;
  distinctCompetitorSkus: number;
  promoterPresencePct: number;
  /** Most facings first; the top of `distinctCompetitorSkus`. */
  topCompetitors: {
    competitorSku: string;
    sightings: number;
    averagePrice: number;
    facings: number;
  }[];
  /** True when `topCompetitors` lists fewer SKUs than `distinctCompetitorSkus`. */
  truncated: boolean;
}

/** Competition — who is on the shelf, at what price. */
export async function getCompetitorActivity(input: PillarWindow): Promise<CompetitorActivity> {
  const where = await visitWhere(input);

  const [totals] = await prisma.$queryRaw<
    { observations: unknown; promoters: unknown; distinct_skus: unknown }[]
  >`
    SELECT COUNT(*)::int AS observations,
      COUNT(*) FILTER (WHERE vc."competitor_promoter_present")::int AS promoters,
      COUNT(DISTINCT vc."competitor_sku")::int AS distinct_skus
    FROM "visit_competitive" vc
    JOIN "visits" v ON v."id" = vc."visit_id"
    WHERE ${where}
  `;

  const top = await prisma.$queryRaw<
    { competitor_sku: string; sightings: unknown; price_sum: unknown; facings: unknown }[]
  >`
    SELECT vc."competitor_sku",
      COUNT(*)::int AS sightings,
      SUM(vc."competitor_price")::float8 AS price_sum,
      SUM(vc."facings_count")::float8 AS facings
    FROM "visit_competitive" vc
    JOIN "visits" v ON v."id" = vc."visit_id"
    WHERE ${where}
    GROUP BY vc."competitor_sku"
    ORDER BY facings DESC, vc."competitor_sku" ASC
    LIMIT ${TOP_COMPETITORS_LIMIT}
  `;

  const observations = num(totals?.observations);
  const distinctCompetitorSkus = num(totals?.distinct_skus);

  return {
    observations,
    distinctCompetitorSkus,
    promoterPresencePct: pct(num(totals?.promoters), observations),
    topCompetitors: top.map((row) => ({
      competitorSku: row.competitor_sku,
      sightings: num(row.sightings),
      averagePrice: round2(num(row.price_sum) / Math.max(1, num(row.sightings))),
      facings: num(row.facings),
    })),
    truncated: distinctCompetitorSkus > top.length,
  };
}

export interface VisitSummary {
  visits: number;
  submitted: number;
  inProgress: number;
  outletsVisited: number;
  geofenceFailures: number;
  /** The newest visits, newest first; the top of `visits`. */
  recent: {
    visitId: string;
    outletName: string;
    /** What to call the agent: their display name, or their email when they have none. */
    agentName: string;
    agentEmail: string;
    checkinTs: string;
    status: string;
  }[];
  /** True when `recent` lists fewer visits than `visits`. The counts are still whole. */
  truncated: boolean;
}

/** Execution — what was actually visited. */
export async function getVisitSummary(
  input: PillarWindow & { agentId?: string; outletId?: string },
): Promise<VisitSummary> {
  const [totals] = await prisma.$queryRaw<
    { visits: unknown; submitted: unknown; in_progress: unknown; outlets: unknown; geofence: unknown }[]
  >`
    SELECT COUNT(*)::int AS visits,
      COUNT(*) FILTER (WHERE v."status" = 'submitted')::int AS submitted,
      COUNT(*) FILTER (WHERE v."status" = 'in_progress')::int AS in_progress,
      COUNT(DISTINCT v."outlet_id")::int AS outlets,
      COUNT(*) FILTER (WHERE NOT v."geofence_pass")::int AS geofence
    FROM "visits" v
    WHERE ${await visitWhere(input)}
  `;

  // The list is a page, not an aggregate, so it stays a Prisma read over the
  // same scope — it needs the agent and outlet relations, and only 20 rows.
  const outlet = await territoryFilter(input.clientId, input.territoryId);
  const recent = await prisma.visit.findMany({
    where: {
      clientId: input.clientId,
      checkinTs: { gte: input.from, lt: input.to },
      ...(Object.keys(outlet).length > 0 ? { outlet } : {}),
      ...(input.agentId ? { agentId: input.agentId } : {}),
      ...(input.outletId ? { outletId: input.outletId } : {}),
    },
    select: {
      id: true,
      status: true,
      checkinTs: true,
      outlet: { select: { name: true } },
      agent: { select: { email: true, displayName: true } },
    },
    orderBy: [{ checkinTs: 'desc' }, { id: 'desc' }],
    take: RECENT_VISITS_LIMIT,
  });

  const visits = num(totals?.visits);

  return {
    visits,
    submitted: num(totals?.submitted),
    inProgress: num(totals?.in_progress),
    outletsVisited: num(totals?.outlets),
    geofenceFailures: num(totals?.geofence),
    recent: recent.map((r) => ({
      visitId: r.id,
      outletName: r.outlet.name,
      agentName: personLabel(r.agent.displayName, r.agent.email),
      agentEmail: r.agent.email,
      checkinTs: r.checkinTs.toISOString(),
      status: r.status,
    })),
    truncated: visits > recent.length,
  };
}

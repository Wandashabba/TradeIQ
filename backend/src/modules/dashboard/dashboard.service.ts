import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { meanOf, pct } from '../../lib/kpiMath';
import { OWN_FACINGS_SQL } from '../../lib/kpiSql';

const PRICE_COMPLIANCE_TOLERANCE_PCT = 5;

/**
 * What an unresolvable `territoryId` filters on: a code no outlet carries, so a
 * bogus id (or another client's territory) matches nothing rather than silently
 * falling back to the whole client. Same rule as the trends endpoints.
 */
const NO_SUCH_TERRITORY = '__no-such-territory__';

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

/**
 * Every numerator and denominator the KPIs need for ONE scope, counted by
 * Postgres.
 *
 * This replaces loading the scope's visits with five eager relation includes
 * and folding them in Node. On the demo tenant that meant 137,451 visits plus
 * 1.7M observation rows — 578MB of column JSON — materialised on every
 * dashboard open, which did not merely take ~28s: it exceeded V8's 512MiB
 * maximum string length, so Prisma's query engine could not hand the result
 * across the N-API boundary at all (`Failed to convert rust String into napi
 * string`) and the endpoint answered 500 every single time. Peak RSS for that
 * one query, measured: 1,964MB. For these aggregates: 71MB.
 *
 * What is counted here, and what is still computed in Node, is a deliberate
 * split: Postgres counts rows and sums columns, and `kpiMath` does every
 * division, rounding and banding. The formulas therefore still have exactly one
 * implementation, which is the #93 rule this module is built on — only the
 * folding moved.
 */
interface KpiAggregates {
  outletsTotal: number;
  totalAcv: number;
  visitedAcv: number;
  visits: number;
  outletsVisited: number;
  /** Stock lines that were COUNTED — `units_available IS NOT NULL` (#389). */
  stockCounted: number;
  stockInStock: number;
  pricingRows: number;
  pricingCompliant: number;
  visibilityRows: number;
  planogramSum: number;
  ownFacings: number;
  competitorFacings: number;
  scorecards: number;
  scoreSum: number;
  greenScorecards: number;
  /** One score per DOOR: its latest scored visit in the window. */
  latestDoorScores: number[];
}

/**
 * A scope with nothing in it. A territory with no outlets and no visits reads
 * as eight zeros and five empty bands, exactly as it did when the fold ran over
 * two empty arrays. Built fresh each time because `latestDoorScores` is
 * mutable.
 */
function emptyAggregates(): KpiAggregates {
  return {
    outletsTotal: 0,
    totalAcv: 0,
    visitedAcv: 0,
    visits: 0,
    outletsVisited: 0,
    stockCounted: 0,
    stockInStock: 0,
    pricingRows: 0,
    pricingCompliant: 0,
    visibilityRows: 0,
    planogramSum: 0,
    ownFacings: 0,
    competitorFacings: 0,
    scorecards: 0,
    scoreSum: 0,
    greenScorecards: 0,
    latestDoorScores: [],
  };
}

/**
 * All of the KPI math, in one place so the single-scope endpoint and the
 * per-territory rollup compute identically. This file has a `#93` history of
 * near-duplicate KPI bugs from formulas drifting between copies — there must be
 * exactly one implementation of this math, not one per caller.
 */
function computeKpisFromAggregates(agg: KpiAggregates): DashboardSummary {
  const numericDistribution = pct(agg.outletsVisited, agg.outletsTotal);

  // Weighted distribution: outlets weighted by their share of category turnover
  // (`Outlet.acvWeight`), so covering one hypermarket is not equivalent to
  // covering one kiosk.
  //
  // This used to be assigned `= numericDistribution` — two tiles on the console,
  // two different labels, always the same number (#93). Now it is a real figure.
  // With every weight left at its default of 1 the two metrics agree, and that
  // is honest: if no weights are supplied, every outlet genuinely does count the
  // same.
  const weightedDistribution = pct(agg.visitedAcv, agg.totalAcv);

  // On-shelf availability over the scope's stock lines: 100 * (lines with
  // stock) / (lines that were COUNTED). An uncounted line (#389) leaves the
  // ratio entirely, which is why the SQL counts the denominator with an
  // `IS NOT NULL` filter rather than counting every row — see
  // `kpiMath.onShelfAvailabilityPct`, the array-shaped twin of this.
  const osaPct = pct(agg.stockInStock, agg.stockCounted);

  const executionScore = meanOf(agg.scoreSum, agg.scorecards);

  const priceCompliancePct = pct(agg.pricingCompliant, agg.pricingRows);

  const visibilityCompliancePct = meanOf(agg.planogramSum, agg.visibilityRows);

  // Share of shelf: our facings against the competitors' facings.
  //
  // This used to divide by the *row count* of competitive captures — so a
  // competitor holding an entire shelf counted exactly the same as one holding a
  // single can, and the denominator measured how much data an agent typed rather
  // than what was on the shelf (#93). Competitor facings are now captured
  // (`VisitCompetitive.facingsCount`), so this is a real ratio.
  const facings = agg.ownFacings + agg.competitorFacings;
  const shareOfShelf = pct(agg.ownFacings, facings);

  const perfectStoreRate = pct(agg.greenScorecards, agg.scorecards);

  // Perfect-store distribution counts DOORS, not visits: an outlet visited
  // three times in the window is one outlet, so each counts once — at its most
  // recent scored visit, the state a manager would find if they went today.
  // The SQL picks that one visit per outlet; the banding stays here so
  // SCORE_BANDS is the only place the thresholds are written down.
  const scoreBands: ScoreBand[] = SCORE_BANDS.map((band) => ({ ...band, outlets: 0 }));
  for (const score of agg.latestDoorScores) {
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
    // read off the same aggregate row, in the same function, so the two cannot
    // drift the way two copies of a formula did in #93.
    sampleSizes: {
      numericDistribution: agg.outletsTotal,
      weightedDistribution: agg.outletsTotal,
      // COUNTED stock lines only, matching `onShelfAvailabilityPct` (#389).
      osaPct: agg.stockCounted,
      executionScore: agg.scorecards,
      priceCompliancePct: agg.pricingRows,
      visibilityCompliancePct: agg.visibilityRows,
      // Facings, not capture rows — the denominator shareOfShelf really uses.
      shareOfShelf: facings,
      perfectStoreRate: agg.scorecards,
    },
    totals: {
      visits: agg.visits,
      outletsVisited: agg.outletsVisited,
      outletsTotal: agg.outletsTotal,
    },
    scoreBands,
  };
}

// ── The aggregate queries ─────────────────────────────────────────────────

/** The resolved scope every aggregate query reads through. */
interface Scope {
  clientId: string;
  /** Already resolved to `Territory.code` — never a `Territory.id`. */
  territoryCode?: string;
  outletId?: string;
  from?: Date;
  to?: Date;
}

/**
 * The group key for a single, undivided scope. `GET /dashboard` asks for one
 * row and reads it back under this key; `GET /dashboard/by-territory` groups by
 * `Outlet.territoryId` instead and reads each row back under a `Territory.code`.
 */
const SINGLE_GROUP = '';

/** The grouping expression for the whole-scope endpoint: one constant group. */
const SINGLE_GROUP_SQL = Prisma.sql`''::text`;

/**
 * The grouping expression for the per-territory rollup. Outlets link to a
 * territory by `Outlet.territoryId` equalling `Territory.code` (a deliberate,
 * pre-existing design), NOT `Territory.id` — see the doc comment on the
 * `Territory` model in schema.prisma. Grouping on `o."id"`, or joining
 * `territories` on the id, would silently zero out every KPI, exactly as the
 * original per-territory bug did.
 */
const TERRITORY_GROUP_SQL = Prisma.sql`o."territory_id"`;

/**
 * The outlet scope — the distribution denominator, over `outlets o`.
 *
 * Both filters are tested with `!== undefined`, not for truthiness. The fold
 * this replaced wrote `if (territoryCode)`, so a territory whose `code` is the
 * empty string — which `POST /territories` accepts, since it only checks the
 * type — applied NO territory filter and showed that territory the whole
 * client's figures under its own name. That is the one figure in this file
 * that deliberately moved; `dashboard.equivalence.test.ts` pins the new
 * behaviour.
 */
function outletScopeSql(scope: Scope): Prisma.Sql {
  return Prisma.sql`o."client_id" = ${scope.clientId}
      ${
        scope.territoryCode !== undefined
          ? Prisma.sql`AND o."territory_id" = ${scope.territoryCode}`
          : Prisma.empty
      }
      ${scope.outletId !== undefined ? Prisma.sql`AND o."id" = ${scope.outletId}` : Prisma.empty}`;
}

/**
 * The visit scope, over `visits v` joined to its `outlets o`.
 *
 * `o."client_id"` is checked as well as `v."client_id"`: the per-territory
 * rollup has always required the visit's outlet to be one of the client's own
 * (it scoped visits through the client's outlet set), and `POST /visits`
 * refuses an outlet belonging to another client, so the two conditions cannot
 * disagree on real data — verified as 0 rows on the demo database. Checking
 * both makes the two endpoints provably one scope instead of two that happen to
 * agree.
 *
 * Timestamps are bound as `::timestamp` from an ISO string, matching the trends
 * aggregates and how Prisma stores `checkin_ts`: a `timestamp(3) without time
 * zone` holding UTC.
 */
function visitScopeSql(scope: Scope): Prisma.Sql {
  return Prisma.sql`v."client_id" = ${scope.clientId}
      AND o."client_id" = ${scope.clientId}
      ${
        scope.territoryCode !== undefined
          ? Prisma.sql`AND o."territory_id" = ${scope.territoryCode}`
          : Prisma.empty
      }
      ${scope.outletId !== undefined ? Prisma.sql`AND o."id" = ${scope.outletId}` : Prisma.empty}
      ${
        scope.from
          ? Prisma.sql`AND v."checkin_ts" >= ${scope.from.toISOString()}::timestamp`
          : Prisma.empty
      }
      ${
        scope.to
          ? Prisma.sql`AND v."checkin_ts" <= ${scope.to.toISOString()}::timestamp`
          : Prisma.empty
      }`;
}

/**
 * The scoped visits, as a subquery: one row per visit in the window, carrying
 * the group key so every observation aggregate below can `GROUP BY` it.
 *
 * Referenced several times from one statement, so Postgres materialises it
 * once (PG12+ default for a multiply-referenced CTE) and the observation tables
 * hash-join against it — one pass each, instead of one row per observation
 * crossing into Node.
 */
function scopedVisitsSql(scope: Scope, groupKey: Prisma.Sql): Prisma.Sql {
  return Prisma.sql`
    SELECT v."id", v."outlet_id", v."checkin_ts", ${groupKey} AS gk
    FROM "visits" v
    JOIN "outlets" o ON o."id" = v."outlet_id"
    WHERE ${visitScopeSql(scope)}`;
}

interface OutletAggRow {
  gk: string;
  outlets_total: number;
  total_acv: number;
  visited_acv: number;
}

interface VisitAggRow {
  gk: string;
  visits: number;
  outlets_visited: number;
  stock_counted: number;
  stock_in_stock: number;
  pricing_rows: number;
  pricing_compliant: number;
  visibility_rows: number;
  planogram_sum: number;
  own_facings: number;
  competitor_facings: number;
  scorecards: number;
  score_sum: number;
  green_scorecards: number;
}

interface DoorScoreRow {
  gk: string;
  score: number;
}

/** Postgres hands `::int` back as a number and `::float8` as a number; a
 * missing row (LEFT JOIN) or a NULL sum reads as 0 rather than NaN. */
function toNumber(value: unknown): number {
  const n = Number(value ?? 0);
  return Number.isFinite(n) ? n : 0;
}

/**
 * Three aggregate queries, run together, each returning one row per group
 * (plus one row per DOOR for the score bands — at most one per outlet).
 *
 * Why three and not one: the outlet denominator and the visit observations are
 * independent scopes that the old code also loaded as two queries, and the door
 * scores are the one result that is legitimately more than one row per group.
 * Fusing them would mean either a cross join or a chain of full outer joins for
 * no measured gain.
 */
async function fetchAggregates(
  scope: Scope,
  groupKey: Prisma.Sql,
): Promise<Map<string, KpiAggregates>> {
  const scopedVisits = scopedVisitsSql(scope, groupKey);

  const [outletRows, visitRows, doorRows] = await Promise.all([
    // The outlet denominator, and the ACV weights behind weighted
    // distribution. `visited_acv` sums the weights of scoped outlets that have
    // a scoped visit — the semijoin the old code did with a Set of outlet ids.
    prisma.$queryRaw<OutletAggRow[]>`
      WITH visited AS (
        SELECT DISTINCT sv."outlet_id" FROM (${scopedVisits}) sv
      )
      SELECT ${groupKey} AS gk,
        COUNT(*)::int AS outlets_total,
        COALESCE(SUM(o."acv_weight"), 0)::float8 AS total_acv,
        COALESCE(
          SUM(o."acv_weight") FILTER (
            WHERE EXISTS (SELECT 1 FROM visited vo WHERE vo."outlet_id" = o."id")
          ),
          0
        )::float8 AS visited_acv
      FROM "outlets" o
      WHERE ${outletScopeSql(scope)}
      GROUP BY 1`,

    // Every observation denominator and numerator, one pass per table.
    //
    // Each table is aggregated against the scoped visits SEPARATELY and the
    // per-group results joined afterwards. Joining them to each other first
    // would multiply out — a visit with 6 stock lines and 3 competitive rows
    // would contribute 18 of each — which is the arithmetic error that makes
    // "just add another include" look harmless.
    prisma.$queryRaw<VisitAggRow[]>`
      WITH sv AS (${scopedVisits}),
      -- Visits per door first, then doors per group. COUNT(DISTINCT outlet_id)
      -- reads better and costs a full sort of every visit in the window --
      -- 314ms of external merge on the demo tenant's 137k rows, where two hash
      -- aggregates over the same rows take under 60ms.
      per_outlet AS (
        SELECT sv.gk, sv."outlet_id", COUNT(*)::int AS n
        FROM sv GROUP BY sv.gk, sv."outlet_id"
      ),
      visit_agg AS (
        SELECT po.gk,
          SUM(po.n)::int AS visits,
          COUNT(*)::int AS outlets_visited
        FROM per_outlet po GROUP BY po.gk
      ),
      stock_agg AS (
        SELECT sv.gk,
          COUNT(*) FILTER (WHERE vs."units_available" IS NOT NULL)::int AS stock_counted,
          COUNT(*) FILTER (WHERE vs."units_available" > 0)::int AS stock_in_stock
        FROM sv JOIN "visit_stock" vs ON vs."visit_id" = sv."id"
        GROUP BY sv.gk
      ),
      pricing_agg AS (
        SELECT sv.gk,
          COUNT(*)::int AS pricing_rows,
          COUNT(*) FILTER (
            WHERE ABS(vp."deviation_pct") <= ${PRICE_COMPLIANCE_TOLERANCE_PCT}
          )::int AS pricing_compliant
        FROM sv JOIN "visit_pricing" vp ON vp."visit_id" = sv."id"
        GROUP BY sv.gk
      ),
      visibility_agg AS (
        SELECT sv.gk,
          COUNT(*)::int AS visibility_rows,
          COALESCE(SUM(vv."planogram_compliance_pct"), 0)::float8 AS planogram_sum,
          COALESCE(SUM(${OWN_FACINGS_SQL}), 0)::float8 AS own_facings
        FROM sv JOIN "visit_visibility" vv ON vv."visit_id" = sv."id"
        GROUP BY sv.gk
      ),
      competitive_agg AS (
        SELECT sv.gk,
          COALESCE(SUM(vc."facings_count"), 0)::float8 AS competitor_facings
        FROM sv JOIN "visit_competitive" vc ON vc."visit_id" = sv."id"
        GROUP BY sv.gk
      ),
      score_agg AS (
        SELECT sv.gk,
          COUNT(*)::int AS scorecards,
          COALESCE(SUM(sc."weighted_total"), 0)::float8 AS score_sum,
          COUNT(*) FILTER (WHERE sc."rating_band" = 'green')::int AS green_scorecards
        FROM sv JOIN "scorecards" sc ON sc."visit_id" = sv."id"
        GROUP BY sv.gk
      )
      SELECT va.gk,
        va.visits, va.outlets_visited,
        COALESCE(st.stock_counted, 0)::int AS stock_counted,
        COALESCE(st.stock_in_stock, 0)::int AS stock_in_stock,
        COALESCE(pr.pricing_rows, 0)::int AS pricing_rows,
        COALESCE(pr.pricing_compliant, 0)::int AS pricing_compliant,
        COALESCE(vi.visibility_rows, 0)::int AS visibility_rows,
        COALESCE(vi.planogram_sum, 0)::float8 AS planogram_sum,
        COALESCE(vi.own_facings, 0)::float8 AS own_facings,
        COALESCE(co.competitor_facings, 0)::float8 AS competitor_facings,
        COALESCE(sa.scorecards, 0)::int AS scorecards,
        COALESCE(sa.score_sum, 0)::float8 AS score_sum,
        COALESCE(sa.green_scorecards, 0)::int AS green_scorecards
      FROM visit_agg va
      LEFT JOIN stock_agg st ON st.gk = va.gk
      LEFT JOIN pricing_agg pr ON pr.gk = va.gk
      LEFT JOIN visibility_agg vi ON vi.gk = va.gk
      LEFT JOIN competitive_agg co ON co.gk = va.gk
      LEFT JOIN score_agg sa ON sa.gk = va.gk`,

    // One row per DOOR: the score of its most recent scored visit in the
    // window. At most one per outlet, so this is hundreds of rows, not
    // hundreds of thousands.
    //
    // `checkin_ts DESC, id DESC` rather than `checkin_ts DESC` alone: two
    // scored visits to one outlet at the identical timestamp used to resolve by
    // whatever order Prisma happened to return, which is to say arbitrarily.
    // The tie is now decided the same way twice.
    prisma.$queryRaw<DoorScoreRow[]>`
      WITH sv AS (${scopedVisits})
      SELECT DISTINCT ON (sv.gk, sv."outlet_id")
        sv.gk, sc."weighted_total"::float8 AS score
      FROM sv JOIN "scorecards" sc ON sc."visit_id" = sv."id"
      ORDER BY sv.gk, sv."outlet_id", sv."checkin_ts" DESC, sv."id" DESC`,
  ]);

  const groups = new Map<string, KpiAggregates>();
  const groupFor = (gk: string): KpiAggregates => {
    const existing = groups.get(gk);
    if (existing) return existing;
    const fresh = emptyAggregates();
    groups.set(gk, fresh);
    return fresh;
  };

  for (const row of outletRows) {
    const agg = groupFor(row.gk);
    agg.outletsTotal = toNumber(row.outlets_total);
    agg.totalAcv = toNumber(row.total_acv);
    agg.visitedAcv = toNumber(row.visited_acv);
  }
  for (const row of visitRows) {
    const agg = groupFor(row.gk);
    agg.visits = toNumber(row.visits);
    agg.outletsVisited = toNumber(row.outlets_visited);
    agg.stockCounted = toNumber(row.stock_counted);
    agg.stockInStock = toNumber(row.stock_in_stock);
    agg.pricingRows = toNumber(row.pricing_rows);
    agg.pricingCompliant = toNumber(row.pricing_compliant);
    agg.visibilityRows = toNumber(row.visibility_rows);
    agg.planogramSum = toNumber(row.planogram_sum);
    agg.ownFacings = toNumber(row.own_facings);
    agg.competitorFacings = toNumber(row.competitor_facings);
    agg.scorecards = toNumber(row.scorecards);
    agg.scoreSum = toNumber(row.score_sum);
    agg.greenScorecards = toNumber(row.green_scorecards);
  }
  for (const row of doorRows) {
    groupFor(row.gk).latestDoorScores.push(toNumber(row.score));
  }

  return groups;
}

/**
 * Resolve a `Territory.id` to the `code` that `Outlet.territoryId` actually
 * stores, scoped to the caller's client. Comparing the id to
 * `Outlet.territoryId` directly matches nothing, which is the bug #97 and the
 * #285 seed fix both chased.
 */
async function resolveTerritoryCode(
  clientId: string,
  territoryId?: string,
): Promise<string | undefined> {
  if (!territoryId) {
    return undefined;
  }
  const territory = await prisma.territory.findFirst({
    where: { id: territoryId, clientId },
    select: { code: true },
  });
  // A territoryId that doesn't resolve (bogus id, or another client's
  // territory) intentionally matches nothing rather than accidentally matching
  // everything.
  return territory?.code ?? NO_SUCH_TERRITORY;
}

export async function getDashboardSummary(filters: DashboardFilters): Promise<DashboardSummary> {
  // filters.territoryId is a Territory.id (the client-facing contract), but
  // Outlet.territoryId is free-text storing Territory.code — never id (see the
  // doc comment on the Territory model in schema.prisma).
  const scope: Scope = {
    clientId: filters.clientId,
    territoryCode: await resolveTerritoryCode(filters.clientId, filters.territoryId),
    outletId: filters.outletId,
    from: filters.from,
    to: filters.to,
  };

  const groups = await fetchAggregates(scope, SINGLE_GROUP_SQL);
  // No outlets and no visits means no row came back at all, which is a scope of
  // zeros — not an error.
  return computeKpisFromAggregates(groups.get(SINGLE_GROUP) ?? emptyAggregates());
}

export interface TerritoryDashboardSummary extends DashboardSummary {
  territoryId: string;
  territoryName: string;
}

/**
 * One set of aggregate queries for every territory at once, instead of the N+1
 * pattern of calling `getDashboardSummary` once per territory (#97) — and
 * instead of loading the whole client's visits and splitting them in Node,
 * which is what made this the slowest route in the API by an order of
 * magnitude.
 *
 * Also the source of truth for the id/code join: see `TERRITORY_GROUP_SQL`.
 */
export async function getDashboardByTerritory(filters: {
  clientId: string;
  from?: Date;
  to?: Date;
}): Promise<TerritoryDashboardSummary[]> {
  const scope: Scope = { clientId: filters.clientId, from: filters.from, to: filters.to };

  const [territories, groups] = await Promise.all([
    prisma.territory.findMany({ where: { clientId: filters.clientId } }),
    fetchAggregates(scope, TERRITORY_GROUP_SQL),
  ]);

  return territories.map((territory) => ({
    territoryId: territory.id,
    territoryName: territory.name,
    // Keyed by CODE, because that is what `Outlet.territoryId` holds. A
    // territory no outlet carries the code of reads as zeros.
    ...computeKpisFromAggregates(groups.get(territory.code) ?? emptyAggregates()),
  }));
}

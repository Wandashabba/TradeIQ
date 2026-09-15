import { prisma } from '../../lib/prisma';
import { facingsTotal, mean, pct, round2 } from '../../lib/kpiMath';
import { kpiThreshold } from '../../lib/kpiThresholds';
import { DEFAULT_GREEN_THRESHOLD } from '../scorecards/scorecards.service';

const DAY_MS = 24 * 60 * 60 * 1000;

/** Default lookback applied only when a `to` bound is given without a `from`. */
const DEFAULT_WINDOW_DAYS = 90;

/**
 * What an unresolvable `territoryId` filters on: a code no outlet carries, so
 * a bogus id (or another client's territory) matches nothing rather than
 * silently falling back to the whole client. Same rule as the dashboard.
 */
const NO_SUCH_TERRITORY = '__no-such-territory__';

export type TrendInterval = 'day' | 'week';

export interface TrendFilters {
  clientId: string;
  interval: TrendInterval;
  from?: Date;
  to?: Date;
  /**
   * A `Territory.id` (the client-facing contract). Resolved to the territory's
   * `code` before filtering — `Outlet.territoryId` stores the code, never the id.
   */
  territoryId?: string;
}

export interface TrendPoint {
  /** ISO-8601 timestamp of the bucket start (UTC midnight; Monday for weeks). */
  period: string;
  value: number;
  count: number;
}

export interface TrendSeries {
  interval: TrendInterval;
  points: TrendPoint[];
}

/**
 * Truncate a timestamp to the start of its bucket in UTC. For 'day' this is
 * 00:00 of the same date; for 'week' it is the Monday 00:00 of the row's week.
 */
// Exported so the demo seed's calendar can assert week-boundary parity against
// the real bucketing rule rather than reimplementing it.
export function bucketStart(date: Date, interval: TrendInterval): Date {
  const dayStart = Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate());
  if (interval === 'day') {
    return new Date(dayStart);
  }
  // getUTCDay: 0=Sun..6=Sat. Days since Monday: Mon->0 .. Sun->6.
  const daysSinceMonday = (new Date(dayStart).getUTCDay() + 6) % 7;
  return new Date(dayStart - daysSinceMonday * DAY_MS);
}

interface DateWindow {
  gte?: Date;
  lte?: Date;
}

/**
 * Resolve the createdAt filter window. No bounds → all rows; a lone `to`
 * defaults the lower bound to `to` minus {@link DEFAULT_WINDOW_DAYS}.
 */
function resolveWindow(from?: Date, to?: Date): DateWindow | undefined {
  if (!from && !to) {
    return undefined;
  }
  const gte = from ?? (to ? new Date(to.getTime() - DEFAULT_WINDOW_DAYS * DAY_MS) : undefined);
  return {
    ...(gte ? { gte } : {}),
    ...(to ? { lte: to } : {}),
  };
}

/**
 * Group rows into interval buckets (in JS, for portability) and reduce each
 * bucket to a single numeric value. Empty input yields an empty series — a
 * bucket with no rows is absent, never a fabricated zero.
 */
function buildSeries<T>(
  rows: T[],
  interval: TrendInterval,
  getDate: (row: T) => Date,
  reduce: (bucketRows: T[]) => number,
): TrendSeries {
  const groups = new Map<string, T[]>();
  for (const row of rows) {
    const key = bucketStart(getDate(row), interval).toISOString();
    const existing = groups.get(key);
    if (existing) {
      existing.push(row);
    } else {
      groups.set(key, [row]);
    }
  }

  const points: TrendPoint[] = [...groups.entries()]
    .map(([period, bucketRows]) => ({
      period,
      value: round2(reduce(bucketRows)),
      count: bucketRows.length,
    }))
    .sort((a, b) => (a.period < b.period ? -1 : a.period > b.period ? 1 : 0));

  return { interval, points };
}

/** The resolved scope every metric loader reads through. */
interface Scope {
  clientId: string;
  from?: Date;
  to?: Date;
  /** Already resolved to `Territory.code` — never a `Territory.id`. */
  territoryCode?: string;
}

/**
 * Resolve a `Territory.id` to the `code` that `Outlet.territoryId` actually
 * stores, scoped to the caller's client — the same join as
 * `getDashboardSummary`. Comparing the id to `Outlet.territoryId` directly
 * matches nothing, which is the bug #97 and the #285 seed fix both chased.
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
  return territory?.code ?? NO_SUCH_TERRITORY;
}

async function scopeFor(filters: TrendFilters): Promise<Scope> {
  return {
    clientId: filters.clientId,
    from: filters.from,
    to: filters.to,
    territoryCode: await resolveTerritoryCode(filters.clientId, filters.territoryId),
  };
}

/** The visit-level tenant + territory filter, shared by every loader. */
function visitScope(scope: Scope) {
  return {
    clientId: scope.clientId,
    ...(scope.territoryCode !== undefined ? { outlet: { territoryId: scope.territoryCode } } : {}),
  };
}

/**
 * A metric's rows, loaded once, with everything needed to reduce them however
 * the caller wants: as one series, as a period summary, or split by territory.
 * The row type is closed over, so the four metrics share one shape.
 */
interface MetricRows {
  count: number;
  series(interval: TrendInterval): TrendSeries;
  /** The metric over every row at once; `null` (never 0) when there are none. */
  average(): number | null;
  /** Rows split by the outlet's `territoryId` (a `Territory.code`). */
  byTerritoryCode(): Map<string, MetricRows>;
  /**
   * Only the rows that actually measured something. Identity for metrics whose
   * denominator is the row count; share-of-shelf drops visits that captured no
   * facings, so a territory that never counted a shelf has no value rather
   * than a 0% that reads as a real result.
   */
  sampled(): MetricRows;
}

interface MetricDef<T> {
  at: (row: T) => Date;
  territoryCode: (row: T) => string;
  reduce: (rows: T[]) => number;
  hasSample?: (row: T) => boolean;
}

function metricRows<T>(rows: T[], def: MetricDef<T>): MetricRows {
  return {
    count: rows.length,
    series: (interval) => buildSeries(rows, interval, def.at, def.reduce),
    average: () => (rows.length > 0 ? round2(def.reduce(rows)) : null),
    byTerritoryCode: () => {
      const groups = new Map<string, T[]>();
      for (const row of rows) {
        const code = def.territoryCode(row);
        const existing = groups.get(code);
        if (existing) {
          existing.push(row);
        } else {
          groups.set(code, [row]);
        }
      }
      return new Map([...groups.entries()].map(([code, group]) => [code, metricRows(group, def)]));
    },
    sampled: () => {
      const hasSample = def.hasSample;
      return hasSample ? metricRows(rows.filter(hasSample), def) : metricRows(rows, def);
    },
  };
}

const outletCodeSelect = { visit: { select: { outlet: { select: { territoryId: true } } } } } as const;

function loadScorecardRows(scope: Scope) {
  const createdAt = resolveWindow(scope.from, scope.to);
  return prisma.scorecard.findMany({
    where: { visit: visitScope(scope), ...(createdAt ? { createdAt } : {}) },
    select: { weightedTotal: true, ratingBand: true, createdAt: true, ...outletCodeSelect },
  });
}

type ScorecardRow = Awaited<ReturnType<typeof loadScorecardRows>>[number];

const scorecardBase = {
  at: (row: ScorecardRow) => row.createdAt,
  territoryCode: (row: ScorecardRow) => row.visit.outlet.territoryId,
};

/** Mean weighted scorecard total. */
async function loadScorecards(scope: Scope): Promise<MetricRows> {
  return metricRows(await loadScorecardRows(scope), {
    ...scorecardBase,
    reduce: (rows) => mean(rows.map((row) => row.weightedTotal)),
  });
}

/** 100 * (scorecards with ratingBand === 'green') / scorecards. */
async function loadPerfectStore(scope: Scope): Promise<MetricRows> {
  return metricRows(await loadScorecardRows(scope), {
    ...scorecardBase,
    reduce: (rows) => pct(rows.filter((row) => row.ratingBand === 'green').length, rows.length),
  });
}

/** 100 * (stock rows with unitsAvailable > 0) / stock rows. */
async function loadAvailability(scope: Scope): Promise<MetricRows> {
  const createdAt = resolveWindow(scope.from, scope.to);
  const rows = await prisma.visitStock.findMany({
    where: { visit: visitScope(scope), ...(createdAt ? { createdAt } : {}) },
    select: { unitsAvailable: true, createdAt: true, ...outletCodeSelect },
  });
  return metricRows(rows, {
    at: (row) => row.createdAt,
    territoryCode: (row) => row.visit.outlet.territoryId,
    reduce: (bucket) => pct(bucket.filter((row) => row.unitsAvailable > 0).length, bucket.length),
  });
}

/**
 * 100 * ownFacings / (ownFacings + competitorFacings), the same formula as
 * `dashboard.service.ts`'s `computeKpisFromScope`, just bucketed over time
 * instead of computed once over a scope. Sharing `pct`/`facingsTotal` with that
 * file guarantees the numbers can never drift apart the way #93 already burned
 * this codebase.
 */
async function loadShareOfShelf(scope: Scope): Promise<MetricRows> {
  const checkinTs = resolveWindow(scope.from, scope.to);
  const visits = await prisma.visit.findMany({
    where: { ...visitScope(scope), ...(checkinTs ? { checkinTs } : {}) },
    select: {
      // Visit has no `createdAt` column (only `checkinTs`, the device's
      // clock — see the doc comment on `Visit.submittedAtClient`), so bucket
      // on the same field the window already filters on.
      checkinTs: true,
      outlet: { select: { territoryId: true } },
      visibility: { select: { facingsCount: true } },
      competitive: { select: { facingsCount: true } },
    },
  });
  type Row = (typeof visits)[number];
  const own = (visit: Row) => (visit.visibility ? facingsTotal(visit.visibility.facingsCount) : 0);
  const competitor = (visit: Row) => visit.competitive.reduce((n, row) => n + row.facingsCount, 0);
  return metricRows(visits, {
    at: (visit) => visit.checkinTs,
    territoryCode: (visit) => visit.outlet.territoryId,
    reduce: (bucket) => {
      const ownFacings = bucket.reduce((sum, visit) => sum + own(visit), 0);
      const competitorFacings = bucket.reduce((sum, visit) => sum + competitor(visit), 0);
      return pct(ownFacings, ownFacings + competitorFacings);
    },
    hasSample: (visit) => own(visit) + competitor(visit) > 0,
  });
}

/**
 * Mean weighted scorecard total per bucket. `value` = mean weightedTotal,
 * `count` = number of scorecards in the bucket.
 */
export async function getScorecardsTrend(filters: TrendFilters): Promise<TrendSeries> {
  return (await loadScorecards(await scopeFor(filters))).series(filters.interval);
}

/**
 * On-Shelf-Availability per bucket: `value` = 100 * (stock rows with
 * unitsAvailable > 0) / (stock rows in the bucket).
 */
export async function getAvailabilityTrend(filters: TrendFilters): Promise<TrendSeries> {
  return (await loadAvailability(await scopeFor(filters))).series(filters.interval);
}

/**
 * Perfect-store rate per bucket: `value` = 100 * (scorecards with
 * ratingBand === 'green') / (scorecards in the bucket).
 */
export async function getPerfectStoreTrend(filters: TrendFilters): Promise<TrendSeries> {
  return (await loadPerfectStore(await scopeFor(filters))).series(filters.interval);
}

/**
 * Share-of-shelf per bucket: `value` = 100 * ownFacings / (ownFacings +
 * competitorFacings); `count` = visits in the bucket. A bucket of visits that
 * captured no facings reads 0 here (the endpoint's long-standing contract); the
 * benchmark, which ranks territories against each other, drops such visits.
 */
export async function getShareOfShelfTrend(filters: TrendFilters): Promise<TrendSeries> {
  return (await loadShareOfShelf(await scopeFor(filters))).series(filters.interval);
}

// ── Territory benchmark (#123) ───────────────────────────────────────────

export const BENCHMARK_METRICS = ['perfectStore', 'availability', 'scorecards', 'shareOfShelf'] as const;
export type BenchmarkMetric = (typeof BENCHMARK_METRICS)[number];

export function isBenchmarkMetric(value: string): value is BenchmarkMetric {
  return (BENCHMARK_METRICS as readonly string[]).includes(value);
}

const LOADERS: Record<BenchmarkMetric, (scope: Scope) => Promise<MetricRows>> = {
  perfectStore: loadPerfectStore,
  availability: loadAvailability,
  scorecards: loadScorecards,
  shareOfShelf: loadShareOfShelf,
};

export interface BenchmarkFilters {
  clientId: string;
  metric: BenchmarkMetric;
  interval: TrendInterval;
  from?: Date;
  to?: Date;
}

export interface BenchmarkSeries {
  /** The metric over the whole window; `null` when nothing was measured. */
  average: number | null;
  /** Rows behind `average` (scorecards, stock rows, or visits with facings). */
  count: number;
  /** Buckets with no rows are absent — never a zero. */
  points: TrendPoint[];
}

export type BenchmarkPosition = 'above' | 'below' | 'level';

export interface TerritoryBenchmark extends BenchmarkSeries {
  territoryId: string;
  territoryName: string;
  territoryCode: string;
  /** 1-based by `average`, highest first; `null` when there is no average. */
  rank: number | null;
  /** `average - client.average`; `null` when either side has no data. */
  deltaFromClient: number | null;
  position: BenchmarkPosition | null;
}

export interface BenchmarkReport {
  metric: BenchmarkMetric;
  interval: TrendInterval;
  unit: 'score' | 'percent';
  /**
   * A configured standard drawn alongside the client average, when the client
   * has one for this metric. Only the scorecard score has one today: the
   * client's `kpiThresholds.green` band floor.
   */
  target: { value: number; label: string } | null;
  /** The whole client — every territory plus outlets outside any territory. */
  client: BenchmarkSeries;
  /** Rows whose outlet's `territoryId` matches no territory of this client. */
  unassigned: { count: number };
  territories: TerritoryBenchmark[];
}

function toBenchmarkSeries(rows: MetricRows, interval: TrendInterval): BenchmarkSeries {
  return { average: rows.average(), count: rows.count, points: rows.series(interval).points };
}

/**
 * Cross-territory benchmark within one client: each territory's series and
 * period average against the client-wide series as the reference line.
 *
 * Query count is fixed — territories, the metric's rows (Prisma batches the
 * outlet join as `IN` lookups) and, for scorecards, the client's thresholds —
 * however many territories or buckets there are. Grouping happens in JS with
 * the same reducers as the single-series endpoints, so a territory's numbers
 * and the client line can never drift from `/trends/*`.
 */
export async function getTerritoryBenchmark(filters: BenchmarkFilters): Promise<BenchmarkReport> {
  const { clientId, metric, interval } = filters;
  const [territories, client, loaded] = await Promise.all([
    prisma.territory.findMany({
      where: { clientId },
      select: { id: true, name: true, code: true },
      orderBy: [{ name: 'asc' }, { id: 'asc' }],
    }),
    metric === 'scorecards'
      ? prisma.client.findUnique({ where: { id: clientId }, select: { kpiThresholds: true } })
      : Promise.resolve(null),
    LOADERS[metric]({ clientId, from: filters.from, to: filters.to }),
  ]);

  const rows = loaded.sampled();
  const clientSeries = toBenchmarkSeries(rows, interval);
  const byCode = rows.byTerritoryCode();

  // Outlets link to a territory by Outlet.territoryId === Territory.code,
  // NOT Territory.id — see getDashboardByTerritory.
  const knownCodes = new Set(territories.map((territory) => territory.code));
  let unassigned = 0;
  for (const [code, group] of byCode) {
    if (!knownCodes.has(code)) unassigned += group.count;
  }

  const ranked = territories
    .map((territory) => {
      const group = byCode.get(territory.code);
      const series: BenchmarkSeries = group
        ? toBenchmarkSeries(group, interval)
        : { average: null, count: 0, points: [] };
      const deltaFromClient =
        series.average !== null && clientSeries.average !== null
          ? round2(series.average - clientSeries.average)
          : null;
      const position: BenchmarkPosition | null =
        deltaFromClient === null ? null : deltaFromClient > 0 ? 'above' : deltaFromClient < 0 ? 'below' : 'level';
      return {
        territoryId: territory.id,
        territoryName: territory.name,
        territoryCode: territory.code,
        ...series,
        deltaFromClient,
        position,
      };
    })
    .sort((a, b) => {
      if (a.average === null || b.average === null) {
        return a.average === b.average ? 0 : a.average === null ? 1 : -1;
      }
      return b.average - a.average;
    });

  let nextRank = 0;
  const withRank: TerritoryBenchmark[] = ranked.map((row) => ({
    ...row,
    rank: row.average === null ? null : ++nextRank,
  }));

  return {
    metric,
    interval,
    unit: metric === 'scorecards' ? 'score' : 'percent',
    target: client
      ? {
          value: kpiThreshold(client.kpiThresholds, 'green', DEFAULT_GREEN_THRESHOLD),
          label: 'Green threshold',
        }
      : null,
    client: clientSeries,
    unassigned: { count: unassigned },
    territories: withRank,
  };
}

import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';

const DAY_MS = 24 * 60 * 60 * 1000;

/** Default lookback applied only when a `to` bound is given without a `from`. */
const DEFAULT_WINDOW_DAYS = 90;

export type TrendInterval = 'day' | 'week';

export interface TrendFilters {
  clientId: string;
  interval: TrendInterval;
  from?: Date;
  to?: Date;
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

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

function mean(values: number[]): number {
  return values.length > 0 ? values.reduce((sum, v) => sum + v, 0) / values.length : 0;
}

/** Ratio helper that returns 0 (never NaN) on an empty denominator. */
function pct(numerator: number, denominator: number): number {
  return denominator > 0 ? (100 * numerator) / denominator : 0;
}

/**
 * Truncate a timestamp to the start of its bucket in UTC. For 'day' this is
 * 00:00 of the same date; for 'week' it is the Monday 00:00 of the row's week.
 */
function bucketStart(date: Date, interval: TrendInterval): Date {
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
 * bucket to a single numeric value. Empty input yields an empty series.
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

function scorecardWhere(filters: TrendFilters): Prisma.ScorecardWhereInput {
  const createdAt = resolveWindow(filters.from, filters.to);
  return {
    visit: { clientId: filters.clientId },
    ...(createdAt ? { createdAt } : {}),
  };
}

function stockWhere(filters: TrendFilters): Prisma.VisitStockWhereInput {
  const createdAt = resolveWindow(filters.from, filters.to);
  return {
    visit: { clientId: filters.clientId },
    ...(createdAt ? { createdAt } : {}),
  };
}

/**
 * Mean weighted scorecard total per bucket. `value` = mean weightedTotal,
 * `count` = number of scorecards in the bucket.
 */
export async function getScorecardsTrend(filters: TrendFilters): Promise<TrendSeries> {
  const rows = await prisma.scorecard.findMany({
    where: scorecardWhere(filters),
    select: { weightedTotal: true, createdAt: true },
  });
  return buildSeries(
    rows,
    filters.interval,
    (row) => row.createdAt,
    (bucket) => mean(bucket.map((row) => row.weightedTotal)),
  );
}

/**
 * On-Shelf-Availability per bucket: `value` = 100 * (stock rows with
 * unitsAvailable > 0) / (stock rows in the bucket).
 */
export async function getAvailabilityTrend(filters: TrendFilters): Promise<TrendSeries> {
  const rows = await prisma.visitStock.findMany({
    where: stockWhere(filters),
    select: { unitsAvailable: true, createdAt: true },
  });
  return buildSeries(
    rows,
    filters.interval,
    (row) => row.createdAt,
    (bucket) => pct(bucket.filter((row) => row.unitsAvailable > 0).length, bucket.length),
  );
}

/**
 * Perfect-store rate per bucket: `value` = 100 * (scorecards with
 * ratingBand === 'green') / (scorecards in the bucket).
 */
export async function getPerfectStoreTrend(filters: TrendFilters): Promise<TrendSeries> {
  const rows = await prisma.scorecard.findMany({
    where: scorecardWhere(filters),
    select: { ratingBand: true, createdAt: true },
  });
  return buildSeries(
    rows,
    filters.interval,
    (row) => row.createdAt,
    (bucket) => pct(bucket.filter((row) => row.ratingBand === 'green').length, bucket.length),
  );
}

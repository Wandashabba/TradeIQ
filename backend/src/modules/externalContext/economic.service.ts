import { prisma } from '../../lib/prisma';
import { ECONOMIC_SERIES, SOURCE_LABELS, type EconomicSource } from './economic.series';
import { isoDay, monthsBetween, OUTSIDE_DATA_NOTICE, type Provenance } from './provenance';

/**
 * Market-wide economic context for a period, read from Postgres.
 *
 * **Never fetches.** The refresh job (`economic.refresh.ts`) keeps the table
 * current; a user's turn only reads it, so a slow or unreachable statistics
 * site can never slow an answer. When the job has not succeeded for a while,
 * the result says how stale the figures are rather than hiding it.
 *
 * Official statistics are published a month or two after the month they
 * describe, so a question about this month usually has no figure yet. That is
 * reported per series as `notYetPublished`, with the latest figure that does
 * exist, so the answer can say "the latest is July's" instead of nothing.
 */

/** A source that has not refreshed for this long is flagged as stale. */
export const STALE_AFTER_DAYS = 45;
/** How far back `latest` may reach when the period itself has no figure. */
const LATEST_LOOKBACK_MONTHS = 6;

export interface EconomicFigure {
  period: string;
  value: number;
  provenance: Provenance;
}

export interface EconomicSeriesContext {
  series: string;
  label: string;
  unit: string;
  meaning: string;
  inPeriod: EconomicFigure[];
  /** The newest figure, when the period's own months have none or there is a newer one. */
  latest: EconomicFigure | null;
  /** Months in the period, up to today, with no figure yet. */
  notYetPublished: string[];
}

export interface EconomicContext {
  notice: string;
  period: { from: string; to: string };
  series: EconomicSeriesContext[];
  refresh: Array<{
    source: string;
    lastSuccessAt: string | null;
    stale: boolean;
  }>;
}

export class EconomicContextError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'EconomicContextError';
  }
}

/** At most two years of months; more is a chart, not context. */
export const MAX_MONTHS = 24;

function shiftMonth(month: string, delta: number): string {
  const year = Number(month.slice(0, 4));
  const index = Number(month.slice(5, 7)) - 1 + delta;
  const y = year + Math.floor(index / 12);
  const m = ((index % 12) + 12) % 12;
  return `${y}-${String(m + 1).padStart(2, '0')}`;
}

export async function getEconomicContext(input: { from: string; to: string; now: Date }): Promise<EconomicContext> {
  const months = monthsBetween(input.from, input.to);
  if (months.length > MAX_MONTHS) {
    throw new EconomicContextError('Economic context covers at most two years of months. Ask for a shorter period.');
  }
  const thisMonth = isoDay(input.now).slice(0, 7);
  const earliest = shiftMonth(months[0], -LATEST_LOOKBACK_MONTHS);

  const [rows, refreshes] = await Promise.all([
    prisma.economicObservation.findMany({
      where: { series: { in: ECONOMIC_SERIES.map((s) => s.key) }, period: { gte: earliest } },
      orderBy: [{ series: 'asc' }, { period: 'asc' }],
    }),
    prisma.economicSourceRefresh.findMany(),
  ]);

  const figure = (row: (typeof rows)[number]): EconomicFigure => ({
    period: row.period,
    value: row.value,
    provenance: {
      sourceName: row.sourceName,
      url: row.sourceUrl,
      publishedAt: row.releasedAt ? isoDay(row.releasedAt) : null,
      retrievedAt: row.retrievedAt.toISOString(),
    },
  });

  const series = ECONOMIC_SERIES.map((definition): EconomicSeriesContext => {
    const own = rows.filter((r) => r.series === definition.key);
    const inPeriod = own.filter((r) => months.includes(r.period)).map(figure);
    const newest = own.at(-1);
    const latest =
      newest && (inPeriod.length === 0 || newest.period > inPeriod.at(-1)!.period) ? figure(newest) : null;
    return {
      series: definition.key,
      label: definition.label,
      unit: definition.unit,
      meaning: definition.meaning,
      inPeriod,
      latest,
      notYetPublished: months.filter((m) => m <= thisMonth && !own.some((r) => r.period === m)),
    };
  }).filter((s) => s.inPeriod.length > 0 || s.latest !== null || s.notYetPublished.length > 0);

  const staleBefore = input.now.getTime() - STALE_AFTER_DAYS * 86_400_000;
  const refresh = (Object.keys(SOURCE_LABELS) as EconomicSource[]).map((source) => {
    const row = refreshes.find((r) => r.source === source);
    return {
      source: SOURCE_LABELS[source],
      lastSuccessAt: row?.lastSuccessAt?.toISOString() ?? null,
      stale: !row?.lastSuccessAt || row.lastSuccessAt.getTime() < staleBefore,
    };
  });

  return {
    notice: OUTSIDE_DATA_NOTICE,
    period: { from: input.from, to: input.to },
    series,
    refresh,
  };
}

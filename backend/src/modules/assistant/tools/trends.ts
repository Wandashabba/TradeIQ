import { z } from 'zod';
import {
  getAvailabilityTrend,
  getPerfectStoreTrend,
  getScorecardsTrend,
  getShareOfShelfTrend,
  type TrendFilters,
  type TrendSeries,
} from '../../trends/trends.service';
import { comparisonRanges, periodCompareToSchema } from '../compare';
import { periodSchema, resolvePeriod } from '../period';
import { eraseToolTypes, type AnyAssistantTool } from '../types';
import { TREND_INTERVALS, TREND_METRICS, type TrendMetric } from '../viewspec';
import { clientTimeZoneOf, type ToolContext } from './execution';

/**
 * The trend tool — how a number has been moving, not what it is.
 *
 * The pillar tools collapse a whole period to scalars on purpose; this one
 * wraps `trends.service.ts`, the semantic layer's existing bucketed series, so
 * the assistant's chart can never disagree with the dashboard's. The metric
 * enum is `TREND_METRICS` from the view-spec catalog — one entry per series the
 * backend can actually compute, because a metric it cannot produce is a chart
 * that renders empty and the model has no way to know that in advance.
 *
 * Note what is absent: `territoryId`. `TrendFilters` has no territory
 * narrowing, and accepting an argument only to ignore it would answer a
 * narrower question with a wider number.
 */

const SERIES_FOR: Record<TrendMetric, (filters: TrendFilters) => Promise<TrendSeries>> = {
  execution_score: getScorecardsTrend,
  availability: getAvailabilityTrend,
  perfect_store: getPerfectStoreTrend,
  share_of_shelf: getShareOfShelfTrend,
};

const trendArgs = z.object({
  metric: z
    .enum(TREND_METRICS)
    .describe(
      'Which series to plot: execution_score (average visit execution score), ' +
        'availability (on-shelf availability %), perfect_store (% of visits rated green), ' +
        'share_of_shelf (our facings as a % of all facings).',
    ),
  period: periodSchema,
  interval: z
    .enum(TREND_INTERVALS)
    .default('day')
    .describe('Bucket width. Use week for periods longer than about a month.'),
  compareTo: periodCompareToSchema.optional(),
});

export function buildTrendTools(ctx: ToolContext): AnyAssistantTool[] {
  const { user, now } = ctx;
  const timeZone = clientTimeZoneOf(ctx);

  return [
    eraseToolTypes({
      name: 'getMetricTrend',
      pillar: 'execution' as const,
      description:
        'Call this when the user asks how a metric has been trending, moving, or changing ' +
        'over time — improving or declining, week on week, day by day, over a period. ' +
        'Covers execution score, on-shelf availability, perfect-store rate, and share of ' +
        'shelf as time series, and can plot the same metric over an earlier window beside ' +
        'it in one turn. Use the other pillar tools instead when the user wants a ' +
        'single figure for a period rather than its movement.',
      args: trendArgs,
      run: async (args) => {
        const fetch = async (window: { from: Date; to: Date }) =>
          SERIES_FOR[args.metric]({
            clientId: user.clientId,
            interval: args.interval,
            ...window,
          });

        // A compared trend draws both lines over the like-for-like windows
        // from `comparisonRanges` (#365) — the current line included, so it
        // cannot end on a half-finished today its comparison does not have.
        const tz = await timeZone();
        const ranges = args.compareTo
          ? comparisonRanges(args.period, args.compareTo, now, tz)
          : undefined;
        const series = await fetch(ranges?.current ?? resolvePeriod(args.period, now, tz));
        // The metric rides with the series so the widget can label the chart
        // without re-deriving it from the spec params.
        const current = { metric: args.metric, interval: series.interval, points: series.points };
        if (!args.compareTo || !ranges) return current;

        // Sequential, like the pillar tools: the same indexed queries over the
        // same tables, and a turn that fans out doubles the peak load on a
        // database also serving the console.
        const earlier = await fetch(ranges.comparison);

        // Shaped like the pillar tools' `Comparison` — same `label`, same
        // `basis` — but carrying `points` instead of `values`, and no `deltas`.
        // That is `compare.ts`'s own rule, not an omission: differencing two
        // series means deciding what a bucket in one window corresponds to in
        // the other, and a bucket with no visits produces no point at all. The
        // client aligns them positionally and says so; inventing a per-bucket
        // delta here would bury that judgement in a number.
        return {
          ...current,
          comparison: {
            label: ranges.label,
            basis: args.compareTo,
            points: earlier.points,
            ...(ranges.note ? { note: ranges.note } : {}),
          },
        };
      },
      // The tool declares what it draws; the model never names a spec type.
      // Everything here is already canonical — metric, interval and the
      // comparison basis are enum args the schema validated, and the period is
      // echoed the same way getAgentScorecard echoes it.
      view: (args) => ({
        type: 'trend_chart',
        params: {
          metric: args.metric,
          period: args.period,
          interval: args.interval,
          ...(args.compareTo ? { compareTo: args.compareTo } : {}),
        },
      }),
    }),
  ];
}

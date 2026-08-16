import { z } from 'zod';
import {
  getAvailabilityTrend,
  getPerfectStoreTrend,
  getScorecardsTrend,
  getShareOfShelfTrend,
  type TrendFilters,
  type TrendSeries,
} from '../../trends/trends.service';
import { periodSchema, resolvePeriod } from '../period';
import { eraseToolTypes, type AnyAssistantTool } from '../types';
import { TREND_INTERVALS, TREND_METRICS, type TrendMetric } from '../viewspec';
import type { ToolContext } from './execution';

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
});

export function buildTrendTools(ctx: ToolContext): AnyAssistantTool[] {
  const { user, now } = ctx;

  return [
    eraseToolTypes({
      name: 'getMetricTrend',
      pillar: 'execution' as const,
      description:
        'Call this when the user asks how a metric has been trending, moving, or changing ' +
        'over time — improving or declining, week on week, day by day, over a period. ' +
        'Covers execution score, on-shelf availability, perfect-store rate, and share of ' +
        'shelf as time series. Use the other pillar tools instead when the user wants a ' +
        'single figure for a period rather than its movement.',
      args: trendArgs,
      run: async (args) => {
        const { from, to } = resolvePeriod(args.period, now);
        const series = await SERIES_FOR[args.metric]({
          clientId: user.clientId,
          interval: args.interval,
          from,
          to,
        });
        // The metric rides with the series so the widget can label the chart
        // without re-deriving it from the spec params.
        return { metric: args.metric, interval: series.interval, points: series.points };
      },
      // The tool declares what it draws; the model never names a spec type.
      // Everything here is already canonical — metric and interval are enum
      // args the schema validated, and the period is echoed the same way
      // getAgentScorecard echoes it.
      view: (args) => ({
        type: 'trend_chart',
        params: { metric: args.metric, period: args.period, interval: args.interval },
      }),
    }),
  ];
}

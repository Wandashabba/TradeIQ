import { z } from 'zod';
import {
  AgentNotFoundError,
  AmbiguousAgentError,
  resolveAgent,
} from '../../scorecards/scorecards.service';
import { compareToSchema, comparisonRanges, numericDeltas } from '../compare';
import type { FigureWindows } from '../figures';
import {
  alertFigures,
  campaignFigures,
  forecastFigures,
  priceComplianceFigures,
  taskFigures,
} from '../figures.operations';
import {
  ALERT_TYPES,
  findTerritories,
  getAlertSummary,
  getCampaignPerformance,
  getContestLeaderboards,
  getPriceCompliance,
  getSellInForecast,
  getTaskSummary,
  OutletLookupError,
  SkuLookupError,
  type AlertSummary,
  type CampaignPerformance,
  type PriceCompliance,
  type SellInForecast,
  type TaskSummary,
} from '../operations.service';
import { periodSchema, resolvePeriod, type Period } from '../period';
import { eraseToolTypes, ToolFacingError, type AnyAssistantTool } from '../types';
import { clientTimeZoneOf, type ToolContext } from './execution';

/**
 * The operational tools (#362) — pricing, campaigns, contests, tasks, alerts,
 * the sell-in forecast, and the territory lookup the rest depend on.
 *
 * Same contract as every other tool file: closures over `ctx.user`, no identity
 * field in any schema, descriptions that state the trigger AND the neighbour to
 * use instead. Each description names the tool a question most plausibly
 * belongs to when it is not this one, because tool choice is scored and the
 * misroutes so far have all been two descriptions claiming the same sentence.
 *
 * Free text in these results (campaign objectives, contest prizes, task fixes,
 * alert messages, names) is untrusted like any other tool result: the
 * orchestrator quarantines and spotlights it before the model reads it.
 */

const territoryIdArg = z
  .string()
  .min(1)
  .optional()
  .describe(
    'Optional territory id, from findTerritories. Never a territory name. Omit for the whole business.',
  );

export function buildOperationTools(ctx: ToolContext): AnyAssistantTool[] {
  const { user, now } = ctx;
  const timeZone = clientTimeZoneOf(ctx);
  const windowOf = async (period: Period | undefined) =>
    period ? resolvePeriod(period, now, await timeZone()) : undefined;

  const resolveAgentId = async (name: string | undefined) => {
    if (!name) return undefined;
    try {
      return (await resolveAgent({ clientId: user.clientId, query: name })).id;
    } catch (err) {
      if (err instanceof AmbiguousAgentError || err instanceof AgentNotFoundError) {
        throw new ToolFacingError(err.message);
      }
      throw err;
    }
  };

  const priceArgs = z.object({
    period: periodSchema,
    territoryId: territoryIdArg,
    outletName: z
      .string()
      .min(1)
      .max(80)
      .optional()
      .describe(
        'Optional part of an outlet or retail chain name, e.g. "QuickSave", to narrow to those stores.',
      ),
    sku: z
      .string()
      .min(1)
      .max(80)
      .optional()
      .describe('Optional one of OUR products, by name or id, e.g. "Cola 2L".'),
    compareTo: compareToSchema.optional(),
  });

  const priceWindows = async (args: z.infer<typeof priceArgs>): Promise<FigureWindows> => {
    const tz = await timeZone();
    if (!args.compareTo) return { timeZone: tz, current: resolvePeriod(args.period, now, tz) };
    const ranges = comparisonRanges(args.period, args.compareTo, now, tz);
    return { timeZone: tz, current: ranges.current, comparison: { range: ranges.comparison, basis: args.compareTo } };
  };

  const campaignArgs = z.object({
    campaign: z
      .string()
      .min(1)
      .max(80)
      .optional()
      .describe('Optional part of a campaign name, e.g. "Winter Warmer". Omit to list campaigns.'),
    state: z
      .enum(['running', 'ended', 'upcoming'])
      .optional()
      .describe('Optional: only campaigns running now, already ended, or not started. Omit for all.'),
    period: periodSchema
      .optional()
      .describe('Optional: only campaigns whose dates overlap this period. Omit for all.'),
  });

  const taskArgs = z.object({
    period: periodSchema
      .optional()
      .describe('Optional: also count tasks raised in this period. The backlog is always as of now.'),
    territoryId: territoryIdArg,
    agent: z
      .string()
      .min(1)
      .max(120)
      .optional()
      .describe("Optional agent's name, email or id, to narrow to the tasks they own."),
  });

  const alertArgs = z.object({
    period: periodSchema
      .optional()
      .describe('Optional: alerts raised in this period. Omit for all alerts, e.g. "still open".'),
    territoryId: territoryIdArg,
    type: z
      .enum(ALERT_TYPES)
      .optional()
      .describe(
        'Optional alert type: out_of_stock, price_deviation, low_scorecard (low execution score) or sla_breach.',
      ),
  });

  return [
    eraseToolTypes({
      name: 'findTerritories',
      pillar: 'execution' as const,
      description:
        'Call this when the user names a territory, area, beat or region — "Gauteng", ' +
        '"Nelson Mandela Bay", "the Soweto beat", "KZN" — and a tool needs its territoryId, or ' +
        'when they ask which territories exist. Returns matching territory ids, names, codes, ' +
        'regions and outlet counts. Call it BEFORE passing territoryId to any tool; never guess ' +
        'or invent an id, and never pass a name as an id. It returns no performance figures, so ' +
        'follow it with the tool that answers the question. Not needed for getTerritoryRanking, ' +
        'whose region filter takes the region name directly.',
      args: z.object({
        query: z
          .string()
          .min(1)
          .max(80)
          .optional()
          .describe('The place as the user said it. Omit to list every territory.'),
      }),
      run: async (args) => findTerritories({ clientId: user.clientId, query: args.query }),
    }),

    eraseToolTypes({
      name: 'getPriceCompliance',
      pillar: 'competition' as const,
      description:
        'Call this when the user asks about the shelf prices of OUR OWN products: price ' +
        'compliance, prices above or below RRP, overpricing or underpricing, which stores or ' +
        'retail chains (e.g. "QuickSave") charge too much, or what outlets charge for one of our ' +
        'SKUs. Compares prices agents captured on visits against each SKU\'s RRP, and returns the ' +
        'average deviation, the share of lines beyond the client\'s deviation threshold, average ' +
        'shelf price vs RRP per SKU, and the outlets furthest from RRP. Use ' +
        'getCompetitorActivity instead for COMPETITOR prices or brands, and getAlerts for the ' +
        'price alerts raised.',
      args: priceArgs,
      run: async (args) => {
        const base = { clientId: user.clientId, outletName: args.outletName, sku: args.sku };
        const tz = await timeZone();
        if (!args.compareTo) {
          return getPriceCompliance({
            ...base,
            ...resolvePeriod(args.period, now, tz),
            territoryId: args.territoryId,
          });
        }
        const ranges = comparisonRanges(args.period, args.compareTo, now, tz);
        const current = await getPriceCompliance({ ...base, ...ranges.current, territoryId: args.territoryId });
        const values = await getPriceCompliance({
          ...base,
          ...ranges.comparison,
          territoryId: args.compareTo.kind === 'territory' ? args.compareTo.id : args.territoryId,
        });
        const deltas = numericDeltas(current, values);
        return {
          ...current,
          comparison: {
            label: ranges.label,
            basis: args.compareTo,
            values,
            ...(deltas ? { deltas } : {}),
            ...(ranges.note ? { note: ranges.note } : {}),
          },
        };
      },
      figures: async (args, result) =>
        priceComplianceFigures(result as PriceCompliance, await priceWindows(args)),
    }),

    eraseToolTypes({
      name: 'getCampaignPerformance',
      pillar: 'sales' as const,
      description:
        'Call this when the user asks about trade campaigns or promotions by campaign: which ' +
        'campaigns are running or have run, whether a named campaign worked or delivered a ' +
        'return, its ROI, its sell-in lift against the period before it, or how well it was ' +
        'executed in store (outlets visited, planogram compliance, promotion live, price ' +
        'deviation). Returns each campaign\'s dates, budget, attributed and baseline SELL-IN ' +
        'value, lift, ROI and execution figures. For a campaign still running the lift is not ' +
        'yet comparable — say so rather than calling it a failure. Use getRateOfSale instead ' +
        'for sell-in or targets not tied to a campaign, and getContestStandings for agent contests.',
      args: campaignArgs,
      run: async (args) =>
        getCampaignPerformance({
          clientId: user.clientId,
          now,
          campaign: args.campaign,
          state: args.state,
          window: await windowOf(args.period),
        }),
      figures: (_args, result) => campaignFigures(result as CampaignPerformance),
    }),

    eraseToolTypes({
      name: 'getContestStandings',
      pillar: 'execution' as const,
      description:
        'Call this when the user asks about agent contests or competitions: who is winning or ' +
        'leading a contest, its standings or leaderboard, points, who won one that ended, or ' +
        'which contests are running. Returns each contest\'s status, dates, prize, territory and ' +
        'ranked agents with points, visits submitted and tasks closed. Contests only — use ' +
        'getAgentScorecard instead for how well an agent is performing generally, and ' +
        'getCampaignPerformance for trade campaigns.',
      args: z.object({
        contest: z
          .string()
          .min(1)
          .max(80)
          .optional()
          .describe('Optional part of a contest name, e.g. "Visit Sprint".'),
        status: z
          .enum(['current', 'active', 'ended', 'upcoming', 'cancelled', 'all'])
          .default('current')
          .describe(
            'current = running now or ended in the last 30 days. Use all when a named contest may be older.',
          ),
      }),
      run: async (args) =>
        getContestLeaderboards({
          clientId: user.clientId,
          now,
          contest: args.contest,
          filter: args.status,
        }),
    }),

    eraseToolTypes({
      name: 'getTaskSummary',
      pillar: 'execution' as const,
      description:
        'Call this when the user asks about follow-up tasks: open, overdue or closed tasks, SLA ' +
        'breaches, the task backlog, or which agents or territories are behind on closing their ' +
        'tasks. Returns the backlog as of now (open, in progress, overdue by priority), overdue ' +
        'tasks by agent and by territory, the oldest overdue tasks, and — with a period — tasks ' +
        'raised and closed in it. Use getAlerts instead for alerts, getVisitHistory for visits, ' +
        'and getAgentScorecard for an agent\'s overall performance.',
      args: taskArgs,
      run: async (args) =>
        getTaskSummary({
          clientId: user.clientId,
          now,
          window: await windowOf(args.period),
          territoryId: args.territoryId,
          agentId: await resolveAgentId(args.agent),
        }),
      figures: (_args, result) => taskFigures(result as TaskSummary),
    }),

    eraseToolTypes({
      name: 'getAlerts',
      pillar: 'execution' as const,
      description:
        'Call this when the user asks about alerts: which alerts were raised, which are still ' +
        'unacknowledged or open, alerts by type (out of stock, price deviation, low execution ' +
        'score, SLA breach) or severity, or which outlets raise the most alerts. Returns counts by ' +
        'type and state, open alerts by severity, the outlets with the most open alerts and the ' +
        'newest open alerts. It reports alerts, not the measures behind them — use ' +
        'getStockLevels, getPriceCompliance or getAgentScorecard for those, and getTaskSummary ' +
        'for follow-up tasks.',
      args: alertArgs,
      run: async (args) =>
        getAlertSummary({
          clientId: user.clientId,
          window: await windowOf(args.period),
          territoryId: args.territoryId,
          type: args.type,
        }),
      figures: (_args, result) => alertFigures(result as AlertSummary),
    }),

    eraseToolTypes({
      name: 'getSellInForecast',
      pillar: 'sales' as const,
      description:
        'Call this when the user asks for a forecast, projection or expected demand for ONE of ' +
        'our products: how many units outlets will likely order per day, or how many days of ' +
        'stock cover are left. Forecasts SELL-IN (units ordered through TradeIQ, never consumer ' +
        'sales) by simple exponential smoothing over the last 28 complete days, for the whole ' +
        'business or one outlet. It has no confidence interval or measured accuracy: always say ' +
        'it is a smoothed estimate from recent orders. Not for past sell-in (use getRateOfSale), ' +
        'and not for macro-economic or next-quarter questions, which nothing here can answer.',
      args: z.object({
        sku: z.string().min(1).max(80).describe('The product, by name or id, e.g. "Cola 2L".'),
        outletId: z
          .string()
          .min(1)
          .optional()
          .describe('Optional outlet id from another tool result, to forecast one outlet.'),
      }),
      run: async (args) => {
        try {
          return await getSellInForecast({
            clientId: user.clientId,
            now,
            sku: args.sku,
            outletId: args.outletId,
          });
        } catch (err) {
          // Written for the model, and carrying only this tenant's SKU names.
          if (err instanceof SkuLookupError || err instanceof OutletLookupError) {
            throw new ToolFacingError(err.message);
          }
          throw err;
        }
      },
      figures: (_args, result) => forecastFigures(result as SellInForecast),
    }),
  ] as AnyAssistantTool[];
}

import { z } from 'zod';
import { listFlagged } from '../../fraud/fraud.service';
import {
  compareToSchema,
  comparisonWindow,
  describeComparison,
  numericDeltas,
  periodCompareToSchema,
  type Comparison,
  type CompareTo,
} from '../compare';
import {
  competitorFigures,
  salesFigures,
  shareOfShelfFigures,
  stockFigures,
  territoryRankingFigures,
  visibilityComplianceFigures,
  type FigureWindows,
} from '../figures';
import { periodSchema, resolvePeriod } from '../period';
import {
  getCompetitorActivity,
  getSalesPerformance,
  getShareOfShelf,
  getSkuMovement,
  getStockLevels,
  getTerritorySellInChange,
  getVisibilityCompliance,
  getVisitSummary,
  type CompetitorActivity,
  type SalesPerformance,
  type ShareOfShelf,
  type StockLevels,
  type TerritorySellInChange,
  type VisibilityCompliance,
} from '../pillars.service';
import { eraseToolTypes, type AnyAssistantTool } from '../types';
import { clientTimeZoneOf, type ToolContext } from './execution';

/**
 * The four pillars, as tools.
 *
 * Grouped the way a manager thinks — *"Sales, stock, visibility, and
 * competition. Those are your four pillars"* — rather than by REST endpoint. A
 * manager asks "how's my visibility in Western Cape", never
 * "GET /visibility?territory=".
 *
 * Every tool here closes over `ctx.user`, so `clientId` cannot appear in any
 * args schema. Descriptions are **prescriptive**: they state when to call the
 * tool, not what it returns, because a stated trigger condition measurably
 * improves should-call rate.
 */

/** Shared by every pillar tool. Note what is absent: any identity field. */
const windowArgs = z.object({
  period: periodSchema,
  territoryId: z
    .string()
    .min(1)
    .optional()
    .describe('Optional territory id to narrow to. Omit for the whole business.'),
});

/**
 * …plus comparison, for the tools that actually honour it.
 *
 * Split rather than added to `windowArgs` so the schema cannot promise what a
 * tool ignores. A declaration the model can see is a capability the model will
 * offer the user, and the three list-shaped tools below (SKU movement, visit
 * history, fraud flags) answer with rows: differencing those means matching
 * records across two windows where either side may be missing, which is a
 * per-tool judgement rather than something the generic helper can do. They keep
 * the plain window until someone makes that judgement for each.
 */
const comparableWindowArgs = windowArgs.extend({ compareTo: compareToSchema.optional() });

export function buildPillarTools(ctx: ToolContext): AnyAssistantTool[] {
  const { user, now } = ctx;
  const timeZone = clientTimeZoneOf(ctx);

  /** Resolve the model's period into the window every service takes. */
  const scope = async (args: z.infer<typeof windowArgs>) => ({
    clientId: user.clientId,
    ...resolvePeriod(args.period, now, await timeZone()),
    ...(args.territoryId ? { territoryId: args.territoryId } : {}),
  });

  /**
   * The same scope, moved to whatever the comparison measures.
   *
   * A period basis moves the window and keeps the territory; a territory basis
   * moves the territory and keeps the window. Never both — a difference that
   * mixed place and time would be uninterpretable, and the user would not be
   * able to tell which half moved.
   */
  const comparisonScope = async (
    args: z.infer<typeof comparableWindowArgs>,
    compareTo: CompareTo,
  ) => ({
    clientId: user.clientId,
    ...comparisonWindow(args.period, compareTo, now, await timeZone()),
    // `id` is optional in the declared shape and guaranteed present for a
    // territory basis by the schema's refinement; the guard keeps the types
    // honest rather than asserting past them.
    ...(compareTo.kind === 'territory' && compareTo.id
      ? { territoryId: compareTo.id }
      : args.territoryId
        ? { territoryId: args.territoryId }
        : {}),
  });

  /**
   * Run a pillar service once, or twice when the user asked to compare.
   *
   * Both runs go through the *same* service with the same tenant binding, so a
   * comparison cannot reach data the uncompared call could not. The second run
   * is sequential rather than parallel: these are the same indexed queries over
   * the same tables, and a turn that fans out doubles the peak load on a
   * database that is also serving the console.
   */
  const withComparison = async <R>(
    args: z.infer<typeof comparableWindowArgs>,
    run: (window: Awaited<ReturnType<typeof scope>>) => Promise<R>,
  ): Promise<R | (R & { comparison: Comparison })> => {
    const current = await run(await scope(args));
    if (!args.compareTo) return current;

    const values = await run(
      (await comparisonScope(args, args.compareTo)) as Awaited<ReturnType<typeof scope>>,
    );
    return {
      ...current,
      comparison: {
        label: describeComparison(args.period, args.compareTo),
        basis: args.compareTo,
        values,
        ...(numericDeltas(current, values) ? { deltas: numericDeltas(current, values) } : {}),
      },
    };
  };

  /**
   * The windows a comparable tool measured, for its figure artifacts.
   *
   * Recomputed from the args with the same functions `scope` and
   * `comparisonScope` used, against the timezone the run already looked up —
   * so no query, and no chance of a tile labelling a different window from the
   * one its numbers came from.
   */
  const windowsFor = async (
    args: z.infer<typeof comparableWindowArgs>,
  ): Promise<FigureWindows> => {
    const tz = await timeZone();
    return {
      timeZone: tz,
      current: resolvePeriod(args.period, now, tz),
      ...(args.compareTo
        ? {
            comparison: {
              range: comparisonWindow(args.period, args.compareTo, now, tz),
              basis: args.compareTo,
            },
          }
        : {}),
    };
  };

  /**
   * The view every comparable pillar tool draws.
   *
   * Params identify the view — pillar, window, scope, basis — and never the
   * figures, which ride in the artifact's `data`. That keeps `params` the one
   * contract the model and the UI's filter controls both write through.
   */
  const pillarView =
    (pillar: 'sales' | 'stock' | 'visibility' | 'competition') =>
    (args: z.infer<typeof comparableWindowArgs>) => ({
      type: 'pillar_metrics' as const,
      params: {
        pillar,
        period: args.period,
        ...(args.territoryId ? { territoryId: args.territoryId } : {}),
        ...(args.compareTo ? { compareTo: args.compareTo } : {}),
      },
    });

  const tools = [
    // ── Sales ────────────────────────────────────────────────────────────
    eraseToolTypes({
      name: 'getRateOfSale',
      pillar: 'sales' as const,
      // The scope note is in the description on purpose (#337). These figures
      // are sell-in — what outlets ORDERED through TradeIQ — and there is no
      // POS feed anywhere in this product, so a model left to its own
      // vocabulary will reach for "sold" and hand a manager a sell-out number
      // that does not exist. It is also where the monthly-target rule has to be
      // stated: the model chooses the period, so it is the only thing that can
      // avoid asking for attainment over a window no target covers.
      description:
        'Call this when the user asks how sales are tracking against target, about rate of ' +
        'sale, attainment, or whether a territory is hitting its numbers. Reports SELL-IN — ' +
        'units ordered through TradeIQ by outlets — against manager-set monthly targets. ' +
        'These are NOT consumer sell-out: there is no till or POS feed, so never describe ' +
        'them as what shoppers bought. Targets are monthly, so a target and attainment come ' +
        'back only for whole calendar months; for any other period you get sell-in units and ' +
        'a null target. A null target means none is set, not a target of zero.',
      args: comparableWindowArgs,
      run: async (args) => withComparison(args, (w) => getSalesPerformance(w)),
      view: pillarView('sales'),
      figures: async (args, result) =>
        salesFigures(result as SalesPerformance, await windowsFor(args)),
    }),

    eraseToolTypes({
      name: 'getTerritoryRanking',
      pillar: 'sales' as const,
      // Narrow on purpose. Every other sales question — a total, a target,
      // attainment, one territory's figure — belongs to getRateOfSale, and a
      // broad description here would steal those selections. The trigger is
      // the RANKING or COMPARISON ACROSS territories, and the description says
      // so in both directions.
      description:
        'Call this when the user wants territories ranked or compared against each other ' +
        'by how their sell-in changed — which territories grew or declined, which area is ' +
        'driving a drop, or the change by territory against an earlier period. Only for ' +
        'comparisons ACROSS territories. ' +
        'Returns each territory\'s SELL-IN (units ordered through TradeIQ — never consumer ' +
        'sell-out) and its % change against the comparison window, worst first. No targets ' +
        'or attainment. Use getRateOfSale instead for a total, a single territory\'s figure, ' +
        'or anything about target.',
      args: z.object({
        period: periodSchema,
        compareTo: periodCompareToSchema
          .default({ kind: 'previous_period' })
          .describe(
            'What to measure the change against. previous_period unless the user says ' +
              'last year.',
          ),
        region: z
          .string()
          .min(1)
          .max(80)
          .optional()
          .describe('Optional region name to narrow to, e.g. "Gauteng". Omit for all territories.'),
      }),
      run: async (args) => {
        const tz = await timeZone();
        return getTerritorySellInChange({
          clientId: user.clientId,
          timeZone: tz,
          current: resolvePeriod(args.period, now, tz),
          comparison: comparisonWindow(args.period, args.compareTo, now, tz),
          ...(args.region ? { region: args.region } : {}),
        });
      },
      figures: async (args, result) => {
        const tz = await timeZone();
        return territoryRankingFigures(result as TerritorySellInChange, {
          timeZone: tz,
          current: resolvePeriod(args.period, now, tz),
          comparison: {
            range: comparisonWindow(args.period, args.compareTo, now, tz),
            basis: args.compareTo,
          },
        });
      },
    }),

    eraseToolTypes({
      name: 'getSkuMovement',
      pillar: 'sales' as const,
      description:
        'Call this when the user asks which products are moving or not moving, about SKU ' +
        'velocity, how long a product has been out of stock, or which lines have been out ' +
        'of stock longest.',
      args: windowArgs.extend({
        limit: z.number().int().min(1).max(50).default(20).describe('How many SKUs to return.'),
      }),
      run: async (args) => getSkuMovement({ ...(await scope(args)), limit: args.limit }),
    }),

    // ── Stock ────────────────────────────────────────────────────────────
    eraseToolTypes({
      name: 'getStockLevels',
      pillar: 'stock' as const,
      description:
        'Call this when the user asks about stock on hand, availability, out-of-stocks, ' +
        'on-shelf availability, or which outlets keep running dry.',
      args: comparableWindowArgs,
      run: async (args) => withComparison(args, (w) => getStockLevels(w)),
      // The tool declares what it draws; the model never names a spec type.
      //
      // Outlet ids come from the RESULT — canonical, so a Phase 2 `refine` can
      // re-run them — and the coordinates ride in the artifact's `data`. `null`
      // when nothing is out of stock: a map of no problems is not an answer,
      // and returning null is the normal case, not a failure.
      view: (_args, result) => {
        const outlets = (result as StockLevels).worstOutlets;
        if (outlets.length === 0) return null;
        return { type: 'outlet_map', params: { outletIds: outlets.map((o) => o.outletId) } };
      },
      figures: async (args, result) => stockFigures(result as StockLevels, await windowsFor(args)),
    }),

    // ── Visibility ───────────────────────────────────────────────────────
    eraseToolTypes({
      name: 'getShareOfShelf',
      pillar: 'visibility' as const,
      description:
        'Call this when the user asks about share of shelf, facings, or how much shelf space ' +
        'we hold against competitors.',
      args: comparableWindowArgs,
      run: async (args) => withComparison(args, (w) => getShareOfShelf(w)),
      view: pillarView('visibility'),
      figures: async (args, result) =>
        shareOfShelfFigures(result as ShareOfShelf, await windowsFor(args)),
    }),

    eraseToolTypes({
      name: 'getVisibilityCompliance',
      pillar: 'visibility' as const,
      description:
        'Call this when the user asks about planogram compliance, merchandising standards, ' +
        'shelf cleanliness, or whether displays are in high-traffic positions.',
      args: comparableWindowArgs,
      run: async (args) => withComparison(args, (w) => getVisibilityCompliance(w)),
      view: pillarView('visibility'),
      figures: async (args, result) =>
        visibilityComplianceFigures(result as VisibilityCompliance, await windowsFor(args)),
    }),

    // ── Competition ──────────────────────────────────────────────────────
    eraseToolTypes({
      name: 'getCompetitorActivity',
      pillar: 'competition' as const,
      description:
        'Call this when the user asks what competitors are doing — their pricing, their ' +
        'facings, their promoters, or which competitor brands are showing up in outlets.',
      args: comparableWindowArgs,
      run: async (args) => withComparison(args, (w) => getCompetitorActivity(w)),
      view: pillarView('competition'),
      figures: async (args, result) =>
        competitorFigures(result as CompetitorActivity, await windowsFor(args)),
    }),

    // ── Execution ────────────────────────────────────────────────────────
    eraseToolTypes({
      name: 'getVisitHistory',
      pillar: 'execution' as const,
      // "…or whether an agent has been checking in" used to end this line, and
      // it was stealing the exit-demo question from getAgentScorecard on the
      // first live sweep: a model reasonably reads it as covering how an agent
      // is doing. Narrowed to activity and coverage, with the hand-off stated.
      description:
        'Call this when the user asks what visits happened, coverage, or which outlets were ' +
        'called on in a period. This tool counts activity; it does not judge quality. ' +
        'Use getAgentScorecard instead if the user asks how WELL a named agent is doing, ' +
        'or wants them compared against their team.',
      args: windowArgs.extend({
        agentId: z.string().min(1).optional().describe('Narrow to one agent.'),
        outletId: z.string().min(1).optional().describe('Narrow to one outlet.'),
      }),
      run: async (args) =>
        getVisitSummary({
          ...(await scope(args)),
          ...(args.agentId ? { agentId: args.agentId } : {}),
          ...(args.outletId ? { outletId: args.outletId } : {}),
        }),
    }),

    eraseToolTypes({
      name: 'getFraudFlags',
      pillar: 'execution' as const,
      // The scope note is in the description on purpose. The assistant must not
      // imply detection we do not have: exactly these ten signals are
      // implemented (fraud.service.ts). Anything beyond them is backend work
      // tracked in STATUS.md, not something to hint at here.
      description:
        'Call this when the user asks about suspicious visits, fraud, or whether an agent ' +
        'may be gaming their numbers. Covers ten signals only: failed check-in attempts, ' +
        'suspiciously fast completion, suspiciously slow completion, geofence distance, ' +
        'missing captures, photo/GPS divergence, photos taken outside the visit\'s time ' +
        'window, the same stock counts repeated visit after visit, a photo reused from ' +
        'another visit, and stock counted while standing in a different store. It does ' +
        'not detect anything beyond these.',
      args: windowArgs.extend({
        minScore: z
          .number()
          .min(0)
          .max(100)
          .default(50)
          .describe('Minimum risk score. Use 50 unless the user asks for everything.'),
      }),
      run: async (args) => {
        const { from, to } = resolvePeriod(args.period, now, await timeZone());
        return listFlagged({ clientId: user.clientId, minScore: args.minScore, from, to });
      },
    }),
  ];

  return tools as AnyAssistantTool[];
}

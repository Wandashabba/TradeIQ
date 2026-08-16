import { z } from 'zod';
import { compareToSchema } from './compare';
import { periodSchema } from './period';

/**
 * The view-spec catalog — what the model is allowed to draw.
 *
 * **The catalog is closed, and that is the feature.** The model never emits UI;
 * it names a spec from this list and supplies parameters. Three things follow:
 *
 * - It cannot invent a chart type that violates the design rules already
 *   encoded in `charts.dart` — one series one hue, recessive chrome, selective
 *   labels. A model that could emit arbitrary UI would produce something
 *   plausible and off-brand on its first surprising question.
 * - An unrecognised spec renders as **text**, never as a blank card. A blank
 *   card is the worst outcome: it looks like a bug in the app rather than like
 *   a question the assistant could not draw.
 * - Validation happens here, on the server, before anything reaches the client.
 *   The Flutter registry can then assume a spec it recognises is well-formed.
 *
 * Pure — no Prisma, no network — so every rejection path is exhaustively
 * testable, which is the point of putting the output contract in a pure file.
 */

export const VIEW_SPEC_TYPES = [
  'agent_scorecard',
  'trend_chart',
  'outlet_map',
  'pillar_metrics',
] as const;
export type ViewSpecType = (typeof VIEW_SPEC_TYPES)[number];

/**
 * Metrics a trend can plot.
 *
 * Each maps onto a series `trends.service.ts` already computes. The list is not
 * "every number in the system": a metric the backend cannot produce is a chart
 * that renders empty, and the model has no way to know that in advance.
 */
export const TREND_METRICS = [
  'execution_score',
  'availability',
  'perfect_store',
  'share_of_shelf',
] as const;
export type TrendMetric = (typeof TREND_METRICS)[number];

export const TREND_INTERVALS = ['day', 'week'] as const;

const agentScorecardParams = z.object({
  agentId: z.string().min(1).describe('The id of the field agent, as returned by a tool.'),
  period: periodSchema,
});

const trendChartParams = z.object({
  metric: z.enum(TREND_METRICS).describe('Which series to plot.'),
  period: periodSchema,
  interval: z
    .enum(TREND_INTERVALS)
    .default('day')
    .describe('Bucket width. Use week for periods longer than about a month.'),
});

/**
 * The four pillars' headline figures, with the comparison beside them.
 *
 * Added because comparison shipped with nowhere to land: of the five tools that
 * accept `compareTo`, only `getStockLevels` declared a view, and an outlet map
 * of stockout pins has no natural place for "on-shelf availability is up 5.1 on
 * the month before". Four of the five drew nothing at all, so the feature the
 * practitioner asked for by name arrived invisible.
 *
 * `params` carries only what identifies the view — which pillar, over what
 * window, against what. The figures themselves ride in the artifact's `data`,
 * exactly as they do for every other spec: params are the contract the model and
 * the UI both write through, and putting numbers in them would make a filter
 * change a data edit.
 */
const pillarMetricsParams = z.object({
  pillar: z
    .enum(['sales', 'stock', 'visibility', 'competition'])
    .describe('Which pillar these figures belong to.'),
  period: periodSchema,
  territoryId: z.string().min(1).optional(),
  compareTo: compareToSchema.optional(),
});

const outletMapParams = z.object({
  // Both optional, but not both absent — see the refine below.
  territoryId: z.string().min(1).optional(),
  outletIds: z.array(z.string().min(1)).max(500).optional(),
});

/**
 * The catalog. One entry per drawable thing, keyed by the type the model names.
 *
 * `params` is the single contract: the model writes through this schema, and
 * from Phase 2 the UI's filter controls will write through the same one. That
 * is what stops the two control paths from drifting into disagreement about
 * what a valid artifact looks like.
 */
export const VIEW_SPEC_CATALOG = {
  agent_scorecard: agentScorecardParams,
  trend_chart: trendChartParams,
  pillar_metrics: pillarMetricsParams,
  outlet_map: outletMapParams.refine(
    (value) => value.territoryId !== undefined || (value.outletIds?.length ?? 0) > 0,
    {
      // An unfiltered map of every outlet in the tenant is not a useful answer
      // to any question, and on a large client it is a slow one. Requiring a
      // scope makes "show me the map" a clarifying question rather than a
      // thousand-pin render.
      message: 'An outlet map needs either a territoryId or at least one outletId.',
    },
  ),
} as const satisfies Record<ViewSpecType, z.ZodType>;

export type ViewSpec = {
  [K in ViewSpecType]: { type: K; params: z.infer<(typeof VIEW_SPEC_CATALOG)[K]> };
}[ViewSpecType];

export interface ViewSpecRejection {
  ok: false;
  /** Safe to log; safe to show a developer. Never streamed to the user as-is. */
  reason: string;
  issues: string[];
}

export type ViewSpecValidation = { ok: true; spec: ViewSpec } | ViewSpecRejection;

/**
 * Validate a candidate view spec.
 *
 * Returns a result rather than throwing. A spec the model got slightly wrong is
 * a routine event, not an exception: the turn should degrade to a text answer
 * and carry on, and an exception three frames into the orchestrator would take
 * the whole turn down instead.
 */
export function validateViewSpec(candidate: unknown): ViewSpecValidation {
  if (typeof candidate !== 'object' || candidate === null || Array.isArray(candidate)) {
    return { ok: false, reason: 'A view spec must be an object.', issues: [] };
  }

  const { type, params } = candidate as { type?: unknown; params?: unknown };

  if (typeof type !== 'string') {
    return { ok: false, reason: 'A view spec must carry a string `type`.', issues: [] };
  }

  // The closed-catalog check. `Object.prototype.hasOwnProperty` rather than
  // `in`, so a type of "toString" or "constructor" cannot resolve to something
  // off the prototype chain and be treated as a schema.
  if (!Object.prototype.hasOwnProperty.call(VIEW_SPEC_CATALOG, type)) {
    return {
      ok: false,
      reason: `Unknown view spec "${type}". The catalog is closed; this renders as text.`,
      issues: [],
    };
  }

  const schema = VIEW_SPEC_CATALOG[type as ViewSpecType];
  const result = schema.safeParse(params);

  if (!result.success) {
    return {
      ok: false,
      reason: `Invalid params for "${type}".`,
      issues: result.error.issues.map((i) => `${i.path.join('.') || '<root>'}: ${i.message}`),
    };
  }

  return { ok: true, spec: { type, params: result.data } as ViewSpec };
}

export function isViewSpecType(value: string): value is ViewSpecType {
  return (VIEW_SPEC_TYPES as readonly string[]).includes(value);
}

import { z } from 'zod';
import { addCalendarDays, localCalendarDate } from '../../lib/clientTime';
import type { AgentPerformance } from '../scorecards/scorecards.service';
import type { CompareTo } from './compare';
import type { DateRange } from './period';
import type {
  CompetitorActivity,
  SalesPerformance,
  ShareOfShelf,
  StockLevels,
  TerritorySellInChange,
  VisibilityCompliance,
} from './pillars.service';

/**
 * Figure artifacts — `stat_tiles` and `ranked_bars`.
 *
 * **The model never supplies a number that lands in one of these.** Every tile
 * and every bar is built here, deterministically, from a tool result the
 * backend already computed — the same object the model reads. A tile is
 * therefore a *view* of retrieved data, exactly like a chart is, and prompt rule
 * 1 ("every figure must come from a tool") holds for the visuals by
 * construction rather than by instruction.
 *
 * Three rules shape everything below:
 *
 * - **No new queries.** A builder only reads what its tool returned. A card the
 *   data cannot fill is omitted, never padded.
 * - **A missing value is not zero.** `pct(0, 0)` in the semantic layer is `0`;
 *   a tile built from it would show a fabricated 0%. So every percentage tile
 *   checks the observation count behind it, and the attainment tile follows
 *   prompt rule 9 — whole months only, never from a null target.
 * - **Sentiment is a table, not a judgement.** Whether "up" is good depends on
 *   the metric (more sell-in is good; more stock-outs is bad), and that is
 *   written out in {@link SENTIMENT} where it can be reviewed, not inferred by
 *   the model or guessed in the app.
 *
 * Pure: no Prisma, no network, no clock. Types are imported as types only.
 */

// ── The contract ─────────────────────────────────────────────────────────────

export const FIGURE_ARTIFACT_TYPES = ['stat_tiles', 'ranked_bars'] as const;
export type FigureArtifactType = (typeof FIGURE_ARTIFACT_TYPES)[number];

/** Outlet names and competitor SKUs are bounded, so one long record cannot break a card. */
const MAX_LABEL_CHARS = 80;

const valueUnit = z.enum(['units', 'pct', 'pts', 'count']);
const deltaUnit = z.enum(['pct', 'pts', 'count']);
const sentiment = z.enum(['good', 'bad', 'warn', 'neutral']);

export type ValueUnit = z.infer<typeof valueUnit>;
export type DeltaUnit = z.infer<typeof deltaUnit>;
export type Sentiment = z.infer<typeof sentiment>;

const deltaSchema = z
  .object({
    /** Magnitude. The sign lives in `direction`, so the two cannot disagree. */
    value: z.number().nonnegative(),
    unit: deltaUnit,
    direction: z.enum(['up', 'down']),
    sentiment,
  })
  .strict();

const tileSchema = z
  .object({
    label: z.string().min(1).max(60),
    value: z.number(),
    unit: valueUnit,
    delta: deltaSchema.optional(),
    comparedTo: z.string().min(1).max(80).optional(),
    meter: z.number().min(0).max(100).optional(),
  })
  .strict();

const statTilesSchema = z.object({ tiles: z.array(tileSchema).min(1).max(6) }).strict();

const rankedBarsSchema = z
  .object({
    title: z.string().min(1).max(80),
    comparedTo: z.string().min(1).max(80),
    unit: valueUnit,
    items: z
      .array(z.object({ label: z.string().min(1).max(MAX_LABEL_CHARS), value: z.number() }).strict())
      .min(1)
      .max(12),
  })
  .strict();

export type StatTile = z.infer<typeof tileSchema>;
export type TileDelta = z.infer<typeof deltaSchema>;
export type StatTiles = z.infer<typeof statTilesSchema>;
export type RankedBars = z.infer<typeof rankedBarsSchema>;

export type FigureArtifact =
  | { type: 'stat_tiles'; data: StatTiles }
  | { type: 'ranked_bars'; data: RankedBars };

const FIGURE_SCHEMAS: Record<FigureArtifactType, z.ZodType> = {
  stat_tiles: statTilesSchema,
  ranked_bars: rankedBarsSchema,
};

/**
 * Validate a figure before it goes on the wire.
 *
 * The builders below should never produce an invalid one, and this is how that
 * claim is checked in production rather than hoped: a malformed figure is
 * dropped (and logged by the caller), so the answer degrades to text and the
 * app never receives a card it cannot draw.
 */
export function validateFigure(
  candidate: unknown,
): { ok: true; figure: FigureArtifact } | { ok: false; reason: string } {
  if (typeof candidate !== 'object' || candidate === null) {
    return { ok: false, reason: 'A figure must be an object.' };
  }
  const { type, data } = candidate as { type?: unknown; data?: unknown };
  if (typeof type !== 'string' || !Object.prototype.hasOwnProperty.call(FIGURE_SCHEMAS, type)) {
    return { ok: false, reason: `Unknown figure type "${String(type)}".` };
  }
  const parsed = FIGURE_SCHEMAS[type as FigureArtifactType].safeParse(data);
  if (!parsed.success) {
    return {
      ok: false,
      reason: parsed.error.issues.map((i) => `${i.path.join('.') || '<root>'}: ${i.message}`).join('; '),
    };
  }
  return { ok: true, figure: { type, data: parsed.data } as FigureArtifact };
}

// ── Sentiment ────────────────────────────────────────────────────────────────

/**
 * What a rise or a fall means, per metric. **The single source of sentiment.**
 *
 * `warn` rather than `bad` where a fall is worth attention but is not by itself
 * a failure — on-shelf availability slipping four points, say, or a competitor
 * adding promoters. The ranking order of {@link rankedBars} is derived from the
 * same table, so a bar list and a tile can never disagree about which way is
 * worse.
 */
export const SENTIMENT = {
  sell_in_units: { up: 'good', down: 'bad' },
  outlets_ordering: { up: 'good', down: 'bad' },
  attainment: { up: 'good', down: 'bad' },
  on_shelf_availability: { up: 'good', down: 'warn' },
  outlets_with_stockout: { up: 'bad', down: 'good' },
  out_of_stock_lines: { up: 'bad', down: 'good' },
  share_of_shelf: { up: 'good', down: 'bad' },
  planogram_compliance: { up: 'good', down: 'warn' },
  high_traffic_pass: { up: 'good', down: 'warn' },
  competitor_promoter_presence: { up: 'warn', down: 'good' },
  competitor_skus: { up: 'warn', down: 'neutral' },
  competitor_facings: { up: 'warn', down: 'good' },
  execution_score: { up: 'good', down: 'bad' },
  visits: { up: 'good', down: 'warn' },
  outlets_visited: { up: 'good', down: 'warn' },
  sell_in_change: { up: 'good', down: 'bad' },
  // Operations (#362).
  price_deviation: { up: 'bad', down: 'good' },
  price_breach_lines: { up: 'bad', down: 'good' },
  campaign_lift: { up: 'good', down: 'bad' },
  campaign_roi: { up: 'good', down: 'bad' },
  open_tasks: { up: 'bad', down: 'good' },
  overdue_tasks: { up: 'bad', down: 'good' },
  alerts_raised: { up: 'warn', down: 'good' },
  unacknowledged_alerts: { up: 'bad', down: 'good' },
  forecast_units: { up: 'neutral', down: 'neutral' },
  days_of_cover: { up: 'good', down: 'warn' },
} as const satisfies Record<string, { up: Sentiment; down: Sentiment }>;

export type FigureMetric = keyof typeof SENTIMENT;

/** Is a higher value better for this metric? Drives ranking order. */
export function higherIsBetter(metric: FigureMetric): boolean {
  return SENTIMENT[metric].up === 'good';
}

// ── Formatting ───────────────────────────────────────────────────────────────

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** Round to one decimal place, without `-0`. */
export function round1(value: number): number {
  const rounded = Math.round(value * 10) / 10;
  return Object.is(rounded, -0) ? 0 : rounded;
}

/**
 * `55034` → `55,034`; `92.35` → `92.4`.
 *
 * Built by hand rather than with `Intl.NumberFormat('en-ZA')`, which uses a
 * non-breaking space as the group separator and a comma as the decimal mark on
 * current ICU builds — so the output would differ between runtimes and would
 * not match the agreed `55,034` shape the app displays.
 */
export function formatNumber(value: number): string {
  const rounded = round1(value);
  const negative = rounded < 0;
  const [whole, fraction] = Math.abs(rounded).toFixed(1).split('.');
  const grouped = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  return `${negative ? '-' : ''}${grouped}${fraction === '0' ? '' : `.${fraction}`}`;
}

export function formatValue(value: number, unit: ValueUnit): string {
  return unit === 'pct' ? `${formatNumber(value)}%` : formatNumber(value);
}

const yy = (date: Date) => `'${String(date.getUTCFullYear() % 100).padStart(2, '0')}`;
const mon = (date: Date) => MONTHS[date.getUTCMonth()];

/**
 * A half-open window as the client reads it: `Aug '25`, `1–17 Sep '26`.
 *
 * Calendar dates are taken in the client's timezone, and the upper bound is
 * exclusive — `[1 Aug, 1 Sep)` is August, not "1 Aug – 1 Sep".
 */
export function formatPeriodLabel(range: DateRange, timeZone: string): string {
  const first = localCalendarDate(range.from, timeZone);
  const last = addCalendarDays(localCalendarDate(range.to, timeZone), -1);
  const sameYear = first.getUTCFullYear() === last.getUTCFullYear();
  const sameMonth = sameYear && first.getUTCMonth() === last.getUTCMonth();

  const wholeMonths = first.getUTCDate() === 1 && addCalendarDays(last, 1).getUTCDate() === 1;
  if (wholeMonths) {
    if (sameMonth) return `${mon(first)} ${yy(first)}`;
    if (sameYear) return `${mon(first)}–${mon(last)} ${yy(last)}`;
    return `${mon(first)} ${yy(first)} – ${mon(last)} ${yy(last)}`;
  }

  if (first.getTime() === last.getTime()) return `${first.getUTCDate()} ${mon(first)} ${yy(first)}`;
  if (sameMonth) return `${first.getUTCDate()}–${last.getUTCDate()} ${mon(last)} ${yy(last)}`;
  if (sameYear) {
    return `${first.getUTCDate()} ${mon(first)} – ${last.getUTCDate()} ${mon(last)} ${yy(last)}`;
  }
  return (
    `${first.getUTCDate()} ${mon(first)} ${yy(first)} – ` +
    `${last.getUTCDate()} ${mon(last)} ${yy(last)}`
  );
}

/** Labels are data (outlet names, competitor SKUs) — bounded, never rewritten. */
function boundLabel(label: string): string {
  const trimmed = label.trim();
  return trimmed.length <= MAX_LABEL_CHARS
    ? trimmed
    : `${trimmed.slice(0, MAX_LABEL_CHARS - 1)}…`;
}

// ── Building blocks ──────────────────────────────────────────────────────────

/** The windows a tool measured, resolved by the tool from its own args. */
export interface FigureWindows {
  timeZone: string;
  current: DateRange;
  /** Present only when the tool ran a comparison. */
  comparison?: { range: DateRange; basis: CompareTo };
}

/** What the comparison is, in the tile's own vocabulary. */
export function comparisonLabel(windows: FigureWindows): string | undefined {
  const comparison = windows.comparison;
  if (!comparison) return undefined;
  if (comparison.basis.kind === 'territory') return 'other territory';
  return formatPeriodLabel(comparison.range, windows.timeZone);
}

/**
 * A delta, or `undefined` when there is nothing honest to show.
 *
 * - `units` change as a percentage; a zero baseline has no percentage ("up from
 *   nothing" is not +100% or +∞), so it falls back to the absolute count.
 * - `pct` and `pts` values change in points — "availability fell 4 points", not
 *   "fell 4.3%", which would be a percentage of a percentage.
 * - A change that rounds to zero is omitted: the contract has no "flat"
 *   direction, and choosing one would colour a non-event.
 */
export function buildDelta(
  metric: FigureMetric,
  unit: ValueUnit,
  current: number,
  baseline: number,
): TileDelta | undefined {
  const difference = current - baseline;
  let value: number;
  let changeUnit: DeltaUnit;

  if (unit === 'units' && baseline !== 0) {
    value = round1((difference / Math.abs(baseline)) * 100);
    changeUnit = 'pct';
  } else if (unit === 'units' || unit === 'count') {
    value = round1(difference);
    changeUnit = 'count';
  } else {
    value = round1(difference);
    changeUnit = 'pts';
  }

  if (value === 0) return undefined;
  const direction = value > 0 ? 'up' : 'down';
  return { value: Math.abs(value), unit: changeUnit, direction, sentiment: SENTIMENT[metric][direction] };
}

/** One tile, with its delta and `vs …` line when a baseline exists. */
export function buildTile(input: {
  metric: FigureMetric;
  label: string;
  value: number;
  unit: ValueUnit;
  baseline?: number | null;
  baselineLabel?: string;
  meter?: number;
  comparedTo?: string;
}): StatTile {
  const tile: StatTile = { label: input.label, value: input.value, unit: input.unit };
  const hasBaseline =
    input.baseline !== undefined && input.baseline !== null && Number.isFinite(input.baseline);

  if (hasBaseline) {
    const delta = buildDelta(input.metric, input.unit, input.value, input.baseline as number);
    if (delta) tile.delta = delta;
  }

  const comparedTo =
    input.comparedTo ??
    (hasBaseline && input.baselineLabel
      ? `vs ${formatValue(input.baseline as number, input.unit)} · ${input.baselineLabel}`
      : undefined);
  if (comparedTo) tile.comparedTo = comparedTo;
  if (input.meter !== undefined) tile.meter = Math.max(0, Math.min(100, Math.round(input.meter)));
  return tile;
}

/**
 * A ranked bar list, **worst first**.
 *
 * Worst is read off {@link SENTIMENT}: for a metric where higher is better
 * (sell-in change) the lowest value leads; where higher is worse (stock-out
 * lines) the highest does. Signs are preserved — a fall is a negative bar.
 * Ties break on label so the order is stable across runs.
 */
export function rankedBars(input: {
  metric: FigureMetric;
  title: string;
  comparedTo: string;
  unit: ValueUnit;
  items: readonly { label: string; value: number }[];
  limit?: number;
}): RankedBars | null {
  const ascending = higherIsBetter(input.metric);
  const items = input.items
    .filter((item) => Number.isFinite(item.value) && item.label.trim().length > 0)
    .map((item) => ({ label: boundLabel(item.label), value: round1(item.value) }))
    .sort((a, b) =>
      a.value === b.value
        ? a.label.localeCompare(b.label)
        : ascending
          ? a.value - b.value
          : b.value - a.value,
    )
    .slice(0, input.limit ?? 10);

  // One bar is not a ranking. The tool's other output already covers it.
  if (items.length < 2) return null;
  return { title: input.title, comparedTo: input.comparedTo, unit: input.unit, items };
}

const tiles = (list: StatTile[]): FigureArtifact[] =>
  list.length > 0 ? [{ type: 'stat_tiles', data: { tiles: list } }] : [];

const bars = (value: RankedBars | null): FigureArtifact[] =>
  value ? [{ type: 'ranked_bars', data: value }] : [];

/** The comparison run's figures, when the tool ran one and returned an object. */
function comparisonValues<T>(result: unknown): Partial<T> | undefined {
  const comparison = (result as { comparison?: { values?: unknown } }).comparison;
  const values = comparison?.values;
  return typeof values === 'object' && values !== null ? (values as Partial<T>) : undefined;
}

const finite = (value: unknown): value is number => typeof value === 'number' && Number.isFinite(value);

// ── Per-tool builders ────────────────────────────────────────────────────────

/**
 * Sell-in (`getRateOfSale`): units, outlets ordering, and — only for whole
 * calendar months with a real target — attainment with a meter.
 *
 * The attainment tile is **omitted**, never zeroed, when the window is a
 * part-month (`months` empty), when no target is set (`targetUnits` null), or
 * when the target is zero (a ratio against nothing). That is prompt rule 9
 * enforced in the visual, so the card cannot contradict the answer.
 */
export function salesFigures(result: SalesPerformance, windows: FigureWindows): FigureArtifact[] {
  const before = comparisonValues<SalesPerformance>(result);
  const against = comparisonLabel(windows);
  const out: StatTile[] = [];

  out.push(
    buildTile({
      metric: 'sell_in_units',
      label: 'Sell-in, units',
      value: result.sellInUnits,
      unit: 'units',
      baseline: finite(before?.sellInUnits) ? before.sellInUnits : null,
      baselineLabel: against,
    }),
  );

  const wholeMonths = Array.isArray(result.months) && result.months.length > 0;
  if (
    wholeMonths &&
    finite(result.targetUnits) &&
    result.targetUnits > 0 &&
    finite(result.attainmentPct)
  ) {
    out.push(
      buildTile({
        metric: 'attainment',
        label: 'Target attainment',
        value: result.attainmentPct,
        unit: 'pct',
        meter: result.attainmentPct,
        comparedTo:
          `of ${formatValue(result.targetUnits, 'units')} · ` +
          formatPeriodLabel(windows.current, windows.timeZone),
      }),
    );
  }

  out.push(
    buildTile({
      metric: 'outlets_ordering',
      label: 'Outlets ordering',
      value: result.outletsOrdering,
      unit: 'count',
      baseline: finite(before?.outletsOrdering) ? before.outletsOrdering : null,
      baselineLabel: against,
    }),
  );

  return tiles(out);
}

/**
 * Stock (`getStockLevels`): availability and outlets with a stock-out, plus the
 * outlets ranked by out-of-stock lines.
 *
 * Nothing when no stock lines were observed: `pct(0, 0)` is `0`, and "0% on
 * shelf" from zero observations is a fabricated crisis.
 */
export function stockFigures(result: StockLevels, windows: FigureWindows): FigureArtifact[] {
  if (!(result.linesObserved > 0)) return [];
  const before = comparisonValues<StockLevels>(result);
  const baselineUsable = finite(before?.linesObserved) && before.linesObserved > 0;
  const against = comparisonLabel(windows);

  const out = tiles([
    buildTile({
      metric: 'on_shelf_availability',
      label: 'On-shelf availability',
      value: result.onShelfAvailabilityPct,
      unit: 'pct',
      baseline: baselineUsable ? before!.onShelfAvailabilityPct : null,
      baselineLabel: against,
    }),
    buildTile({
      metric: 'outlets_with_stockout',
      label: 'Outlets with a stock-out',
      value: result.outletsWithStockout,
      unit: 'count',
      baseline: baselineUsable ? before!.outletsWithStockout : null,
      baselineLabel: against,
    }),
  ]);

  const ranking = rankedBars({
    metric: 'out_of_stock_lines',
    title: 'Out-of-stock lines by outlet',
    comparedTo: formatPeriodLabel(windows.current, windows.timeZone),
    unit: 'count',
    items: (result.worstOutlets ?? []).map((o) => ({ label: o.outletName, value: o.outOfStockLines })),
  });

  return [...out, ...bars(ranking)];
}

/** Visibility (`getShareOfShelf`). Nothing when no facings were counted. */
export function shareOfShelfFigures(result: ShareOfShelf, windows: FigureWindows): FigureArtifact[] {
  if (!(result.ourFacings + result.competitorFacings > 0)) return [];
  const before = comparisonValues<ShareOfShelf>(result);
  const baselineUsable =
    finite(before?.ourFacings) &&
    finite(before?.competitorFacings) &&
    before.ourFacings + before.competitorFacings > 0;

  return tiles([
    buildTile({
      metric: 'share_of_shelf',
      label: 'Share of shelf',
      value: result.shareOfShelfPct,
      unit: 'pct',
      baseline: baselineUsable ? before!.shareOfShelfPct : null,
      baselineLabel: comparisonLabel(windows),
    }),
  ]);
}

/** Visibility (`getVisibilityCompliance`). Nothing when nothing was observed. */
export function visibilityComplianceFigures(
  result: VisibilityCompliance,
  windows: FigureWindows,
): FigureArtifact[] {
  if (!(result.observations > 0)) return [];
  const before = comparisonValues<VisibilityCompliance>(result);
  const baselineUsable = finite(before?.observations) && before.observations > 0;
  const against = comparisonLabel(windows);

  return tiles([
    buildTile({
      metric: 'planogram_compliance',
      label: 'Planogram compliance',
      value: result.planogramCompliancePct,
      unit: 'pct',
      baseline: baselineUsable ? before!.planogramCompliancePct : null,
      baselineLabel: against,
    }),
    buildTile({
      metric: 'high_traffic_pass',
      label: 'High-traffic placement',
      value: result.highTrafficPassPct,
      unit: 'pct',
      baseline: baselineUsable ? before!.highTrafficPassPct : null,
      baselineLabel: against,
    }),
  ]);
}

/** Competition (`getCompetitorActivity`): presence tiles and facings ranking. */
export function competitorFigures(
  result: CompetitorActivity,
  windows: FigureWindows,
): FigureArtifact[] {
  if (!(result.observations > 0)) return [];
  const before = comparisonValues<CompetitorActivity>(result);
  const baselineUsable = finite(before?.observations) && before.observations > 0;
  const against = comparisonLabel(windows);

  const out = tiles([
    buildTile({
      metric: 'competitor_promoter_presence',
      label: 'Competitor promoters present',
      value: result.promoterPresencePct,
      unit: 'pct',
      baseline: baselineUsable ? before!.promoterPresencePct : null,
      baselineLabel: against,
    }),
    buildTile({
      metric: 'competitor_skus',
      label: 'Competitor SKUs seen',
      value: result.distinctCompetitorSkus,
      unit: 'count',
      baseline: baselineUsable ? before!.distinctCompetitorSkus : null,
      baselineLabel: against,
    }),
  ]);

  const ranking = rankedBars({
    metric: 'competitor_facings',
    title: 'Competitor facings by SKU',
    comparedTo: formatPeriodLabel(windows.current, windows.timeZone),
    unit: 'count',
    items: (result.topCompetitors ?? [])
      .filter((c) => c.facings > 0)
      .map((c) => ({ label: c.competitorSku, value: c.facings })),
  });

  return [...out, ...bars(ranking)];
}

/**
 * Execution (`getAgentScorecard`): the agent's score against the team's, and
 * their activity. The score tile is omitted when nothing was scored — an
 * average of no scorecards is `0`, not a terrible month.
 */
export function scorecardFigures(result: AgentPerformance, windows: FigureWindows): FigureArtifact[] {
  const period = formatPeriodLabel(windows.current, windows.timeZone);
  const out: StatTile[] = [];

  if (result.scoredVisits > 0) {
    out.push(
      buildTile({
        metric: 'execution_score',
        label: 'Execution score',
        value: result.averageScore,
        unit: 'pts',
        baseline: finite(result.teamAverageScore) ? result.teamAverageScore : null,
        ...(finite(result.teamAverageScore)
          ? { comparedTo: `vs team ${formatValue(result.teamAverageScore, 'pts')} · ${period}` }
          : {}),
      }),
    );
  }

  out.push(
    buildTile({ metric: 'visits', label: 'Visits', value: result.visits, unit: 'count' }),
    buildTile({
      metric: 'outlets_visited',
      label: 'Outlets visited',
      value: result.outletsVisited,
      unit: 'count',
    }),
  );

  return tiles(out);
}

/**
 * Territory ranking (`getTerritoryRanking`): diverging bars of signed
 * sell-in change, worst first, plus a headline tile for the territories'
 * combined sell-in — a sum the tool already computed, so no extra query.
 *
 * Territories with no comparison-window sell-in are already excluded by the
 * service; they never appear as a bar.
 */
export function territoryRankingFigures(
  result: TerritorySellInChange,
  windows: FigureWindows,
): FigureArtifact[] {
  const against = comparisonLabel(windows);
  const out: FigureArtifact[] = [];

  if (result.totalSellInUnits > 0 || result.comparisonTotalSellInUnits > 0) {
    out.push(
      ...tiles([
        buildTile({
          metric: 'sell_in_units',
          label: 'Sell-in, units',
          value: result.totalSellInUnits,
          unit: 'units',
          baseline: result.comparisonTotalSellInUnits,
          baselineLabel: against,
        }),
      ]),
    );
  }

  const ranking = rankedBars({
    metric: 'sell_in_change',
    title: 'Change by territory',
    comparedTo: against ? `vs ${against}` : formatPeriodLabel(windows.current, windows.timeZone),
    unit: 'pct',
    items: result.territories.map((t) => ({ label: t.territoryName, value: t.changePct })),
    limit: 12,
  });
  return [...out, ...bars(ranking)];
}

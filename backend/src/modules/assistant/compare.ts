import { z } from 'zod';
import { describePeriod, resolvePeriod, type DateRange, type Period } from './period';
import { localCalendarDate, startOfLocalDay } from '../../lib/clientTime';

/**
 * Comparison — the feature that kills the Excel overlay.
 *
 * The practitioner described the workflow this replaces exactly: *"filter… get
 * an output. Save the output… then you go back to something else and you try
 * and **overlay what you've saved there with what you have here**."* So a
 * comparison is not a second question the user asks after the first. It is one
 * answer with two series in it, resolved in a single turn — otherwise we have
 * rebuilt the dashboard they already have, with a chat box on top.
 *
 * **A comparison re-runs the same tool, not a different one.** Whatever scoping
 * and authorisation the tool already does happens twice, identically. There is
 * no second query path here that could read wider than the first.
 */

/**
 * What to measure against.
 *
 * Deliberately narrower than the plan's full list. The plan names
 * `{territory|agent|sku}: id` alongside the two period bases, but the pillar
 * services take a territory and *do not take* an agent or a SKU — offering
 * those here would declare a capability to the model that the tool cannot
 * honour, and the model would confidently promise it to the user. They belong
 * with the tools that actually scope by them.
 */
/**
 * A tagged object rather than a discriminated union, deliberately.
 *
 * The natural Zod shape here is `z.discriminatedUnion('kind', …)`, and it does
 * not survive the trip to Gemini: it serialises as `oneOf`, which
 * `geminiSchema.ts` refuses outright because Gemini has no equivalent and
 * mapping it across would silently relax exclusivity. So the *declaration* is a
 * flat object with an enum tag, which converts cleanly, and the exclusivity
 * rule that a union would have expressed is enforced by the refinement below.
 *
 * The declaration is therefore slightly looser than the validation — the model
 * could emit `{kind: 'previous_period', id: 't1'}` and be told no. That is the
 * right way round: a model correcting itself against a real error beats a
 * schema Gemini rejects at request time.
 */
export const compareToSchema = z
  .object({
    kind: z
      .enum(['previous_period', 'same_period_last_year', 'territory'])
      .describe(
        'previous_period = the equally long window just before this one. ' +
          'same_period_last_year = the same dates a year earlier, for seasonality. ' +
          'territory = another territory over the same period.',
      ),
    id: z
      .string()
      .min(1)
      .optional()
      .describe('Required when kind is "territory": the territory id to measure against.'),
  })
  .refine((value) => value.kind !== 'territory' || Boolean(value.id), {
    message: 'A territory comparison needs the id of the territory to compare against.',
    path: ['id'],
  })
  .describe(
    'Optional. Set this when the user asks to compare, or says "versus", "vs", ' +
      '"against last year", or "how does that compare". One turn answers both sides.',
  );

export type CompareTo = z.infer<typeof compareToSchema>;

/**
 * The same idea, minus the basis a time series cannot honour.
 *
 * `trends.service.ts` has no territory narrowing — `TrendFilters` is
 * `{clientId, interval, from, to}` and nothing else — so a trend tool that
 * declared `kind: 'territory'` would be promising a comparison it can only
 * answer by silently ignoring the territory and returning the whole business
 * twice. Same rule as the three list-shaped pillar tools: a declaration the
 * model can see is a capability the model will offer the user, so the narrower
 * schema is the honest one.
 */
export const periodCompareToSchema = z
  .object({
    kind: z
      .enum(['previous_period', 'same_period_last_year'])
      .describe(
        'previous_period = the equally long window just before this one. ' +
          'same_period_last_year = the same dates a year earlier, for seasonality.',
      ),
  })
  .describe(
    'Optional. Set this when the user asks to compare the trend — "versus last month", ' +
      '"against last year", "how does that compare" — and both lines come back in one turn.',
  );

export type PeriodCompareTo = z.infer<typeof periodCompareToSchema>;

/**
 * The window the comparison series is measured over.
 *
 * A scope comparison (territory) keeps the *same* window — comparing Gauteng
 * last month against Western Cape this month would answer a question nobody
 * asked, and the difference would silently mix place and time.
 */
export function comparisonWindow(
  period: Period,
  compareTo: CompareTo,
  now: Date,
  timeZone: string,
): DateRange {
  const current = resolvePeriod(period, now, timeZone);
  switch (compareTo.kind) {
    case 'previous_period': {
      // Same length, ending where this one starts — the definition the
      // dashboard's KPI tiles already use, so a figure in chat and the same
      // figure on the console cannot disagree.
      const span = current.to.getTime() - current.from.getTime();
      return { from: new Date(current.from.getTime() - span), to: current.from };
    }
    case 'same_period_last_year': {
      // Calendar-shifted, not 365 days back: "March vs March" must stay March
      // across a leap year, and the practitioner's vocabulary is months.
      return { from: shiftYear(current.from, timeZone), to: shiftYear(current.to, timeZone) };
    }
    case 'territory':
      return current;
  }
}

/**
 * The same local midnight one calendar year earlier. Shifted on the client's
 * calendar date, not the instant: the instant a Johannesburg day starts is
 * 22:00Z the evening before, and moving that UTC timestamp would mis-date
 * windows that touch 1 March or a DST change. 29 Feb rolls to 1 Mar, as before.
 */
function shiftYear(boundary: Date, timeZone: string): Date {
  const date = localCalendarDate(boundary, timeZone);
  const shifted = new Date(
    Date.UTC(date.getUTCFullYear() - 1, date.getUTCMonth(), date.getUTCDate()),
  );
  return startOfLocalDay(shifted, timeZone);
}

/** How the comparison series should be labelled, in the user's own vocabulary. */
export function describeComparison(period: Period, compareTo: CompareTo): string {
  switch (compareTo.kind) {
    case 'previous_period':
      return `the ${describePeriod(period)} before this one`;
    case 'same_period_last_year':
      return `${describePeriod(period)} last year`;
    case 'territory':
      return 'the other territory, same period';
  }
}

export interface Delta {
  absolute: number;
  /**
   * Percentage change, or `null` when the baseline is zero.
   *
   * "Up from nothing" has no percentage — reporting `Infinity`, `0`, or `100`
   * would each be a different lie, and a chart axis will happily plot any of
   * them. Null is the only honest answer, and the client renders it as "n/a".
   */
  pct: number | null;
}

/**
 * Deltas for every numeric field the two runs share.
 *
 * **Top-level scalars only, by design.** A tool's result also carries arrays —
 * worst outlets, trend points — and differencing those means matching rows
 * across two windows, where the same outlet may be absent from one side. That
 * is a per-tool judgement, not something this can do generically; the client
 * gets both series and draws them, which is what a comparison chart is.
 *
 * Non-finite values are skipped rather than propagated: `NaN` in a delta poisons
 * every axis it touches, and silently.
 */
export function numericDeltas(
  current: unknown,
  comparison: unknown,
): Record<string, Delta> | undefined {
  if (!isRecord(current) || !isRecord(comparison)) return undefined;

  const deltas: Record<string, Delta> = {};
  for (const [key, value] of Object.entries(current)) {
    const before = comparison[key];
    if (typeof value !== 'number' || typeof before !== 'number') continue;
    if (!Number.isFinite(value) || !Number.isFinite(before)) continue;
    deltas[key] = {
      absolute: round2(value - before),
      pct: before === 0 ? null : round2(((value - before) / Math.abs(before)) * 100),
    };
  }
  return Object.keys(deltas).length > 0 ? deltas : undefined;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

/** What a compared tool result carries alongside the current figures. */
export interface Comparison {
  /** Human label for the second series — chart legend, table column header. */
  label: string;
  basis: CompareTo;
  values: unknown;
  deltas?: Record<string, Delta>;
}

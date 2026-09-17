import { z } from 'zod';
import { describePeriod, resolvePeriod, type DateRange, type Period } from './period';
import {
  addCalendarDays,
  localCalendarDate,
  localClockMs,
  localInstantAt,
  startOfLocalDay,
} from '../../lib/clientTime';

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
        'previous_period = the same complete days one period earlier (month to date: the same days last month). ' +
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
        'previous_period = the same complete days one period earlier (month to date: the same days last month). ' +
          'same_period_last_year = the same dates a year earlier, for seasonality.',
      ),
  })
  .describe(
    'Optional. Set this when the user asks to compare the trend — "versus last month", ' +
      '"against last year", "how does that compare" — and both lines come back in one turn.',
  );

export type PeriodCompareTo = z.infer<typeof periodCompareToSchema>;

/**
 * The two windows a compared figure is measured over, resolved together.
 *
 * **Like for like (#365).** A comparison used to set the current window from
 * `resolvePeriod` and the comparison to "the equally long window just before
 * it". On 17 September that measured 1–17 Sep — today included, still at zero
 * while orders arrive — against 15–31 Aug, which carries the month-end ordering
 * spike, and reported sell-in down 12% when the like-for-like change was about
 * 1%. The rule now is **the same calendar days, complete days only**:
 *
 * - `mtd`: current is the 1st of this month up to the start of today; the
 *   comparison is the same days of the month before (or of the same month last
 *   year), so on the 17th both sides are days 1–16. When last month is shorter,
 *   the comparison stops at its end: on 31 March, 1–30 Mar meets all of February.
 * - `ytd`: 1 January up to the start of today, against the same calendar days of
 *   last year. For a year-to-date both bases are the same window.
 * - `today` is partial by nature, so it is compared with yesterday (or the same
 *   date last year) **up to the same local clock time**.
 * - `yesterday`, `previous_week` and `custom` are whole days already. The
 *   previous period stays the equally long run of days just before; last year
 *   stays the same dates a year earlier.
 * - A `territory` comparison keeps the uncompared window on both sides: nothing
 *   moves in time, so a partial today is shared by both and is like for like.
 *
 * **The 1st of the month, and 1 January.** There are no complete days in the
 * period yet. An empty window would come back as a confident −100% or n/a with
 * nothing to say why, so instead the whole previous month (or year) is compared
 * with the one before it — or the same month last year — and `note` says so,
 * for the model to pass on. The labels follow the windows, not the period name.
 *
 * Only a compared figure is trimmed. A plain month-to-date total with no
 * comparison still includes today (`resolvePeriod`), because "what have we sold
 * this month" should count this morning's orders; the moment two windows are set
 * side by side, both are complete days. Every compared tool reads both windows
 * from here, so the current series can never be measured over a different
 * window from the one its comparison was trimmed to.
 *
 * All arithmetic is on the client's calendar dates, converted to instants only
 * at the boundaries, exactly as `resolvePeriod` does.
 */
export interface ComparisonRanges {
  current: DateRange;
  comparison: DateRange;
  /** Human label for the comparison series. */
  label: string;
  /** Set when the windows are not what the period's name suggests. */
  note?: string;
}

export function comparisonRanges(
  period: Period,
  compareTo: CompareTo,
  now: Date,
  timeZone: string,
): ComparisonRanges {
  const label = describeComparison(period, compareTo);
  if (compareTo.kind === 'territory') {
    const current = resolvePeriod(period, now, timeZone);
    return { current, comparison: current, label };
  }

  const lastYear = compareTo.kind === 'same_period_last_year';
  const at = (date: Date) => startOfLocalDay(date, timeZone);
  const range = (from: Date, to: Date): DateRange => ({ from: at(from), to: at(to) });
  const today = localCalendarDate(now, timeZone);
  const year = today.getUTCFullYear();
  const month = today.getUTCMonth();
  const day = today.getUTCDate();
  const monthStart = (y: number, m: number) => new Date(Date.UTC(y, m, 1));

  switch (period.kind) {
    case 'today': {
      const other = lastYear ? shiftCalendarYear(today) : addCalendarDays(today, -1);
      return {
        current: { from: at(today), to: now },
        comparison: { from: at(other), to: localInstantAt(other, localClockMs(now, timeZone), timeZone) },
        label,
      };
    }

    case 'mtd': {
      if (day === 1) {
        const current = range(monthStart(year, month - 1), monthStart(year, month));
        const comparison = lastYear
          ? range(monthStart(year - 1, month - 1), monthStart(year - 1, month))
          : range(monthStart(year, month - 2), monthStart(year, month - 1));
        const shown = monthName(monthStart(year, month - 1));
        const against = monthName(localCalendarDate(comparison.from, timeZone));
        return {
          current,
          comparison,
          label: lastYear ? 'the same month last year' : 'the month before',
          note:
            `Today is the 1st, so this month has no complete days yet. These figures are ` +
            `for all of ${shown}, compared with all of ${against}.`,
        };
      }
      const current = range(monthStart(year, month), today);
      if (lastYear) {
        return {
          current,
          comparison: range(monthStart(year - 1, month), shiftCalendarYear(today)),
          label,
        };
      }
      // The same day-of-month last month, clamped to that month's end: day 31
      // of March meets the 1st of March, i.e. all of February and no more.
      const daysInLastMonth = new Date(Date.UTC(year, month, 0)).getUTCDate();
      const end = new Date(Date.UTC(year, month - 1, Math.min(day, daysInLastMonth + 1)));
      return { current, comparison: range(monthStart(year, month - 1), end), label };
    }

    case 'ytd': {
      if (month === 0 && day === 1) {
        return {
          current: range(monthStart(year - 1, 0), monthStart(year, 0)),
          comparison: range(monthStart(year - 2, 0), monthStart(year - 1, 0)),
          label: 'the year before',
          note:
            `Today is 1 January, so this year has no complete days yet. These figures are ` +
            `for all of ${year - 1}, compared with all of ${year - 2}.`,
        };
      }
      // "Month to date" logic does not fit a year: the previous period of a
      // year-to-date is the same calendar days of last year, whichever basis.
      return {
        current: range(monthStart(year, 0), today),
        comparison: range(monthStart(year - 1, 0), shiftCalendarYear(today)),
        label,
      };
    }

    case 'yesterday':
    case 'previous_week':
    case 'custom': {
      const current = resolvePeriod(period, now, timeZone);
      const first = localCalendarDate(current.from, timeZone);
      const end = localCalendarDate(current.to, timeZone);
      if (lastYear) {
        return { current, comparison: range(shiftCalendarYear(first), shiftCalendarYear(end)), label };
      }
      // Already whole days: the same number of days, ending where this starts.
      // Counted in calendar days so a DST change cannot shift a boundary.
      const days = Math.round((end.getTime() - first.getTime()) / DAY_MS);
      return { current, comparison: range(addCalendarDays(first, -days), first), label };
    }

    default: {
      const unreachable: never = period;
      throw new Error(`Unknown period: ${JSON.stringify(unreachable)}`);
    }
  }
}

const DAY_MS = 24 * 60 * 60 * 1000;

const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/** A calendar date's month and year: `August 2026`. */
function monthName(calendarDate: Date): string {
  return `${MONTH_NAMES[calendarDate.getUTCMonth()]} ${calendarDate.getUTCFullYear()}`;
}

/**
 * The same calendar date one year earlier. Shifted on the client's calendar
 * date, not the instant: the instant a Johannesburg day starts is 22:00Z the
 * evening before, and moving that UTC timestamp would mis-date windows that
 * touch 1 March or a DST change. 29 Feb rolls to 1 Mar, as before.
 */
function shiftCalendarYear(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear() - 1, date.getUTCMonth(), date.getUTCDate()));
}

/**
 * How the comparison series should be labelled, in the user's own vocabulary.
 * {@link comparisonRanges} carries the label actually used, which differs from
 * this only on the 1st of the month and 1 January.
 */
export function describeComparison(period: Period, compareTo: CompareTo): string {
  switch (compareTo.kind) {
    case 'previous_period':
      switch (period.kind) {
        case 'today':
          return 'yesterday, up to the same time';
        case 'yesterday':
          return 'the day before';
        case 'previous_week':
          return 'the week before';
        case 'mtd':
          return 'the same days last month';
        case 'ytd':
          return 'the same days last year';
        case 'custom':
          return 'the same number of days before';
      }
      break;
    case 'same_period_last_year':
      switch (period.kind) {
        case 'today':
          return 'the same day last year, up to the same time';
        case 'mtd':
        case 'ytd':
          return 'the same days last year';
        default:
          return `${describePeriod(period)} last year`;
      }
    case 'territory':
      return 'the other territory, same period';
  }
  return 'the period before';
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
  /** Why the windows differ from the period's name — see {@link comparisonRanges}. */
  note?: string;
}

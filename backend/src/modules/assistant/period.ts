import { z } from 'zod';
import {
  addCalendarDays,
  localCalendarDate,
  mondayOfCalendarWeek,
  startOfLocalDay,
} from '../../lib/clientTime';

/**
 * The period vocabulary, taken verbatim from what the practitioner filters by
 * daily — *"day-to-day, previous day, previous week, month-to-date and
 * year-to-date… and then a drop-down for a specific period"*.
 *
 * Not invented, and not a superset. Adding `last_7_days` because it seems
 * useful would put a period in the model's vocabulary that has no counterpart
 * in the UI the user already knows, and the two surfaces would disagree about
 * what "recently" means.
 *
 * Pure, and split from `viewspec.ts` because both the view specs and every
 * tool need it — a tool resolves a period into a date range before it can query
 * anything, and a view spec carries the unresolved period so the artifact can
 * be re-run later against a different one.
 */

export const PERIOD_KINDS = [
  'today',
  'yesterday',
  'previous_week',
  'mtd',
  'ytd',
  'custom',
] as const;

export type PeriodKind = (typeof PERIOD_KINDS)[number];

/** ISO calendar date, `YYYY-MM-DD`. Not a timestamp — a period is whole days. */
const isoDate = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'Expected an ISO date, YYYY-MM-DD')
  .refine((value) => !Number.isNaN(Date.parse(`${value}T00:00:00Z`)), 'Not a real calendar date');

/** The validated shape everything downstream works with. */
export type Period =
  | { kind: Exclude<PeriodKind, 'custom'> }
  | { kind: 'custom'; from: string; to: string };

/**
 * **Flat on the wire, a discriminated union out.**
 *
 * The obvious spelling is `z.discriminatedUnion('kind', [...])`, and it was
 * that until `tools.test.ts` caught what it produces: Zod emits a discriminated
 * union as JSON Schema `oneOf`, and **Gemini's `Schema` has no `oneOf`**. Every
 * tool takes a period, so that would have been a 400 on literally every turn —
 * and it would not have been found until a request went out, because nothing
 * about the Zod schema looks wrong.
 *
 * So the *input* is one flat object that Gemini can declare, and `transform`
 * narrows it back to the union afterwards. Nothing downstream changes: the
 * output type is still the union, and `z.toJSONSchema(..., { io: 'input' })` —
 * which is what the adapter declares — sees the flat form.
 *
 * Strictness is not traded away for this. `refine` still rejects a `custom`
 * period with no dates, and rejects dates supplied alongside a fixed period,
 * which is where a model most plausibly gets it wrong.
 */
export const periodSchema = z
  .object({
    kind: z
      .enum(PERIOD_KINDS)
      .describe('Use mtd when the user is vague ("lately", "recently") and say so in your answer.'),
    from: isoDate.optional().describe('Start date. Required when kind is custom, omit otherwise.'),
    to: isoDate.optional().describe('End date, inclusive. Required when kind is custom.'),
  })
  .refine((value) => value.kind !== 'custom' || (value.from !== undefined && value.to !== undefined), {
    message: 'A custom period needs both from and to.',
    path: ['from'],
  })
  .refine((value) => value.kind === 'custom' || (value.from === undefined && value.to === undefined), {
    // A model that sends `{kind: 'mtd', from: …}` has contradicted itself, and
    // silently ignoring the dates answers a different question from the one
    // asked — the worst way to be wrong here.
    message: 'from and to are only valid when kind is custom.',
    path: ['from'],
  })
  .transform((value): Period =>
    value.kind === 'custom'
      ? { kind: 'custom', from: value.from!, to: value.to! }
      : { kind: value.kind },
  )
  .describe('The reporting period.');

export interface DateRange {
  from: Date;
  to: Date;
}

/**
 * A period → a half-open date range `[from, to)`.
 *
 * **Half-open, deliberately.** An inclusive `to` has to be "the last instant of
 * the day", which invites `23:59:59` — and that silently drops every row
 * written in the final second. Every caller here compares `gte from` and
 * `lt to`, so a day boundary belongs to exactly one bucket.
 *
 * **The client's calendar (#309).** Days, weeks, months and years are counted
 * in the client's timezone — the same calendar the trends service buckets in
 * (`bucketStart` in `trends.service.ts`), so the assistant and the dashboard
 * agree about what "today" contains. The calendar dates are worked out first
 * (`localCalendarDate`, stepped in whole days), and only the boundaries are
 * converted to instants: "today" in Johannesburg on 6 Aug is
 * `[5 Aug 22:00Z, 6 Aug 22:00Z)`, because the rows it filters carry real
 * instants. Stepping instants by 24h instead would drift an hour across DST.
 *
 * `now` is a parameter rather than a call to `new Date()` so this function is
 * pure and its tests do not fail on a date nobody chose — the exact trap that
 * bit the fraud suite (#262).
 */
export function resolvePeriod(period: Period, now: Date, timeZone: string): DateRange {
  // Calendar date → the instant it begins in the client's zone.
  const at = (date: Date) => startOfLocalDay(date, timeZone);
  const today = localCalendarDate(now, timeZone);
  const tomorrow = addCalendarDays(today, 1);

  switch (period.kind) {
    case 'today':
      return { from: at(today), to: at(tomorrow) };

    case 'yesterday':
      return { from: at(addCalendarDays(today, -1)), to: at(today) };

    case 'previous_week': {
      // The previous *calendar* week, Monday to Monday — not "the last 7 days".
      // A manager asking about last week means the week that ended, and a
      // rolling window would include today's partial data in the comparison.
      const thisMonday = mondayOfCalendarWeek(today);
      return { from: at(addCalendarDays(thisMonday, -7)), to: at(thisMonday) };
    }

    case 'mtd':
      return {
        from: at(new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), 1))),
        to: at(tomorrow),
      };

    case 'ytd':
      return {
        from: at(new Date(Date.UTC(today.getUTCFullYear(), 0, 1))),
        to: at(tomorrow),
      };

    case 'custom': {
      const from = at(new Date(`${period.from}T00:00:00.000Z`));
      // The user's `to` is the last day they mean to include, so the half-open
      // upper bound is the day after. Using `to` directly excludes the whole
      // final day — an off-by-one that reads as "the data is missing".
      const to = at(addCalendarDays(new Date(`${period.to}T00:00:00.000Z`), 1));
      if (to <= from) {
        throw new InvalidPeriodError('The end of a custom period must not precede its start.');
      }
      return { from, to };
    }

    default: {
      const unreachable: never = period;
      throw new InvalidPeriodError(`Unknown period: ${JSON.stringify(unreachable)}`);
    }
  }
}

export class InvalidPeriodError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'InvalidPeriodError';
  }
}

/** How a period reads in an answer, so the model does not have to phrase it. */
export function describePeriod(period: Period): string {
  switch (period.kind) {
    case 'today':
      return 'today';
    case 'yesterday':
      return 'yesterday';
    case 'previous_week':
      return 'last week';
    case 'mtd':
      return 'month to date';
    case 'ytd':
      return 'year to date';
    case 'custom':
      return `${period.from} to ${period.to}`;
    default: {
      const unreachable: never = period;
      return String(unreachable);
    }
  }
}

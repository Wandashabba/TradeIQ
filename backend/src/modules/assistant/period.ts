import { z } from 'zod';

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

export const periodSchema = z
  .discriminatedUnion('kind', [
    z.object({ kind: z.literal('today') }),
    z.object({ kind: z.literal('yesterday') }),
    z.object({ kind: z.literal('previous_week') }),
    z.object({ kind: z.literal('mtd') }),
    z.object({ kind: z.literal('ytd') }),
    z.object({ kind: z.literal('custom'), from: isoDate, to: isoDate }),
  ])
  .describe(
    'The reporting period. Use mtd when the user is vague ("lately", "recently") and say so in your answer.',
  );

export type Period = z.infer<typeof periodSchema>;

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
 * **UTC throughout.** Rows are stored in UTC and the existing dashboard and
 * trends services bucket in UTC (`bucketStart` in `trends.service.ts`). Doing
 * anything else here would make the assistant disagree with the dashboard about
 * what "today" contains, which is a worse failure than being an hour off from
 * SAST — the user can reconcile a consistent number, not a contradictory one.
 *
 * `now` is a parameter rather than a call to `new Date()` so this function is
 * pure and its tests do not fail on a date nobody chose — the exact trap that
 * bit the fraud suite (#262).
 */
export function resolvePeriod(period: Period, now: Date): DateRange {
  const startOfDay = (d: Date) =>
    new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const addDays = (d: Date, days: number) => new Date(d.getTime() + days * 86_400_000);

  const today = startOfDay(now);

  switch (period.kind) {
    case 'today':
      return { from: today, to: addDays(today, 1) };

    case 'yesterday':
      return { from: addDays(today, -1), to: today };

    case 'previous_week': {
      // The previous *calendar* week, Monday to Monday — not "the last 7 days".
      // A manager asking about last week means the week that ended, and a
      // rolling window would include today's partial data in the comparison.
      const dayOfWeek = (today.getUTCDay() + 6) % 7; // Monday = 0
      const thisMonday = addDays(today, -dayOfWeek);
      return { from: addDays(thisMonday, -7), to: thisMonday };
    }

    case 'mtd':
      return {
        from: new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)),
        to: addDays(today, 1),
      };

    case 'ytd':
      return {
        from: new Date(Date.UTC(now.getUTCFullYear(), 0, 1)),
        to: addDays(today, 1),
      };

    case 'custom': {
      const from = new Date(`${period.from}T00:00:00.000Z`);
      // The user's `to` is the last day they mean to include, so the half-open
      // upper bound is the day after. Using `to` directly excludes the whole
      // final day — an off-by-one that reads as "the data is missing".
      const to = addDays(new Date(`${period.to}T00:00:00.000Z`), 1);
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

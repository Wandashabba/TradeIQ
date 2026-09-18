import { z } from 'zod';
import { addCalendarDays, localCalendarDate } from '../../../lib/clientTime';
import {
  CalendarContextError,
  getCalendarContext,
  PROVINCES,
} from '../../externalContext/calendar.service';
import { EconomicContextError, getEconomicContext } from '../../externalContext/economic.service';
import { isoDay, type Provenance } from '../../externalContext/provenance';
import type { RawWebSource } from '../providers/types';
import { getWeatherContext, WeatherContextError } from '../../externalContext/weather.service';
import { periodSchema, resolvePeriod, type Period } from '../period';
import { eraseToolTypes, ToolFacingError, type AnyAssistantTool } from '../types';
import { clientTimeZoneOf, type ToolContext } from './execution';

/**
 * Outside context: the calendar, the weather and the economy.
 *
 * These answer "is it us, or is it the month?" — the question a manager needs
 * settled before blaming a team for a dip. Nothing here is tenant data: the
 * calendar is static tables, the economy is public series read from Postgres
 * (fetched by a job, never on the turn), and weather is Open-Meteo at each
 * territory's outlet centroid, which is the only tenant-derived value that
 * leaves the process.
 *
 * Every result carries per-figure sources and a notice that the figures are
 * outside data, so the answer labels them and never merges them into the
 * client's totals. Gated like every other tool by the roster, and removed
 * entirely when the client has `assistantExternalContextEnabled` off.
 */

export async function periodDays(period: Period, now: Date, timeZone: string) {
  const range = resolvePeriod(period, now, timeZone);
  return {
    from: isoDay(localCalendarDate(range.from, timeZone)),
    // Half-open: the last included day is the one before `to`.
    to: isoDay(addCalendarDays(localCalendarDate(range.to, timeZone), -1)),
  };
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/**
 * Provenance → the shared sources shape, retrieval date included.
 *
 * `publisher` and `publishedAt` now travel as themselves (#406). They used to
 * be flattened on the way out — the publisher's name into the untrusted `title`
 * field, and the release date into English prose in `pageAge` ("Released 19 Aug
 * 2026") — so the app had to parse a sentence back into a date, and could not
 * tell a publisher we assigned from a title a page had given itself. The prose
 * stays in `pageAge` for clients that already read it; the machine-readable
 * fields sit beside it.
 */
export function provenanceSources(
  provenance: readonly Provenance[],
  origin: RawWebSource['origin'],
): RawWebSource[] {
  return provenance.map((p) => ({
    url: p.url,
    title: p.sourceName,
    origin,
    publisher: p.sourceName,
    publishedAt: p.publishedAt,
    pageAge: p.publishedAt
      ? `Released ${Number(p.publishedAt.slice(8, 10))} ${MONTHS[Number(p.publishedAt.slice(5, 7)) - 1]} ${p.publishedAt.slice(0, 4)}`
      : null,
    snippet: null,
    // When we fetched it, or when a person last verified a static table.
    retrievedAt: p.retrievedAt,
  }));
}

/** Every provenance an economic result carries, newest figure first per series. */
function economicProvenance(result: { series?: Array<{ inPeriod: Array<{ provenance: Provenance }>; latest: { provenance: Provenance } | null }> }) {
  return (result.series ?? []).flatMap((s) => [
    ...s.inPeriod.map((f) => f.provenance).reverse(),
    ...(s.latest ? [s.latest.provenance] : []),
  ]);
}

const facing = <T>(run: () => Promise<T>) =>
  run().catch((err) => {
    if (
      err instanceof CalendarContextError ||
      err instanceof WeatherContextError ||
      err instanceof EconomicContextError
    ) {
      throw new ToolFacingError(err.message);
    }
    throw err;
  });

export function buildContextTools(ctx: ToolContext): AnyAssistantTool[] {
  const { user, now } = ctx;
  const timeZone = clientTimeZoneOf(ctx);

  return [
    eraseToolTypes({
      name: 'getCalendarContext',
      pillar: 'context' as const,
      description:
        'Call this when explaining why sell-in, visits or availability changed and the DATES might ' +
        'be the reason: public holidays (including Sunday holidays moved to Monday), long weekends, ' +
        'school terms and school holidays, the month-end payday window, and SASSA grant payment ' +
        'dates — for the period and the same days last year. Also for direct questions like "was ' +
        'there a public holiday last week?" or "when are SASSA grants paid this month?". Returns ' +
        'calendar facts from official tables with sources, never business figures. Do not use it ' +
        'for the numbers themselves (use getRateOfSale, getTerritoryRanking or getMetricTrend), ' +
        'for weather (getWeatherContext) or for the economy (getEconomicContext).',
      args: z.object({
        period: periodSchema,
        province: z
          .enum(PROVINCES)
          .optional()
          .describe('Optional South African province, when school calendars could differ by region.'),
      }),
      run: async (args) =>
        facing(async () =>
          getCalendarContext({ ...(await periodDays(args.period, now, await timeZone())), province: args.province }),
        ),
      sources: (_args, result) =>
        provenanceSources((result as { sources?: Provenance[] }).sources ?? [], 'calendar'),
    }),

    eraseToolTypes({
      name: 'getWeatherContext',
      pillar: 'context' as const,
      description:
        'Call this when a change in sell-in, visits or stock might be down to the WEATHER: heavy ' +
        'rain, floods, heatwaves or a cold snap, or when the user asks whether it was wetter or ' +
        'hotter than usual in a territory. Returns daily-rainfall and maximum-temperature totals ' +
        'per territory (at the average location of its outlets) for the period and the same days ' +
        'last year, from Open-Meteo, with sources. Pass territoryId from findTerritories to narrow ' +
        'it; omit for the busiest territories. Never for the business figures themselves (use ' +
        'getRateOfSale or getStockLevels), public holidays (getCalendarContext) or prices and ' +
        'inflation (getEconomicContext).',
      args: z.object({
        period: periodSchema,
        territoryId: z
          .string()
          .min(1)
          .optional()
          .describe('Optional territory id, from findTerritories. Never a territory name.'),
      }),
      run: async (args) =>
        facing(async () => {
          const tz = await timeZone();
          return getWeatherContext({
            clientId: user.clientId,
            ...(await periodDays(args.period, now, tz)),
            timeZone: tz,
            territoryId: args.territoryId,
          });
        }),
      sources: (_args, result) =>
        provenanceSources((result as { sources?: Provenance[] }).sources ?? [], 'weather'),
    }),

    eraseToolTypes({
      name: 'getEconomicContext',
      pillar: 'context' as const,
      description:
        'Call this when a change might be down to the wider SOUTH AFRICAN ECONOMY rather than the ' +
        'team: whether retail sales across the country were up or down, consumer inflation (CPI) ' +
        'and food inflation, or fuel price increases squeezing shoppers. Returns official Stats SA ' +
        'retail trade sales and CPI (year-on-year) and the monthly fuel price adjustments for the ' +
        'period\'s months, each with its release date and source. Market-wide figures only — never ' +
        'the client\'s own sales (use getRateOfSale) or competitor prices (getCompetitorActivity), ' +
        'and not for forecasts or news, which this cannot answer (news is for web search).',
      args: z.object({ period: periodSchema }),
      run: async (args) =>
        facing(async () => getEconomicContext({ ...(await periodDays(args.period, now, await timeZone())), now })),
      sources: (_args, result) =>
        provenanceSources(
          economicProvenance(result as Parameters<typeof economicProvenance>[0]),
          'stats_sa',
        ),
    }),
  ] as AnyAssistantTool[];
}

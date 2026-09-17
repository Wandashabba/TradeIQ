import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { fetchDailyWeather, type DailyWeather, type OpenMeteoOptions } from './openMeteo';
import { OUTSIDE_DATA_NOTICE, sameDayLastYear, type Provenance } from './provenance';

/**
 * Weather over a period, per territory, against the same days last year.
 *
 * Territories carry no coordinates, so a territory's point is the **centroid
 * of its outlets** — the mean of their captured lat/lng. That is where the
 * trade actually happens, which is the point of asking. Outlets at (0, 0) are
 * placeholders, not places, and are left out.
 *
 * Rain and heat are summarised rather than listed: the question is "was it
 * wetter or hotter than usual", and 30 rows of daily values answer that worse
 * than two totals and a difference.
 */

/** Enough to cover a region; beyond this the answer is a list, not an explanation. */
export const MAX_TERRITORIES = 8;
/** A day with at least this much rain counts as a rainy day (the WMO convention). */
export const RAINY_DAY_MM = 1;
/** A year of daily points per territory is the most one question needs. */
export const MAX_PERIOD_DAYS = 366;

export interface WeatherSummary {
  daysWithData: number;
  totalRainMm: number | null;
  rainyDays: number | null;
  avgMaxTempC: number | null;
  hottestMaxTempC: number | null;
}

export interface TerritoryWeather {
  territoryId: string;
  territoryName: string;
  region: string | null;
  point: { lat: number; lng: number; outlets: number };
  available: boolean;
  unavailableReason?: string;
  current?: WeatherSummary;
  sameDaysLastYear?: WeatherSummary;
  difference?: {
    rainMm: number | null;
    rainyDays: number | null;
    avgMaxTempC: number | null;
  };
}

export interface WeatherContext {
  notice: string;
  period: { from: string; to: string };
  comparisonPeriod: { from: string; to: string };
  pointBasis: string;
  territories: TerritoryWeather[];
  /** Territories that exist but were not looked up, when there are more than {@link MAX_TERRITORIES}. */
  omittedTerritories: number;
  sources: Provenance[];
}

const round1 = (value: number) => Math.round(value * 10) / 10;

export function summarise(days: readonly DailyWeather[]): WeatherSummary {
  const rain = days.map((d) => d.rainMm).filter((v): v is number => v !== null);
  const heat = days.map((d) => d.maxTempC).filter((v): v is number => v !== null);
  return {
    daysWithData: Math.max(rain.length, heat.length),
    totalRainMm: rain.length ? round1(rain.reduce((a, b) => a + b, 0)) : null,
    rainyDays: rain.length ? rain.filter((v) => v >= RAINY_DAY_MM).length : null,
    avgMaxTempC: heat.length ? round1(heat.reduce((a, b) => a + b, 0) / heat.length) : null,
    hottestMaxTempC: heat.length ? round1(Math.max(...heat)) : null,
  };
}

const diff = (a: number | null, b: number | null) => (a === null || b === null ? null : round1(a - b));

interface TerritoryPoint {
  id: string;
  name: string;
  region: string | null;
  lat: number;
  lng: number;
  outlets: number;
}

/** Each territory's outlet centroid, busiest first. Tenant-scoped. */
async function territoryPoints(clientId: string, territoryId?: string): Promise<{ points: TerritoryPoint[]; total: number }> {
  // Outlet.territoryId holds the territory CODE (see pillars.service.ts).
  const rows = await prisma.$queryRaw<
    Array<{ id: string; name: string; region: string | null; lat: number; lng: number; outlets: bigint }>
  >`
    SELECT t."id", t."name", t."region",
           AVG(o."lat")::float8 AS "lat", AVG(o."lng")::float8 AS "lng", COUNT(*) AS "outlets"
    FROM "territories" t
    JOIN "outlets" o ON o."client_id" = t."client_id" AND o."territory_id" = t."code"
    WHERE t."client_id" = ${clientId}
      AND NOT (o."lat" = 0 AND o."lng" = 0)
      ${territoryId ? Prisma.sql`AND t."id" = ${territoryId}` : Prisma.empty}
    GROUP BY t."id", t."name", t."region"
    ORDER BY COUNT(*) DESC, t."name" ASC
  `;
  const points = rows.map((r) => ({ ...r, outlets: Number(r.outlets) }));
  return { points: points.slice(0, MAX_TERRITORIES), total: points.length };
}

export class WeatherContextError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'WeatherContextError';
  }
}

export async function getWeatherContext(
  input: {
    clientId: string;
    /** Inclusive local calendar days. */
    from: string;
    to: string;
    timeZone: string;
    territoryId?: string;
  },
  options: OpenMeteoOptions = {},
): Promise<WeatherContext> {
  const spanDays = (Date.parse(input.to) - Date.parse(input.from)) / 86_400_000 + 1;
  if (spanDays > MAX_PERIOD_DAYS) {
    throw new WeatherContextError('Weather context covers at most a year at a time. Ask for a shorter period.');
  }

  const { points, total } = await territoryPoints(input.clientId, input.territoryId);
  if (input.territoryId && points.length === 0) {
    throw new WeatherContextError(
      'That territory has no outlets with a location, so there is no point to look weather up for. ' +
        'Do not guess an id; use findTerritories.',
    );
  }

  const comparison = { from: sameDayLastYear(input.from), to: sameDayLastYear(input.to) };
  const sources = new Map<string, Provenance>();

  const territories = await Promise.all(
    points.map(async (point): Promise<TerritoryWeather> => {
      const base = {
        territoryId: point.id,
        territoryName: point.name,
        region: point.region,
        point: { lat: Math.round(point.lat * 100) / 100, lng: Math.round(point.lng * 100) / 100, outlets: point.outlets },
      };
      const at = { lat: point.lat, lng: point.lng, timeZone: input.timeZone };
      const [current, lastYear] = await Promise.all([
        fetchDailyWeather({ ...at, from: input.from, to: input.to }, options),
        fetchDailyWeather({ ...at, ...comparison }, options),
      ]);
      if (!current.ok || !lastYear.ok) {
        const reason = !current.ok ? current.reason : !lastYear.ok ? lastYear.reason : 'unknown';
        return { ...base, available: false, unavailableReason: `weather service ${reason.replace('_', ' ')}` };
      }
      for (const p of [...current.provenance, ...lastYear.provenance]) sources.set(p.sourceName, p);
      const now = summarise(current.days);
      const then = summarise(lastYear.days);
      return {
        ...base,
        available: true,
        current: now,
        sameDaysLastYear: then,
        difference: {
          rainMm: diff(now.totalRainMm, then.totalRainMm),
          rainyDays: now.rainyDays === null || then.rainyDays === null ? null : now.rainyDays - then.rainyDays,
          avgMaxTempC: diff(now.avgMaxTempC, then.avgMaxTempC),
        },
      };
    }),
  );

  return {
    notice: OUTSIDE_DATA_NOTICE,
    period: { from: input.from, to: input.to },
    comparisonPeriod: comparison,
    pointBasis:
      'Each territory is one point: the average location of its outlets. Weather varies within a ' +
      'territory, so treat this as the broad picture, and days still ahead as a forecast.',
    territories,
    omittedTerritories: Math.max(0, total - points.length),
    sources: [...sources.values()],
  };
}

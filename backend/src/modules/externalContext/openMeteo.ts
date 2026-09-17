import { isoDay, parseIsoDay, type Provenance } from './provenance';
import { TtlCache } from './ttlCache';

/**
 * Open-Meteo daily weather: free, no key, CC BY 4.0.
 *
 * Two endpoints, split by how old a day is:
 *
 * - **Historical** (`archive-api.open-meteo.com/v1/archive`) is reanalysis
 *   (ERA5 and friends). It lags real time by about five days, and a past day
 *   there does not change, so it is cached for a week.
 * - **Forecast** (`api.open-meteo.com/v1/forecast`) covers the recent past and
 *   the next 16 days from weather models. Those values are revised as models
 *   rerun, so they are cached for an hour.
 *
 * Every call has a hard timeout. A slow or failing weather API must cost the
 * answer its weather paragraph, never the turn: callers get a typed failure
 * they can describe, not an exception.
 */

export const OPEN_METEO_ARCHIVE_URL = 'https://archive-api.open-meteo.com/v1/archive';
export const OPEN_METEO_FORECAST_URL = 'https://api.open-meteo.com/v1/forecast';
export const OPEN_METEO_SOURCE = 'Open-Meteo (CC BY 4.0)';
export const OPEN_METEO_DOCS_URL = 'https://open-meteo.com/en/docs/historical-weather-api';

/** Days older than this come from the archive; newer ones from the forecast API. */
export const ARCHIVE_LAG_DAYS = 7;
/** The forecast API's reach into the future (it serves 16 days including today). */
const FORECAST_MAX_FUTURE_DAYS = 15;
export const DEFAULT_TIMEOUT_MS = 4_000;
export const ARCHIVE_TTL_MS = 7 * 24 * 60 * 60_000;
export const FORECAST_TTL_MS = 60 * 60_000;
export const FAILURE_TTL_MS = 5 * 60_000;

export interface DailyWeather {
  date: string;
  /** Millimetres; null when the source has no value for the day. */
  rainMm: number | null;
  maxTempC: number | null;
}

export type WeatherFetch =
  | { ok: true; days: DailyWeather[]; provenance: Provenance[] }
  | { ok: false; reason: 'timeout' | 'http_error' | 'bad_response' | 'network_error' };

export type FetchLike = (url: string, init: { signal: AbortSignal }) => Promise<{
  ok: boolean;
  status: number;
  json(): Promise<unknown>;
}>;

export interface OpenMeteoOptions {
  fetchImpl?: FetchLike;
  timeoutMs?: number;
  clock?: () => Date;
  cache?: TtlCache<WeatherFetch>;
}

const sharedCache = new TtlCache<WeatherFetch>(500);

/** For tests: forget everything the process has cached. */
export function clearWeatherCache(): void {
  sharedCache.clear();
}

type Endpoint = 'archive' | 'forecast';

export interface DailyWeatherRequest {
  lat: number;
  lng: number;
  /** Inclusive `YYYY-MM-DD` range. */
  from: string;
  to: string;
  timeZone: string;
}

/**
 * Daily rain and maximum temperature for a point over an inclusive day range,
 * stitched from the archive and forecast endpoints as needed.
 */
export async function fetchDailyWeather(
  request: DailyWeatherRequest,
  options: OpenMeteoOptions = {},
): Promise<WeatherFetch> {
  const now = (options.clock ?? (() => new Date()))();
  const cutoff = isoDay(new Date(now.getTime() - ARCHIVE_LAG_DAYS * 86_400_000));
  const lastForecast = isoDay(new Date(now.getTime() + FORECAST_MAX_FUTURE_DAYS * 86_400_000));
  const to = request.to < lastForecast ? request.to : lastForecast;

  const segments: Array<{ endpoint: Endpoint; from: string; to: string }> = [];
  if (request.from <= cutoff) {
    segments.push({ endpoint: 'archive', from: request.from, to: to < cutoff ? to : cutoff });
  }
  if (to > cutoff) {
    const from = request.from > cutoff ? request.from : isoDay(new Date(parseIsoDay(cutoff).getTime() + 86_400_000));
    if (from <= to) segments.push({ endpoint: 'forecast', from, to });
  }

  const days: DailyWeather[] = [];
  const provenance: Provenance[] = [];
  for (const segment of segments) {
    const part = await fetchSegment(request, segment, now, options);
    if (!part.ok) return part;
    days.push(...part.days);
    provenance.push(...part.provenance);
  }
  return { ok: true, days, provenance };
}

/** Coordinates rounded to ~1 km, which is finer than the models and makes nearby outlets share a cache entry. */
const round = (value: number) => Math.round(value * 100) / 100;

async function fetchSegment(
  request: DailyWeatherRequest,
  segment: { endpoint: Endpoint; from: string; to: string },
  now: Date,
  options: OpenMeteoOptions,
): Promise<WeatherFetch> {
  const cache = options.cache ?? sharedCache;
  const base = segment.endpoint === 'archive' ? OPEN_METEO_ARCHIVE_URL : OPEN_METEO_FORECAST_URL;
  const params = new URLSearchParams({
    latitude: String(round(request.lat)),
    longitude: String(round(request.lng)),
    start_date: segment.from,
    end_date: segment.to,
    daily: 'precipitation_sum,temperature_2m_max',
    timezone: request.timeZone,
  });
  const url = `${base}?${params.toString()}`;

  const cached = cache.get(url);
  if (cached) return cached;

  const fetchImpl = options.fetchImpl ?? (fetch as unknown as FetchLike);
  const timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  let result: WeatherFetch;
  try {
    const response = await fetchImpl(url, { signal: controller.signal });
    if (!response.ok) {
      result = { ok: false, reason: 'http_error' };
    } else {
      const days = parseDaily(await response.json());
      result = days
        ? {
            ok: true,
            days,
            provenance: [
              {
                sourceName:
                  segment.endpoint === 'archive'
                    ? `${OPEN_METEO_SOURCE}, historical weather (reanalysis)`
                    : `${OPEN_METEO_SOURCE}, weather forecast models`,
                url: segment.endpoint === 'archive' ? OPEN_METEO_DOCS_URL : 'https://open-meteo.com/en/docs',
                publishedAt: null,
                retrievedAt: now.toISOString(),
              },
            ],
          }
        : { ok: false, reason: 'bad_response' };
    }
  } catch {
    result = { ok: false, reason: controller.signal.aborted ? 'timeout' : 'network_error' };
  } finally {
    clearTimeout(timer);
  }

  // Failures are cached briefly too, so a down API is not hammered once per
  // territory per turn — but only briefly, so it recovers on its own.
  cache.set(
    url,
    result,
    !result.ok ? FAILURE_TTL_MS : segment.endpoint === 'archive' ? ARCHIVE_TTL_MS : FORECAST_TTL_MS,
  );
  return result;
}

/** The `daily` block of an Open-Meteo response, or null if it is not the shape we asked for. */
export function parseDaily(body: unknown): DailyWeather[] | null {
  if (typeof body !== 'object' || body === null) return null;
  const daily = (body as { daily?: unknown }).daily;
  if (typeof daily !== 'object' || daily === null) return null;
  const { time, precipitation_sum: rain, temperature_2m_max: temp } = daily as Record<string, unknown>;
  if (!Array.isArray(time) || !Array.isArray(rain) || !Array.isArray(temp)) return null;
  if (rain.length !== time.length || temp.length !== time.length) return null;

  const num = (value: unknown) => (typeof value === 'number' && Number.isFinite(value) ? value : null);
  const days: DailyWeather[] = [];
  for (let i = 0; i < time.length; i += 1) {
    const date = time[i];
    if (typeof date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(date)) return null;
    days.push({ date, rainMm: num(rain[i]), maxTempC: num(temp[i]) });
  }
  return days;
}

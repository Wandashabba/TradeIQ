import {
  ARCHIVE_TTL_MS,
  FAILURE_TTL_MS,
  FORECAST_TTL_MS,
  fetchDailyWeather,
  parseDaily,
  type FetchLike,
} from './openMeteo';
import { TtlCache } from './ttlCache';
import type { WeatherFetch } from './openMeteo';

const NOW = new Date('2026-09-17T10:00:00.000Z');
const clock = () => NOW;
const at = { lat: -26.2041, lng: 28.0473, timeZone: 'Africa/Johannesburg' };

function body(dates: string[], rain: Array<number | null>, temp: Array<number | null>) {
  return { daily: { time: dates, precipitation_sum: rain, temperature_2m_max: temp } };
}

/** A fetch that answers from a function of the URL and records every call. */
function fakeFetch(answer: (url: URL) => { status?: number; json: unknown }) {
  const calls: URL[] = [];
  const impl: FetchLike = async (url) => {
    const parsed = new URL(url);
    calls.push(parsed);
    const { status = 200, json } = answer(parsed);
    return { ok: status >= 200 && status < 300, status, json: async () => json };
  };
  return { impl, calls };
}

/** Echo the requested range back, 2mm and 25°C every day. */
function echo(url: URL) {
  const from = url.searchParams.get('start_date')!;
  const to = url.searchParams.get('end_date')!;
  const dates: string[] = [];
  for (let d = new Date(`${from}T00:00:00Z`); d.toISOString().slice(0, 10) <= to; d = new Date(d.getTime() + 86_400_000)) {
    dates.push(d.toISOString().slice(0, 10));
  }
  return { json: body(dates, dates.map(() => 2), dates.map(() => 25)) };
}

describe('Open-Meteo client', () => {
  it('uses only the archive for days older than the reanalysis lag', async () => {
    const { impl, calls } = fakeFetch(echo);
    const result = await fetchDailyWeather(
      { ...at, from: '2025-09-01', to: '2025-09-17' },
      { fetchImpl: impl, clock, cache: new TtlCache(10) },
    );
    expect(result.ok).toBe(true);
    expect(calls).toHaveLength(1);
    expect(calls[0].host).toBe('archive-api.open-meteo.com');
    expect(calls[0].searchParams.get('daily')).toBe('precipitation_sum,temperature_2m_max');
    expect(calls[0].searchParams.get('timezone')).toBe('Africa/Johannesburg');
    // Rounded to ~1 km, so neighbouring outlets share a cache entry.
    expect(calls[0].searchParams.get('latitude')).toBe('-26.2');
    if (result.ok) {
      expect(result.days).toHaveLength(17);
      expect(result.provenance[0].sourceName).toMatch(/Open-Meteo/);
      expect(result.provenance[0].retrievedAt).toBe(NOW.toISOString());
    }
  });

  it('stitches archive and forecast for a period running up to today', async () => {
    const { impl, calls } = fakeFetch(echo);
    const result = await fetchDailyWeather(
      { ...at, from: '2026-09-01', to: '2026-09-17' },
      { fetchImpl: impl, clock, cache: new TtlCache(10) },
    );
    expect(calls.map((c) => c.host)).toEqual(['archive-api.open-meteo.com', 'api.open-meteo.com']);
    expect(calls[0].searchParams.get('end_date')).toBe('2026-09-10');
    expect(calls[1].searchParams.get('start_date')).toBe('2026-09-11');
    expect(result.ok && result.days.map((d) => d.date)).toHaveLength(17);
  });

  it('clamps a future end to the forecast horizon', async () => {
    const { impl, calls } = fakeFetch(echo);
    await fetchDailyWeather(
      { ...at, from: '2026-09-15', to: '2026-12-31' },
      { fetchImpl: impl, clock, cache: new TtlCache(10) },
    );
    expect(calls).toHaveLength(1);
    expect(calls[0].searchParams.get('end_date')).toBe('2026-10-02');
  });

  it('serves a repeat request from the cache, with a long TTL for the archive', async () => {
    const { impl, calls } = fakeFetch(echo);
    let ms = 0;
    const cache = new TtlCache<WeatherFetch>(10, () => ms);
    const request = { ...at, from: '2025-09-01', to: '2025-09-30' };
    await fetchDailyWeather(request, { fetchImpl: impl, clock, cache });
    await fetchDailyWeather(request, { fetchImpl: impl, clock, cache });
    expect(calls).toHaveLength(1);

    ms = ARCHIVE_TTL_MS + 1;
    await fetchDailyWeather(request, { fetchImpl: impl, clock, cache });
    expect(calls).toHaveLength(2);
  });

  it('expires forecast answers after an hour', async () => {
    const { impl, calls } = fakeFetch(echo);
    let ms = 0;
    const cache = new TtlCache<WeatherFetch>(10, () => ms);
    const request = { ...at, from: '2026-09-15', to: '2026-09-20' };
    await fetchDailyWeather(request, { fetchImpl: impl, clock, cache });
    ms = FORECAST_TTL_MS - 1;
    await fetchDailyWeather(request, { fetchImpl: impl, clock, cache });
    expect(calls).toHaveLength(1);
    ms = FORECAST_TTL_MS + 1;
    await fetchDailyWeather(request, { fetchImpl: impl, clock, cache });
    expect(calls).toHaveLength(2);
  });

  it('times out instead of hanging the turn', async () => {
    const hanging: FetchLike = (_url, init) =>
      new Promise((_resolve, reject) => {
        init.signal.addEventListener('abort', () => reject(new Error('aborted')));
      });
    const result = await fetchDailyWeather(
      { ...at, from: '2025-09-01', to: '2025-09-02' },
      { fetchImpl: hanging, clock, timeoutMs: 20, cache: new TtlCache(10) },
    );
    expect(result).toEqual({ ok: false, reason: 'timeout' });
  });

  it('reports an HTTP error, and caches the failure only briefly', async () => {
    const { impl, calls } = fakeFetch(() => ({ status: 503, json: {} }));
    let ms = 0;
    const cache = new TtlCache<WeatherFetch>(10, () => ms);
    const request = { ...at, from: '2025-09-01', to: '2025-09-02' };
    expect(await fetchDailyWeather(request, { fetchImpl: impl, clock, cache })).toEqual({
      ok: false,
      reason: 'http_error',
    });
    await fetchDailyWeather(request, { fetchImpl: impl, clock, cache });
    expect(calls).toHaveLength(1);
    ms = FAILURE_TTL_MS + 1;
    await fetchDailyWeather(request, { fetchImpl: impl, clock, cache });
    expect(calls).toHaveLength(2);
  });

  it('reports a network error', async () => {
    const failing: FetchLike = async () => {
      throw new Error('ECONNRESET');
    };
    expect(
      await fetchDailyWeather(
        { ...at, from: '2025-09-01', to: '2025-09-02' },
        { fetchImpl: failing, clock, cache: new TtlCache(10) },
      ),
    ).toEqual({ ok: false, reason: 'network_error' });
  });

  it('rejects a body that is not the shape it asked for', async () => {
    const { impl } = fakeFetch(() => ({ json: { error: true, reason: 'bad' } }));
    expect(
      await fetchDailyWeather(
        { ...at, from: '2025-09-01', to: '2025-09-02' },
        { fetchImpl: impl, clock, cache: new TtlCache(10) },
      ),
    ).toEqual({ ok: false, reason: 'bad_response' });
  });
});

describe('parseDaily', () => {
  it('keeps nulls as missing values rather than zeros', () => {
    expect(parseDaily(body(['2026-01-01', '2026-01-02'], [null, 3.2], [30.1, null]))).toEqual([
      { date: '2026-01-01', rainMm: null, maxTempC: 30.1 },
      { date: '2026-01-02', rainMm: 3.2, maxTempC: null },
    ]);
  });

  it('rejects mismatched arrays and malformed dates', () => {
    expect(parseDaily(body(['2026-01-01'], [1, 2], [3]))).toBeNull();
    expect(parseDaily(body(['01/01/2026'], [1], [3]))).toBeNull();
    expect(parseDaily(null)).toBeNull();
    expect(parseDaily({ daily: null })).toBeNull();
  });
});

describe('TtlCache', () => {
  it('evicts the oldest entry past its size bound', () => {
    const cache = new TtlCache<number>(2, () => 0);
    cache.set('a', 1, 1000);
    cache.set('b', 2, 1000);
    cache.set('c', 3, 1000);
    expect(cache.get('a')).toBeUndefined();
    expect(cache.get('c')).toBe(3);
    expect(cache.size).toBe(2);
  });
});

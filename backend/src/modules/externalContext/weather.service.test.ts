import { prisma } from '../../lib/prisma';
import type { FetchLike, WeatherFetch } from './openMeteo';
import { TtlCache } from './ttlCache';
import { getWeatherContext, summarise, WeatherContextError } from './weather.service';
import { sameDayLastYear } from './provenance';

/**
 * Real territory and outlet rows (the centroid is a query worth running for
 * real: territory codes, (0,0) placeholders, another tenant's outlets), and a
 * fake weather API.
 */
describe('getWeatherContext', () => {
  const NOW = new Date('2026-09-17T10:00:00.000Z');
  const clock = () => NOW;
  let clientId: string;
  let otherClientId: string;
  let gautengId: string;
  let capeId: string;
  let emptyId: string;

  const days = (from: string, to: string) => {
    const out: string[] = [];
    for (let d = new Date(`${from}T00:00:00Z`); d.toISOString().slice(0, 10) <= to; d = new Date(d.getTime() + 86_400_000)) {
      out.push(d.toISOString().slice(0, 10));
    }
    return out;
  };

  /** 2026 is wet (5mm a day) and hot (30°C) everywhere; 2025 dry and mild. */
  const calls: URL[] = [];
  const fakeFetch: FetchLike = async (url) => {
    const u = new URL(url);
    calls.push(u);
    const dates = days(u.searchParams.get('start_date')!, u.searchParams.get('end_date')!);
    const wet = dates[0].startsWith('2026');
    return {
      ok: true,
      status: 200,
      json: async () => ({
        daily: {
          time: dates,
          precipitation_sum: dates.map(() => (wet ? 5 : 0.5)),
          temperature_2m_max: dates.map(() => (wet ? 30 : 24)),
        },
      }),
    };
  };
  const options = () => ({ fetchImpl: fakeFetch, clock, cache: new TtlCache<WeatherFetch>(100) });

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'WX-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    const other = await prisma.client.create({
      data: { name: 'WX-Other', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = other.id;

    const territory = (cid: string, name: string, code: string, region: string) =>
      prisma.territory.create({ data: { clientId: cid, name, code, region } });
    gautengId = (await territory(clientId, 'Joburg North', 'WX-GP', 'Gauteng')).id;
    capeId = (await territory(clientId, 'Cape Town', 'WX-WC', 'Western Cape')).id;
    emptyId = (await territory(clientId, 'Nowhere', 'WX-NONE', 'Limpopo')).id;
    await territory(otherClientId, 'Other Joburg', 'WX-GP', 'Gauteng');

    const outlet = (cid: string, code: string, territoryCode: string, lat: number, lng: number) =>
      prisma.outlet.create({
        data: { clientId: cid, name: code, code, channelType: 'spaza', lat, lng, territoryId: territoryCode },
      });
    await outlet(clientId, 'WX-1', 'WX-GP', -26.0, 28.0);
    await outlet(clientId, 'WX-2', 'WX-GP', -26.2, 28.2);
    // A placeholder location must not drag the centroid to the Gulf of Guinea.
    await outlet(clientId, 'WX-3', 'WX-GP', 0, 0);
    await outlet(clientId, 'WX-4', 'WX-WC', -33.9, 18.4);
    // Another tenant's outlet under the same territory code.
    await outlet(otherClientId, 'WX-5', 'WX-GP', 10, 10);
    await outlet(clientId, 'WX-6', 'WX-NONE', 0, 0);
  });

  beforeEach(() => {
    calls.length = 0;
  });

  it('summarises each territory at its outlet centroid against the same days last year', async () => {
    const ctx = await getWeatherContext(
      { clientId, from: '2026-08-01', to: '2026-08-31', timeZone: 'Africa/Johannesburg' },
      options(),
    );
    expect(ctx.territories.map((t) => t.territoryName)).toEqual(['Joburg North', 'Cape Town']);
    const gp = ctx.territories[0];
    expect(gp.point).toEqual({ lat: -26.1, lng: 28.1, outlets: 2 });
    expect(gp.available).toBe(true);
    expect(gp.current).toEqual({
      daysWithData: 31,
      totalRainMm: 155,
      rainyDays: 31,
      avgMaxTempC: 30,
      hottestMaxTempC: 30,
    });
    expect(gp.sameDaysLastYear?.totalRainMm).toBe(15.5);
    expect(gp.difference).toEqual({ rainMm: 139.5, rainyDays: 31, avgMaxTempC: 6 });
    expect(ctx.comparisonPeriod).toEqual({ from: '2025-08-01', to: '2025-08-31' });
    expect(ctx.notice).toMatch(/not TradeIQ data/);
    expect(ctx.sources.length).toBeGreaterThan(0);
    for (const source of ctx.sources) {
      expect(source.url).toMatch(/^https:\/\/open-meteo\.com/);
      expect(source.retrievedAt).toBe(NOW.toISOString());
    }
    // No other tenant's coordinates reach the weather API.
    expect(calls.every((u) => u.searchParams.get('latitude') !== '10')).toBe(true);
  });

  it('narrows to one territory', async () => {
    const ctx = await getWeatherContext(
      { clientId, from: '2026-08-01', to: '2026-08-07', timeZone: 'Africa/Johannesburg', territoryId: capeId },
      options(),
    );
    expect(ctx.territories.map((t) => t.territoryId)).toEqual([capeId]);
    expect(ctx.omittedTerritories).toBe(0);
  });

  it('refuses a territory with no located outlets, and another tenant\'s territory', async () => {
    const input = { clientId, from: '2026-08-01', to: '2026-08-07', timeZone: 'Africa/Johannesburg' };
    await expect(getWeatherContext({ ...input, territoryId: emptyId }, options())).rejects.toThrow(
      WeatherContextError,
    );
    const foreign = await prisma.territory.findFirst({ where: { clientId: otherClientId } });
    await expect(getWeatherContext({ ...input, territoryId: foreign!.id }, options())).rejects.toThrow(
      WeatherContextError,
    );
    expect(gautengId).toBeTruthy();
  });

  it('degrades per territory when the weather API fails, instead of failing the turn', async () => {
    const failing: FetchLike = async () => ({ ok: false, status: 502, json: async () => ({}) });
    const ctx = await getWeatherContext(
      { clientId, from: '2026-08-01', to: '2026-08-07', timeZone: 'Africa/Johannesburg' },
      { fetchImpl: failing, clock, cache: new TtlCache<WeatherFetch>(100) },
    );
    expect(ctx.territories.every((t) => !t.available)).toBe(true);
    expect(ctx.territories[0].unavailableReason).toBe('weather service http error');
    expect(ctx.sources).toEqual([]);
  });

  it('refuses a period longer than a year', async () => {
    await expect(
      getWeatherContext({ clientId, from: '2024-01-01', to: '2026-01-01', timeZone: 'Africa/Johannesburg' }, options()),
    ).rejects.toThrow(WeatherContextError);
  });
});

describe('weather summaries', () => {
  it('ignores missing days rather than counting them as dry', () => {
    expect(
      summarise([
        { date: '2026-01-01', rainMm: null, maxTempC: null },
        { date: '2026-01-02', rainMm: 0.4, maxTempC: 28.44 },
        { date: '2026-01-03', rainMm: 12, maxTempC: 31 },
      ]),
    ).toEqual({ daysWithData: 2, totalRainMm: 12.4, rainyDays: 1, avgMaxTempC: 29.7, hottestMaxTempC: 31 });
    expect(summarise([])).toEqual({
      daysWithData: 0,
      totalRainMm: null,
      rainyDays: null,
      avgMaxTempC: null,
      hottestMaxTempC: null,
    });
  });

  it('maps 29 February to 28 February a year earlier', () => {
    expect(sameDayLastYear('2028-02-29')).toBe('2027-02-28');
    expect(sameDayLastYear('2026-09-17')).toBe('2025-09-17');
  });
});

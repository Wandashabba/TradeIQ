import { readFileSync } from 'fs';
import { join } from 'path';
import { prisma } from '../../lib/prisma';
import { FUEL_PRICE_ADJUSTMENTS } from './data/fuelPriceAdjustments';
import {
  fuelObservations,
  refreshEconomicData,
  releasePdfUrl,
  STATSSA_CPI_URL,
  STATSSA_RETAIL_URL,
  type Downloader,
} from './economic.refresh';
import { EconomicContextError, getEconomicContext } from './economic.service';
import { isRefreshDue, REFRESH_EVERY_MS, startEconomicRefreshWorker } from './economic.worker';

/**
 * Ingestion and reading, against saved Stats SA files and a real database.
 * No network: the downloader is a map of URL → fixture.
 *
 * The expected rates are the ones Stats SA published for July 2026 (retail
 * P6242.1 released 16 Sep 2026; CPI P0141 released 19 Aug 2026), so a parser
 * change that drifts from the official figures fails here.
 */
const fixture = (name: string) => readFileSync(join(__dirname, '__fixtures__', name));
const NOW = new Date('2026-09-17T08:00:00.000Z');
const RETAIL_RELEASED = new Date('2026-09-16T11:00:13.000Z');
const CPI_RELEASED = new Date('2026-08-19T08:00:41.000Z');

function downloaderFor(files: Record<string, { name: string; lastModified: Date }>, requested: string[] = []): Downloader {
  return async (url) => {
    requested.push(url);
    const file = files[url];
    return file ? { status: 'ok', body: fixture(file.name), lastModified: file.lastModified } : { status: 'not_found' };
  };
}

const releaseFiles = {
  [STATSSA_RETAIL_URL('2026-07')]: { name: 'P62421_retail_ascii_202607.zip', lastModified: RETAIL_RELEASED },
  [STATSSA_CPI_URL('2026-07')]: { name: 'P0141_CPI_ascii_202607_subset.zip', lastModified: CPI_RELEASED },
};

async function reset() {
  await prisma.economicObservation.deleteMany();
  await prisma.economicSourceRefresh.deleteMany();
}

describe('refreshEconomicData', () => {
  beforeEach(reset);

  it('steps back to the newest hosted release and stores official year-on-year rates with provenance', async () => {
    const requested: string[] = [];
    const results = await refreshEconomicData({ now: NOW, download: downloaderFor(releaseFiles, requested) });

    expect(results.map((r) => [r.source, r.ok])).toEqual([
      ['statssa_retail', true],
      ['statssa_cpi', true],
      ['fuel_prices', true],
    ]);
    // August's file is not up yet (404), so July's is used.
    expect(requested[0]).toBe(STATSSA_RETAIL_URL('2026-08'));
    expect(requested[1]).toBe(STATSSA_RETAIL_URL('2026-07'));

    const get = (series: string, period: string) =>
      prisma.economicObservation.findUnique({ where: { series_period: { series, period } } });

    const retail = await get('retail_trade_yoy', '2026-07');
    expect(retail).toMatchObject({
      value: 3.4,
      unit: 'pct',
      sourceUrl: 'https://www.statssa.gov.za/publications/P62421/P62421July2026.pdf',
      retrievedAt: NOW,
    });
    expect(retail!.releasedAt!.toISOString().slice(0, 10)).toBe('2026-09-16');
    // Revised figures, as the July 2026 release's Table 2 shows them.
    expect((await get('retail_trade_yoy', '2026-06'))!.value).toBe(1.1);
    expect((await get('retail_trade_yoy', '2025-08'))!.value).toBe(2.2);
    expect((await get('retail_trade_yoy_general_dealers', '2026-07'))!.value).toBe(3.2);
    expect((await get('retail_trade_yoy_hardware_paint_glass', '2026-07'))!.value).toBe(-1.1);

    // Headline CPI is all urban areas (4.3%), not total country (4.1%).
    expect((await get('cpi_headline_yoy', '2026-07'))!.value).toBe(4.3);
    expect((await get('cpi_headline_yoy', '2026-05'))!.value).toBe(4.5);
    expect((await get('cpi_food_yoy', '2026-07'))!.value).toBe(0.9);
    expect((await get('cpi_food_yoy', '2025-09'))!.value).toBe(4.5);

    expect((await get('fuel_petrol95_inland_change', '2026-09'))!.value).toBe(129);
    expect((await get('fuel_petrol95_inland_price', '2026-08'))!.value).toBe(25.58);
    // Sources disagree on May 2026 diesel, so it is not stored at all.
    expect(await get('fuel_diesel_0005_change', '2026-05')).toBeNull();

    const refresh = await prisma.economicSourceRefresh.findMany({ orderBy: { source: 'asc' } });
    expect(refresh.map((r) => [r.source, r.lastSuccessAt?.getTime(), r.lastError])).toEqual([
      ['fuel_prices', NOW.getTime(), null],
      ['statssa_cpi', NOW.getTime(), null],
      ['statssa_retail', NOW.getTime(), null],
    ]);
  });

  it('keeps going when one source fails, and records why without a response body', async () => {
    const broken: Downloader = async (url) =>
      url.includes('P6242.1')
        ? { status: 'ok', body: Buffer.from('<html>Incapsula incident</html>'), lastModified: null }
        : downloaderFor(releaseFiles)(url);
    const results = await refreshEconomicData({ now: NOW, download: broken });
    expect(results.find((r) => r.source === 'statssa_retail')).toMatchObject({ ok: false, written: 0 });
    expect(results.find((r) => r.source === 'statssa_cpi')?.ok).toBe(true);

    const row = await prisma.economicSourceRefresh.findUnique({ where: { source: 'statssa_retail' } });
    expect(row?.lastSuccessAt).toBeNull();
    expect(row?.lastError).toBe('Not a zip archive.');
  });

  it('reports a network failure and a release that cannot be found', async () => {
    const offline: Downloader = async () => ({ status: 'error', reason: 'timeout' });
    const [result] = await refreshEconomicData({ now: NOW, download: offline, sources: ['statssa_cpi'] });
    expect(result).toMatchObject({ ok: false, detail: 'download failed (timeout)' });

    const [missing] = await refreshEconomicData({
      now: NOW,
      download: downloaderFor({}),
      sources: ['statssa_retail'],
    });
    expect(missing.detail).toMatch(/no release file/);
  });

  it('overwrites a revised figure on the next refresh', async () => {
    await prisma.economicObservation.create({
      data: {
        series: 'retail_trade_yoy',
        period: '2026-06',
        value: 1.6,
        unit: 'pct',
        sourceName: 'first estimate',
        sourceUrl: releasePdfUrl('P62421', '2026-06'),
        retrievedAt: new Date('2026-08-20T00:00:00Z'),
      },
    });
    await refreshEconomicData({ now: NOW, download: downloaderFor(releaseFiles), sources: ['statssa_retail'] });
    const row = await prisma.economicObservation.findUnique({
      where: { series_period: { series: 'retail_trade_yoy', period: '2026-06' } },
    });
    expect(row).toMatchObject({ value: 1.1, sourceUrl: releasePdfUrl('P62421', '2026-07') });
  });
});

describe('the fuel price table', () => {
  it('writes every month it has, with the statement as the source', () => {
    const observations = fuelObservations();
    const months = new Set(observations.map((o) => o.period));
    expect(months.size).toBe(FUEL_PRICE_ADJUSTMENTS.entries.length);
    for (const o of observations) expect(o.sourceUrl).toMatch(/^https:\/\//);
  });
});

describe('getEconomicContext', () => {
  beforeAll(async () => {
    await reset();
    await refreshEconomicData({ now: NOW, download: downloaderFor(releaseFiles) });
  });

  it('gives the period\'s figures with provenance, and says which months are not published yet', async () => {
    const ctx = await getEconomicContext({ from: '2026-07-01', to: '2026-09-17', now: NOW });
    const headline = ctx.series.find((s) => s.series === 'cpi_headline_yoy')!;
    expect(headline.inPeriod).toEqual([
      {
        period: '2026-07',
        value: 4.3,
        provenance: {
          sourceName: 'Stats SA, Consumer Price Index (P0141), time series',
          url: 'https://www.statssa.gov.za/publications/P0141/P0141July2026.pdf',
          publishedAt: '2026-08-19',
          retrievedAt: NOW.toISOString(),
        },
      },
    ]);
    expect(headline.notYetPublished).toEqual(['2026-08', '2026-09']);
    expect(headline.latest).toBeNull();

    const petrol = ctx.series.find((s) => s.series === 'fuel_petrol95_inland_change')!;
    expect(petrol.inPeriod.map((f) => [f.period, f.value])).toEqual([
      ['2026-07', -196],
      ['2026-08', -52],
      ['2026-09', 129],
    ]);
    expect(ctx.notice).toMatch(/never add them into the client's own totals/);
    expect(ctx.refresh.every((r) => !r.stale)).toBe(true);
  });

  it('offers the latest figure when the period has none yet', async () => {
    const ctx = await getEconomicContext({ from: '2026-09-01', to: '2026-09-17', now: NOW });
    const retail = ctx.series.find((s) => s.series === 'retail_trade_yoy')!;
    expect(retail.inPeriod).toEqual([]);
    expect(retail.latest).toMatchObject({ period: '2026-07', value: 3.4 });
  });

  it('flags sources that have not refreshed for weeks', async () => {
    const later = new Date('2026-12-01T00:00:00.000Z');
    const ctx = await getEconomicContext({ from: '2026-11-01', to: '2026-11-30', now: later });
    expect(ctx.refresh.every((r) => r.stale)).toBe(true);
  });

  it('refuses more than two years of months', async () => {
    await expect(getEconomicContext({ from: '2023-01-01', to: '2026-01-31', now: NOW })).rejects.toThrow(
      EconomicContextError,
    );
  });
});

describe('the economic refresh worker', () => {
  it('is due with no attempt on record, or a day after the last', () => {
    expect(isRefreshDue(NOW, null)).toBe(true);
    expect(isRefreshDue(NOW, new Date(NOW.getTime() - REFRESH_EVERY_MS + 1))).toBe(false);
    expect(isRefreshDue(NOW, new Date(NOW.getTime() - REFRESH_EVERY_MS))).toBe(true);
  });

  it('refreshes once when due and skips when a recent attempt is recorded', async () => {
    await reset();
    const refresh = jest.fn(async () => {
      await prisma.economicSourceRefresh.create({ data: { source: 'fuel_prices', lastAttemptAt: NOW } });
      return [];
    });
    const runFor = async (ms: number) => {
      jest.useFakeTimers({ doNotFake: ['nextTick', 'setImmediate'] });
      const worker = startEconomicRefreshWorker({ intervalMs: 1_000, now: () => NOW, refresh });
      try {
        // Each tick awaits a real database query, so time is advanced in steps.
        for (let t = 0; t < ms; t += 1_000) {
          await jest.advanceTimersByTimeAsync(1_000);
          await new Promise((resolve) => setImmediate(resolve));
        }
        await worker.stop();
      } finally {
        jest.useRealTimers();
      }
    };

    await runFor(12_000);
    expect(refresh).toHaveBeenCalledTimes(1);

    // A second instance (or a restart) sees the recorded attempt and does nothing.
    await runFor(12_000);
    expect(refresh).toHaveBeenCalledTimes(1);
  });
});

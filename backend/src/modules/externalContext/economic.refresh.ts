import { prisma } from '../../lib/prisma';
import { FUEL_PRICE_ADJUSTMENTS } from './data/fuelPriceAdjustments';
import { SERIES_BY_KEY, SOURCE_LABELS, type EconomicSource } from './economic.series';
import { parseStatsSaAscii, yearOnYear, type StatsSaSeries } from './statssaAscii';
import { readZip } from './zip';

/**
 * Keeps `economic_observations` current. Run by the daily worker and by
 * `npm run refresh-economic-context`; never on a user's turn.
 *
 * ## Stats SA (retail trade P6242.1, CPI P0141)
 *
 * The time-series data files' URLs follow a fixed pattern with the reference
 * month in the name. Only the newest month's file is hosted — last month's returns 404 once
 * the next release is up — so the job tries the most recent plausible month and
 * steps back. It downloads the ASCII zip, parses it, and derives year-on-year
 * rates from the published levels/indices (the files carry no percentages).
 * Those rates match the release tables to the published decimal.
 *
 * Every refresh rewrites the last {@link YEARS_KEPT} years of each series,
 * because Stats SA revises earlier months in later releases (retail especially).
 *
 * `releasedAt` is the file's HTTP `Last-Modified` date, which is the release
 * day; the cited URL is that release's PDF, which a person can open.
 *
 * **Bot protection.** Stats SA's Imperva filter can answer the data files with
 * a JavaScript challenge page instead of the zip (it does from some networks).
 * That is reported as blocked and not worked around: a person downloads the
 * file in a browser and imports it with
 * `npm run refresh-economic-context -- --file <downloaded zip>`, which goes
 * through the same parsing and checks. A manual import has no `Last-Modified`,
 * so its release date is left unknown rather than guessed.
 *
 * ## Fuel prices
 *
 * No feed exists; the manual table `data/fuelPriceAdjustments.ts` is copied in.
 */

export const STATSSA_RETAIL_URL = (month: string) =>
  'https://www.statssa.gov.za/timeseriesdata/Ascii/P6242.1%20Retail%20trade%20sales%20' +
  `(New%20time%20series)%20from%20January%202002_${month.replace('-', '')}.zip`;
export const STATSSA_CPI_URL = (month: string) =>
  'https://www.statssa.gov.za/timeseriesdata/Ascii/P0141%20-%20CPI(COICOP)%20from%20Jan%202008%20' +
  `(${month.replace('-', '')}).zip`;

const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
/** The human-readable release, by the month it reports on. */
export const releasePdfUrl = (publication: 'P62421' | 'P0141', month: string) =>
  `https://www.statssa.gov.za/publications/${publication}/${publication}` +
  `${MONTH_NAMES[Number(month.slice(5, 7)) - 1]}${month.slice(0, 4)}.pdf`;

/** How many years of each series a refresh (re)writes. */
export const YEARS_KEPT = 3;
/** Downloads larger than this are refused; the real files are ~25 KB and ~250 KB. */
export const MAX_DOWNLOAD_BYTES = 5 * 1024 * 1024;
export const DOWNLOAD_TIMEOUT_MS = 30_000;

/** Stats SA series code → our series key. Retail at constant prices, unadjusted; CPI for all urban areas. */
export const RETAIL_CODES: Readonly<Record<string, string>> = {
  con_act: 'retail_trade_yoy',
  con_S621C: 'retail_trade_yoy_general_dealers',
  con_S6220: 'retail_trade_yoy_food_beverages_tobacco',
  con_S6231: 'retail_trade_yoy_pharmaceutical_toiletries',
  con_S6232: 'retail_trade_yoy_textiles_clothing_footwear',
  con_S6233: 'retail_trade_yoy_household_furniture_appliances',
  con_S6234: 'retail_trade_yoy_hardware_paint_glass',
  con_S6239: 'retail_trade_yoy_other',
};
export const CPI_CODES: Readonly<Record<string, string>> = {
  CPS00000: 'cpi_headline_yoy',
  CPS01000: 'cpi_food_yoy',
};

export interface Observation {
  series: string;
  period: string;
  value: number;
  sourceName: string;
  sourceUrl: string;
  releasedAt: Date | null;
}

export type Downloader = (url: string) => Promise<
  | { status: 'ok'; body: Buffer; lastModified: Date | null }
  | { status: 'not_found' }
  | { status: 'error'; reason: string }
>;

/** The real downloader: bounded in time and size, and never logs a body. */
export const httpDownloader: Downloader = async (url) => {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), DOWNLOAD_TIMEOUT_MS);
  try {
    const response = await fetch(url, { signal: controller.signal, redirect: 'follow' });
    if (response.status === 404) return { status: 'not_found' };
    if (!response.ok) return { status: 'error', reason: `HTTP ${response.status}` };
    const length = Number(response.headers.get('content-length') ?? 0);
    if (length > MAX_DOWNLOAD_BYTES) return { status: 'error', reason: 'download too large' };
    const body = Buffer.from(await response.arrayBuffer());
    if (body.length > MAX_DOWNLOAD_BYTES) return { status: 'error', reason: 'download too large' };
    const modified = response.headers.get('last-modified');
    const lastModified = modified && !Number.isNaN(Date.parse(modified)) ? new Date(modified) : null;
    return { status: 'ok', body, lastModified };
  } catch {
    return { status: 'error', reason: controller.signal.aborted ? 'timeout' : 'network error' };
  } finally {
    clearTimeout(timer);
  }
};

function monthsBack(now: Date, count: number): string[] {
  const months: string[] = [];
  for (let i = 1; i <= count; i += 1) {
    const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - i, 1));
    months.push(d.toISOString().slice(0, 7));
  }
  return months;
}

/** Year-on-year observations for the mapped series in a parsed Stats SA file. */
export function statsSaObservations(
  series: readonly StatsSaSeries[],
  codes: Readonly<Record<string, string>>,
  options: {
    publication: 'P62421' | 'P0141';
    source: EconomicSource;
    fileMonth: string;
    releasedAt: Date | null;
    since: string;
    /** CPI appears under a region header; only this region is taken. */
    region?: string;
  },
): Observation[] {
  const out: Observation[] = [];
  const seen = new Set<string>();
  for (const block of series) {
    const key = codes[block.code];
    if (!key || seen.has(key)) continue;
    if (options.region && block.headers.H13 !== options.region) continue;
    // Retail: constant prices, actual (not seasonally adjusted) — the basis of the published y/y.
    if (options.publication === 'P62421' && block.headers.H16 && !/actual/i.test(block.headers.H16)) continue;
    seen.add(key);
    for (const { period, value } of yearOnYear(block, options.since)) {
      out.push({
        series: key,
        period,
        value,
        sourceName: `${SOURCE_LABELS[options.source]}, time series`,
        sourceUrl: releasePdfUrl(options.publication, options.fileMonth),
        releasedAt: options.releasedAt,
      });
    }
  }
  return out;
}

export function fuelObservations(): Observation[] {
  const out: Observation[] = [];
  const name = SOURCE_LABELS.fuel_prices;
  for (const entry of FUEL_PRICE_ADJUSTMENTS.entries) {
    const announced = new Date(`${entry.announcedOn}T00:00:00.000Z`);
    out.push({
      series: 'fuel_petrol95_inland_change',
      period: entry.month,
      value: entry.petrol95InlandChange,
      sourceName: name,
      sourceUrl: entry.sourceUrl,
      releasedAt: announced,
    });
    if (entry.diesel0005Change !== null) {
      out.push({
        series: 'fuel_diesel_0005_change',
        period: entry.month,
        value: entry.diesel0005Change,
        sourceName: name,
        sourceUrl: entry.sourceUrl,
        releasedAt: announced,
      });
    }
    if (entry.petrol95GautengPriceCents !== null) {
      out.push({
        series: 'fuel_petrol95_inland_price',
        period: entry.month,
        value: entry.petrol95GautengPriceCents / 100,
        sourceName: 'Central Energy Fund fuel price history',
        sourceUrl: entry.priceSourceUrl ?? entry.sourceUrl,
        releasedAt: announced,
      });
    }
  }
  return out;
}

export interface SourceResult {
  source: EconomicSource;
  ok: boolean;
  written: number;
  detail: string;
}

export type StatsSaSource = 'statssa_retail' | 'statssa_cpi';

/** A Stats SA release file a person downloaded in a browser. */
export interface ManualStatsSaFile {
  body: Buffer;
  /** The reference month, `YYYY-MM`, as the file name carries it. */
  month: string;
}

export const BLOCKED_DETAIL =
  'Stats SA answered with a web page instead of the data file (its bot protection blocks ' +
  'automated downloads from here). Download the zip in a browser and run: ' +
  'npm run refresh-economic-context -- --file <downloaded zip>';

/**
 * Which source and month a downloaded file holds, from its name — the names the
 * time-series page serves (`…P6242.1 Retail trade sales…_202607.zip`,
 * `P0141 - CPI(COICOP) from Jan 2008 (202607).zip`). Browsers may swap spaces
 * for underscores or append ` (1)`, so only the publication code and the
 * six-digit month are relied on. Null when the name is neither.
 */
export function identifyStatsSaFile(fileName: string): { source: StatsSaSource; month: string } | null {
  const source: StatsSaSource | null = /P6242\.1/i.test(fileName)
    ? 'statssa_retail'
    : /P0141/i.test(fileName)
      ? 'statssa_cpi'
      : null;
  const month = /(20\d{2})(0[1-9]|1[0-2])\)?(?:\s*\(\d+\))?\.zip$/i.exec(fileName);
  if (!source || !month) return null;
  return { source, month: `${month[1]}-${month[2]}` };
}

/** A zip starts with the local file header signature `PK\x03\x04`. */
const isZip = (body: Buffer) => body.length >= 4 && body.readUInt32LE(0) === 0x04034b50;

async function fetchStatsSa(
  source: StatsSaSource,
  now: Date,
  download: Downloader,
  manual?: ManualStatsSaFile,
): Promise<{ observations: Observation[]; detail: string }> {
  const isRetail = source === 'statssa_retail';
  const urlFor = isRetail ? STATSSA_RETAIL_URL : STATSSA_CPI_URL;
  const since = `${now.getUTCFullYear() - YEARS_KEPT}-${String(now.getUTCMonth() + 1).padStart(2, '0')}`;

  // Retail is published ~7 weeks after the month, CPI ~3 weeks: four months back covers both with room.
  const attempts = manual ? [manual.month] : monthsBack(now, 4);
  for (const month of attempts) {
    const result = manual
      ? ({ status: 'ok', body: manual.body, lastModified: null } as const)
      : await download(urlFor(month));
    if (result.status === 'not_found') continue;
    if (result.status === 'error') throw new Error(`download failed (${result.reason})`);
    if (!isZip(result.body)) {
      throw new Error(manual ? 'the file is not a zip archive' : BLOCKED_DETAIL);
    }

    const entry = readZip(result.body, (name) => /\.txt$/i.test(name))[0];
    if (!entry) throw new Error('the archive has no ASCII file');
    const series = parseStatsSaAscii(entry.data.toString('latin1'));
    const observations = statsSaObservations(series, isRetail ? RETAIL_CODES : CPI_CODES, {
      publication: isRetail ? 'P62421' : 'P0141',
      source,
      fileMonth: month,
      releasedAt: result.lastModified,
      since,
      ...(isRetail ? {} : { region: 'All urban areas' }),
    });
    const expected = new Set(Object.values(isRetail ? RETAIL_CODES : CPI_CODES));
    const found = new Set(observations.map((o) => o.series));
    const missing = [...expected].filter((key) => !found.has(key));
    // A file that has lost its headline series has changed shape: refuse it
    // rather than half-update the table.
    if (!found.has(isRetail ? 'retail_trade_yoy' : 'cpi_headline_yoy')) {
      throw new Error('the file no longer contains the headline series');
    }
    return {
      observations,
      detail: `release ${month}${manual ? ' (imported file)' : ''}${missing.length ? `; missing ${missing.join(', ')}` : ''}`,
    };
  }
  throw new Error('no release file found for the last four months');
}

async function store(source: EconomicSource, observations: Observation[], retrievedAt: Date): Promise<number> {
  for (const o of observations) {
    if (!SERIES_BY_KEY.has(o.series)) throw new Error(`unknown series ${o.series}`);
  }
  await prisma.$transaction(
    observations.map((o) =>
      prisma.economicObservation.upsert({
        where: { series_period: { series: o.series, period: o.period } },
        create: { ...o, unit: SERIES_BY_KEY.get(o.series)!.unit, retrievedAt },
        update: {
          value: o.value,
          sourceName: o.sourceName,
          sourceUrl: o.sourceUrl,
          releasedAt: o.releasedAt,
          retrievedAt,
        },
      }),
    ),
  );
  return observations.length;
}

/** Refresh every source. One source failing never stops the others. */
export async function refreshEconomicData(
  options: {
    now?: Date;
    download?: Downloader;
    sources?: EconomicSource[];
    /** Import these downloaded files instead of fetching those sources. */
    files?: Partial<Record<StatsSaSource, ManualStatsSaFile>>;
  } = {},
): Promise<SourceResult[]> {
  const now = options.now ?? new Date();
  const download = options.download ?? httpDownloader;
  const sources = options.sources ?? (['statssa_retail', 'statssa_cpi', 'fuel_prices'] as EconomicSource[]);
  const results: SourceResult[] = [];

  for (const source of sources) {
    let result: SourceResult;
    try {
      const { observations, detail } =
        source === 'fuel_prices'
          ? { observations: fuelObservations(), detail: `table ${FUEL_PRICE_ADJUSTMENTS.version}` }
          : await fetchStatsSa(source, now, download, options.files?.[source]);
      const written = await store(source, observations, now);
      result = { source, ok: true, written, detail };
    } catch (err) {
      // The reason only — never a response body, which could be anything.
      const reason = err instanceof Error ? err.message.slice(0, 300) : 'unknown error';
      result = { source, ok: false, written: 0, detail: reason };
    }
    await prisma.economicSourceRefresh.upsert({
      where: { source },
      create: {
        source,
        lastAttemptAt: now,
        lastSuccessAt: result.ok ? now : null,
        lastError: result.ok ? null : result.detail,
      },
      update: {
        lastAttemptAt: now,
        ...(result.ok ? { lastSuccessAt: now, lastError: null } : { lastError: result.detail }),
      },
    });
    results.push(result);
  }
  return results;
}

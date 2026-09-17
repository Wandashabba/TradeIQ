import type { AuthTokenPayload } from '../../auth/auth.service';
import * as economicService from '../../externalContext/economic.service';
import * as weatherService from '../../externalContext/weather.service';
import { ToolFacingError, type AnyAssistantTool } from '../types';
import { periodDays, provenanceSources } from './context';
import { buildTools } from './index';

/**
 * Wiring for the outside-context tools: the period resolves to the client's
 * local days, the caller's tenant (and only that) reaches the weather lookup,
 * and service refusals become messages the model can act on.
 *
 * The services run against a database and saved fixtures in
 * `externalContext/*.test.ts`; here they are mocked, apart from the calendar,
 * which is pure.
 */

jest.mock('../../clients/clients.service', () => ({
  getClientTimeZone: jest.fn(async () => 'Africa/Johannesburg'),
}));

jest.mock('../../externalContext/weather.service', () => {
  const actual = jest.requireActual('../../externalContext/weather.service');
  return { ...actual, getWeatherContext: jest.fn() };
});

jest.mock('../../externalContext/economic.service', () => {
  const actual = jest.requireActual('../../externalContext/economic.service');
  return { ...actual, getEconomicContext: jest.fn() };
});

const weather = weatherService as unknown as Record<string, jest.Mock>;
const economic = economicService as unknown as Record<string, jest.Mock>;

const NOW = new Date('2026-09-17T10:00:00.000Z');
const USER: AuthTokenPayload = { userId: 'u1', role: 'manager', clientId: 'c1' };
const AUGUST = { kind: 'custom', from: '2026-08-01', to: '2026-08-31' };

function tool(name: string): AnyAssistantTool {
  const found = buildTools({ user: USER, now: NOW }).find((t) => t.name === name);
  if (!found) throw new Error(`no tool ${name}`);
  return found;
}

const run = (name: string, rawArgs: unknown) => {
  const t = tool(name);
  return t.run(t.args.parse(rawArgs));
};

beforeEach(() => jest.clearAllMocks());

describe('periodDays', () => {
  it('turns a period into inclusive local calendar days', async () => {
    const tz = 'Africa/Johannesburg';
    expect(await periodDays({ kind: 'custom', from: '2026-08-01', to: '2026-08-31' }, NOW, tz)).toEqual({
      from: '2026-08-01',
      to: '2026-08-31',
    });
    expect(await periodDays({ kind: 'mtd' }, NOW, tz)).toEqual({ from: '2026-09-01', to: '2026-09-17' });
    // 23:30 UTC on the 16th is already the 17th in Johannesburg.
    expect(await periodDays({ kind: 'today' }, new Date('2026-09-16T23:30:00Z'), tz)).toEqual({
      from: '2026-09-17',
      to: '2026-09-17',
    });
  });
});

describe('getCalendarContext', () => {
  it('answers from the calendar tables for the period', async () => {
    const result = (await run('getCalendarContext', { period: AUGUST })) as {
      publicHolidays: Array<{ date: string }>;
      notice: string;
    };
    expect(result.publicHolidays.map((h) => h.date)).toEqual(['2026-08-09', '2026-08-10']);
    expect(result.notice).toMatch(/Outside context/);
  });

  it('rejects a province that is not one', () => {
    expect(tool('getCalendarContext').args.safeParse({ period: AUGUST, province: 'Gautang' }).success).toBe(false);
  });

  it('turns a refusal into a message for the model', async () => {
    await expect(
      run('getCalendarContext', { period: { kind: 'custom', from: '2020-01-01', to: '2026-01-01' } }),
    ).rejects.toThrow(ToolFacingError);
  });
});

describe('getWeatherContext', () => {
  it('passes the caller\'s tenant, local days and timezone — never a tenant from the model', async () => {
    weather.getWeatherContext.mockResolvedValue({ territories: [] });
    await run('getWeatherContext', { period: AUGUST, territoryId: 't-1' });
    expect(weather.getWeatherContext).toHaveBeenCalledWith({
      clientId: 'c1',
      from: '2026-08-01',
      to: '2026-08-31',
      timeZone: 'Africa/Johannesburg',
      territoryId: 't-1',
    });
  });

  it('translates a weather refusal and lets other failures stay generic', async () => {
    weather.getWeatherContext.mockRejectedValueOnce(new weatherService.WeatherContextError('no outlets'));
    await expect(run('getWeatherContext', { period: AUGUST })).rejects.toThrow(ToolFacingError);
    weather.getWeatherContext.mockRejectedValueOnce(new Error('connection refused'));
    await expect(run('getWeatherContext', { period: AUGUST })).rejects.not.toThrow(ToolFacingError);
  });
});

describe('getEconomicContext', () => {
  it('reads the stored series for the period', async () => {
    economic.getEconomicContext.mockResolvedValue({ series: [] });
    await run('getEconomicContext', { period: AUGUST });
    expect(economic.getEconomicContext).toHaveBeenCalledWith({ from: '2026-08-01', to: '2026-08-31', now: NOW });
  });

  it('translates a refusal', async () => {
    economic.getEconomicContext.mockRejectedValueOnce(new economicService.EconomicContextError('too long'));
    await expect(run('getEconomicContext', { period: AUGUST })).rejects.toThrow(ToolFacingError);
  });
});

describe('cited sources', () => {
  it('turns provenance into the shared sources shape, release date in the page-age slot', () => {
    expect(
      provenanceSources([
        { sourceName: 'Stats SA CPI', url: 'https://x.example/a.pdf', publishedAt: '2026-08-19', retrievedAt: '2026-09-17' },
        { sourceName: 'Open-Meteo', url: 'https://open-meteo.com/en/docs', publishedAt: null, retrievedAt: '2026-09-17' },
      ]),
    ).toEqual([
      { url: 'https://x.example/a.pdf', title: 'Stats SA CPI', pageAge: 'Released 19 Aug 2026', snippet: null },
      { url: 'https://open-meteo.com/en/docs', title: 'Open-Meteo', pageAge: null, snippet: null },
    ]);
  });

  it('cites the calendar tables a calendar answer used', async () => {
    const t = tool('getCalendarContext');
    const args = t.args.parse({ period: { kind: 'custom', from: '2026-11-01', to: '2026-11-07' } });
    const cited = t.sources!(args, await t.run(args)).map((s) => s.url);
    expect(cited).toContain('https://www.gov.za/news/media-statements/president-cyril-ramaphosa-declares-election-day');
  });

  it('cites each economic figure\'s release', () => {
    const t = tool('getEconomicContext');
    const provenance = { sourceName: 'Stats SA', url: 'https://s.example/r.pdf', publishedAt: '2026-09-16', retrievedAt: 'x' };
    const cited = t.sources!({}, {
      series: [{ inPeriod: [{ provenance }], latest: { provenance: { ...provenance, url: 'https://s.example/l.pdf' } } }],
    });
    expect(cited.map((s) => s.url)).toEqual(['https://s.example/r.pdf', 'https://s.example/l.pdf']);
  });
});

describe('descriptions', () => {
  const names = ['getCalendarContext', 'getWeatherContext', 'getEconomicContext'];

  it('each names the internal tools to use instead, so outside context never answers a business question', () => {
    for (const name of names) {
      expect(tool(name).description).toMatch(/getRateOfSale/);
    }
  });

  it('each says what the others cover, so they do not claim the same question', () => {
    expect(tool('getCalendarContext').description).toMatch(/getWeatherContext.*getEconomicContext/s);
    expect(tool('getWeatherContext').description).toMatch(/getCalendarContext.*getEconomicContext/s);
    expect(tool('getEconomicContext').description).toMatch(/not for forecasts or news/);
  });
});

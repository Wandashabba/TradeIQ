import type { AuthTokenPayload } from '../../auth/auth.service';
import * as trendsService from '../../trends/trends.service';
import type { FigureArtifact, StatTile } from '../figures';
import * as pillarsService from '../pillars.service';
import type { AnyAssistantTool } from '../types';
import { buildTools } from './index';

/**
 * Tool-level wiring for figure artifacts: which tool draws what, from the
 * result it actually returned, labelled with the window it actually measured.
 *
 * The services are mocked — the builders are exhaustively tested in
 * `figures.test.ts`, and the point here is the closure: args → windows →
 * builder, with no extra query.
 */

jest.mock('../../clients/clients.service', () => ({
  getClientTimeZone: jest.fn(async () => 'Africa/Johannesburg'),
}));

jest.mock('../pillars.service', () => ({
  getSalesPerformance: jest.fn(),
  getStockLevels: jest.fn(),
  getTerritorySellInChange: jest.fn(),
  getShareOfShelf: jest.fn(),
  getVisibilityCompliance: jest.fn(),
  getCompetitorActivity: jest.fn(),
  getSkuMovement: jest.fn(),
  getVisitSummary: jest.fn(),
}));

jest.mock('../../trends/trends.service', () => ({
  getScorecardsTrend: jest.fn(),
  getAvailabilityTrend: jest.fn(),
  getPerfectStoreTrend: jest.fn(),
  getShareOfShelfTrend: jest.fn(),
}));

// Hoisted above the imports by ts-jest, so these are the mocks.
const pillars = pillarsService as unknown as Record<string, jest.Mock>;
const trends = trendsService as unknown as Record<string, jest.Mock>;

const NOW = new Date('2026-09-17T10:00:00.000Z');
const USER: AuthTokenPayload = { userId: 'u1', role: 'manager', clientId: 'c1' };
const AUGUST = { kind: 'custom', from: '2026-08-01', to: '2026-08-31' };

function tool(name: string): AnyAssistantTool {
  const found = buildTools({ user: USER, now: NOW }).find((t) => t.name === name);
  if (!found) throw new Error(`no tool ${name}`);
  return found;
}

async function runWithFigures(name: string, rawArgs: unknown) {
  const t = tool(name);
  const args = t.args.parse(rawArgs);
  const result = await t.run(args);
  const figures = t.figures ? await t.figures(args, result) : [];
  return { result, figures };
}

const tiles = (figures: FigureArtifact[]): StatTile[] =>
  (figures.find((f) => f.type === 'stat_tiles')?.data as { tiles: StatTile[] })?.tiles ?? [];

const sellIn = (units: number, extra: Record<string, unknown> = {}) => ({
  metric: 'sell_in_units',
  sellInUnits: units,
  outletsOrdering: 90,
  months: ['2026-08'],
  targetUnits: 59_500,
  attainmentPct: 81,
  ...extra,
});

beforeEach(() => jest.clearAllMocks());

describe('getRateOfSale figures', () => {
  it('labels the comparison with the window the second run measured', async () => {
    pillars.getSalesPerformance
      .mockResolvedValueOnce(sellIn(48_210))
      .mockResolvedValueOnce(sellIn(55_034, { months: ['2025-08'] }));

    const { figures } = await runWithFigures('getRateOfSale', {
      period: AUGUST,
      compareTo: { kind: 'same_period_last_year' },
    });

    // Two service calls: the tool's own run and its comparison. The figures
    // added none.
    expect(pillars.getSalesPerformance).toHaveBeenCalledTimes(2);
    expect(tiles(figures)[0]).toMatchObject({
      label: 'Sell-in, units',
      value: 48_210,
      delta: { value: 12.4, unit: 'pct', direction: 'down', sentiment: 'bad' },
      comparedTo: "vs 55,034 · Aug '25",
    });
    expect(tiles(figures)[1]).toMatchObject({ label: 'Target attainment', meter: 81 });
  });

  it('omits attainment for month-to-date', async () => {
    pillars.getSalesPerformance.mockResolvedValueOnce(
      sellIn(20_000, { months: [], targetUnits: null, attainmentPct: null }),
    );
    const { figures } = await runWithFigures('getRateOfSale', { period: { kind: 'mtd' } });
    expect(tiles(figures).map((t) => t.label)).toEqual(['Sell-in, units', 'Outlets ordering']);
  });
});

describe('getStockLevels figures', () => {
  it('draws tiles and the outlet ranking, alongside its outlet map view', async () => {
    pillars.getStockLevels.mockResolvedValueOnce({
      onShelfAvailabilityPct: 88,
      linesObserved: 100,
      outOfStockLines: 12,
      outletsWithStockout: 2,
      worstOutlets: [
        { outletId: 'o1', outletName: 'Kasi Spaza', outOfStockLines: 4, lat: 0, lng: 0 },
        { outletId: 'o2', outletName: 'Soweto Superette', outOfStockLines: 8, lat: 0, lng: 0 },
      ],
      truncated: false,
    });

    const t = tool('getStockLevels');
    const args = t.args.parse({ period: { kind: 'mtd' } });
    const result = await t.run(args);
    expect(t.view?.(args, result)).toMatchObject({ type: 'outlet_map' });

    const figures = await t.figures!(args, result);
    expect(figures.map((f) => f.type)).toEqual(['stat_tiles', 'ranked_bars']);
    expect(figures[1].data).toMatchObject({
      comparedTo: "1–17 Sep '26",
      items: [{ label: 'Soweto Superette', value: 8 }, { label: 'Kasi Spaza', value: 4 }],
    });
  });
});

describe('tools without figures', () => {
  it.each(['getSkuMovement', 'getVisitHistory', 'getFraudFlags', 'getMetricTrend'])(
    '%s declares none',
    (name) => {
      expect(tool(name).figures).toBeUndefined();
    },
  );

  it.each([
    'getRateOfSale',
    'getStockLevels',
    'getShareOfShelf',
    'getVisibilityCompliance',
    'getCompetitorActivity',
    'getAgentScorecard',
    'getTerritoryRanking',
  ])('%s declares figures', (name) => {
    expect(tool(name).figures).toEqual(expect.any(Function));
  });
});

describe('getMetricTrend comparison series', () => {
  const series = (values: number[]) => ({
    interval: 'day',
    points: values.map((value, i) => ({ period: `2026-09-0${i + 1}`, value, count: 1 })),
  });

  it('is unchanged — no comparison key — when none was asked for', async () => {
    trends.getAvailabilityTrend.mockResolvedValueOnce(series([90, 88]));
    const { result } = await runWithFigures('getMetricTrend', {
      metric: 'availability',
      period: { kind: 'mtd' },
    });

    expect(result).toEqual({
      metric: 'availability',
      interval: 'day',
      points: series([90, 88]).points,
    });
    expect(trends.getAvailabilityTrend).toHaveBeenCalledTimes(1);
  });

  it('carries the prior series it already fetched, shaped like the main one', async () => {
    trends.getAvailabilityTrend
      .mockResolvedValueOnce(series([90, 88]))
      .mockResolvedValueOnce(series([93, 92]));

    const { result } = await runWithFigures('getMetricTrend', {
      metric: 'availability',
      period: { kind: 'mtd' },
      compareTo: { kind: 'same_period_last_year' },
    });

    expect(result).toMatchObject({
      points: series([90, 88]).points,
      comparison: {
        label: 'the same days last year',
        basis: { kind: 'same_period_last_year' },
        points: series([93, 92]).points,
      },
    });
    expect(trends.getAvailabilityTrend).toHaveBeenCalledTimes(2);
    // Both lines over complete days only (#365): on 17 Sep that is 1–16 Sep
    // against 1–16 Sep last year, local midnights — the current line included.
    const windows = trends.getAvailabilityTrend.mock.calls.map(([f]) => [
      f.from.toISOString(),
      f.to.toISOString(),
    ]);
    expect(windows).toEqual([
      ['2026-08-31T22:00:00.000Z', '2026-09-16T22:00:00.000Z'],
      ['2025-08-31T22:00:00.000Z', '2025-09-16T22:00:00.000Z'],
    ]);
  });
});

describe('getTerritoryRanking', () => {
  const change = {
    totalSellInUnits: 476,
    comparisonTotalSellInUnits: 475,
    territories: [
      { territoryName: 'Soweto', changePct: -31 },
      { territoryName: 'Pretoria East', changePct: 7 },
    ],
    excludedNoComparison: [],
  };

  it('resolves both windows in the client calendar and defaults to the previous period', async () => {
    pillars.getTerritorySellInChange.mockResolvedValueOnce(change);
    const { figures } = await runWithFigures('getTerritoryRanking', { period: AUGUST });

    const call = pillars.getTerritorySellInChange.mock.calls[0][0];
    expect(call).toMatchObject({
      clientId: 'c1',
      timeZone: 'Africa/Johannesburg',
      current: { from: new Date('2026-07-31T22:00:00.000Z'), to: new Date('2026-08-31T22:00:00.000Z') },
      comparison: { from: new Date('2026-06-30T22:00:00.000Z'), to: new Date('2026-07-31T22:00:00.000Z') },
    });
    expect(call).not.toHaveProperty('region');
    expect(pillars.getTerritorySellInChange).toHaveBeenCalledTimes(1);

    expect(figures.find((f) => f.type === 'ranked_bars')?.data).toEqual({
      title: 'Change by territory',
      comparedTo: "vs Jul '26",
      unit: 'pct',
      items: [
        { label: 'Soweto', value: -31 },
        { label: 'Pretoria East', value: 7 },
      ],
    });
  });

  it('measures against last year when asked, and passes a region through', async () => {
    pillars.getTerritorySellInChange.mockResolvedValueOnce(change);
    const { figures } = await runWithFigures('getTerritoryRanking', {
      period: AUGUST,
      compareTo: { kind: 'same_period_last_year' },
      region: 'Gauteng',
    });
    expect(pillars.getTerritorySellInChange.mock.calls[0][0]).toMatchObject({
      region: 'Gauteng',
      comparison: { from: new Date('2025-07-31T22:00:00.000Z') },
    });
    expect(figures.find((f) => f.type === 'ranked_bars')?.data).toMatchObject({ comparedTo: "vs Aug '25" });
  });

  it('refuses a territory comparison basis, which a ranking across territories cannot honour', () => {
    const parsed = tool('getTerritoryRanking').args.safeParse({
      period: AUGUST,
      compareTo: { kind: 'territory', id: 't1' },
    });
    expect(parsed.success).toBe(false);
  });

  it('states its narrow trigger, the sell-in basis, and the hand-off to getRateOfSale', () => {
    const { description } = tool('getTerritoryRanking');
    expect(description).toMatch(/^Call this when the user wants territories ranked or compared/);
    expect(description).toMatch(/Only for comparisons ACROSS territories\./);
    expect(description).toMatch(/SELL-IN/);
    expect(description).toMatch(/never consumer sell-out/);
    expect(description).toMatch(/No targets or attainment/);
    expect(description).toMatch(/Use getRateOfSale instead/);
  });
});

describe('like-for-like comparison windows (#365)', () => {
  const windowOf = (mock: jest.Mock, call: number) => {
    const { from, to } = mock.mock.calls[call][0] as { from: Date; to: Date };
    return [from.toISOString(), to.toISOString()];
  };

  it('measures BOTH sides of a compared month to date over complete days', async () => {
    // The reported case: on 17 Sep, 1–17 Sep (today still at zero) was set
    // against 15–31 Aug (month-end spike). The current run must be trimmed to
    // the same days as its comparison, not resolved separately.
    pillars.getSalesPerformance
      .mockResolvedValueOnce(sellIn(475))
      .mockResolvedValueOnce(sellIn(481));
    const { result } = await runWithFigures('getRateOfSale', {
      period: { kind: 'mtd' },
      compareTo: { kind: 'previous_period' },
    });

    expect(windowOf(pillars.getSalesPerformance, 0)).toEqual([
      '2026-08-31T22:00:00.000Z',
      '2026-09-16T22:00:00.000Z',
    ]);
    expect(windowOf(pillars.getSalesPerformance, 1)).toEqual([
      '2026-07-31T22:00:00.000Z',
      '2026-08-16T22:00:00.000Z',
    ]);
    expect(result).toMatchObject({ comparison: { label: 'the same days last month' } });
    expect((result as { comparison: object }).comparison).not.toHaveProperty('note');
  });

  it('leaves an uncompared month to date including today', async () => {
    pillars.getSalesPerformance.mockResolvedValueOnce(sellIn(481));
    await runWithFigures('getRateOfSale', { period: { kind: 'mtd' } });
    expect(windowOf(pillars.getSalesPerformance, 0)).toEqual([
      '2026-08-31T22:00:00.000Z',
      '2026-09-17T22:00:00.000Z',
    ]);
  });

  it('ranks territories over the trimmed windows, and explains the 1st of the month', async () => {
    pillars.getTerritorySellInChange.mockResolvedValue(change());
    const midMonth = await runWithFigures('getTerritoryRanking', { period: { kind: 'mtd' } });
    const { current, comparison } = pillars.getTerritorySellInChange.mock.calls[0][0];
    expect([current.from, current.to, comparison.from, comparison.to].map((d) => d.toISOString())).toEqual([
      '2026-08-31T22:00:00.000Z',
      '2026-09-16T22:00:00.000Z',
      '2026-07-31T22:00:00.000Z',
      '2026-08-16T22:00:00.000Z',
    ]);
    expect(midMonth.result).toMatchObject({ comparisonLabel: 'the same days last month' });
    expect(midMonth.result).not.toHaveProperty('windowNote');

    const firstOfMonth = buildTools({ user: USER, now: new Date('2026-09-01T07:00:00.000Z') }).find(
      (t) => t.name === 'getTerritoryRanking',
    )!;
    const result = await firstOfMonth.run(firstOfMonth.args.parse({ period: { kind: 'mtd' } }));
    const call = pillars.getTerritorySellInChange.mock.calls[1][0];
    expect([call.current.from.toISOString(), call.comparison.from.toISOString()]).toEqual([
      '2026-07-31T22:00:00.000Z',
      '2026-06-30T22:00:00.000Z',
    ]);
    expect(result).toMatchObject({
      comparisonLabel: 'the month before',
      windowNote: expect.stringMatching(/all of August 2026, compared with all of July 2026/),
    });
  });

  function change() {
    return { totalSellInUnits: 10, comparisonTotalSellInUnits: 12, territories: [], excludedNoComparison: [] };
  }
});

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
        label: 'month to date last year',
        basis: { kind: 'same_period_last_year' },
        points: series([93, 92]).points,
      },
    });
    expect(trends.getAvailabilityTrend).toHaveBeenCalledTimes(2);
  });
});

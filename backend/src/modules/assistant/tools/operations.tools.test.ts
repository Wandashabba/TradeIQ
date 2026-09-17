import type { AuthTokenPayload } from '../../auth/auth.service';
import * as scorecardsService from '../../scorecards/scorecards.service';
import type { FigureArtifact, RankedBars, StatTile } from '../figures';
import * as operationsService from '../operations.service';
import { ToolFacingError, type AnyAssistantTool } from '../types';
import { buildTools } from './index';

/**
 * Tool-level wiring for the #362 tools: args → the service call, bound to the
 * caller's tenant and resolved in the client's calendar; service errors the
 * model can act on → `ToolFacingError`; results → figures.
 *
 * The services are mocked here and exercised against a database in
 * `operations.service.test.ts`, cross-tenant cases included.
 */

jest.mock('../../clients/clients.service', () => ({
  getClientTimeZone: jest.fn(async () => 'Africa/Johannesburg'),
}));

jest.mock('../operations.service', () => {
  const actual = jest.requireActual('../operations.service');
  return {
    ...actual,
    findTerritories: jest.fn(),
    getPriceCompliance: jest.fn(),
    getCampaignPerformance: jest.fn(),
    getContestLeaderboards: jest.fn(),
    getTaskSummary: jest.fn(),
    getAlertSummary: jest.fn(),
    getSellInForecast: jest.fn(),
  };
});

jest.mock('../../scorecards/scorecards.service', () => {
  const actual = jest.requireActual('../../scorecards/scorecards.service');
  return { ...actual, resolveAgent: jest.fn() };
});

const ops = operationsService as unknown as Record<string, jest.Mock>;
const scorecards = scorecardsService as unknown as Record<string, jest.Mock>;

const NOW = new Date('2026-09-17T10:00:00.000Z');
const USER: AuthTokenPayload = { userId: 'u1', role: 'manager', clientId: 'c1' };
const AUGUST = { kind: 'custom', from: '2026-08-01', to: '2026-08-31' };
const AUGUST_RANGE = {
  from: new Date('2026-07-31T22:00:00.000Z'),
  to: new Date('2026-08-31T22:00:00.000Z'),
};

function tool(name: string): AnyAssistantTool {
  const found = buildTools({ user: USER, now: NOW }).find((t) => t.name === name);
  if (!found) throw new Error(`no tool ${name}`);
  return found;
}

async function run(name: string, rawArgs: unknown) {
  const t = tool(name);
  const args = t.args.parse(rawArgs);
  const result = await t.run(args);
  const figures: FigureArtifact[] = t.figures ? await t.figures(args, result) : [];
  return { args, result, figures };
}

const tiles = (figures: FigureArtifact[]): StatTile[] =>
  (figures.find((f) => f.type === 'stat_tiles')?.data as { tiles: StatTile[] } | undefined)?.tiles ?? [];
const bars = (figures: FigureArtifact[]) =>
  figures.find((f) => f.type === 'ranked_bars')?.data as RankedBars | undefined;

const price = (avgDeviationPct: number, extra: Record<string, unknown> = {}) => ({
  thresholdPct: 10,
  pricedLines: 40,
  outletsPriced: 4,
  avgDeviationPct,
  avgAbsDeviationPct: Math.abs(avgDeviationPct),
  linesAboveThresholdPct: 50,
  linesBelowThresholdPct: 0,
  promoActivePct: 10,
  bySku: [],
  worstOutlets: [
    { outletId: 'o1', outletName: 'QuickSave Alpha', outletCode: 'A', territoryCode: 'GP', avgDeviationPct: 14, lines: 10, linesAboveThresholdPct: 80 },
    { outletId: 'o2', outletName: 'Corner Spaza', outletCode: 'B', territoryCode: 'GP', avgDeviationPct: 1, lines: 10, linesAboveThresholdPct: 0 },
  ],
  basis: 'b',
  ...extra,
});

const campaign = (name: string, windowState: string, liftPct: number | null, roiPct: number | null = 10) => ({
  campaignId: name,
  name,
  objective: null,
  status: 'completed',
  windowState,
  startDate: '2026-05-04',
  endDate: '2026-06-14',
  daysTotal: 42,
  daysElapsed: 42,
  budget: 100,
  outlets: 50,
  performance:
    windowState === 'upcoming'
      ? null
      : {
          roi: { roiPct, attributedRevenue: 1, baselineRevenue: 1, incrementalRevenue: 0 },
          liftPct,
          liftComparable: windowState === 'ended',
          execution: { outletsTotal: 50, outletsVisited: 50, visitCoverageRate: 100, avgPlanogramCompliancePct: 94 },
        },
});

beforeEach(() => jest.clearAllMocks());

describe('findTerritories', () => {
  it('passes the place as said, bound to the caller\'s tenant', async () => {
    ops.findTerritories.mockResolvedValueOnce({ matches: [] });
    await run('findTerritories', { query: 'Nelson Mandela Bay' });
    expect(ops.findTerritories).toHaveBeenCalledWith({ clientId: 'c1', query: 'Nelson Mandela Bay' });
  });
});

describe('getPriceCompliance', () => {
  it('resolves the period in the client calendar and draws tiles and outlet bars', async () => {
    ops.getPriceCompliance.mockResolvedValueOnce(price(13.7));
    const { figures } = await run('getPriceCompliance', { period: AUGUST, outletName: 'QuickSave', sku: 'Cola 2L' });

    expect(ops.getPriceCompliance).toHaveBeenCalledWith({
      clientId: 'c1',
      ...AUGUST_RANGE,
      outletName: 'QuickSave',
      sku: 'Cola 2L',
      territoryId: undefined,
    });
    expect(tiles(figures).map((t) => [t.label, t.value])).toEqual([
      ['Avg price vs RRP', 13.7],
      ['Lines >10% above RRP', 50],
    ]);
    expect(bars(figures)?.items[0]).toEqual({ label: 'QuickSave Alpha', value: 14 });
  });

  it('runs a comparison twice, moving only the territory for a territory basis', async () => {
    ops.getPriceCompliance.mockResolvedValueOnce(price(13.7)).mockResolvedValueOnce(price(1));
    const { result, figures } = await run('getPriceCompliance', {
      period: AUGUST,
      territoryId: 't1',
      compareTo: { kind: 'territory', id: 't2' },
    });
    expect(ops.getPriceCompliance.mock.calls.map((c) => c[0].territoryId)).toEqual(['t1', 't2']);
    expect((result as { comparison: { deltas: Record<string, unknown> } }).comparison.deltas.avgDeviationPct).toEqual({
      absolute: 12.7,
      pct: 1270,
    });
    expect(tiles(figures)[0]).toMatchObject({ delta: { direction: 'up', sentiment: 'bad' } });
  });

  it('draws nothing from no priced lines', async () => {
    ops.getPriceCompliance.mockResolvedValueOnce(price(0, { pricedLines: 0, worstOutlets: [] }));
    expect((await run('getPriceCompliance', { period: AUGUST })).figures).toEqual([]);
  });
});

describe('getCampaignPerformance', () => {
  it('turns a period into an overlap window and passes the filters through', async () => {
    ops.getCampaignPerformance.mockResolvedValueOnce({ campaigns: [], omitted: 0 });
    await run('getCampaignPerformance', { campaign: 'Winter Warmer', state: 'ended', period: AUGUST });
    expect(ops.getCampaignPerformance).toHaveBeenCalledWith({
      clientId: 'c1',
      now: NOW,
      campaign: 'Winter Warmer',
      state: 'ended',
      window: AUGUST_RANGE,
    });
  });

  it('draws one campaign as tiles, and hides lift while it is still running', async () => {
    ops.getCampaignPerformance.mockResolvedValueOnce({ campaigns: [campaign('Winter Warmer', 'ended', -11.1, -318)] });
    const ended = await run('getCampaignPerformance', {});
    expect(tiles(ended.figures).map((t) => t.label)).toEqual([
      'Sell-in lift vs baseline',
      'Return on budget',
      'Campaign outlets visited',
      'Planogram compliance',
    ]);

    ops.getCampaignPerformance.mockResolvedValueOnce({ campaigns: [campaign('Braai Day', 'running', -46)] });
    const running = await run('getCampaignPerformance', {});
    expect(tiles(running.figures).map((t) => t.label)).not.toContain('Sell-in lift vs baseline');
  });

  it('ranks ended campaigns by lift, worst first, leaving out running and upcoming ones', async () => {
    ops.getCampaignPerformance.mockResolvedValueOnce({
      campaigns: [
        campaign('Zero Launch', 'ended', 24.3),
        campaign('Winter Warmer', 'ended', -11.1),
        campaign('Braai Day', 'running', -46),
        campaign('Summer', 'upcoming', null),
      ],
    });
    const { figures } = await run('getCampaignPerformance', {});
    expect(bars(figures)?.items).toEqual([
      { label: 'Winter Warmer', value: -11.1 },
      { label: 'Zero Launch', value: 24.3 },
    ]);
  });
});

describe('getContestStandings', () => {
  it('defaults to current contests', async () => {
    ops.getContestLeaderboards.mockResolvedValueOnce({ contests: [], omitted: 0 });
    await run('getContestStandings', { contest: 'Visit Sprint' });
    expect(ops.getContestLeaderboards).toHaveBeenCalledWith({
      clientId: 'c1',
      now: NOW,
      contest: 'Visit Sprint',
      filter: 'current',
    });
  });
});

describe('getTaskSummary', () => {
  const summary = {
    backlog: { open: 3, inProgress: 1, overdue: 2, overdueByPriority: [] },
    raisedInPeriod: null,
    overdueByAgent: [],
    overdueByTerritory: [
      { territoryCode: 'KZN', territoryName: 'KwaZulu-Natal', overdue: 505 },
      { territoryCode: 'MP', territoryName: null, overdue: 139 },
    ],
    oldestOverdue: [],
  };

  it('resolves a named agent to an id in the caller\'s tenant', async () => {
    scorecards.resolveAgent.mockResolvedValueOnce({ id: 'agent-9' });
    ops.getTaskSummary.mockResolvedValueOnce(summary);
    const { figures } = await run('getTaskSummary', { agent: 'Kagiso', period: { kind: 'mtd' } });

    expect(scorecards.resolveAgent).toHaveBeenCalledWith({ clientId: 'c1', query: 'Kagiso' });
    expect(ops.getTaskSummary).toHaveBeenCalledWith(
      expect.objectContaining({ clientId: 'c1', now: NOW, agentId: 'agent-9', window: expect.any(Object) }),
    );
    expect(tiles(figures).map((t) => [t.label, t.value])).toEqual([
      ['Open tasks', 4],
      ['Overdue tasks', 2],
    ]);
    expect(bars(figures)?.items.map((i) => i.label)).toEqual(['KwaZulu-Natal', 'MP']);
  });

  it('turns an ambiguous name into a question the model can ask', async () => {
    scorecards.resolveAgent.mockRejectedValueOnce(
      new scorecardsService.AmbiguousAgentError('Sipho', [
        { id: 'a', email: 'a@x', displayName: 'Sipho A' },
        { id: 'b', email: 'b@x', displayName: 'Sipho B' },
      ]),
    );
    await expect(run('getTaskSummary', { agent: 'Sipho' })).rejects.toBeInstanceOf(ToolFacingError);
    expect(ops.getTaskSummary).not.toHaveBeenCalled();
  });

  it('omits the period and agent when not given', async () => {
    ops.getTaskSummary.mockResolvedValueOnce(summary);
    await run('getTaskSummary', {});
    expect(ops.getTaskSummary).toHaveBeenCalledWith({
      clientId: 'c1',
      now: NOW,
      window: undefined,
      territoryId: undefined,
      agentId: undefined,
    });
  });
});

describe('getAlerts', () => {
  it('passes the type and territory, and refuses a type that does not exist', async () => {
    ops.getAlertSummary.mockResolvedValueOnce({
      raised: 3,
      unacknowledged: 2,
      byType: [],
      unacknowledgedBySeverity: [],
      topOutlets: [
        { outletId: 'o1', outletName: 'QuickSave Alpha', unacknowledged: 2 },
        { outletId: 'o2', outletName: 'Corner Spaza', unacknowledged: 1 },
      ],
      newestUnacknowledged: [],
    });
    const { figures } = await run('getAlerts', { type: 'price_deviation', territoryId: 't1' });
    expect(ops.getAlertSummary).toHaveBeenCalledWith({
      clientId: 'c1',
      window: undefined,
      territoryId: 't1',
      type: 'price_deviation',
    });
    expect(tiles(figures).map((t) => t.value)).toEqual([3, 2]);
    expect(bars(figures)?.items[0]).toEqual({ label: 'QuickSave Alpha', value: 2 });
    expect(tool('getAlerts').args.safeParse({ type: 'weather' }).success).toBe(false);
  });

  it('draws nothing when no alert was raised', async () => {
    ops.getAlertSummary.mockResolvedValueOnce({ raised: 0, unacknowledged: 0, topOutlets: [] });
    expect((await run('getAlerts', { period: { kind: 'yesterday' } })).figures).toEqual([]);
  });
});

describe('getSellInForecast', () => {
  const forecast = {
    skuId: 's1',
    skuName: 'Cola 2L',
    forecastDailyUnits: 120.5,
    daysOfCover: 4.2,
    historyDays: 28,
    daysWithOrders: 20,
    confidence: null,
  };

  it('forecasts for the caller\'s tenant and draws the estimate and cover', async () => {
    ops.getSellInForecast.mockResolvedValueOnce(forecast);
    const { figures } = await run('getSellInForecast', { sku: 'Cola 2L', outletId: 'o1' });
    expect(ops.getSellInForecast).toHaveBeenCalledWith({ clientId: 'c1', now: NOW, sku: 'Cola 2L', outletId: 'o1' });
    expect(tiles(figures).map((t) => [t.label, t.value])).toEqual([
      ['Forecast sell-in / day', 120.5],
      ['Days of cover', 4.2],
    ]);
  });

  it('draws nothing from a history with no orders, and no cover tile when cover is unbounded', async () => {
    ops.getSellInForecast.mockResolvedValueOnce({ ...forecast, daysWithOrders: 0 });
    expect((await run('getSellInForecast', { sku: 'Cola 2L' })).figures).toEqual([]);
    ops.getSellInForecast.mockResolvedValueOnce({ ...forecast, daysOfCover: null });
    expect(tiles((await run('getSellInForecast', { sku: 'Cola 2L' })).figures)).toHaveLength(1);
  });

  it.each([
    new operationsService.SkuLookupError('More than one product matches "Cola". Ask which one.'),
    new operationsService.OutletLookupError('No outlet with that id.'),
  ])('shows the model a lookup failure it can act on: %s', async (error) => {
    ops.getSellInForecast.mockRejectedValueOnce(error);
    await expect(run('getSellInForecast', { sku: 'Cola' })).rejects.toBeInstanceOf(ToolFacingError);
  });

  it('keeps any other failure generic', async () => {
    ops.getSellInForecast.mockRejectedValueOnce(new Error('relation "orders" does not exist'));
    await expect(run('getSellInForecast', { sku: 'Cola' })).rejects.not.toBeInstanceOf(ToolFacingError);
  });

  it('requires a product', () => {
    expect(tool('getSellInForecast').args.safeParse({}).success).toBe(false);
  });
});

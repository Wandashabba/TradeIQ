import type { AgentPerformance } from '../scorecards/scorecards.service';
import { comparisonRanges, type CompareTo } from './compare';
import {
  buildDelta,
  competitorFigures,
  formatNumber,
  formatPeriodLabel,
  rankedBars,
  salesFigures,
  scorecardFigures,
  SENTIMENT,
  shareOfShelfFigures,
  stockFigures,
  validateFigure,
  visibilityComplianceFigures,
  type FigureArtifact,
  type FigureWindows,
  type StatTile,
} from './figures';
import { resolvePeriod, type Period } from './period';
import type {
  CompetitorActivity,
  SalesPerformance,
  ShareOfShelf,
  StockLevels,
  VisibilityCompliance,
} from './pillars.service';

const TZ = 'Africa/Johannesburg';
const NOW = new Date('2026-09-17T10:00:00.000Z');
const AUGUST: Period = { kind: 'custom', from: '2026-08-01', to: '2026-08-31' };
const MTD: Period = { kind: 'mtd' };

function windows(period: Period, compareTo?: CompareTo): FigureWindows {
  if (!compareTo) return { timeZone: TZ, current: resolvePeriod(period, NOW, TZ) };
  // The tools read both windows from one helper, so the tests do too (#365).
  const ranges = comparisonRanges(period, compareTo, NOW, TZ);
  return {
    timeZone: TZ,
    current: ranges.current,
    comparison: { range: ranges.comparison, basis: compareTo },
  };
}

function sales(overrides: Partial<SalesPerformance> = {}): SalesPerformance {
  const range = resolvePeriod(AUGUST, NOW, TZ);
  return {
    metric: 'sell_in_units',
    metricLabel: 'Sell-in (units ordered)',
    basis: 'sell-in',
    timeZone: TZ,
    from: range.from,
    to: range.to,
    sellInUnits: 48_210,
    targetedSellInUnits: 48_195,
    outletsOrdering: 90,
    skusOrdered: 12,
    months: ['2026-08'],
    targetUnits: 59_500,
    attainmentPct: 81,
    targetBasis: 'Target is the sum of …',
    ...overrides,
  } as SalesPerformance;
}

const tilesOf = (figures: FigureArtifact[]): StatTile[] =>
  (figures.find((f) => f.type === 'stat_tiles')?.data as { tiles: StatTile[] } | undefined)
    ?.tiles ?? [];
const tile = (figures: FigureArtifact[], label: string) =>
  tilesOf(figures).find((t) => t.label === label);
const barsOf = (figures: FigureArtifact[]) => figures.find((f) => f.type === 'ranked_bars');

/** Every builder's output must pass the same validator the orchestrator runs. */
function expectValid(figures: FigureArtifact[]): void {
  for (const figure of figures) expect(validateFigure(figure)).toMatchObject({ ok: true });
}

describe('formatting', () => {
  it('groups thousands with commas and keeps one decimal only when needed', () => {
    expect(formatNumber(55_034)).toBe('55,034');
    expect(formatNumber(1_234_567)).toBe('1,234,567');
    expect(formatNumber(92.35)).toBe('92.4');
    expect(formatNumber(92.0)).toBe('92');
    expect(formatNumber(0)).toBe('0');
    expect(formatNumber(-3.04)).toBe('-3');
  });

  it('labels a whole month by name, in the client calendar', () => {
    // [31 Jul 22:00Z, 31 Aug 22:00Z) is August in Johannesburg. Read in UTC it
    // would straddle two months.
    expect(formatPeriodLabel(resolvePeriod(AUGUST, NOW, TZ), TZ)).toBe("Aug '26");
  });

  it('labels part-months, single days, multi-month and cross-year ranges', () => {
    const label = (from: string, to: string) =>
      formatPeriodLabel(resolvePeriod({ kind: 'custom', from, to }, NOW, TZ), TZ);
    expect(formatPeriodLabel(resolvePeriod(MTD, NOW, TZ), TZ)).toBe("1–17 Sep '26");
    expect(label('2026-08-12', '2026-08-12')).toBe("12 Aug '26");
    expect(label('2026-07-25', '2026-08-03')).toBe("25 Jul – 3 Aug '26");
    expect(label('2026-06-01', '2026-08-31')).toBe("Jun–Aug '26");
    expect(label('2025-12-28', '2026-01-03')).toBe("28 Dec '25 – 3 Jan '26");
    expect(label('2025-12-01', '2026-01-31')).toBe("Dec '25 – Jan '26");
  });
});

describe('sentiment', () => {
  it('is an explicit table: more sell-in is good, more stock-outs is bad', () => {
    expect(SENTIMENT.sell_in_units).toEqual({ up: 'good', down: 'bad' });
    expect(SENTIMENT.on_shelf_availability).toEqual({ up: 'good', down: 'warn' });
    expect(SENTIMENT.outlets_with_stockout).toEqual({ up: 'bad', down: 'good' });
    expect(SENTIMENT.out_of_stock_lines).toEqual({ up: 'bad', down: 'good' });
    expect(SENTIMENT.competitor_promoter_presence).toEqual({ up: 'warn', down: 'good' });
  });

  it('comes from the table, never from the sign alone', () => {
    expect(buildDelta('sell_in_units', 'units', 110, 100)).toMatchObject({ direction: 'up', sentiment: 'good' });
    expect(buildDelta('outlets_with_stockout', 'count', 17, 8)).toMatchObject({
      value: 9,
      unit: 'count',
      direction: 'up',
      sentiment: 'bad',
    });
  });
});

describe('deltas', () => {
  it('uses a percentage for units, points for percentages, counts for counts', () => {
    expect(buildDelta('sell_in_units', 'units', 48_210, 55_034)).toEqual({
      value: 12.4,
      unit: 'pct',
      direction: 'down',
      sentiment: 'bad',
    });
    expect(buildDelta('on_shelf_availability', 'pct', 88, 92)).toEqual({
      value: 4,
      unit: 'pts',
      direction: 'down',
      sentiment: 'warn',
    });
  });

  it('falls back to an absolute count when the baseline is zero', () => {
    // "Up from nothing" has no percentage.
    expect(buildDelta('sell_in_units', 'units', 40, 0)).toEqual({
      value: 40,
      unit: 'count',
      direction: 'up',
      sentiment: 'good',
    });
  });

  it('omits a change that rounds to nothing, rather than choosing a direction', () => {
    expect(buildDelta('sell_in_units', 'units', 100_000, 100_001)).toBeUndefined();
    expect(buildDelta('on_shelf_availability', 'pct', 90, 90)).toBeUndefined();
  });
});

describe('salesFigures', () => {
  it('builds units, attainment and outlets for a whole month against last year', () => {
    const compareTo: CompareTo = { kind: 'same_period_last_year' };
    const result = {
      ...sales(),
      comparison: {
        label: '… last year',
        basis: compareTo,
        values: sales({ sellInUnits: 55_034, outletsOrdering: 94, attainmentPct: 88 }),
      },
    };

    const figures = salesFigures(result, windows(AUGUST, compareTo));
    expectValid(figures);

    expect(tilesOf(figures)).toEqual([
      {
        label: 'Sell-in, units',
        value: 48_210,
        unit: 'units',
        delta: { value: 12.4, unit: 'pct', direction: 'down', sentiment: 'bad' },
        comparedTo: "vs 55,034 · Aug '25",
      },
      {
        label: 'Target attainment',
        value: 81,
        unit: 'pct',
        comparedTo: "of 59,500 · Aug '26",
        meter: 81,
      },
      {
        label: 'Outlets ordering',
        value: 90,
        unit: 'count',
        delta: { value: 4, unit: 'count', direction: 'down', sentiment: 'bad' },
        comparedTo: "vs 94 · Aug '25",
      },
    ]);
  });

  it('carries no delta or comparedTo when nothing was compared', () => {
    const units = tile(salesFigures(sales(), windows(AUGUST)), 'Sell-in, units');
    expect(units).toEqual({ label: 'Sell-in, units', value: 48_210, unit: 'units' });
  });

  it('labels a territory comparison as such, not as a period', () => {
    const compareTo: CompareTo = { kind: 'territory', id: 't2' };
    const result = {
      ...sales(),
      comparison: { label: 'x', basis: compareTo, values: sales({ sellInUnits: 40_000 }) },
    };
    expect(tile(salesFigures(result, windows(AUGUST, compareTo)), 'Sell-in, units')?.comparedTo).toBe(
      'vs 40,000 · other territory',
    );
  });

  describe('the attainment tile (rule 9)', () => {
    it('is omitted for a part-month, even if a target somehow came back', () => {
      const figures = salesFigures(
        sales({ months: [], targetUnits: null, attainmentPct: null }),
        windows(MTD),
      );
      expect(tile(figures, 'Target attainment')).toBeUndefined();
      expect(tile(figures, 'Sell-in, units')).toBeDefined();

      // Defence in depth: the tile keys off `months` itself, not only the nulls.
      const inconsistent = salesFigures(sales({ months: [] }), windows(MTD));
      expect(tile(inconsistent, 'Target attainment')).toBeUndefined();
    });

    it('is omitted when no target is set — a null target is not zero', () => {
      const figures = salesFigures(sales({ targetUnits: null, attainmentPct: null }), windows(AUGUST));
      expect(tile(figures, 'Target attainment')).toBeUndefined();
      expect(JSON.stringify(figures)).not.toContain('"value":0,"unit":"pct"');
    });

    it('is omitted for a zero target, and never shows 0% from one', () => {
      const figures = salesFigures(sales({ targetUnits: 0, attainmentPct: 0 }), windows(AUGUST));
      expect(tile(figures, 'Target attainment')).toBeUndefined();
    });

    it('clamps the meter to 0–100 while keeping the real value', () => {
      const over = tile(
        salesFigures(sales({ attainmentPct: 123.4 }), windows(AUGUST)),
        'Target attainment',
      );
      expect(over).toMatchObject({ value: 123.4, meter: 100 });
    });
  });
});

describe('stockFigures', () => {
  const stock = (overrides: Partial<StockLevels> = {}): StockLevels => ({
    onShelfAvailabilityPct: 88,
    linesObserved: 400,
    outOfStockLines: 48,
    outletsWithStockout: 17,
    worstOutlets: [
      { outletId: 'o1', outletName: 'Kasi Spaza', outOfStockLines: 3, lat: 0, lng: 0 },
      { outletId: 'o2', outletName: 'Soweto Superette', outOfStockLines: 9, lat: 0, lng: 0 },
      { outletId: 'o3', outletName: 'Alpha Cash & Carry', outOfStockLines: 3, lat: 0, lng: 0 },
    ],
    truncated: false,
    ...overrides,
  });

  it('builds availability and stock-out tiles with table-driven sentiment', () => {
    const compareTo: CompareTo = { kind: 'previous_period' };
    const result = {
      ...stock(),
      comparison: {
        label: 'x',
        basis: compareTo,
        values: stock({ onShelfAvailabilityPct: 92, outletsWithStockout: 8 }),
      },
    };
    const figures = stockFigures(result, windows(AUGUST, compareTo));
    expectValid(figures);

    expect(tile(figures, 'On-shelf availability')).toEqual({
      label: 'On-shelf availability',
      value: 88,
      unit: 'pct',
      delta: { value: 4, unit: 'pts', direction: 'down', sentiment: 'warn' },
      comparedTo: "vs 92% · Jul '26",
    });
    expect(tile(figures, 'Outlets with a stock-out')).toMatchObject({
      value: 17,
      delta: { value: 9, unit: 'count', direction: 'up', sentiment: 'bad' },
    });
  });

  it('ranks outlets worst first, ties by name', () => {
    const bars = barsOf(stockFigures(stock(), windows(AUGUST)));
    expect(bars?.data).toEqual({
      title: 'Out-of-stock lines by outlet',
      comparedTo: "Aug '26",
      unit: 'count',
      items: [
        { label: 'Soweto Superette', value: 9 },
        { label: 'Alpha Cash & Carry', value: 3 },
        { label: 'Kasi Spaza', value: 3 },
      ],
    });
  });

  it('draws nothing from zero observations rather than a fabricated 0%', () => {
    expect(
      stockFigures(
        stock({ linesObserved: 0, onShelfAvailabilityPct: 0, outletsWithStockout: 0, worstOutlets: [] }),
        windows(AUGUST),
      ),
    ).toEqual([]);
  });

  it('skips the delta when the comparison window observed nothing', () => {
    const compareTo: CompareTo = { kind: 'previous_period' };
    const result = {
      ...stock(),
      comparison: {
        label: 'x',
        basis: compareTo,
        values: stock({ linesObserved: 0, onShelfAvailabilityPct: 0 }),
      },
    };
    const availability = tile(stockFigures(result, windows(AUGUST, compareTo)), 'On-shelf availability');
    expect(availability?.delta).toBeUndefined();
    expect(availability?.comparedTo).toBeUndefined();
  });

  it('draws no ranking from a single outlet', () => {
    const one = stock({ worstOutlets: [stock().worstOutlets[0]] });
    expect(barsOf(stockFigures(one, windows(AUGUST)))).toBeUndefined();
  });
});

describe('rankedBars', () => {
  it('puts the biggest fall first when higher is better, and keeps signs', () => {
    const bars = rankedBars({
      metric: 'sell_in_change',
      title: 'Change by territory',
      comparedTo: "vs Aug '25",
      unit: 'pct',
      items: [
        { label: 'Pretoria East', value: 7 },
        { label: 'Soweto', value: -31 },
        { label: 'Sandton', value: 4 },
        { label: 'Tembisa', value: -9.04 },
      ],
    });
    expect(bars).toEqual({
      title: 'Change by territory',
      comparedTo: "vs Aug '25",
      unit: 'pct',
      items: [
        { label: 'Soweto', value: -31 },
        { label: 'Tembisa', value: -9 },
        { label: 'Sandton', value: 4 },
        { label: 'Pretoria East', value: 7 },
      ],
    });
  });

  it('bounds long labels and the item count, and drops non-finite values', () => {
    const bars = rankedBars({
      metric: 'out_of_stock_lines',
      title: 't',
      comparedTo: 'c',
      unit: 'count',
      limit: 3,
      items: [
        { label: 'x'.repeat(200), value: 5 },
        { label: 'b', value: Number.NaN },
        { label: 'c', value: 4 },
        { label: 'd', value: 3 },
        { label: 'e', value: 2 },
      ],
    });
    expect(bars?.items).toHaveLength(3);
    expect(bars?.items[0].label).toHaveLength(80);
    expect(bars?.items.map((i) => i.label)).not.toContain('b');
  });
});

describe('the other pillar builders', () => {
  it('share of shelf: a tile only when facings were counted', () => {
    const base: ShareOfShelf = {
      shareOfShelfPct: 41.5,
      ourFacings: 83,
      competitorFacings: 117,
      observations: 20,
      truncated: false,
    };
    const figures = shareOfShelfFigures(base, windows(AUGUST));
    expectValid(figures);
    expect(tilesOf(figures)).toEqual([{ label: 'Share of shelf', value: 41.5, unit: 'pct' }]);
    expect(
      shareOfShelfFigures({ ...base, ourFacings: 0, competitorFacings: 0, shareOfShelfPct: 0 }, windows(AUGUST)),
    ).toEqual([]);
  });

  it('visibility compliance: two percentage tiles, none from no observations', () => {
    const base: VisibilityCompliance = {
      planogramCompliancePct: 76,
      cleanlinessScore: 4,
      highTrafficPassPct: 60,
      observations: 12,
      truncated: false,
    };
    const figures = visibilityComplianceFigures(base, windows(AUGUST));
    expectValid(figures);
    expect(tilesOf(figures).map((t) => t.label)).toEqual([
      'Planogram compliance',
      'High-traffic placement',
    ]);
    expect(visibilityComplianceFigures({ ...base, observations: 0 }, windows(AUGUST))).toEqual([]);
  });

  it('competition: presence tiles and a facings ranking', () => {
    const base: CompetitorActivity = {
      observations: 30,
      distinctCompetitorSkus: 4,
      promoterPresencePct: 20,
      topCompetitors: [
        { competitorSku: 'Rival Cola 500ml', sightings: 10, averagePrice: 12, facings: 14 },
        { competitorSku: 'Fizz 2L', sightings: 6, averagePrice: 25, facings: 30 },
        { competitorSku: 'Ghost', sightings: 1, averagePrice: 9, facings: 0 },
      ],
      truncated: false,
    };
    const figures = competitorFigures(base, windows(AUGUST));
    expectValid(figures);
    expect(barsOf(figures)?.data).toMatchObject({
      items: [
        { label: 'Fizz 2L', value: 30 },
        { label: 'Rival Cola 500ml', value: 14 },
      ],
    });
  });

  it('scorecard: score against the team, omitted when nothing was scored', () => {
    const base = {
      agentId: 'a1',
      agentName: 'Tumo',
      agentDisplayName: 'Tumo',
      agentEmail: 't@example.com',
      visits: 22,
      outletsVisited: 18,
      scoredVisits: 20,
      averageScore: 82,
      ratingBands: {},
      dimensionAverages: {},
      teamAverageScore: 71,
      deltaVsTeam: 11,
    } as AgentPerformance;

    const figures = scorecardFigures(base, windows(AUGUST));
    expectValid(figures);
    expect(tile(figures, 'Execution score')).toEqual({
      label: 'Execution score',
      value: 82,
      unit: 'pts',
      delta: { value: 11, unit: 'pts', direction: 'up', sentiment: 'good' },
      comparedTo: "vs team 71 · Aug '26",
    });

    const unscored = scorecardFigures(
      { ...base, scoredVisits: 0, averageScore: 0 },
      windows(AUGUST),
    );
    expect(tile(unscored, 'Execution score')).toBeUndefined();
    expect(tile(unscored, 'Visits')).toMatchObject({ value: 22 });
  });
});

describe('validateFigure', () => {
  it('rejects unknown types, extra fields, and out-of-range meters', () => {
    expect(validateFigure({ type: 'pie_chart', data: {} }).ok).toBe(false);
    expect(validateFigure({ type: 'toString', data: {} }).ok).toBe(false);
    expect(
      validateFigure({
        type: 'stat_tiles',
        data: { tiles: [{ label: 'x', value: 1, unit: 'units', meter: 140 }] },
      }).ok,
    ).toBe(false);
    expect(
      validateFigure({
        type: 'stat_tiles',
        data: { tiles: [{ label: 'x', value: 1, unit: 'units', html: '<b>' }] },
      }).ok,
    ).toBe(false);
    expect(
      validateFigure({
        type: 'ranked_bars',
        data: { title: 't', comparedTo: 'c', unit: 'pct', items: [{ label: 'a', value: 1 }] },
      }).ok,
    ).toBe(true);
  });
});

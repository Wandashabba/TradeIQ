import {
  buildTile,
  comparisonLabel,
  formatPeriodLabel,
  rankedBars,
  type FigureArtifact,
  type FigureWindows,
  type RankedBars,
  type StatTile,
} from './figures';
import type {
  AlertSummary,
  CampaignPerformance,
  PriceCompliance,
  SellInForecast,
  TaskSummary,
} from './operations.service';

/**
 * Stat tiles and ranked bars for the operational tools (#362).
 *
 * Same rules as `figures.ts`, whose building blocks these use: pure, no new
 * queries, and a card the result cannot honestly fill is left out rather than
 * drawn with zeros.
 */

const tiles = (list: StatTile[]): FigureArtifact[] =>
  // Every operations figure is the tenant's own data, so the run is internal
  // and says so explicitly rather than by omission (#406).
  list.length > 0 ? [{ type: 'stat_tiles', data: { tiles: list, outsideData: false } }] : [];

const bars = (value: RankedBars | null): FigureArtifact[] =>
  value ? [{ type: 'ranked_bars', data: value }] : [];

const finite = (value: unknown): value is number => typeof value === 'number' && Number.isFinite(value);

/** Pricing: average deviation and breach share, and the outlets furthest from RRP. */
export function priceComplianceFigures(
  result: PriceCompliance,
  windows: FigureWindows,
): FigureArtifact[] {
  if (!(result.pricedLines > 0)) return [];
  const before = (result as { comparison?: { values?: Partial<PriceCompliance> } }).comparison?.values;
  const usable = finite(before?.pricedLines) && before.pricedLines > 0;
  const against = comparisonLabel(windows);

  const out = tiles([
    buildTile({
      metric: 'price_deviation',
      label: 'Avg price vs RRP',
      value: result.avgDeviationPct,
      unit: 'pct',
      baseline: usable ? before!.avgDeviationPct : null,
      baselineLabel: against,
      // Priced lines: the mean's own denominator (#387).
      sampleSize: result.pricedLines,
      baselineSampleSize: usable ? before!.pricedLines! : null,
    }),
    buildTile({
      metric: 'price_breach_lines',
      label: `Lines >${result.thresholdPct}% above RRP`,
      value: result.linesAboveThresholdPct,
      unit: 'pct',
      baseline: usable ? before!.linesAboveThresholdPct : null,
      baselineLabel: against,
      sampleSize: result.pricedLines,
      baselineSampleSize: usable ? before!.pricedLines! : null,
    }),
  ]);

  const ranking = rankedBars({
    metric: 'price_deviation',
    title: 'Price vs RRP by outlet',
    comparedTo: formatPeriodLabel(windows.current, windows.timeZone),
    unit: 'pct',
    items: result.worstOutlets.map((o) => ({
      label: o.outletName,
      value: o.avgDeviationPct,
      // Priced lines at THIS outlet: a "worst offender" built from one line is
      // not the same claim as one built from forty.
      sampleSize: o.lines,
    })),
    sampleSize: result.pricedLines,
  });
  return [...out, ...bars(ranking)];
}

/**
 * Campaigns: one measured campaign draws its tiles; several draw their lift
 * side by side — ended campaigns only, since a running campaign's lift is not
 * comparable yet and a bar would present it as if it were.
 */
export function campaignFigures(result: CampaignPerformance): FigureArtifact[] {
  const measured = result.campaigns.filter((c) => c.performance !== null);

  if (measured.length === 1) {
    const c = measured[0];
    const p = c.performance!;
    const list: StatTile[] = [];
    if (p.liftComparable && finite(p.liftPct)) {
      list.push(
        buildTile({ metric: 'campaign_lift', label: 'Sell-in lift vs baseline', value: p.liftPct, unit: 'pct' }),
      );
    }
    if (p.liftComparable && finite(p.roi.roiPct)) {
      list.push(buildTile({ metric: 'campaign_roi', label: 'Return on budget', value: p.roi.roiPct, unit: 'pct' }));
    }
    if (p.execution.outletsTotal > 0) {
      list.push(
        buildTile({
          metric: 'outlets_visited',
          label: 'Campaign outlets visited',
          value: p.execution.visitCoverageRate,
          unit: 'pct',
          meter: p.execution.visitCoverageRate,
          // Outlets in the campaign's scope — the coverage rate's denominator.
          sampleSize: p.execution.outletsTotal,
        }),
      );
    }
    if (p.execution.outletsVisited > 0) {
      list.push(
        buildTile({
          metric: 'planogram_compliance',
          label: 'Planogram compliance',
          value: p.execution.avgPlanogramCompliancePct,
          unit: 'pct',
          meter: p.execution.avgPlanogramCompliancePct,
          // Only the outlets that were actually visited can be scored.
          sampleSize: p.execution.outletsVisited,
        }),
      );
    }
    return tiles(list);
  }

  const ended = measured.filter((c) => c.performance!.liftComparable && finite(c.performance!.liftPct));
  return bars(
    rankedBars({
      metric: 'campaign_lift',
      title: 'Campaign sell-in lift vs baseline',
      comparedTo: 'vs the equal period before each',
      unit: 'pct',
      items: ended.map((c) => ({ label: c.name, value: c.performance!.liftPct as number })),
      // Campaigns compared, not rows: the bars ARE the sample.
      sampleSize: ended.length,
    }),
  );
}

/** Tasks: the backlog now, and where the overdue ones sit. */
export function taskFigures(result: TaskSummary): FigureArtifact[] {
  const out = tiles([
    buildTile({
      metric: 'open_tasks',
      label: 'Open tasks',
      value: result.backlog.open + result.backlog.inProgress,
      unit: 'count',
    }),
    buildTile({ metric: 'overdue_tasks', label: 'Overdue tasks', value: result.backlog.overdue, unit: 'count' }),
  ]);
  const ranking = rankedBars({
    metric: 'overdue_tasks',
    title: 'Overdue tasks by territory',
    comparedTo: 'as of now',
    unit: 'count',
    items: result.overdueByTerritory.map((t) => ({
      label: t.territoryName ?? t.territoryCode,
      value: t.overdue,
    })),
  });
  return [...out, ...bars(ranking)];
}

/** Alerts: raised and still open, and the outlets with the most open. */
export function alertFigures(result: AlertSummary): FigureArtifact[] {
  if (!(result.raised > 0)) return [];
  const out = tiles([
    buildTile({ metric: 'alerts_raised', label: 'Alerts raised', value: result.raised, unit: 'count' }),
    buildTile({
      metric: 'unacknowledged_alerts',
      label: 'Unacknowledged',
      value: result.unacknowledged,
      unit: 'count',
    }),
  ]);
  const ranking = rankedBars({
    metric: 'unacknowledged_alerts',
    title: 'Unacknowledged alerts by outlet',
    comparedTo: 'still open',
    unit: 'count',
    items: result.topOutlets.map((o) => ({ label: o.outletName, value: o.unacknowledged })),
  });
  return [...out, ...bars(ranking)];
}

/** Forecast: expected daily sell-in and days of cover. Nothing from a history of no orders. */
export function forecastFigures(result: SellInForecast): FigureArtifact[] {
  if (!(result.daysWithOrders > 0)) return [];
  const list: StatTile[] = [
    buildTile({
      metric: 'forecast_units',
      label: 'Forecast sell-in / day',
      value: result.forecastDailyUnits,
      unit: 'units',
      comparedTo: `smoothed from ${result.historyDays} days`,
      // Days that actually carried an order. A forecast smoothed from two
      // ordering days inside a 90-day window is the low-sample case exactly.
      sampleSize: result.daysWithOrders,
    }),
  ];
  if (finite(result.daysOfCover)) {
    list.push(buildTile({ metric: 'days_of_cover', label: 'Days of cover', value: result.daysOfCover, unit: 'count' }));
  }
  return tiles(list);
}

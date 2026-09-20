import 'package:flutter/material.dart' show showDateRangePicker, DateTimeRange;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/period_label.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/figure/chart/chart.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../data/trends_repository.dart';

/// TRENDS — three series over time, or every territory against the client.
///
/// ```text
///   Trends                                          [ ⟳ ]
///   Server-side buckets — weeks start Monday, UTC.
///   (Over time)(Compare territories) | (Daily)(Weekly) | (Custom range)
///   ── Scorecard trend ───────────────── (Chart)(Table)
///   ── Gauteng North  ─  ─  Client average ─────────────
///   ┌──────────────────────────────────────────────────┐
///   │                            ╭──────               │
///   │      ╭─────╮ ╭──          ╭╯                     │
///   │─ ─ ─╯─ ─ ─ ╰╯─ ─ ─ ─ ─ ─ ─╯─ ─ ─ ─ ─ Target 70   │
///   └──────────────────────────────────────────────────┘
///   W26                                            W38
///   [ nav pill ]
/// ```
///
/// ## The chart is never the only way to read a value
///
/// Every panel carries a **table twin** behind a two-chip toggle, and it is
/// not a debug view: it is what a screen reader gets, what a printer gets, and
/// what **Veld** gets, because Veld draws no charts at all (unify §4). The
/// twin carries the unabbreviated period — the axis says `W26` because it has
/// 40dp; the table says `2026-W26` because a manager quoting a week into a
/// spreadsheet needs the year.
///
/// ## An empty window is a designed state
///
/// `/trends/*` omits an empty bucket rather than sending a zero, so a window
/// with nothing in it comes back as an empty list — not a flat line at zero,
/// which is what a chart that filled the gap would draw. The panel says so in
/// words and draws no plot.
///
/// ## The amber, counted
///
/// A tab root reached from the Menu, so the nav's active tab is slot 1 and the
/// content has one grant left. **Every phase declines it.** The chart-focus
/// rung is real and the comparison view is the one place in this product where
/// the ladder would grant it — but three charts on one route is three focus
/// objects asking, the budget is counted per route rather than per viewport,
/// and a grant that released on scroll is a grant that blinks. The subject
/// series is carried by weight, by a solid stroke against a dashed one and by
/// the legend's word instead. Day and Veld: zero, on every phase.
class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final view = ref.watch(trendsViewProvider);
    final gutter = context.skin.space.gutter;

    return ConsoleFrame(
      phase: view == TrendsView.compareTerritories ? 'compare' : 'over-time',
      active: ConsoleSlot.menu,
      header: TorchAppHeader(
        title: l10n.trendsTitle,
        facts: <String>[l10n.trendsFact],
      ),
      children: <Widget>[
        TorchBleed(extra: gutter * 2, child: const _TrendFilters()),
        SizedBox(height: context.skin.space.blockGap),
        if (view == TrendsView.compareTerritories)
          const _TerritoryBenchmarkPanel(
            key: ValueKey<String>('trend-benchmark'),
          )
        else ...<Widget>[
          _TrendPanel(
            key: const ValueKey<String>('trend-scorecards'),
            heading: l10n.trendScorecards,
            seriesName: l10n.trendScorecardsSeries,
            provider: scorecardsTrendProvider,
          ),
          SizedBox(height: context.skin.space.blockGap),
          _TrendPanel(
            key: const ValueKey<String>('trend-availability'),
            heading: l10n.trendAvailability,
            seriesName: l10n.trendAvailabilitySeries,
            provider: availabilityTrendProvider,
            unit: TiqUnit.percent,
          ),
          SizedBox(height: context.skin.space.blockGap),
          _TrendPanel(
            key: const ValueKey<String>('trend-perfect-store'),
            heading: l10n.trendPerfectStore,
            seriesName: l10n.trendPerfectStoreSeries,
            provider: perfectStoreTrendProvider,
            unit: TiqUnit.percent,
          ),
        ],
      ],
    );
  }
}

/// One series, as a chart or as its table twin.
class _TrendPanel extends ConsumerStatefulWidget {
  const _TrendPanel({
    super.key,
    required this.heading,
    required this.seriesName,
    required this.provider,
    this.unit = TiqUnit.none,
  });

  final String heading;
  final String seriesName;
  final FutureProvider<List<TrendPoint>> provider;
  final TiqUnit unit;

  @override
  ConsumerState<_TrendPanel> createState() => _TrendPanelState();
}

class _TrendPanelState extends ConsumerState<_TrendPanel> {
  bool _asTable = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(widget.provider);
    // Veld draws no chart, so the toggle would be a control with one working
    // position. The table is simply what Veld shows.
    final veld = context.skin.mode == SkinMode.veld;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule(widget.heading),
        const SizedBox(height: TiqSpace.s3),
        if (!veld) ...<Widget>[
          _ViewToggle(
            asTable: _asTable,
            onChanged: (v) => setState(() => _asTable = v),
          ),
          const SizedBox(height: TiqSpace.s4),
        ],
        async.when(
          loading: () => Skeleton(
            label: widget.heading,
            slowLine: l10n.torchStillFetching,
            child: SkeletonShell(
              height: veld ? 120 : trendChartHeight(context),
            ),
          ),
          error: (error, _) => TorchErrorRegion(
            name: widget.heading,
            child: ErrorState(
              scope: ErrorScope.inline,
              message: TorchErrorMessage.sanitise(error),
              action: TorchTertiaryButton(
                key: ValueKey<String>('${widget.heading}-retry'),
                label: l10n.torchTryAgain,
                onPressed: () => ref.invalidate(widget.provider),
              ),
            ),
          ),
          data: (points) {
            if (points.isEmpty) {
              // Not "every bucket scored 0" — the server omits an empty
              // bucket, so nothing in this window was measured at all.
              return EmptyState(
                scope: EmptyScope.inPanel,
                headline: l10n.trendsEmptyHeadline,
                body: l10n.trendsEmptyBody,
              );
            }
            final series = ChartSeries(
              name: widget.seriesName,
              readings: <ChartReading>[
                for (final p in points)
                  ChartReading(
                    label: formatPeriodLabel(p.period),
                    longLabel: p.period,
                    value: p.value,
                    sampleSize: p.count,
                  ),
              ],
            );
            final table = TableTwin(
              series: <ChartSeries>[series],
              unit: widget.unit,
              periodHeading: l10n.trendsPeriod,
              notMeasuredWord: l10n.trendsNotMeasured,
              semanticsLabel: widget.heading,
            );
            if (veld || _asTable) return table;
            return TrendChart(
              series: <ChartSeries>[series],
              unit: widget.unit,
              decimals: 1,
              semanticsLabel: l10n.trendsChartHint(
                widget.heading,
                points.length,
              ),
              notMeasuredWord: l10n.trendsNotMeasured,
              scrubHint: l10n.trendsScrubHint,
            );
          },
        ),
      ],
    );
  }
}

/// Chart or table. Two filter chips, which is the one selected vocabulary in
/// this system: lifted fill, a 1px ink-1 border, a tick and weight 700 —
/// three channels, and never amber on any screen in any skin.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.asTable, required this.onChanged});

  final bool asTable;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TorchFilterRail(
        semanticsLabel: l10n.trendsViewAs,
        chips: <Widget>[
          TorchFilterChip(
            key: const ValueKey<String>('view-chart'),
            label: l10n.trendsAsChart,
            selected: !asTable,
            onSelected: () => onChanged(false),
          ),
          TorchFilterChip(
            key: const ValueKey<String>('view-table'),
            label: l10n.trendsAsTable,
            selected: asTable,
            onSelected: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

/// One filter rail scoping every chart below it — view, bucket and window.
///
/// A per-panel range control would let two charts silently disagree about
/// which slice of time they show, which is worse than no control at all. The
/// territory comparison reads the same rail for the same reason.
class _TrendFilters extends ConsumerWidget {
  const _TrendFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final query = ref.watch(trendQueryProvider);
    final view = ref.watch(trendsViewProvider);

    void update(TrendQuery next) =>
        ref.read(trendQueryProvider.notifier).set(next);

    Future<void> pickRange() async {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
        initialDateRange: query.from != null && query.to != null
            ? DateTimeRange(start: query.from!, end: query.to!)
            : null,
      );
      if (range != null) {
        update(
          TrendQuery(
            interval: query.interval,
            from: range.start,
            to: range.end,
          ),
        );
      }
    }

    return TorchFilterRail(
      semanticsLabel: l10n.trendsFilters,
      chips: <Widget>[
        for (final (label, option) in <(String, TrendsView)>[
          (l10n.trendsOverTime, TrendsView.overTime),
          (l10n.trendsCompare, TrendsView.compareTerritories),
        ])
          TorchFilterChip(
            key: ValueKey<String>('trends-view-${option.name}'),
            label: label,
            selected: option == view,
            onSelected: () => ref.read(trendsViewProvider.notifier).set(option),
          ),
        for (final interval in TrendInterval.values)
          TorchFilterChip(
            key: ValueKey<String>('interval-${interval.name}'),
            label: interval == TrendInterval.day
                ? l10n.trendsDaily
                : l10n.trendsWeekly,
            selected: interval == query.interval,
            onSelected: () => update(
              TrendQuery(interval: interval, from: query.from, to: query.to),
            ),
          ),
        TorchFilterChip(
          key: const ValueKey<String>('trend-daterange'),
          // Null is not "all time" — it is the server's own default lookback.
          // Say that, rather than implying a range nobody asked for.
          label: query.isRanged
              ? l10n.trendsCustomRange
              : l10n.trendsServerDefault,
          selected: query.isRanged,
          onSelected: pickRange,
        ),
        if (query.isRanged)
          TorchFilterChip(
            key: const ValueKey<String>('trend-clear'),
            label: l10n.trendsClearRange,
            selected: false,
            onSelected: () => update(TrendQuery(interval: query.interval)),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Compare territories — every territory of the client against the client's
// own average. Cross-client benchmarks are deliberately absent.
// ═══════════════════════════════════════════════════════════════════════

class _TerritoryBenchmarkPanel extends ConsumerStatefulWidget {
  const _TerritoryBenchmarkPanel({super.key});

  @override
  ConsumerState<_TerritoryBenchmarkPanel> createState() =>
      _TerritoryBenchmarkPanelState();
}

class _TerritoryBenchmarkPanelState
    extends ConsumerState<_TerritoryBenchmarkPanel> {
  /// The territory drawn in the chart. Null means the top-ranked one.
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metric = ref.watch(benchmarkMetricProvider);
    final gutter = context.skin.space.gutter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule(l10n.trendsCompare),
        const SizedBox(height: TiqSpace.s3),
        TorchBleed(
          extra: gutter * 2,
          child: TorchFilterRail(
            semanticsLabel: l10n.trendsMetric,
            chips: <Widget>[
              for (final option in BenchmarkMetric.values)
                TorchFilterChip(
                  key: ValueKey<String>('benchmark-metric-${option.name}'),
                  label: _metricLabel(l10n, option),
                  selected: option == metric,
                  onSelected: () =>
                      ref.read(benchmarkMetricProvider.notifier).set(option),
                ),
            ],
          ),
        ),
        SizedBox(height: context.skin.space.blockGap),
        ref
            .watch(territoryBenchmarkProvider)
            .when(
              loading: () => Skeleton(
                label: l10n.trendsCompare,
                slowLine: l10n.torchStillFetching,
                child: const SkeletonRows(count: 3, rowHeight: 80),
              ),
              error: (error, _) => TorchErrorRegion(
                name: 'territory comparison',
                child: ErrorState(
                  message: TorchErrorMessage.sanitise(error),
                  action: TorchSecondaryButton(
                    key: const ValueKey<String>('benchmark-retry'),
                    label: l10n.torchTryAgain,
                    onPressed: () => ref.invalidate(territoryBenchmarkProvider),
                  ),
                ),
              ),
              data: _body,
            ),
      ],
    );
  }

  Widget _body(TerritoryBenchmarkReport report) {
    final l10n = context.l10n;
    if (report.territories.isEmpty) {
      return EmptyState(
        scope: EmptyScope.inPanel,
        headline: l10n.trendsNoTerritoriesHeadline,
        body: l10n.trendsNoTerritoriesBody,
      );
    }
    final clientAverage = report.client.average;
    if (clientAverage == null) {
      // Not "every territory scored 0" — nothing was measured at all.
      return EmptyState(
        scope: EmptyScope.inPanel,
        headline: l10n.trendsEmptyHeadline,
        body: l10n.trendsCompareEmptyBody,
      );
    }
    final selected = report.territories.firstWhere(
      (t) => t.territoryId == _selectedId,
      orElse: () => report.territories.first,
    );
    final gutter = context.skin.space.gutter;
    final unit = report.isPercent ? TiqUnit.percent : TiqUnit.none;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _ClientAverage(report: report, average: clientAverage, unit: unit),
        SizedBox(height: context.skin.space.blockGap),
        TorchBleed(
          extra: gutter * 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = 0; i < report.territories.length; i++)
                _BenchmarkRow(
                  key: ValueKey<String>(
                    'benchmark-row-${report.territories[i].territoryId}',
                  ),
                  territory: report.territories[i],
                  report: report,
                  clientAverage: clientAverage,
                  unit: unit,
                  selected:
                      report.territories[i].territoryId == selected.territoryId,
                  last: i == report.territories.length - 1,
                  onTap: () => setState(
                    () => _selectedId = report.territories[i].territoryId,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: context.skin.space.blockGap),
        _BenchmarkChart(territory: selected, report: report, unit: unit),
      ],
    );
  }
}

/// The client's own line, as a figure with the sentence that qualifies it.
class _ClientAverage extends StatelessWidget {
  const _ClientAverage({
    required this.report,
    required this.average,
    required this.unit,
  });

  final TerritoryBenchmarkReport report;
  final double average;
  final TiqUnit unit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final target = report.target;
    final unassigned = report.unassignedCount;

    return StatCluster(
      semanticsLabel: l10n.trendsClientAverage,
      tiles: <StatTile>[
        StatTile(
          key: const ValueKey<String>('benchmark-client-average'),
          eyebrow: l10n.trendsClientAverage,
          value: average,
          unit: unit,
          meter: target == null
              ? null
              : MeterData(value: average, maximum: 100, target: target),
          stateLine: unassigned > 0
              ? l10n.trendsUnassignedNote(
                  _samples(l10n, report.metric, unassigned),
                )
              : null,
        ),
        // The configured standard is a tile of its own rather than a
        // parenthesis: it is a different fact about a different thing, and a
        // territory is read against both.
        if (target != null)
          StatTile(
            key: const ValueKey<String>('benchmark-target'),
            eyebrow: report.targetLabel ?? l10n.trendsTarget,
            value: target,
            unit: unit,
          ),
      ],
    );
  }
}

/// One territory against the client line.
class _BenchmarkRow extends StatelessWidget {
  const _BenchmarkRow({
    super.key,
    required this.territory,
    required this.report,
    required this.clientAverage,
    required this.unit,
    required this.selected,
    required this.last,
    required this.onTap,
  });

  final TerritoryBenchmark territory;
  final TerritoryBenchmarkReport report;
  final double clientAverage;
  final TiqUnit unit;
  final bool selected;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final average = territory.average;
    final word = _positionWord(l10n, territory.position);
    final rank = territory.rank;

    return SoftRow(
      density: SoftRowDensity.tall,
      title: territory.territoryName,
      titleTruncation: SoftRowTruncation.middle,
      subtitle: _note(context),
      // Selection is a word in the row plus the chart's own heading beneath —
      // never a fill, which would make a list of fifteen rows a list of
      // fifteen fills with one different.
      leading: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // A rank is never invented: the server ranks, and a territory it
          // could not rank shows the em dash and says why in the note.
          FigureSlot(
            value: rank,
            role: skin.text.figureS,
            unit: TiqUnit.none,
            state: rank == null ? FigureState.missing : FigureState.measured,
            semanticsLabel: rank == null ? l10n.trendsUnranked : null,
          ),
        ],
      ),
      meta: average == null
          ? null
          : Meter(
              value: average,
              maximum: 100,
              target: clientAverage,
              semanticsValue: l10n.trendsMeterHint(
                territory.territoryName,
                average.round(),
                clientAverage.round(),
              ),
            ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (selected)
            Text(
              l10n.trendsShowing,
              textAlign: TextAlign.end,
              style: skin.text.label.style(color: skin.palette.ink1),
            ),
          FigureSlot(
            key: ValueKey<String>('benchmark-average-${territory.territoryId}'),
            value: average,
            role: skin.text.figureS,
            unit: average == null ? TiqUnit.none : unit,
            state: average == null ? FigureState.missing : FigureState.measured,
            textAlign: TextAlign.end,
            semanticsLabel: average == null ? l10n.trendsNotMeasured : null,
          ),
          Text(
            word,
            textAlign: TextAlign.end,
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
        ],
      ),
      onTap: onTap,
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[
        territory.territoryName,
        if (rank != null) l10n.trendsRank(rank),
        word,
        _note(context),
        if (selected) l10n.trendsShowing,
      ].join('. '),
    );
  }

  String _note(BuildContext context) {
    final l10n = context.l10n;
    final average = territory.average;
    if (average == null) return l10n.trendsNothingMeasuredHere;
    final samples = _samples(l10n, report.metric, territory.count);
    final delta = territory.deltaFromClient;
    return switch (territory.position) {
      BenchmarkPosition.above when delta != null => l10n.trendsAboveBy(
        _trim(delta.abs()),
        samples,
      ),
      BenchmarkPosition.below when delta != null => l10n.trendsBelowBy(
        _trim(delta.abs()),
        samples,
      ),
      _ => l10n.trendsLevelWith(samples),
    };
  }
}

/// The selected territory's series against the client line.
///
/// The two runs are aligned on the **union** of their periods, with a null
/// wherever one of them has no bucket. The old chart aligned by position and
/// cut the client line to the territory's own length, which put a territory's
/// week 38 alongside the client's week 37 the moment the territory lost a week
/// — a comparison against the wrong week, drawn as if it were the right one.
class _BenchmarkChart extends StatelessWidget {
  const _BenchmarkChart({
    required this.territory,
    required this.report,
    required this.unit,
  });

  final TerritoryBenchmark territory;
  final TerritoryBenchmarkReport report;
  final TiqUnit unit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final periods = <String>{
      for (final p in territory.points) p.period,
      for (final p in report.client.points) p.period,
    }.toList()..sort();

    if (periods.isEmpty) {
      return EmptyState(
        scope: EmptyScope.inPanel,
        headline: l10n.trendsEmptyHeadline,
        body: l10n.trendsCompareEmptyBody,
      );
    }

    double? valueAt(List<TrendPoint> points, String period) {
      for (final p in points) {
        if (p.period == period) return p.value;
      }
      return null;
    }

    List<ChartReading> readings(List<TrendPoint> points) => <ChartReading>[
      for (final period in periods)
        ChartReading(
          label: formatPeriodLabel(period),
          longLabel: period,
          value: valueAt(points, period),
        ),
    ];

    final subject = ChartSeries(
      name: territory.territoryName,
      readings: readings(territory.points),
    );
    final comparison = ChartSeries(
      name: l10n.trendsClientAverage,
      role: ChartSeriesRole.comparison,
      readings: readings(report.client.points),
    );
    final gaps = subject.gaps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule(l10n.trendsAgainstClient(territory.territoryName)),
        const SizedBox(height: TiqSpace.s4),
        if (context.skin.mode == SkinMode.veld)
          TableTwin(
            series: <ChartSeries>[subject, comparison],
            unit: unit,
            periodHeading: l10n.trendsPeriod,
            notMeasuredWord: l10n.trendsNotMeasured,
            semanticsLabel: territory.territoryName,
          )
        else
          TrendChart(
            key: const ValueKey<String>('benchmark-chart'),
            series: <ChartSeries>[subject, comparison],
            unit: unit,
            decimals: 1,
            threshold: report.target == null
                ? null
                : ChartThreshold(
                    value: report.target!,
                    label: report.targetLabel ?? l10n.trendsTarget,
                  ),
            semanticsLabel: l10n.trendsChartHint(
              territory.territoryName,
              periods.length,
            ),
            notMeasuredWord: l10n.trendsNotMeasured,
            gapNote: gaps == 0 ? null : l10n.trendsGapNote(gaps),
            scrubHint: l10n.trendsScrubHint,
            veldReplacement: null,
          ),
      ],
    );
  }
}

String _metricLabel(AppLocalizations l10n, BenchmarkMetric metric) =>
    switch (metric) {
      BenchmarkMetric.scorecards => l10n.trendsMetricScore,
      BenchmarkMetric.perfectStore => l10n.trendsMetricPerfectStore,
      BenchmarkMetric.availability => l10n.trendsMetricAvailability,
      BenchmarkMetric.shareOfShelf => l10n.trendsMetricShareOfShelf,
    };

String _positionWord(AppLocalizations l10n, BenchmarkPosition? position) =>
    switch (position) {
      BenchmarkPosition.above => l10n.trendsAboveAverage,
      BenchmarkPosition.below => l10n.trendsBelowAverage,
      BenchmarkPosition.level => l10n.trendsAtAverage,
      null => l10n.trendsNotMeasured,
    };

String _samples(AppLocalizations l10n, BenchmarkMetric metric, int count) =>
    switch (metric) {
      BenchmarkMetric.scorecards ||
      BenchmarkMetric.perfectStore => l10n.trendsSamplesScorecards(count),
      BenchmarkMetric.availability => l10n.trendsSamplesStockLines(count),
      BenchmarkMetric.shareOfShelf => l10n.trendsSamplesFacings(count),
    };

/// Drops a trailing `.0` so a delta reads `4` rather than `4.0`.
///
/// It is a **sentence** fragment, not a figure in a data role — the figures on
/// this screen all go through `FigureSlot`, and this is the number inside
/// "4 points above the client average".
String _trim(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

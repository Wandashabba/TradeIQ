import 'package:flutter/material.dart' show showDateRangePicker, DateTimeRange;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tiq_number.dart';
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
            // A mean of weighted scores, so n >= 3 — not a rate.
            kind: MetricKind.average,
          ),
          SizedBox(height: context.skin.space.blockGap),
          _TrendPanel(
            key: const ValueKey<String>('trend-availability'),
            heading: l10n.trendAvailability,
            seriesName: l10n.trendAvailabilitySeries,
            provider: availabilityTrendProvider,
            unit: TiqUnit.percent,
            kind: MetricKind.rate,
          ),
          SizedBox(height: context.skin.space.blockGap),
          _TrendPanel(
            key: const ValueKey<String>('trend-perfect-store'),
            heading: l10n.trendPerfectStore,
            seriesName: l10n.trendPerfectStoreSeries,
            provider: perfectStoreTrendProvider,
            unit: TiqUnit.percent,
            kind: MetricKind.rate,
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
    required this.kind,
    this.unit = TiqUnit.none,
  });

  final String heading;
  final String seriesName;
  final FutureProvider<List<TrendPoint>> provider;
  final TiqUnit unit;

  /// What kind of quantity this series is, for the sample threshold. A bucket
  /// with too few rows behind it is drawn at ink-2 rather than at full
  /// commitment — unify line 271, and the reason `ChartReading.sampleSize`
  /// exists at all.
  final MetricKind kind;

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
                    sampleSize: _sampleN(p.count),
                  ),
              ],
            );
            final table = TableTwin(
              series: <ChartSeries>[series],
              unit: widget.unit,
              periodHeading: l10n.trendsPeriod,
              notMeasuredWord: l10n.trendsNotMeasured,
              sampleKind: widget.kind,
              lowSampleWord: l10n.trendsSmallSample,
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
              dashedWord: l10n.trendsDashed,
              sampleKind: widget.kind,
              lowSampleWord: l10n.trendsSmallSample,
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

  /// Chart or table. This pane has the same toggle the over-time panels have,
  /// and it is not a nicety: the plot's only other way in is a horizontal
  /// drag-scrub, which a screen reader cannot perform and a printed page does
  /// not carry — and `trendsChartHint` sends the reader to "the table view",
  /// which has to exist.
  bool _asTable = false;

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
        _BenchmarkChart(
          territory: selected,
          report: report,
          unit: unit,
          asTable: _asTable,
          onViewChanged: (v) => setState(() => _asTable = v),
        ),
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
    final n = _sampleN(report.client.count);
    // The client line is computed from `client.count` rows, and a client line
    // off two scorecards is not a line anybody should be ranked against. The
    // tile steps to ink-2, outlines the meter fill and drops the delta.
    final sampling = FigureSampling(kind: _metricKind(report.metric), n: n);

    return StatCluster(
      semanticsLabel: l10n.trendsClientAverage,
      tiles: <StatTile>[
        StatTile(
          key: const ValueKey<String>('benchmark-client-average'),
          eyebrow: l10n.trendsClientAverage,
          value: average,
          unit: unit,
          sampling: sampling,
          // The kit's own default is `from $n`, which is English. The count
          // is already in this screen's vocabulary — "2 scorecards" — so the
          // screen hands it over rather than letting the kit invent one.
          sampleNote: n == null ? null : _samples(l10n, report.metric, n),
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

  /// What this territory's own figure was computed from. `count` is the wire's
  /// row count — scorecards, stock lines, visits with facings — and a count
  /// below the metric's threshold is the whole reason this getter exists.
  FigureSampling get _sampling => FigureSampling(
    kind: _metricKind(report.metric),
    n: _sampleN(territory.count),
  );

  /// A real figure computed off too few rows. Not the same as no figure: the
  /// number is arithmetically true and epistemically worthless, so it is drawn
  /// at ink-2 with the fill outlined and **the verdict taken off it**.
  bool get _thin => territory.average != null && _sampling.isLowSample;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final average = territory.average;
    // "Above average" is a delta wearing a word. A delta never stands beside
    // a figure this thin, so neither does the word.
    final word = _thin
        ? l10n.trendsSmallSample
        : _positionWord(l10n, territory.position);
    final rank = territory.rank;

    return SoftRow(
      density: SoftRowDensity.tall,
      title: territory.territoryName,
      titleTruncation: SoftRowTruncation.middle,
      subtitle: _note(context),
      // Selection is a word in the row plus the chart's own heading beneath —
      // never a fill, which would make a list of fifteen rows a list of
      // fifteen fills with one different.
      // A rank is never invented: the server ranks, and a territory it could
      // not rank shows the em dash and says why in the note.
      leading: FigureSlot(
        value: rank,
        role: skin.text.figureS,
        unit: TiqUnit.none,
        state: rank == null ? FigureState.missing : FigureState.measured,
        semanticsLabel: rank == null ? l10n.trendsUnranked : null,
      ),
      meta: average == null
          ? null
          // Outline against fill, not a paler fill: a shape distinction is the
          // one that survives greyscale, sun and deuteranopia.
          : Meter(
              value: average,
              maximum: 100,
              target: clientAverage,
              state: _thin ? MeterState.lowSample : MeterState.filled,
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
            state: average == null
                ? FigureState.missing
                : _thin
                ? FigureState.lowSample
                : FigureState.measured,
            textAlign: TextAlign.end,
            // The figure AND its qualification in one utterance. A reader who
            // hears "92 percent" and only then, a beat later, "small sample"
            // has already acted on the first half.
            semanticsLabel: average == null
                ? l10n.trendsNotMeasured
                : _thin
                ? '${TiqNumber.of(context).format(average, unit: unit)}, '
                      '${l10n.trendsSmallSample}'
                : null,
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
    // unify line 271: low sample removes the delta. "37 points above the
    // client average" off two stock lines is a hard verdict computed from two
    // observations, drawn exactly like one computed from two hundred, and it
    // is the kind of number an agent gets reassigned over.
    if (_thin) return l10n.trendsTooFewToCompare(samples);
    final delta = territory.deltaFromClient;
    // Through TiqNumber even inside a sentence. `toStringAsFixed` writes the C
    // locale's decimal point, so "4,5 punte" would read "4.5 punte" on an
    // Afrikaans phone — the one thing a formatter exists to stop.
    final numbers = TiqNumber.of(context);
    return switch (territory.position) {
      BenchmarkPosition.above when delta != null => l10n.trendsAboveBy(
        numbers.format(delta.abs()),
        samples,
      ),
      BenchmarkPosition.below when delta != null => l10n.trendsBelowBy(
        numbers.format(delta.abs()),
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
    required this.asTable,
    required this.onViewChanged,
  });

  final TerritoryBenchmark territory;
  final TerritoryBenchmarkReport report;
  final TiqUnit unit;

  /// Whether the reader asked for the table. Veld ignores it and shows the
  /// table regardless, because Veld draws no plot at all.
  final bool asTable;
  final ValueChanged<bool> onViewChanged;

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

    // Looked up BY PERIOD, never by position: a territory that lost a week
    // must get a hole, not a shifted line.
    List<ChartReading> readings(List<TrendPoint> points) {
      final byPeriod = <String, TrendPoint>{
        for (final p in points) p.period: p,
      };
      return <ChartReading>[
        for (final period in periods)
          ChartReading(
            label: formatPeriodLabel(period),
            longLabel: period,
            value: byPeriod[period]?.value,
            sampleSize: _sampleN(byPeriod[period]?.count ?? 0),
          ),
      ];
    }

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
    final veld = context.skin.mode == SkinMode.veld;
    final kind = _metricKind(report.metric);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule(l10n.trendsAgainstClient(territory.territoryName)),
        // Veld draws no plot, so the toggle would be a control with one
        // working position — the same reasoning as the over-time panels.
        if (veld)
          const SizedBox(height: TiqSpace.s4)
        else ...<Widget>[
          const SizedBox(height: TiqSpace.s3),
          _ViewToggle(asTable: asTable, onChanged: onViewChanged),
          const SizedBox(height: TiqSpace.s4),
        ],
        if (veld || asTable)
          TableTwin(
            key: const ValueKey<String>('benchmark-table'),
            series: <ChartSeries>[subject, comparison],
            unit: unit,
            periodHeading: l10n.trendsPeriod,
            notMeasuredWord: l10n.trendsNotMeasured,
            sampleKind: kind,
            lowSampleWord: l10n.trendsSmallSample,
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
            dashedWord: l10n.trendsDashed,
            sampleKind: kind,
            lowSampleWord: l10n.trendsSmallSample,
            gapNote: gaps == 0 ? null : l10n.trendsGapNote(gaps),
            scrubHint: l10n.trendsScrubHint,
          ),
      ],
    );
  }
}

/// What kind of quantity a benchmark metric is, for the sample threshold.
///
/// The scorecard benchmark is a **mean of weighted scores** — the server sends
/// it with `unit: 'score'` — so it takes the average threshold of 3. The other
/// three come back as `unit: 'percent'` and are rates, which is the most
/// sample-sensitive thing this product shows: 100% off one stock line is
/// arithmetically true and epistemically worthless.
MetricKind _metricKind(BenchmarkMetric metric) => switch (metric) {
  BenchmarkMetric.scorecards => MetricKind.average,
  BenchmarkMetric.perfectStore ||
  BenchmarkMetric.availability ||
  BenchmarkMetric.shareOfShelf => MetricKind.rate,
};

/// The wire's row count as a sample size, or null.
///
/// `count` defaults to 0 when the field is absent, and the two cases are not
/// the same thing: the server omits an empty bucket rather than sending one,
/// so a point that exists always measured something and a 0 here means
/// "nobody sent a count". Passing that 0 on as `n` would mark **every** figure
/// low-sample the day the field is dropped — the low-sample rule failing in
/// the direction that looks like diligence.
int? _sampleN(int count) => count <= 0 ? null : count;

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

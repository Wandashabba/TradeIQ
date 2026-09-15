import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/period_label.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/lumen_kit.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/trends_repository.dart';

class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(trendsViewProvider);
    return ManagerScaffold(
      title: 'Trends',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Server-side buckets — weeks start Monday, UTC.',
            style: TextStyle(fontSize: 12, color: context.colors.ink3),
          ),
          const SizedBox(height: 12),
          const _TrendFilters(),
          const SizedBox(height: 12),
          if (view == TrendsView.compareTerritories)
            const _TerritoryBenchmarkPanel(key: ValueKey('trend-benchmark'))
          else ...[
            _TrendPanel(
              key: const ValueKey('trend-scorecards'),
              heading: 'Scorecard trend',
              subtitle: 'Weighted execution score',
              provider: scorecardsTrendProvider,
            ),
            const SizedBox(height: 12),
            _TrendPanel(
              key: const ValueKey('trend-availability'),
              heading: 'Availability trend',
              subtitle: 'On-shelf availability',
              provider: availabilityTrendProvider,
              suffix: '%',
            ),
            const SizedBox(height: 12),
            _TrendPanel(
              key: const ValueKey('trend-perfect-store'),
              heading: 'Perfect store trend',
              subtitle: 'Outlets passing every gate',
              provider: perfectStoreTrendProvider,
              suffix: '%',
            ),
          ],
        ],
      ),
    );
  }
}

/// A chart and its table-view twin.
///
/// The toggle is not decoration: a chart that is the *only* way to read a value
/// fails anyone using a screen reader, printing it, or checking an exact figure.
/// The table is the WCAG-clean equivalent of the same data.
class _TrendPanel extends ConsumerStatefulWidget {
  const _TrendPanel({
    super.key,
    required this.heading,
    required this.subtitle,
    required this.provider,
    this.suffix = '',
  });

  final String heading;
  final String subtitle;
  final FutureProvider<List<TrendPoint>> provider;
  final String suffix;

  @override
  ConsumerState<_TrendPanel> createState() => _TrendPanelState();
}

class _TrendPanelState extends ConsumerState<_TrendPanel> {
  bool _asTable = false;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: widget.heading,
      subtitle: widget.subtitle,
      trailing: _ViewToggle(
        asTable: _asTable,
        onChanged: (v) => setState(() => _asTable = v),
      ),
      child: AsyncSection<List<TrendPoint>>(
        value: ref.watch(widget.provider),
        label: widget.heading.toLowerCase(),
        onRetry: () => ref.invalidate(widget.provider),
        builder: (points) {
          if (points.isEmpty) {
            return const EmptyState(
              message: 'No data in range',
              hint: 'Trends fill in as visits are submitted and scored.',
            );
          }
          return _asTable
              ? _TrendTable(points: points, suffix: widget.suffix)
              : ColumnChart(
                  points: [
                    for (final p in points)
                      (label: formatPeriodLabel(p.period), value: p.value),
                  ],
                  valueSuffix: widget.suffix,
                  seriesName: widget.heading,
                );
        },
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.asTable, required this.onChanged});

  final bool asTable;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Segments(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      fontSize: 11.5,
      segments: [
        for (final (label, isTable) in const [('Chart', false), ('Table', true)])
          (
            key: ValueKey('view-${label.toLowerCase()}'),
            label: label,
            selected: isTable == asTable,
            onTap: () => onChanged(isTable),
          ),
      ],
    );
  }
}

class _TrendTable extends StatelessWidget {
  const _TrendTable({required this.points, required this.suffix});

  final List<TrendPoint> points;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Expanded(child: SectionLabel('Period')),
              SectionLabel('Value'),
            ],
          ),
        ),
        for (final p in points)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              // Glass rules are the pane's own rim, not a grey hairline.
              border: Border(
                top: BorderSide(
                  color: colors.glass ? context.lumen.panelRim : colors.line,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    p.period,
                    style: TextStyle(fontSize: 12.5, color: colors.ink2),
                  ),
                ),
                Text(
                  '${_trim(p.value)}$suffix',
                  style: _figure(context, size: 12.5),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Drops a trailing `.0` so figures read `92` rather than `92.0`.
String _trim(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// A data figure: JetBrains Mono in glass, tabular figures in the flat theme.
TextStyle _figure(BuildContext context, {double size = 14, Color? color}) {
  final colors = context.colors;
  final ink = color ?? colors.ink1;
  return colors.glass
      ? LumenGlass.figure(size: size, color: ink)
      : TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w600,
          color: ink,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
}

/// One filter row scoping every chart below it — view, interval and window.
///
/// A per-panel range control would let two charts silently disagree about which
/// slice of time they show, which is worse than no control at all. The
/// territory comparison reads through the same row for the same reason.
class _TrendFilters extends ConsumerWidget {
  const _TrendFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(trendQueryProvider);
    final view = ref.watch(trendsViewProvider);

    void update(TrendQuery next) =>
        ref.read(trendQueryProvider.notifier).set(next);

    Future<void> pickRange() async {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
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

    const segmentPadding = EdgeInsets.symmetric(horizontal: 11, vertical: 5);

    return FilterRow(
      children: [
        const SectionLabel('View'),
        _Segments(
          padding: segmentPadding,
          fontSize: 12,
          segments: [
            for (final (label, option) in const [
              ('Over time', TrendsView.overTime),
              ('Compare territories', TrendsView.compareTerritories),
            ])
              (
                key: ValueKey('trends-view-${option.name}'),
                label: label,
                selected: option == view,
                onTap: () => ref.read(trendsViewProvider.notifier).set(option),
              ),
          ],
        ),
        const SizedBox(width: 4),
        const SectionLabel('Bucket'),
        _Segments(
          padding: segmentPadding,
          fontSize: 12,
          segments: [
            for (final interval in TrendInterval.values)
              (
                key: ValueKey('interval-${interval.name}'),
                label: interval == TrendInterval.day ? 'Daily' : 'Weekly',
                selected: interval == query.interval,
                onTap: () => update(
                  TrendQuery(
                    interval: interval,
                    from: query.from,
                    to: query.to,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 4),
        const SectionLabel('Window'),
        OutlinedButton.icon(
          key: const ValueKey('trend-daterange'),
          icon: const Icon(Icons.date_range, size: 14),
          // Null is not "all time" — it is the server's own default lookback.
          // Say that, rather than implying a range we never asked for.
          label: Text(query.isRanged ? 'Custom range' : 'Server default'),
          onPressed: pickRange,
        ),
        if (query.isRanged)
          TextButton(
            key: const ValueKey('trend-clear'),
            onPressed: () => update(TrendQuery(interval: query.interval)),
            child: const Text('Clear'),
          ),
      ],
    );
  }
}

typedef _Segment = ({
  Key key,
  String label,
  bool selected,
  VoidCallback onTap,
});

/// The segmented control every switch on this screen shares.
///
/// Glass: a bar track with the selected segment lifted onto a bright pill — the
/// dashboard filter bar's idiom. Both states share one [padding] (a pane's rim
/// paints over its edge, it adds no size), so a tap never shifts the row.
/// Flat: a bordered row with the selected segment on the raised surface.
class _Segments extends StatelessWidget {
  const _Segments({
    required this.segments,
    required this.padding,
    required this.fontSize,
  });

  final List<_Segment> segments;
  final EdgeInsets padding;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (!colors.glass) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colors.lineStrong),
          borderRadius: BorderRadius.circular(AppColors.radiusControl),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, s) in segments.indexed)
              Semantics(
                button: true,
                selected: s.selected,
                child: InkWell(
                  key: s.key,
                  onTap: s.onTap,
                  child: Container(
                    padding: padding,
                    decoration: BoxDecoration(
                      color:
                          s.selected ? colors.surface3 : Colors.transparent,
                      border: Border(
                        right: BorderSide(
                          color: i == segments.length - 1
                              ? Colors.transparent
                              : colors.lineStrong,
                        ),
                      ),
                    ),
                    child: Text(
                      s.label,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: s.selected ? colors.ink1 : colors.ink2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    const inner = LumenGlass.radiusControl - 3;
    // Ink when selected, the muted ink otherwise — both clear 4.5:1 on the bar.
    Widget label(_Segment s) => Text(
      s.label,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: s.selected ? context.lumen.ink : context.lumen.inkMuted,
      ),
    );

    return GlassPane(
      kind: GlassKind.bar,
      radius: LumenGlass.radiusControl,
      blur: false,
      shadow: false,
      specular: false,
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in segments)
            Semantics(
              button: true,
              selected: s.selected,
              child: InkWell(
                key: s.key,
                onTap: s.onTap,
                borderRadius: BorderRadius.circular(inner),
                child: s.selected
                    ? GlassPane(
                        kind: GlassKind.pill,
                        radius: inner,
                        padding: padding,
                        child: label(s),
                      )
                    : Padding(padding: padding, child: label(s)),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Compare territories (#123) — every territory of the client against the
// client's own average. Cross-client benchmarks are deliberately absent.
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
    final metric = ref.watch(benchmarkMetricProvider);
    return PanelCard(
      title: 'Compare territories',
      subtitle: "Each territory's average for the window against the client "
          'average',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _Segments(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                fontSize: 11.5,
                segments: [
                  for (final option in BenchmarkMetric.values)
                    (
                      key: ValueKey('benchmark-metric-${option.name}'),
                      label: option.label,
                      selected: option == metric,
                      onTap: () => ref
                          .read(benchmarkMetricProvider.notifier)
                          .set(option),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          AsyncSection<TerritoryBenchmarkReport>(
            value: ref.watch(territoryBenchmarkProvider),
            label: 'territory comparison',
            onRetry: () => ref.invalidate(territoryBenchmarkProvider),
            builder: _body,
          ),
        ],
      ),
    );
  }

  Widget _body(TerritoryBenchmarkReport report) {
    if (report.territories.isEmpty) {
      return const EmptyState(
        message: 'No territories set up',
        hint: 'Add territories to compare them against the client average.',
      );
    }
    final clientAverage = report.client.average;
    if (clientAverage == null) {
      // Not "every territory scored 0" — nothing was measured at all.
      return const EmptyState(
        message: 'No data in range',
        hint: 'The comparison fills in as visits are submitted and scored.',
      );
    }
    final selected = report.territories.firstWhere(
      (t) => t.territoryId == _selectedId,
      orElse: () => report.territories.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ClientAverageHeader(report: report, clientAverage: clientAverage),
        const SizedBox(height: 10),
        for (final territory in report.territories)
          _TerritoryBenchmarkRow(
            territory: territory,
            report: report,
            clientAverage: clientAverage,
            selected: territory.territoryId == selected.territoryId,
            onTap: () => setState(() => _selectedId = territory.territoryId),
          ),
        const SizedBox(height: 16),
        _TerritoryChart(territory: selected, report: report),
      ],
    );
  }
}

class _ClientAverageHeader extends StatelessWidget {
  const _ClientAverageHeader({
    required this.report,
    required this.clientAverage,
  });

  final TerritoryBenchmarkReport report;
  final double clientAverage;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final note = TextStyle(fontSize: 11.5, color: colors.ink2);
    final target = report.target;
    final unassigned = report.unassignedCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            const SectionLabel('Client average'),
            Text(
              '${_trim(clientAverage)}${report.suffix}',
              key: const ValueKey('benchmark-client-average'),
              style: _figure(context, size: 16),
            ),
            if (target != null)
              Text(
                '· ${report.targetLabel ?? 'Target'} '
                '${_trim(target)}${report.suffix}',
                key: const ValueKey('benchmark-target'),
                style: note,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'The tick on each bar marks the client average.'
          '${unassigned > 0 ? ' The average also includes '
              '${report.metric.samples(unassigned)} from outlets outside '
              'any territory.' : ''}',
          style: note,
        ),
      ],
    );
  }
}

class _TerritoryBenchmarkRow extends StatelessWidget {
  const _TerritoryBenchmarkRow({
    required this.territory,
    required this.report,
    required this.clientAverage,
    required this.selected,
    required this.onTap,
  });

  final TerritoryBenchmark territory;
  final TerritoryBenchmarkReport report;
  final double clientAverage;
  final bool selected;
  final VoidCallback onTap;

  static const _gutter = 24.0;

  /// Above is on standard for this comparison; below is a watch, not a breach —
  /// sitting under your own average is not failing a configured threshold.
  static LumenStatus statusOf(BenchmarkPosition? position) =>
      switch (position) {
        BenchmarkPosition.above => LumenStatus.good,
        BenchmarkPosition.below => LumenStatus.warn,
        BenchmarkPosition.level || null => LumenStatus.none,
      };

  static String wordOf(BenchmarkPosition? position) => switch (position) {
        BenchmarkPosition.above => 'Above average',
        BenchmarkPosition.below => 'Below average',
        BenchmarkPosition.level => 'At average',
        null => 'No data',
      };

  String _note() {
    final average = territory.average;
    if (average == null) return 'Nothing measured in this window';
    final samples = report.metric.samples(territory.count);
    final delta = territory.deltaFromClient;
    return switch (territory.position) {
      BenchmarkPosition.above when delta != null =>
        '${_trim(delta.abs())} pts above the client average · $samples',
      BenchmarkPosition.below when delta != null =>
        '${_trim(delta.abs())} pts below the client average · $samples',
      _ => 'Level with the client average · $samples',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final status = statusOf(territory.position);
    final average = territory.average;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          key: ValueKey('benchmark-row-${territory.territoryId}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              // Selection is an outline, not a fill, so every word in the row
              // keeps the panel as its ground. The chart heading names the
              // selected territory too.
              border: Border.all(
                color: selected ? colors.lineStrong : Colors.transparent,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: _gutter,
                      child: Text(
                        territory.rank == null ? '–' : '${territory.rank}',
                        style: _figure(context, size: 12, color: colors.ink2),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        territory.territoryName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: colors.ink1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    LumenStatusPill(
                      status: status,
                      label: wordOf(territory.position),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      average == null ? '—' : '${_trim(average)}${report.suffix}',
                      key: ValueKey('benchmark-average-${territory.territoryId}'),
                      style: _figure(context),
                    ),
                  ],
                ),
                // No bar without a value: an empty track would read as a zero.
                if (average != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: _gutter),
                    child: BenchmarkBar(
                      value: average,
                      target: clientAverage,
                      status: status,
                      height: 8,
                    ),
                  ),
                ],
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.only(left: _gutter),
                  child: Text(
                    _note(),
                    style: TextStyle(fontSize: 11, color: colors.ink2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The selected territory's series over the client line.
///
/// [LineChart] aligns its comparison by position, so the client line is cut to
/// exactly the buckets the territory has — a territory with a gap week is then
/// compared bucket-for-bucket, never against a neighbouring week.
class _TerritoryChart extends StatelessWidget {
  const _TerritoryChart({required this.territory, required this.report});

  final TerritoryBenchmark territory;
  final TerritoryBenchmarkReport report;

  @override
  Widget build(BuildContext context) {
    final periods = {for (final p in territory.points) p.period};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${territory.territoryName} against the client average',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: context.colors.ink1,
          ),
        ),
        const SizedBox(height: 8),
        LineChart(
          key: const ValueKey('benchmark-chart'),
          height: 180,
          points: [
            for (final p in territory.points)
              (label: formatPeriodLabel(p.period), value: p.value),
          ],
          comparison: [
            for (final p in report.client.points)
              if (periods.contains(p.period))
                (label: formatPeriodLabel(p.period), value: p.value),
          ],
          seriesName: territory.territoryName,
          comparisonName: 'Client average',
          valueSuffix: report.suffix,
          target: report.target,
        ),
      ],
    );
  }
}

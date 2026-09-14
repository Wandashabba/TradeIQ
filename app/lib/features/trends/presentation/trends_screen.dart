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
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/trends_repository.dart';

class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final colors = context.colors;
    if (colors.glass) {
      return _GlassSegments(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        fontSize: 11.5,
        segments: [
          for (final (label, isTable) in const [
            ('Chart', false),
            ('Table', true),
          ])
            (
              key: ValueKey('view-${label.toLowerCase()}'),
              label: label,
              selected: isTable == asTable,
              onTap: () => onChanged(isTable),
            ),
        ],
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colors.lineStrong),
        borderRadius: BorderRadius.circular(AppColors.radiusControl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (label, isTable) in const [
            ('Chart', false),
            ('Table', true),
          ])
            InkWell(
              key: ValueKey('view-${label.toLowerCase()}'),
              onTap: () => onChanged(isTable),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isTable == asTable
                      ? colors.surface3
                      : Colors.transparent,
                  border: Border(
                    right: BorderSide(
                      color: isTable ? Colors.transparent : colors.lineStrong,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isTable == asTable ? colors.ink1 : colors.ink2,
                  ),
                ),
              ),
            ),
        ],
      ),
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
                  style: colors.glass
                      ? LumenGlass.figure(size: 12.5, color: colors.ink1)
                      : TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: colors.ink1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _trim(double v) {
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }
}

/// One filter row scoping every chart below it — interval and window.
///
/// A per-panel range control would let two charts silently disagree about which
/// slice of time they show, which is worse than no control at all.
class _TrendFilters extends ConsumerWidget {
  const _TrendFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final query = ref.watch(trendQueryProvider);

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

    return FilterRow(
      children: [
        const SectionLabel('Bucket'),
        if (colors.glass)
          _GlassSegments(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
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
          )
        else
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: colors.lineStrong),
            borderRadius: BorderRadius.circular(AppColors.radiusControl),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final interval in TrendInterval.values)
                InkWell(
                  key: ValueKey('interval-${interval.name}'),
                  onTap: () => update(
                    TrendQuery(
                      interval: interval,
                      from: query.from,
                      to: query.to,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: interval == query.interval
                          ? colors.surface3
                          : Colors.transparent,
                      border: Border(
                        right: BorderSide(
                          color: interval == TrendInterval.values.last
                              ? Colors.transparent
                              : colors.lineStrong,
                        ),
                      ),
                    ),
                    child: Text(
                      interval == TrendInterval.day ? 'Daily' : 'Weekly',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: interval == query.interval
                            ? colors.ink1
                            : colors.ink2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
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

typedef _GlassSegment = ({
  Key key,
  String label,
  bool selected,
  VoidCallback onTap,
});

/// The glass segmented control both switches on this screen share: a bar
/// track with the selected segment lifted onto a bright pill — the dashboard
/// filter bar's idiom. Both states share one [padding] (a pane's rim paints
/// over its edge, it adds no size), so a tap never shifts the row.
class _GlassSegments extends StatelessWidget {
  const _GlassSegments({
    required this.segments,
    required this.padding,
    required this.fontSize,
  });

  final List<_GlassSegment> segments;
  final EdgeInsets padding;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    const inner = LumenGlass.radiusControl - 3;
    // Ink when selected, the muted ink otherwise — both clear 4.5:1 on the bar.
    Widget label(_GlassSegment s) => Text(
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
            InkWell(
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
        ],
      ),
    );
  }
}

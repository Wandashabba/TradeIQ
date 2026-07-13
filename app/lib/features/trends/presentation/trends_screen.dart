import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/console.dart';
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
          const Text(
            'Server-side buckets — weeks start Monday, UTC.',
            style: TextStyle(fontSize: 12, color: AppColors.ink3),
          ),
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
                      (label: _shortPeriod(p.period), value: p.value),
                  ],
                  valueSuffix: widget.suffix,
                  seriesName: widget.heading,
                );
        },
      ),
    );
  }

  /// `2026-W26` → `W26`; an ISO date keeps its `MM-DD`. Axis ticks have no room
  /// for the year, and it is the same for every bucket anyway.
  static String _shortPeriod(String period) {
    final week = RegExp(r'^\d{4}-(W\d{1,2})$').firstMatch(period);
    if (week != null) return week.group(1)!;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(period)) {
      return period.substring(5);
    }
    return period;
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.asTable, required this.onChanged});

  final bool asTable;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.lineStrong),
        borderRadius: BorderRadius.circular(AppColors.radiusControl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (label, isTable) in const [('Chart', false), ('Table', true)])
            InkWell(
              key: ValueKey('view-${label.toLowerCase()}'),
              onTap: () => onChanged(isTable),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isTable == asTable
                      ? AppColors.surface3
                      : Colors.transparent,
                  border: Border(
                    right: BorderSide(
                      color: isTable ? Colors.transparent : AppColors.lineStrong,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isTable == asTable ? AppColors.ink1 : AppColors.ink2,
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
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    p.period,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.ink2),
                  ),
                ),
                Text(
                  '${_trim(p.value)}$suffix',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink1,
                    fontFeatures: [FontFeature.tabularFigures()],
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

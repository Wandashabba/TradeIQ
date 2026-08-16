import 'package:flutter/material.dart';

import '../../../core/format/period_label.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/console.dart';
import '../data/chat_controller.dart';

/// The `trend_chart` spec, rendered inline in the chat stream.
///
/// **Deliberately minimal — the anti-crowding rule.** One series on the shared
/// [LineChart], a title, and nothing else: no table twin, no filter chrome, no
/// period picker. Phase 2's Expanded mode is where those belong.
///
/// The data it reads is `getMetricTrend`'s result — `{ metric, interval,
/// points: [{ period, value, count }] }` — but that shape is a convention with
/// the emitting tool, not part of the server-validated spec contract. Every
/// read is therefore type-tested, and a row that cannot be read is skipped
/// rather than plotted as zero: a fabricated zero *is* a data point on a
/// chart, and it changes what the line says.
class TrendChartCard extends StatelessWidget {
  const TrendChartCard({super.key, required this.artifact});

  final ChatArtifact artifact;

  /// Titles per metric. An unknown metric falls back to its raw key — a
  /// server that grows the enum before this build ships still gets a titled
  /// chart rather than a nameless one.
  static const Map<String, String> _metricLabels = {
    'execution_score': 'Execution score',
    'availability': 'On-shelf availability',
    'perfect_store': 'Perfect-store rate',
    'share_of_shelf': 'Share of shelf',
  };

  /// The metrics whose values are percentages, for the axis suffix.
  static const Set<String> _percentMetrics = {
    'availability',
    'perfect_store',
    'share_of_shelf',
  };

  Map<String, dynamic> get _data {
    final data = artifact.data;
    return data is Map<String, dynamic> ? data : const {};
  }

  String? _string(String key) {
    final value = _data[key];
    return value is String ? value : null;
  }

  List<ChartPoint> _points() {
    final raw = _data['points'];
    if (raw is! List) return const [];

    final points = <ChartPoint>[];
    for (final row in raw) {
      if (row is! Map<String, dynamic>) continue;
      final value = row['value'];
      if (value is! num) continue;
      final period = row['period'];
      points.add((
        label: formatPeriodLabel(period is String ? period : ''),
        value: value.toDouble(),
      ));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final metric = _string('metric');
    final title = _metricLabels[metric] ?? metric ?? 'Trend';
    final interval = _string('interval');

    return PanelCard(
      title: title,
      subtitle: interval == null ? null : 'By $interval',
      // Fewer than two readable points renders the chart's own honest empty
      // plot ("Not enough data to plot") rather than a dot pretending to be
      // a trend.
      child: LineChart(
        points: _points(),
        seriesName: title,
        valueSuffix: metric != null && _percentMetrics.contains(metric) ? '%' : '',
      ),
    );
  }
}

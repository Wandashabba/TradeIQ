import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/format/period_label.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/delta_pill.dart';
import '../../../core/widgets/worklist.dart';
import '../data/artifact_repository.dart';
import '../data/chat_controller.dart';
import 'view_spec_registry.dart';

/// Expanded mode — the artifact with everything the inline card leaves out.
///
/// The inline card is deliberately impoverished (the anti-crowding rule): a
/// headline figure and nothing else, because a date picker in every chat bubble
/// is exactly the crowding to avoid. Everything that got left out lives here —
/// the full chart, the comparison as a second series, and the **table twin**
/// `charts.dart` already mandates, so no value is reachable only by hovering.
///
/// Two of the four specs get a purpose-built expansion; the other two fall back
/// to their inline card. That is not a stub: an `outlet_map` is already the
/// whole answer at any size, and inventing a table twin for a scatter of pins
/// would be a table of coordinates nobody asked for. What Expanded adds for
/// those is the filter controls and the route, which is the part that was
/// missing.
Widget expandedArtifactView(BuildContext context, ArtifactDetail artifact) {
  switch (artifact.type) {
    case 'trend_chart':
      return TrendExpandedView(artifact: artifact);
    case 'pillar_metrics':
      return PillarExpandedView(artifact: artifact);
    default:
      // Reuses the registry, so an unknown type still explains itself rather
      // than rendering an empty panel — the same contract the chat stream has.
      return ArtifactView(
        artifact: ChatArtifact(
          id: artifact.id,
          type: artifact.type,
          params: artifact.params,
          data: artifact.data,
        ),
      );
  }
}

/// A trend, its comparison, and the table underneath both.
class TrendExpandedView extends StatefulWidget {
  const TrendExpandedView({super.key, required this.artifact});

  final ArtifactDetail artifact;

  @override
  State<TrendExpandedView> createState() => _TrendExpandedViewState();
}

class _TrendExpandedViewState extends State<TrendExpandedView> {
  bool _asTable = false;

  static const Map<String, String> _metricLabels = {
    'execution_score': 'Execution score',
    'availability': 'On-shelf availability',
    'perfect_store': 'Perfect-store rate',
    'share_of_shelf': 'Share of shelf',
  };

  static const Set<String> _percentMetrics = {
    'availability',
    'perfect_store',
    'share_of_shelf',
  };

  Map<String, dynamic> get _data {
    final data = widget.artifact.data;
    return data is Map<String, dynamic> ? data : const {};
  }

  Map<String, dynamic> get _comparison {
    final value = _data['comparison'];
    return value is Map<String, dynamic> ? value : const {};
  }

  String? get _comparisonLabel {
    final label = _comparison['label'];
    return label is String && label.isNotEmpty ? label : null;
  }

  /// Points from a `{period, value}` row list. Unreadable rows are skipped, not
  /// plotted as zero: a fabricated zero IS a data point, and it changes what
  /// the line says.
  List<ChartPoint> _pointsFrom(dynamic raw) {
    if (raw is! List) return const [];
    final points = <ChartPoint>[];
    for (final row in raw) {
      if (row is! Map<String, dynamic>) continue;
      final value = row['value'];
      if (value is! num || !value.isFinite) continue;
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
    final metric = _data['metric'];
    final title =
        _metricLabels[metric] ?? (metric is String ? metric : 'Trend');
    final suffix = metric is String && _percentMetrics.contains(metric)
        ? '%'
        : '';
    final points = _pointsFrom(_data['points']);
    final comparison = _pointsFrom(_comparison['points']);
    final interval = _data['interval'];
    final subtitle = [
      if (interval is String) 'By $interval',
      if (_comparisonLabel != null) 'vs ${_comparisonLabel!}',
    ].join(' · ');

    return PanelCard(
      title: title,
      subtitle: subtitle.isEmpty ? null : subtitle,
      // The toggle is not decoration: a chart that is the only way to read a
      // value fails anyone using a screen reader, printing it, or checking an
      // exact figure.
      trailing: ChartTableToggle(
        asTable: _asTable,
        onChanged: (value) => setState(() => _asTable = value),
      ),
      child: points.isEmpty
          ? const EmptyState(
              message: 'No data in range',
              hint: 'Trends fill in as visits are submitted and scored.',
            )
          : _asTable
          ? _TrendTable(
              points: points,
              comparison: comparison,
              comparisonLabel: _comparisonLabel,
              suffix: suffix,
            )
          : LineChart(
              points: points,
              comparison: comparison,
              seriesName: title,
              comparisonName: _comparisonLabel ?? '',
              valueSuffix: suffix,
              height: 300,
            ),
    );
  }
}

/// The table twin — every plotted value, plus the movement against the
/// comparison in absolute and percentage terms.
///
/// **Rows are aligned by position, and the table says so.** The two windows are
/// different stretches of calendar, and a bucket with no visits produces no
/// point at all, so nth-against-nth is the only alignment available. Showing
/// the compared bucket's own label in its column is what keeps that visible
/// instead of implying the two rows are the same date.
class _TrendTable extends StatelessWidget {
  const _TrendTable({
    required this.points,
    required this.comparison,
    required this.comparisonLabel,
    required this.suffix,
  });

  final List<ChartPoint> points;
  final List<ChartPoint> comparison;
  final String? comparisonLabel;
  final String suffix;

  ChartPoint? _against(int i) {
    if (comparison.isEmpty) return null;
    if (comparison.length == 1 || points.length < 2) return comparison.first;
    final t = i / (points.length - 1);
    return comparison[(t * (comparison.length - 1)).round().clamp(
      0,
      comparison.length - 1,
    )];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final compared = comparison.isNotEmpty;

    // A delta column plus a comparison column does not fit a phone, and a table
    // that wraps its figures is not a table. It takes the width it has, and
    // scrolls sideways below the width its columns need.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(constraints.maxWidth, compared ? 480 : 260),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Expanded(flex: 3, child: SectionLabel('Period')),
                    const Expanded(flex: 2, child: SectionLabel('Value')),
                    if (compared) ...[
                      Expanded(
                        flex: 3,
                        child: SectionLabel(comparisonLabel ?? 'Comparison'),
                      ),
                      const Expanded(flex: 3, child: SectionLabel('Change')),
                    ],
                  ],
                ),
              ),
              for (var i = 0; i < points.length; i++)
                _TrendRow(
                  point: points[i],
                  against: _against(i),
                  compared: compared,
                  suffix: suffix,
                  colors: colors,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({
    required this.point,
    required this.against,
    required this.compared,
    required this.suffix,
    required this.colors,
  });

  final ChartPoint point;
  final ChartPoint? against;
  final bool compared;
  final String suffix;
  final TiqColors colors;

  @override
  Widget build(BuildContext context) {
    final other = against;
    final delta = other == null ? null : point.value - other.value;
    // "Up from nothing" has no percentage — the same rule the server applies to
    // scalar deltas, held here so the two cannot disagree.
    final pct = other == null || other.value == 0
        ? null
        : (point.value - other.value) / other.value.abs() * 100;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              point.label,
              style: TextStyle(fontSize: 12.5, color: colors.ink2),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${_trim(point.value)}$suffix',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: colors.ink1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (compared) ...[
            Expanded(
              flex: 3,
              child: Text(
                other == null
                    // An absent counterpart is stated, never filled in with a
                    // zero that would then be differenced into a fake movement.
                    ? '—'
                    : '${_trim(other.value)}$suffix · ${other.label}',
                style: TextStyle(fontSize: 12.5, color: colors.ink3),
              ),
            ),
            Expanded(
              flex: 3,
              child: delta == null
                  ? Text(
                      '—',
                      style: TextStyle(fontSize: 12.5, color: colors.ink3),
                    )
                  : Row(
                      children: [
                        DeltaPill(
                          delta: delta,
                          tone: delta < 0 ? DeltaTone.bad : DeltaTone.good,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          pct == null ? 'n/a' : '${pct.toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 11.5, color: colors.ink3),
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A pillar's figures as a table — value, comparison, and the delta column.
///
/// The inline card already shows the movement beside each figure; what this
/// adds is the **baseline itself**, which the pill cannot carry. "Up 5.1" and
/// "88.0 → 93.1" answer different questions, and the second is the one that
/// replaces exporting both periods and lining them up in a spreadsheet.
class PillarExpandedView extends StatelessWidget {
  const PillarExpandedView({super.key, required this.artifact});

  final ArtifactDetail artifact;

  /// Shared with the inline card by copy rather than by import: the card reads
  /// the chat stream's spec params and this reads the stored tool args, and
  /// merging the two readers would tie the expanded view to a shape it does not
  /// receive. The labels themselves are a display convention, not a contract.
  static const Map<String, String> _labels = {
    'osaPct': 'On-shelf availability',
    'onShelfAvailabilityPct': 'On-shelf availability',
    'shareOfShelfPct': 'Share of shelf',
    'visibilityCompliancePct': 'Visibility compliance',
    'priceCompliancePct': 'Price compliance',
    'attainmentPct': 'Attainment',
    'rateOfSale': 'Rate of sale',
    'outletsWithStockout': 'Outlets with a stockout',
    'outOfStockLines': 'Out-of-stock lines',
    'linesObserved': 'Lines observed',
    'competitorFacings': 'Competitor facings',
  };

  static const Set<String> _percentSuffixed = {
    'osaPct',
    'onShelfAvailabilityPct',
    'shareOfShelfPct',
    'visibilityCompliancePct',
    'priceCompliancePct',
    'attainmentPct',
  };

  Map<String, dynamic> get _data {
    final data = artifact.data;
    return data is Map<String, dynamic> ? data : const {};
  }

  Map<String, dynamic> get _comparison {
    final value = _data['comparison'];
    return value is Map<String, dynamic> ? value : const {};
  }

  Map<String, dynamic> get _baseline {
    final values = _comparison['values'];
    return values is Map<String, dynamic> ? values : const {};
  }

  Map<String, dynamic> get _deltas {
    final value = _comparison['deltas'];
    return value is Map<String, dynamic> ? value : const {};
  }

  static String label(String key) {
    final known = _labels[key];
    if (known != null) return known;
    final spaced = key.replaceAllMapped(
      RegExp(r'(?<=[a-z0-9])([A-Z])'),
      (m) => ' ${m[1]!.toLowerCase()}',
    );
    return spaced.isEmpty ? key : spaced[0].toUpperCase() + spaced.substring(1);
  }

  static String format(String key, num value) {
    final suffix = _percentSuffixed.contains(key) ? '%' : '';
    final asDouble = value.toDouble();
    final body = asDouble == asDouble.roundToDouble() && suffix.isEmpty
        ? asDouble.round().toString()
        : asDouble.toStringAsFixed(1);
    return '$body$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final figures = <MapEntry<String, num>>[
      for (final entry in _data.entries)
        if (entry.value is num && (entry.value as num).isFinite)
          MapEntry(entry.key, entry.value as num),
    ];
    final rawLabel = _comparison['label'];
    final label = rawLabel is String ? rawLabel : '';
    final compared = label.isNotEmpty;

    return PanelCard(
      title: 'Figures',
      subtitle: compared ? 'vs $label' : null,
      child: figures.isEmpty
          ? const EmptyState(
              message: 'No figures were returned for this period',
              hint: 'Widen the period, or clear the territory filter.',
            )
          : LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(constraints.maxWidth, compared ? 480 : 260),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Expanded(
                              flex: 4,
                              child: SectionLabel('Figure'),
                            ),
                            const Expanded(
                              flex: 2,
                              child: SectionLabel('Value'),
                            ),
                            if (compared) ...[
                              Expanded(flex: 3, child: SectionLabel(label)),
                              const Expanded(
                                flex: 3,
                                child: SectionLabel('Change'),
                              ),
                            ],
                          ],
                        ),
                      ),
                      for (final figure in figures)
                        _PillarRow(
                          label: PillarExpandedView.label(figure.key),
                          value: format(figure.key, figure.value),
                          baseline: _baselineFor(figure.key),
                          delta: _deltaFor(figure.key),
                          compared: compared,
                          colors: colors,
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  String? _baselineFor(String key) {
    final raw = _baseline[key];
    if (raw is! num || !raw.isFinite) return null;
    return format(key, raw);
  }

  ({double absolute, double? pct})? _deltaFor(String key) {
    final raw = _deltas[key];
    if (raw is! Map<String, dynamic>) return null;
    final absolute = raw['absolute'];
    if (absolute is! num || !absolute.isFinite) return null;
    final pct = raw['pct'];
    return (
      absolute: absolute.toDouble(),
      // Null is meaningful, not missing: the server sends it when the baseline
      // was zero, because "up from nothing" has no percentage.
      pct: pct is num && pct.isFinite ? pct.toDouble() : null,
    );
  }
}

class _PillarRow extends StatelessWidget {
  const _PillarRow({
    required this.label,
    required this.value,
    required this.baseline,
    required this.delta,
    required this.compared,
    required this.colors,
  });

  final String label;
  final String value;
  final String? baseline;
  final ({double absolute, double? pct})? delta;
  final bool compared;
  final TiqColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: colors.ink2),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: colors.ink1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (compared) ...[
            Expanded(
              flex: 3,
              child: Text(
                baseline ?? '—',
                style: TextStyle(fontSize: 12.5, color: colors.ink3),
              ),
            ),
            Expanded(
              flex: 3,
              child: delta == null
                  ? Text(
                      '—',
                      style: TextStyle(fontSize: 12.5, color: colors.ink3),
                    )
                  : Row(
                      children: [
                        DeltaPill(
                          delta: delta!.absolute,
                          tone: delta!.absolute < 0
                              ? DeltaTone.bad
                              : DeltaTone.good,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          delta!.pct == null
                              ? 'n/a'
                              : '${delta!.pct!.toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 11.5, color: colors.ink3),
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chart ⇄ Table, the console's existing two-state toggle.
///
/// Lifted from the trends screen's private one rather than forked: the table
/// twin is a rule the design system already states, and two toggles that drift
/// apart would make the same affordance behave differently on two screens.
class ChartTableToggle extends StatelessWidget {
  const ChartTableToggle({
    super.key,
    required this.asTable,
    required this.onChanged,
  });

  final bool asTable;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
              key: ValueKey('artifact-view-${label.toLowerCase()}'),
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

String _trim(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

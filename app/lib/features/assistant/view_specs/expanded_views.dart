import 'package:flutter/material.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/format/period_label.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/delta_pill.dart';
import '../../../core/widgets/worklist.dart';
import '../data/artifact_repository.dart';
import '../data/chat_controller.dart';
import 'artifact_table.dart';
import 'rich_figures.dart';
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
/// those is the filter controls, the route and the export.
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

  /// Points for the chart. The table takes the same rows through
  /// [artifactTableFor], so the two cannot disagree about a value — only about
  /// how it is drawn.
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
    final title = expandedArtifactTitle(widget.artifact);
    final suffix = metric is String && _percentMetrics.contains(metric)
        ? '%'
        : '';
    final points = _pointsFrom(_data['points']);
    final comparison = _pointsFrom(_comparison['points']);
    final subtitle = expandedArtifactSubtitle(widget.artifact);

    return PanelCard(
      title: title,
      subtitle: subtitle,
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
          ? ArtifactTableView(table: artifactTableFor(widget.artifact))
          : LineChart(
              points: points,
              comparison: comparison,
              seriesName: title,
              comparisonName: _comparisonLabel ?? '',
              // The same dashed reference line the chat card draws, so
              // expanding a card does not restyle the line being read.
              dashedComparison: true,
              valueSuffix: suffix,
              height: 300,
            ),
    );
  }
}

/// A pillar's figures as a table — value, baseline, and the delta column.
///
/// The inline card already shows the movement beside each figure; what this
/// adds is the **baseline itself**, which a pill cannot carry. "Up 5.1" and
/// "88.0 → 93.1" answer different questions, and the second is the one that
/// replaces exporting both periods and lining them up in a spreadsheet.
class PillarExpandedView extends StatelessWidget {
  const PillarExpandedView({super.key, required this.artifact});

  final ArtifactDetail artifact;

  @override
  Widget build(BuildContext context) {
    final table = artifactTableFor(artifact);

    return PanelCard(
      title: expandedArtifactTitle(artifact),
      subtitle: expandedArtifactSubtitle(artifact),
      child: table == null || table.isEmpty
          ? const EmptyState(
              message: 'No figures were returned for this period',
              hint: 'Widen the period, or clear the territory filter.',
            )
          : ArtifactTableView(table: table),
    );
  }
}

/// The table twin, rendered from the shared derivation.
///
/// **Rows are aligned by position, and the table says so.** For a trend the two
/// windows are different stretches of calendar, and a bucket with no visits
/// produces no point at all, so nth-against-nth is the only alignment
/// available. Each comparison cell carries its own bucket label, which is what
/// keeps that visible instead of implying the two rows are the same date.
class ArtifactTableView extends StatelessWidget {
  const ArtifactTableView({super.key, required this.table});

  final ArtifactTable? table;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final table = this.table;
    if (table == null || table.isEmpty) {
      return const EmptyState(message: 'Nothing to tabulate');
    }

    // A delta column plus a comparison column does not fit a phone, and a table
    // that wraps its figures is not a table. It takes the width it has, and
    // scrolls sideways below the width its columns need.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: constraints.maxWidth < (table.compared ? 480 : 260)
              ? (table.compared ? 480 : 260)
              : constraints.maxWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    for (var i = 0; i < table.columns.length; i++)
                      Expanded(
                        flex: i == 0 ? 3 : 2,
                        child: SectionLabel(table.columns[i]),
                      ),
                  ],
                ),
              ),
              for (final row in table.rows)
                _TableRow(row: row, table: table, colors: colors),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.row,
    required this.table,
    required this.colors,
  });

  final ArtifactTableRow row;
  final ArtifactTable table;
  final TiqColors colors;

  @override
  Widget build(BuildContext context) {
    if (colors.glass) return _glass(context.lumen);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < table.columns.length; i++)
            Expanded(
              flex: i == 0 ? 3 : 2,
              child: i < row.cells.length
                  ? Text(
                      row.cells[i],
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: i == 1 ? FontWeight.w600 : FontWeight.w400,
                        color: i == 0
                            ? colors.ink2
                            : (i == 1 ? colors.ink1 : colors.ink3),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    )
                  : _Change(row: row, colors: colors),
            ),
        ],
      ),
    );
  }

  /// Glass: a white-rim divider — the pane's own lit edge, not a grey rule —
  /// and every figure in JetBrains Mono, so the columns align by glyph.
  Widget _glass(LumenPalette lumen) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: lumen.white(0xB3))),
      ),
      child: Row(
        children: [
          for (var i = 0; i < table.columns.length; i++)
            Expanded(
              flex: i == 0 ? 3 : 2,
              child: i < row.cells.length
                  ? Text(
                      row.cells[i],
                      style: i == 0
                          ? TextStyle(fontSize: 12.5, color: lumen.ink)
                          : LumenGlass.figure(
                              size: i == 1 ? 12.5 : 12,
                              color: i == 1 ? lumen.ink : lumen.inkMuted,
                              weight: i == 1
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                    )
                  : _Change(row: row, colors: colors),
            ),
        ],
      ),
    );
  }
}

class _Change extends StatelessWidget {
  const _Change({required this.row, required this.colors});

  final ArtifactTableRow row;
  final TiqColors colors;

  @override
  Widget build(BuildContext context) {
    final delta = row.delta;
    if (delta == null) {
      return Text(
        '—',
        style: colors.glass
            ? LumenGlass.figure(size: 12, color: context.lumen.inkMuted)
            : TextStyle(fontSize: 12.5, color: colors.ink3),
      );
    }
    return Row(
      children: [
        DeltaPill(
          delta: delta,
          tone: delta < 0 ? DeltaTone.bad : DeltaTone.good,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            // "n/a" rather than a percentage the server refused to invent.
            row.deltaPct == null
                ? 'n/a'
                : formatChangePct(
                    row.deltaPct!,
                    number: TiqNumber.of(context),
                  ),
            style: colors.glass
                ? LumenGlass.figure(
                    size: 11.5,
                    weight: FontWeight.w400,
                    color: context.lumen.inkMuted,
                  )
                : TextStyle(fontSize: 11.5, color: colors.ink3),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// What this view is called, on screen and in the exported report.
///
/// Shared so the PDF's header and the panel above the chart cannot drift into
/// naming the same thing differently.
String expandedArtifactTitle(ArtifactDetail artifact) {
  final data = artifact.data;
  if (artifact.type == 'ranked_bars') {
    return RankedBarsData.from(data).title ?? 'Ranking';
  }
  if (artifact.type == 'stat_tiles') return 'Key figures';
  if (artifact.type == 'trend_chart' && data is Map<String, dynamic>) {
    final metric = data['metric'];
    return trendMetricLabels[metric] ?? (metric is String ? metric : 'Trend');
  }
  if (artifact.type == 'pillar_metrics') {
    final params = artifact.params;
    final pillar = params['pillar'];
    return switch (pillar) {
      'sales' => 'Sales figures',
      'stock' => 'Stock figures',
      'visibility' => 'Visibility figures',
      'competition' => 'Competition figures',
      // The row stores TOOL args, which carry no pillar — the pillar lives in
      // the view spec the chat stream sent, and this screen loads from the
      // server by id. So the honest fallback is the neutral noun.
      _ => 'Figures',
    };
  }
  return 'View';
}

/// "By day · vs the month before this one", or null when neither applies.
String? expandedArtifactSubtitle(ArtifactDetail artifact) {
  final data = artifact.data;
  if (data is! Map<String, dynamic>) return null;
  final comparison = data['comparison'];
  final label = comparison is Map<String, dynamic> ? comparison['label'] : null;
  final interval = data['interval'];
  final comparedTo = data['comparedTo'];
  if (artifact.type == 'ranked_bars' && comparedTo is String) {
    // Pre-formatted by the server ("vs Aug '25").
    return comparedTo.isEmpty ? null : comparedTo;
  }
  final parts = [
    if (interval is String) 'By $interval',
    if (label is String && label.isNotEmpty) 'vs $label',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
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
    if (colors.glass) {
      // Glass: a recessed track holding a bright raised pill for the view in
      // force. The pill's lift and the heavier weight mark it, not the hue.
      final lumen = context.lumen;
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: lumen.tileFill,
          border: Border.all(color: lumen.pillRim),
          borderRadius: BorderRadius.circular(LumenGlass.radiusChip + 2),
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
                borderRadius: BorderRadius.circular(LumenGlass.radiusChip),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isTable == asTable
                        ? lumen.pillFill
                        : Colors.transparent,
                    border: Border.all(
                      color: isTable == asTable
                          ? lumen.panelRim
                          : Colors.transparent,
                    ),
                    borderRadius: BorderRadius.circular(LumenGlass.radiusChip),
                    boxShadow: isTable == asTable
                        ? [
                            BoxShadow(
                              color: lumen.shadow,
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isTable == asTable
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isTable == asTable ? lumen.ink : lumen.inkMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
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

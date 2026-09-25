import 'package:flutter/widgets.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/format/period_label.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/figure/chart/chart.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
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
/// the design system already mandates, so no value is reachable only by
/// hovering.
///
/// Two of the four specs get a purpose-built expansion; the other two fall back
/// to their inline card. That is not a stub: an `outlet_map` is already the
/// whole answer at any size, and inventing a table twin for a scatter of pins
/// would be a table of coordinates nobody asked for. What Expanded adds for
/// those is the filter controls, the route and the export.
///
/// **Amber: none.** The chart-focus rung is real and this view declines it, for
/// the reason the chart kit declines it everywhere: the subject is carried by
/// weight, by a solid stroke against a dashed one and by the legend's word.
/// The one lit object on this route is the export, and it is the route's.
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

  static const Set<String> _percentMetrics = <String>{
    'availability',
    'perfect_store',
    'share_of_shelf',
  };

  Map<String, dynamic> get _data {
    final data = widget.artifact.data;
    return data is Map<String, dynamic> ? data : const <String, dynamic>{};
  }

  Map<String, dynamic> get _comparison {
    final value = _data['comparison'];
    return value is Map<String, dynamic> ? value : const <String, dynamic>{};
  }

  String? get _comparisonLabel {
    final label = _comparison['label'];
    return label is String && label.isNotEmpty ? label : null;
  }

  /// Readings for the chart. The table takes the same rows through
  /// [artifactTableFor], so the two cannot disagree about a value — only about
  /// how it is drawn.
  ///
  /// A row whose value is not a finite number becomes a **null reading**, not a
  /// dropped one: `/trends` omits an empty bucket and the chart breaks its
  /// stroke across the gap, which is the honest drawing of a week nobody
  /// measured. Interpolating across it draws a trend that was never observed.
  List<ChartReading> _readingsFrom(dynamic raw) {
    if (raw is! List) return const <ChartReading>[];
    final readings = <ChartReading>[];
    for (final row in raw) {
      if (row is! Map<String, dynamic>) continue;
      final value = row['value'];
      final period = row['period'];
      final label = period is String ? period : '';
      readings.add(
        ChartReading(
          label: formatPeriodLabel(label),
          longLabel: label.isEmpty ? null : label,
          value: value is num && value.isFinite ? value.toDouble() : null,
        ),
      );
    }
    return readings;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final metric = _data['metric'];
    final title = expandedArtifactTitle(context, widget.artifact);
    final unit = metric is String && _percentMetrics.contains(metric)
        ? TiqUnit.percent
        : TiqUnit.none;
    final readings = _readingsFrom(_data['points']);
    final comparison = _readingsFrom(_comparison['points']);
    final subtitle = expandedArtifactSubtitle(context, widget.artifact);
    // Veld draws no plot (unify §4), so the toggle would be a control with one
    // working position. The table is simply what Veld shows.
    final veld = skin.mode == SkinMode.veld;
    final measured = readings.any((r) => r.value != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule(title),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s3),
          Text(
            subtitle,
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
        ],
        const SizedBox(height: TiqSpace.s4),
        if (!measured)
          EmptyState(
            scope: EmptyScope.inPanel,
            headline: l10n.trendsEmptyHeadline,
            body: l10n.trendsEmptyBody,
          )
        else ...<Widget>[
          // Not decoration: a chart that is the only way to read a value fails
          // anyone using a screen reader, printing it, or checking an exact
          // figure.
          if (!veld) ...<Widget>[
            ChartTableToggle(
              asTable: _asTable,
              onChanged: (value) => setState(() => _asTable = value),
            ),
            const SizedBox(height: TiqSpace.s4),
          ],
          if (veld || _asTable)
            ArtifactTableView(table: artifactTableFor(widget.artifact))
          else
            TrendChart(
              key: const ValueKey<String>('artifact-trend-chart'),
              series: <ChartSeries>[
                ChartSeries(name: title, readings: readings),
                if (comparison.isNotEmpty)
                  ChartSeries(
                    name: _comparisonLabel ?? l10n.artifactComparison,
                    role: ChartSeriesRole.comparison,
                    readings: comparison,
                  ),
              ],
              unit: unit,
              decimals: 1,
              semanticsLabel: l10n.trendsChartHint(title, readings.length),
              notMeasuredWord: l10n.trendsNotMeasured,
              dashedWord: l10n.trendsDashed,
              scrubHint: l10n.trendsScrubHint,
            ),
        ],
      ],
    );
  }
}

/// A pillar's figures as a table — value, baseline, and the delta column.
///
/// The inline card already shows the movement beside each figure; what this
/// adds is the **baseline itself**, which a delta cannot carry. "Up 5.1" and
/// "88.0 → 93.1" answer different questions, and the second is the one that
/// replaces exporting both periods and lining them up in a spreadsheet.
class PillarExpandedView extends StatelessWidget {
  const PillarExpandedView({super.key, required this.artifact});

  final ArtifactDetail artifact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final table = artifactTableFor(artifact);
    final subtitle = expandedArtifactSubtitle(context, artifact);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule(expandedArtifactTitle(context, artifact)),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s3),
          Text(
            subtitle,
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
        ],
        const SizedBox(height: TiqSpace.s4),
        if (table == null || table.isEmpty)
          EmptyState(
            scope: EmptyScope.inPanel,
            headline: l10n.artifactNoFiguresHeadline,
            body: l10n.artifactNoFiguresBody,
          )
        else
          ArtifactTableView(table: table),
      ],
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
    final l10n = context.l10n;
    final table = this.table;
    if (table == null || table.isEmpty) {
      return EmptyState(
        scope: EmptyScope.inPanel,
        headline: l10n.artifactNothingToTabulate,
      );
    }

    // A delta column plus a comparison column does not fit a phone, and a table
    // that wraps its figures is not a table. It takes the width it has, and
    // scrolls sideways below the width its columns need.
    return LayoutBuilder(
      builder: (context, constraints) {
        final needed = table.compared ? 480.0 : 260.0;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: constraints.maxWidth < needed ? needed : constraints.maxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: TiqSpace.s2),
                  child: Row(
                    children: <Widget>[
                      for (var i = 0; i < table.columns.length; i++)
                        Expanded(
                          flex: i == 0 ? 3 : 2,
                          child: Eyebrow(table.columns[i]),
                        ),
                    ],
                  ),
                ),
                for (var i = 0; i < table.rows.length; i++)
                  _TableRow(
                    row: table.rows[i],
                    table: table,
                    last: i == table.rows.length - 1,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.row,
    required this.table,
    required this.last,
  });

  final ArtifactTableRow row;
  final ArtifactTable table;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    return Semantics(
      container: true,
      label: <String>[
        ...row.cells,
        if (row.cells.length < table.columns.length) _changeInWords(context),
      ].join('. '),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: TiqSpace.s3),
        decoration: BoxDecoration(
          // A non-tappable row takes the decorative hairline; the 3:1
          // edge-structure rule is for rows a thumb can open.
          border: last
              ? null
              : Border(
                  bottom: BorderSide(
                    color: p.hairline,
                    width: skin.depth.borderWidth,
                  ),
                ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (var i = 0; i < table.columns.length; i++)
              Expanded(
                flex: i == 0 ? 3 : 2,
                child: i < row.cells.length
                    ? Text(
                        row.cells[i],
                        // The label is prose; every other column is a figure,
                        // and a figure is set in the mono face so the columns
                        // align by glyph.
                        style: i == 0
                            ? skin.text.body.style(color: p.ink2)
                            : (i == 1 ? skin.text.figureS : skin.text.meta)
                                  .style(color: i == 1 ? p.ink1 : p.ink3),
                      )
                    : _Change(row: row),
              ),
          ],
        ),
      ),
    );
  }

  String _changeInWords(BuildContext context) {
    final delta = row.delta;
    if (delta == null) return context.l10n.trendsNotMeasured;
    final pct = row.deltaPct;
    final numbers = TiqNumber.of(context);
    return <String>[
      numbers.format(delta, signed: true),
      if (pct != null) formatChangePct(pct, number: numbers),
    ].join(', ');
  }
}

/// The change column: the drawn triangle and the percentage beside it.
class _Change extends StatelessWidget {
  const _Change({required this.row});

  final ArtifactTableRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final delta = row.delta;
    // A delta never stands beside nothing: no movement means no mark at all,
    // and the em dash says the comparison was not made.
    if (delta == null) {
      return Text(
        emDash,
        style: skin.text.figureS.style(color: skin.palette.ink3),
      );
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: TiqSpace.s2,
      children: <Widget>[
        DeltaSlot(
          data: DeltaData(
            direction: delta > 0
                ? DeltaDirection.up
                : delta < 0
                ? DeltaDirection.down
                : DeltaDirection.flat,
            // Direction is the shape and sentiment is the colour, and neither
            // is derived from the other. These figures are all "more is
            // better" pillar metrics, which is stated here once.
            sentiment: delta > 0
                ? TiqSentiment.good
                : delta < 0
                ? TiqSentiment.bad
                : TiqSentiment.neutral,
            magnitude: delta.abs(),
            decimals: 1,
          ),
          figureState: FigureState.measured,
          compact: true,
        ),
        Text(
          // The server's own refusal to invent a percentage, said in words
          // rather than as "n/a" beside a triangle.
          row.deltaPct == null
              ? l10n.artifactNoBaseline
              : formatChangePct(row.deltaPct!, number: TiqNumber.of(context)),
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
      ],
    );
  }
}

/// What this view is called, on screen and in the exported report.
///
/// Shared so the PDF's header and the rule above the chart cannot drift into
/// naming the same thing differently.
String expandedArtifactTitle(BuildContext context, ArtifactDetail artifact) {
  final l10n = context.l10n;
  final data = artifact.data;
  if (artifact.type == 'ranked_bars') {
    return RankedBarsData.from(data).title ?? l10n.artifactTitleRanking;
  }
  if (artifact.type == 'stat_tiles') return l10n.artifactTitleKeyFigures;
  if (artifact.type == 'trend_chart' && data is Map<String, dynamic>) {
    final metric = data['metric'];
    return trendMetricLabels[metric] ??
        (metric is String ? metric : l10n.artifactTitleTrend);
  }
  if (artifact.type == 'pillar_metrics') {
    final pillar = artifact.params['pillar'];
    return switch (pillar) {
      'sales' => l10n.artifactTitleSalesFigures,
      'stock' => l10n.artifactTitleStockFigures,
      'visibility' => l10n.artifactTitleVisibilityFigures,
      'competition' => l10n.artifactTitleCompetitionFigures,
      // The row stores TOOL args, which carry no pillar — the pillar lives in
      // the view spec the chat stream sent, and this screen loads from the
      // server by id. So the honest fallback is the neutral noun.
      _ => l10n.artifactTitleFigures,
    };
  }
  return l10n.artifactTitleView;
}

/// "By day · vs the month before this one", or null when neither applies.
String? expandedArtifactSubtitle(
  BuildContext context,
  ArtifactDetail artifact,
) {
  final l10n = context.l10n;
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
  final parts = <String>[
    if (interval == 'day')
      l10n.artifactByDay
    else if (interval == 'week')
      l10n.artifactByWeek,
    if (label is String && label.isNotEmpty) l10n.artifactVersus(label),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Chart ⇄ Table.
///
/// Two filter chips, which is the one selected vocabulary in this system:
/// lifted fill, a 1px ink-1 border, a tick and weight 700 — three channels, and
/// never amber on any screen in any skin. The trends screen's toggle is the
/// same two chips, deliberately: the table twin is a rule the design system
/// already states, and two toggles that drift apart would make the same
/// affordance behave differently on two screens.
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
    final l10n = context.l10n;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TorchFilterRail(
        semanticsLabel: l10n.trendsViewAs,
        chips: <Widget>[
          TorchFilterChip(
            key: const ValueKey<String>('artifact-view-chart'),
            label: l10n.trendsAsChart,
            selected: !asTable,
            onSelected: () => onChanged(false),
          ),
          TorchFilterChip(
            key: const ValueKey<String>('artifact-view-table'),
            label: l10n.trendsAsTable,
            selected: asTable,
            onSelected: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

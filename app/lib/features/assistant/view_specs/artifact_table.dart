import '../../../core/design/tiq_number.dart';
import '../../../core/format/period_label.dart';
import '../data/artifact_repository.dart';
import 'rich_figures.dart';

/// The table twin's data, derived once and rendered twice.
///
/// The on-screen table and the PDF's vector table are the same table. Deriving
/// them separately is how a report ends up disagreeing with the screen it was
/// exported from — the kind of discrepancy nobody notices until a customer
/// quotes the PDF back at you. So the numbers, the labels and the deltas are
/// computed here; the two renderers only decide how to draw them.
///
/// Every read is type-tested. The shape of a tool result is a convention with
/// the emitting tool, not part of the server-validated spec contract, so a
/// service that renames a field must degrade to a missing row rather than an
/// exception in an export the user is waiting on.

/// One row: the plain cells, plus the movement as numbers.
///
/// The delta stays numeric rather than pre-formatted because the two renderers
/// need different things from it — the screen wants a coloured pill with a
/// glyph, the PDF wants text that survives greyscale printing.
class ArtifactTableRow {
  const ArtifactTableRow({required this.cells, this.delta, this.deltaPct});

  final List<String> cells;

  /// Absolute change against the comparison, or null when there is nothing to
  /// compare this row against — a bucket the other window does not have.
  final double? delta;

  /// Percentage change, or null when the baseline was zero. "Up from nothing"
  /// has no percentage; the server applies the same rule to scalar deltas, and
  /// both renderers print "n/a" rather than inventing one.
  final double? deltaPct;
}

class ArtifactTable {
  const ArtifactTable({
    required this.columns,
    required this.rows,
    required this.compared,
  });

  /// Headers, including the comparison and Change columns when compared.
  final List<String> columns;
  final List<ArtifactTableRow> rows;
  final bool compared;

  bool get isEmpty => rows.isEmpty;
}

/// Human labels for the figures the pillar services return.
///
/// An unlisted key still renders, de-camel-cased: a backend that grows a metric
/// before this build ships shows it with a plain name rather than hiding a
/// number the narrative already mentioned.
const Map<String, String> _figureLabels = {
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

const Set<String> _percentSuffixed = {
  'osaPct',
  'onShelfAvailabilityPct',
  'shareOfShelfPct',
  'visibilityCompliancePct',
  'priceCompliancePct',
  'attainmentPct',
};

const Set<String> _percentMetrics = {
  'availability',
  'perfect_store',
  'share_of_shelf',
};

const Map<String, String> trendMetricLabels = {
  'execution_score': 'Execution score',
  'availability': 'On-shelf availability',
  'perfect_store': 'Perfect-store rate',
  'share_of_shelf': 'Share of shelf',
};

String figureLabel(String key) {
  final known = _figureLabels[key];
  if (known != null) return known;
  final spaced = key.replaceAllMapped(
    RegExp(r'(?<=[a-z0-9])([A-Z])'),
    (m) => ' ${m[1]!.toLowerCase()}',
  );
  return spaced.isEmpty ? key : spaced[0].toUpperCase() + spaced.substring(1);
}

/// A pillar figure as table text, through the one formatter.
///
/// Integers stay integers — "24 lines", not "24.0 lines" — and a percentage
/// keeps one place. The table is built without a context (the PDF has none),
/// so it takes the formatter it is handed; English is the export's language.
String formatFigure(String key, num value, {TiqNumber number = TiqNumber.en}) {
  final percent = _percentSuffixed.contains(key);
  final whole = value == value.roundToDouble();
  return number.format(
    value,
    unit: percent ? TiqUnit.percent : TiqUnit.none,
    decimals: whole && !percent ? 0 : 1,
  );
}

/// Up to one place, a trailing zero dropped, grouped: `1,284.5`, `62`.
String trimNumber(double v, {TiqNumber number = TiqNumber.en}) =>
    number.format(v);

/// A relative change as table text, signed, one place: `+5.8%`, `−40%`.
String formatChangePct(double pct, {TiqNumber number = TiqNumber.en}) =>
    number.format(pct, unit: TiqUnit.percent, decimals: 1, signed: true);

Map<String, dynamic> _map(dynamic value) =>
    value is Map<String, dynamic> ? value : const {};

/// The table for an artifact, or null when its type has no tabular twin.
///
/// A map of outlets and a single scorecard are already whole answers; a table
/// of pin coordinates is not the "table-view twin" the design system means by
/// the term, it is filler.
ArtifactTable? artifactTableFor(ArtifactDetail artifact) {
  switch (artifact.type) {
    case 'trend_chart':
      return _trendTable(artifact);
    case 'pillar_metrics':
      return _pillarTable(artifact);
    case 'stat_tiles':
      return _statTilesTable(artifact);
    case 'ranked_bars':
      return _rankedBarsTable(artifact);
    default:
      return null;
  }
}

/// Points as `(label, value)`, skipping rows that cannot be read.
///
/// A row that is dropped is a row the chart also drops — a fabricated zero is a
/// real data point on a line, and it changes what the line says.
List<({String label, double value})> _points(dynamic raw) {
  if (raw is! List) return const [];
  final points = <({String label, double value})>[];
  for (final row in raw) {
    if (row is! Map<String, dynamic>) continue;
    final value = row['value'];
    if (value is! num || !value.isFinite) continue;
    final period = row['period'];
    points.add((label: period is String ? period : '', value: value.toDouble()));
  }
  return points;
}

ArtifactTable _trendTable(ArtifactDetail artifact) {
  final data = _map(artifact.data);
  final comparison = _map(data['comparison']);
  final label = comparison['label'];
  final points = _points(data['points']);
  final against = _points(comparison['points']);
  final compared = against.isNotEmpty;
  final metric = data['metric'];
  final suffix = metric is String && _percentMetrics.contains(metric) ? '%' : '';

  return ArtifactTable(
    columns: [
      'Period',
      'Value',
      if (compared) label is String && label.isNotEmpty ? label : 'Comparison',
      if (compared) 'Change',
    ],
    compared: compared,
    rows: [
      for (var i = 0; i < points.length; i++)
        _trendRow(points[i], _alignedAt(i, points.length, against), compared, suffix),
    ],
  );
}

/// The comparison point sitting under index [i] of the main series.
///
/// **Positional, and deliberately so.** The two windows are different stretches
/// of calendar with their own bucket labels, and a bucket with no visits
/// produces no point at all — so nth-against-nth is the only alignment
/// available, and it is the one a period-over-period overlay has always used.
/// Both renderers show the compared bucket's own label, so the approximation is
/// visible instead of implied.
({String label, double value})? _alignedAt(
  int i,
  int length,
  List<({String label, double value})> against,
) {
  if (against.isEmpty) return null;
  if (against.length == 1 || length < 2) return against.first;
  final t = i / (length - 1);
  return against[(t * (against.length - 1)).round().clamp(0, against.length - 1)];
}

ArtifactTableRow _trendRow(
  ({String label, double value}) point,
  ({String label, double value})? against,
  bool compared,
  String suffix,
) {
  final delta = against == null ? null : point.value - against.value;
  return ArtifactTableRow(
    cells: [
      // Formatted here rather than in each renderer, so the report and the
      // screen name the same bucket the same way.
      formatPeriodLabel(point.label),
      '${trimNumber(point.value)}$suffix',
      if (compared)
        against == null
            // Stated, never filled in with a zero that would then be
            // differenced into a movement that did not happen.
            ? '—'
            : '${trimNumber(against.value)}$suffix · ${formatPeriodLabel(against.label)}',
    ],
    delta: delta,
    deltaPct: against == null || against.value == 0
        ? null
        : (point.value - against.value) / against.value.abs() * 100,
  );
}

ArtifactTable _pillarTable(ArtifactDetail artifact) {
  final data = _map(artifact.data);
  final comparison = _map(artifact.data is Map<String, dynamic> ? data['comparison'] : null);
  final baseline = _map(comparison['values']);
  final deltas = _map(comparison['deltas']);
  final label = comparison['label'];
  final compared = label is String && label.isNotEmpty;

  final figures = <MapEntry<String, num>>[
    for (final entry in data.entries)
      // Top-level finite numbers only: the result also carries rows and flags,
      // and a stray boolean rendered as a metric is worse than an absent one.
      if (entry.value is num && (entry.value as num).isFinite)
        MapEntry(entry.key, entry.value as num),
  ];

  return ArtifactTable(
    columns: [
      'Figure',
      'Value',
      if (compared) label,
      if (compared) 'Change',
    ],
    compared: compared,
    rows: [
      for (final figure in figures)
        _pillarRow(figure, baseline[figure.key], _map(deltas[figure.key]), compared),
    ],
  );
}

ArtifactTableRow _pillarRow(
  MapEntry<String, num> figure,
  dynamic baseline,
  Map<String, dynamic> delta,
  bool compared,
) {
  final absolute = delta['absolute'];
  final pct = delta['pct'];
  return ArtifactTableRow(
    cells: [
      figureLabel(figure.key),
      formatFigure(figure.key, figure.value),
      if (compared)
        baseline is num && baseline.isFinite
            ? formatFigure(figure.key, baseline)
            : '—',
    ],
    delta: absolute is num && absolute.isFinite ? absolute.toDouble() : null,
    deltaPct: pct is num && pct.isFinite ? pct.toDouble() : null,
  );
}

/// The tiles as rows. Every cell is pre-formatted text — the delta carries its
/// own unit (`%`, `pts`, a count), which the numeric Change column cannot — so
/// the glyph and sign spell the direction on paper as they do on screen.
ArtifactTable _statTilesTable(ArtifactDetail artifact) {
  final tiles = StatTileData.listFrom(artifact.data);
  return ArtifactTable(
    columns: const ['Figure', 'Value', 'Change', 'Compared with'],
    compared: false,
    rows: [
      for (final tile in tiles)
        ArtifactTableRow(
          cells: [
            tile.label,
            tile.formatted(),
            tile.delta?.text() ?? '—',
            tile.comparedTo ?? '—',
          ],
        ),
    ],
  );
}

/// The ranking in the server's own order, labelled as the card labels it.
ArtifactTable _rankedBarsTable(ArtifactDetail artifact) {
  final data = RankedBarsData.from(artifact.data);
  return ArtifactTable(
    columns: const ['Name', 'Value'],
    compared: false,
    rows: [
      for (final item in data.items)
        ArtifactTableRow(
          cells: [item.label, data.label(item.value)],
        ),
    ],
  );
}

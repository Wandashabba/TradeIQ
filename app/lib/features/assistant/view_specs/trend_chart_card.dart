import 'package:flutter/widgets.dart';

import '../../../core/design/figure_slot.dart';
import '../../../core/design/motion_budget.dart';
import '../../../core/design/tiq_number.dart';
import '../../../core/format/period_label.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../l10n/l10n.dart';
import '../answer/answer_motion.dart';
import '../answer/ask_light.dart';
import '../data/chat_controller.dart';
import 'answer_focus.dart';

/// One plotted point.
typedef TrendPoint = ({String label, double value});

/// THE `trend_chart` SPEC — our series against its comparison, over time.
///
/// ## The legend is a rule, not a courtesy
///
/// It renders on **every** chart, every time, before the plot mounts, even
/// with one series. Hue is doing almost nothing for a dichromat on the
/// amber/terracotta pair, so the swatch is drawn with the series' **actual
/// stroke** — solid, or dashed 4-3 — and the spoken legend names the channel
/// and not the colour: "this year, solid line; last year, dashed line". The
/// previous draft said "solid amber; dashed terracotta", which handed a blind
/// manager the one channel she cannot use.
///
/// ## What it does not have
///
/// No tooltip, no crosshair, no scrub, no tap. Those belong to the full view
/// at `/artifact/:id`, which is reachable from the row beneath the block. An
/// inline chart in a transcript is a reading.
///
/// ## Amber
///
/// At most one object: the primary series **and its area fill, counted as a
/// single object**, and only when the route's arbiter lands here — which it
/// does only when the answer has no ranked bars and the trough is empty.
/// Never the comparison, never a gridline, never the target rule, never an
/// axis, never a point marker.
class TrendChartCard extends StatelessWidget {
  const TrendChartCard({super.key, required this.artifact});

  final ChatArtifact artifact;

  /// Titles per metric. An unknown metric falls back to its raw key — a
  /// server that grows the enum before this build ships still gets a titled
  /// chart rather than a nameless one.
  static const Map<String, String> metricLabels = {
    'execution_score': 'Execution score',
    'availability': 'On-shelf availability',
    'perfect_store': 'Perfect-store rate',
    'share_of_shelf': 'Share of shelf',
  };

  /// The metrics whose values are percentages.
  static const Set<String> percentMetrics = {
    'availability',
    'perfect_store',
    'share_of_shelf',
  };

  /// 208 Console phone / 232 Field / 180 Veld / 260 at ≥600dp (unify §1.17).
  /// The assistant surface asked for 160 and lost on its own arithmetic: with
  /// a 38dp gutter that leaves about 120dp of plot.
  static double plotHeightFor(TiqSkin skin, double width) {
    if (skin.density == TiqDensity.veld) return 180;
    if (width >= 600) return 260;
    return skin.density == TiqDensity.field ? 232 : 208;
  }

  Map<String, dynamic> get _data {
    final data = artifact.data;
    return data is Map<String, dynamic> ? data : const {};
  }

  String? _string(String key) {
    final value = _data[key];
    return value is String ? value : null;
  }

  Map<String, dynamic> get _comparison {
    final value = _data['comparison'];
    return value is Map<String, dynamic> ? value : const {};
  }

  /// What the second series is measured against, in the user's own
  /// vocabulary. Null on a turn that asked for no comparison.
  String? get _comparisonLabel {
    final label = _comparison['label'];
    return label is String && label.isNotEmpty ? label : null;
  }

  /// Points from a `{period, value}` row list.
  ///
  /// A row that cannot be read is **skipped, never plotted as zero**: a
  /// fabricated zero is a data point on a chart, and it changes what the line
  /// says.
  List<TrendPoint> _points(dynamic raw) {
    if (raw is! List) return const [];
    final points = <TrendPoint>[];
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
    final skin = context.skin;
    final l10n = context.l10n;
    final metric = _string('metric');
    final title = metricLabels[metric] ?? metric ?? l10n.askOverTime;
    final comparisonLabel = _comparisonLabel;
    final comparison = _points(_comparison['points']);
    final points = _points(_data['points']);
    final percent = metric != null && percentMetrics.contains(metric);
    // The primary series is the route's one lit object only when this chart
    // is the turn's target — which it is only when the answer has no ranking.
    final lit = AnswerFocusScope.isLit(context, artifact);

    // Fewer than two readable points is not a chart. One honest line in the
    // block's slot, and the legend is dropped with it — naming a line that is
    // not there is the failure this avoids.
    if (points.length < 2) {
      return Text(
        l10n.askNotEnoughToPlot(points.length),
        key: const ValueKey<String>('trend-not-enough'),
        style: skin.text.meta.style(color: skin.palette.ink3),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ChartLegend(
            entries: <ChartLegendEntry>[
              // Ink, lit or not. A legend is a label, and amber is never a
              // label: the swatch beside the lit series would be a second
              // lit object on the route. The solid/dashed pattern carries it.
              ChartLegendEntry(
                label: title,
                dashed: false,
                colour: skin.palette.ink1,
              ),
              if (comparisonLabel != null && comparison.isNotEmpty)
                ChartLegendEntry(
                  label: comparisonLabel,
                  dashed: true,
                  colour: skin.palette.comparison,
                ),
            ],
          ),
          // A comparison was asked for and the earlier window had none: say
          // so quietly rather than naming a line that is not on the chart.
          if (comparisonLabel != null && comparison.isEmpty) ...<Widget>[
            const SizedBox(height: TiqSpace.s1),
            Text(
              l10n.askNoComparisonData(comparisonLabel),
              style: skin.text.meta.style(color: skin.palette.ink3),
            ),
          ],
          SizedBox(height: skin.space.intraBlock),
          _Plot(
            points: points,
            comparison: comparison,
            lit: lit,
            percent: percent,
            height: plotHeightFor(skin, constraints.maxWidth),
            title: title,
            comparisonLabel: comparisonLabel,
          ),
        ],
      ),
    );
  }
}

/// One legend entry: a swatch drawn with the series' real stroke, and a name.
@immutable
class ChartLegendEntry {
  const ChartLegendEntry({
    required this.label,
    required this.dashed,
    required this.colour,
  });

  final String label;
  final bool dashed;
  final Color colour;
}

/// A 20dp row above every plot. No boxes, no dots, no colour chips — a chip
/// would show the hue and hide the pattern, which is the channel doing the
/// work.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.entries});

  final List<ChartLegendEntry> entries;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final veld = skin.mode == SkinMode.veld;
    final spoken = <String>[
      for (final e in entries)
        l10n.askLegendEntry(
          e.label,
          e.dashed ? l10n.askChartDashedLine : l10n.askChartSolidLine,
        ),
    ].join('; ');

    return Semantics(
      label: l10n.askLegend(spoken),
      excludeSemantics: true,
      child: Wrap(
        spacing: veld ? TiqSpace.s6 : TiqSpace.s4,
        runSpacing: TiqSpace.s2,
        children: <Widget>[
          for (final entry in entries)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CustomPaint(
                  size: Size(veld ? 20 : 16, veld ? 2 : 2),
                  painter: _SwatchPainter(
                    colour: entry.colour,
                    dashed: entry.dashed,
                    thickness: veld ? 2 : 2,
                  ),
                ),
                const SizedBox(width: 6),
                // Wraps rather than overflowing: a metric name at 2.0× or in
                // Afrikaans is wider than a 360dp phone's panel.
                Flexible(
                  child: Text(
                    entry.label,
                    style: skin.text.label.style(color: skin.palette.ink2),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter({
    required this.colour,
    required this.dashed,
    required this.thickness,
  });

  final Color colour;
  final bool dashed;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + 4).clamp(0, size.width), y),
        paint,
      );
      x += 7;
    }
  }

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.colour != colour || old.dashed != dashed;
}

class _Plot extends StatelessWidget {
  const _Plot({
    required this.points,
    required this.comparison,
    required this.lit,
    required this.percent,
    required this.height,
    required this.title,
    required this.comparisonLabel,
  });

  final List<TrendPoint> points;
  final List<TrendPoint> comparison;
  final bool lit;
  final bool percent;
  final double height;
  final String title;
  final String? comparisonLabel;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final number = TiqNumber.of(context);
    final unit = percent ? TiqUnit.percent : TiqUnit.none;

    String say(double v) => number.format(v, unit: unit, decimals: 1);

    // A spoken summary rather than a picture read aloud: where it started,
    // where it ended, and what it was measured against.
    final summary = <String>[
      title,
      say(points.first.value),
      say(points.last.value),
      if (comparison.isNotEmpty) say(comparison.last.value),
    ].join(', ');

    return Semantics(
      label: summary,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: height,
            child: RepaintBoundary(
              child: GrowIn(
                duration: const Duration(milliseconds: 600),
                builder: (context, t) => ClipRect(
                  // A horizontal clip, not a path-length shader: this system
                  // has a zero-`saveLayer` budget.
                  clipper: _RevealClipper(
                    MotionBudget.of(context).still ? 1 : t,
                  ),
                  child: CustomPaint(
                    painter: _TrendPainter(
                      skin: skin,
                      points: points,
                      comparison: comparison,
                      series: AskLight.focusFill(skin, lit: lit),
                      wash: AskLight.seriesWash(skin, lit: lit),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: TiqSpace.s1),
          // The axis row. Mono, ink-3, thinned to the first and the last —
          // at 2.0× they thin further rather than overlapping.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                points.first.label,
                style: skin.text.axisLabel.style(color: skin.palette.ink3),
              ),
              Text(
                points.last.label,
                style: skin.text.axisLabel.style(color: skin.palette.ink3),
              ),
            ],
          ),
          const SizedBox(height: TiqSpace.s1),
          // The values behind the picture, always — the plate's own table
          // twin, in one line, because a chart nobody can read is a chart
          // that said nothing.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              FigureSlot(
                value: points.first.value,
                role: skin.text.figureS,
                unit: unit,
                decimals: 1,
                color: skin.palette.ink2,
                semanticsLabel: l10n.askOverTime,
              ),
              FigureSlot(
                value: points.last.value,
                role: skin.text.figureS,
                unit: unit,
                decimals: 1,
                color: skin.palette.ink1,
                textAlign: TextAlign.end,
                semanticsLabel: l10n.askOverTime,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Reveals the plot left to right.
class _RevealClipper extends CustomClipper<Rect> {
  const _RevealClipper(this.t);

  final double t;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * t, size.height);

  @override
  bool shouldReclip(_RevealClipper old) => old.t != t;
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.skin,
    required this.points,
    required this.comparison,
    required this.series,
    required this.wash,
  });

  final TiqSkin skin;
  final List<TrendPoint> points;
  final List<TrendPoint> comparison;
  final Color series;
  final Gradient wash;

  @override
  void paint(Canvas canvas, Size size) {
    final values = <double>[
      for (final p in points) p.value,
      for (final p in comparison) p.value,
    ];
    var low = values.reduce((a, b) => a < b ? a : b);
    var high = values.reduce((a, b) => a > b ? a : b);
    if (high - low < 0.0001) {
      // All values equal: a ±10% band, so a flat line sits in the middle
      // rather than on the floor.
      final pad = high.abs() < 0.0001 ? 1.0 : high.abs() * 0.1;
      low -= pad;
      high += pad;
    }
    final span = high - low;

    double y(double v) => size.height * (1 - (v - low) / span);
    double x(int i, int n) => n <= 1 ? 0 : size.width * i / (n - 1);

    final veld = skin.mode == SkinMode.veld;

    // Gridlines: horizontal only, three, hairline in Night and Day and a 2px
    // border in Veld at two values. No vertical gridlines, no plot border,
    // no background fill — the legend above and the axis row below bound it.
    final grid = Paint()
      ..color = veld ? skin.palette.ink1 : skin.palette.hairline
      ..strokeWidth = veld ? 2 : 1;
    final lines = veld ? 2 : 3;
    for (var i = 0; i <= lines; i++) {
      final gy = size.height * i / lines;
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), grid);
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final point = Offset(x(i, points.length), y(points[i].value));
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }

    // The area fill is part of the series object, not a second one: one
    // gradient in the same draw call, and never in Veld.
    if (!veld) {
      final area = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()..shader = wash.createShader(Offset.zero & size),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = series
        ..strokeWidth = veld ? 2 : 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    if (comparison.length >= 2) {
      // 1.5dp dashed, and NEVER an area fill: a filled comparison breaks the
      // 1.41:1 deuteranopia pair that the stroke pattern is carrying.
      final dash = Paint()
        ..color = veld ? skin.palette.ink2 : skin.palette.comparison
        ..strokeWidth = veld ? 2 : 1.5
        ..style = PaintingStyle.stroke;
      Offset? previous;
      for (var i = 0; i < comparison.length; i++) {
        final point = Offset(
          x(i, comparison.length),
          y(comparison[i].value),
        );
        if (previous != null) _dashed(canvas, previous, point, dash, veld);
        previous = point;
      }
    }

    // One point marker per series: the last. Everything else is a line.
    canvas.drawCircle(
      Offset(x(points.length - 1, points.length), y(points.last.value)),
      3,
      Paint()..color = series,
    );
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint, bool veld) {
    final total = (b - a).distance;
    if (total == 0) return;
    final step = veld ? 10.0 : 7.0;
    final on = veld ? 6.0 : 4.0;
    final direction = (b - a) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final end = (travelled + on).clamp(0.0, total);
      canvas.drawLine(a + direction * travelled, a + direction * end, paint);
      travelled += step;
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points != points ||
      old.comparison != comparison ||
      old.series != series ||
      old.skin != skin;
}

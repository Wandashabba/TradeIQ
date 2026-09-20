import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../../design/tiq_number.dart';
import '../../../../theme/torchlight/tiq_skin.dart';
import 'chart_legend.dart';
import 'chart_series.dart';
import 'scrub_readout.dart';

/// THE TREND CHART, and the frame it is drawn in.
///
/// A run of readings over time, with an optional comparison run behind it and
/// an optional dashed threshold across it. One component, four rules it does
/// not bend:
///
/// **The legend is mandatory.** It is not a parameter — [TrendChart] builds a
/// [ChartLegend] from the series it was handed. The old chart set took
/// `comparisonName` as an option and shipped two-line charts with no key.
///
/// **A comparison series is dashed.** Truffle *and* a dash, never Truffle
/// alone: unify §4 wants a second channel on every hue-coded distinction, and
/// the dash is the one that survives greyscale, deuteranopia, a printed page
/// and 40% backlight in a warehouse.
///
/// **Nothing here is amber.** The chart focus rung exists on the ladder and
/// this component declines it. The subject is carried by weight (2dp against
/// 1.5), by a solid stroke against a dashed one, and by the legend's word —
/// three channels, none of them light. A trends route carries three of these
/// and the budget is counted per route, so the honest answer is zero.
///
/// **A null reading breaks the line.** The trends endpoints omit an empty
/// bucket rather than sending a zero. Joining across a gap would draw a
/// straight line through a week nobody measured and invite a manager to read a
/// trend off it; the stroke stops instead, and the legend counts the gaps.
///
/// **In Veld it does not render at all.** unify §4: "the plate, sparklines,
/// trend charts, maps and thumbnails do not render; figure lists replace
/// them". The caller supplies that list — [TrendChart] is not going to invent
/// one — and this widget renders [veldReplacement] in its place, or the
/// legend alone if the caller passed none.
class TrendChart extends StatefulWidget {
  const TrendChart({
    super.key,
    required this.series,
    required this.unit,
    required this.semanticsLabel,
    this.threshold,
    this.decimals,
    required this.notMeasuredWord,
    this.gapNote,
    this.veldReplacement,
    this.scrubHint,
  }) : assert(series.length > 0, 'A chart with no series is not a chart.');

  /// The subject first, the comparison after it. At most one of each — see
  /// [ChartSeriesRole].
  final List<ChartSeries> series;

  final TiqUnit unit;
  final int? decimals;

  /// A dashed rule across the plot, named in the legend.
  final ChartThreshold? threshold;

  /// What a screen reader is told the chart is. The **values** are not in
  /// here: they are in the table twin, which is a real widget with real rows
  /// rather than a paragraph read out at 200 words a minute.
  final String semanticsLabel;

  /// The words a null reading takes in the scrub readout, localised.
  final String notMeasuredWord;

  /// "2 weeks not measured", from the caller's own plural rules.
  final String? gapNote;

  /// What renders instead of the plot in Veld.
  final Widget? veldReplacement;

  /// "Drag across the chart to read a week." Shown under the plot on a touch
  /// device; null hides it.
  final String? scrubHint;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  /// Which bucket the thumb is on, or null for none. A readout, never a
  /// selection: nothing is gated behind it and the table twin holds every
  /// value it can show.
  int? _scrub;

  ChartSeries get _subject => widget.series.firstWhere(
    (s) => s.role == ChartSeriesRole.subject,
    orElse: () => widget.series.first,
  );

  ChartSeries? get _comparison {
    for (final s in widget.series) {
      if (s.role == ChartSeriesRole.comparison) return s;
    }
    return null;
  }

  void _scrubTo(Offset local, double width, int count) {
    if (count == 0) return;
    final step = count == 1 ? width : width / (count - 1);
    final index = (local.dx / step).round().clamp(0, count - 1);
    if (index != _scrub) setState(() => _scrub = index);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final legend = ChartLegend(
      series: widget.series,
      threshold: widget.threshold,
      gapNote: widget.gapNote,
    );

    if (skin.mode == SkinMode.veld) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          legend,
          if (widget.veldReplacement != null) ...<Widget>[
            SizedBox(height: skin.space.intraBlock),
            widget.veldReplacement!,
          ],
        ],
      );
    }

    final subject = _subject;
    final height = trendChartHeight(context);
    final readings = subject.readings;
    final scrubIndex = _scrub;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        legend,
        SizedBox(height: skin.space.intraBlock),
        Semantics(
          label: widget.semanticsLabel,
          excludeSemantics: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) =>
                    _scrubTo(d.localPosition, width, readings.length),
                onHorizontalDragUpdate: (d) =>
                    _scrubTo(d.localPosition, width, readings.length),
                onHorizontalDragEnd: (_) => setState(() => _scrub = null),
                onHorizontalDragCancel: () => setState(() => _scrub = null),
                onTapDown: (d) =>
                    _scrubTo(d.localPosition, width, readings.length),
                onTapUp: (_) => setState(() => _scrub = null),
                onTapCancel: () => setState(() => _scrub = null),
                child: SizedBox(
                  height: height,
                  child: CustomPaint(
                    painter: TrendChartPainter(
                      skin: skin,
                      subject: subject,
                      comparison: _comparison,
                      threshold: widget.threshold,
                      scrub: scrubIndex,
                      axisStyle: skin.text.axisLabel.style(
                        color: skin.palette.ink3,
                      ),
                      axisScale: TiqTextScale.sizeOf(
                            MediaQuery.maybeTextScalerOf(context) ??
                                TextScaler.noScaling,
                            skin.text.axisLabel,
                          ) /
                          skin.text.axisLabel.size,
                      textDirection: Directionality.of(context),
                    ),
                    isComplex: true,
                    willChange: false,
                  ),
                ),
              );
            },
          ),
        ),
        if (scrubIndex != null && scrubIndex < readings.length) ...<Widget>[
          SizedBox(height: skin.space.intraBlock),
          ScrubReadout(
            period: readings[scrubIndex].readLabel,
            entries: <ScrubEntry>[
              for (final s in widget.series)
                if (scrubIndex < s.readings.length)
                  ScrubEntry(
                    name: s.name,
                    value: s.readings[scrubIndex].value,
                    role: s.role,
                  ),
            ],
            unit: widget.unit,
            decimals: widget.decimals,
            notMeasuredWord: widget.notMeasuredWord,
          ),
        ] else if (widget.scrubHint != null) ...<Widget>[
          SizedBox(height: skin.space.intraBlock),
          Text(
            widget.scrubHint!,
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
        ],
      ],
    );
  }
}

/// The plot. Public so its arithmetic can be exercised without a widget tree.
class TrendChartPainter extends CustomPainter {
  TrendChartPainter({
    required this.skin,
    required this.subject,
    required this.comparison,
    required this.threshold,
    required this.scrub,
    required this.axisStyle,
    required this.axisScale,
    required this.textDirection,
  });

  final TiqSkin skin;
  final ChartSeries subject;
  final ChartSeries? comparison;
  final ChartThreshold? threshold;
  final int? scrub;
  final TextStyle axisStyle;
  final double axisScale;
  final TextDirection textDirection;

  /// How much room the axis labels take under the plot.
  static const double axisBand = 20;

  @override
  void paint(Canvas canvas, Size size) {
    final readings = subject.readings;
    if (readings.isEmpty) return;

    final band = axisBand * axisScale;
    final plot = Rect.fromLTWH(
      0,
      0,
      size.width,
      math.max(size.height - band, 1),
    );

    final scale = niceScale(
      <double>[
        for (final r in readings)
          ?r.value,
        if (comparison != null)
          for (final r in comparison!.readings)
            ?r.value,
      ],
      include: threshold?.value,
    );

    double y(double value) {
      final span = scale.max - scale.min;
      if (span <= 0) return plot.bottom;
      return plot.bottom -
          ((value - scale.min) / span).clamp(0.0, 1.0) * plot.height;
    }

    final count = readings.length;
    double x(int index) =>
        count == 1 ? plot.center.dx : plot.width * index / (count - 1);

    // ── Gridlines. `lifted`, per unify §1.17, and solid: a dashed gridline
    // would compete with the threshold, which is the one dash that means
    // something here.
    final grid = Paint()
      ..color = skin.palette.lifted
      ..strokeWidth = 1;
    for (var v = scale.min; v <= scale.max + 1e-9; v += scale.step) {
      final gy = y(v);
      canvas.drawLine(Offset(plot.left, gy), Offset(plot.right, gy), grid);
    }

    // ── The baseline axis. 1dp ink-1 at 15:1 — never amber (unify §1.1).
    final axis = Paint()
      ..color = skin.palette.ink1
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(plot.left, plot.bottom),
      Offset(plot.right, plot.bottom),
      axis,
    );

    // ── The threshold, dashed, ink-1.
    final rule = threshold;
    if (rule != null && rule.value >= scale.min && rule.value <= scale.max) {
      _dashedLine(
        canvas,
        Offset(plot.left, y(rule.value)),
        Offset(plot.right, y(rule.value)),
        Paint()
          ..color = skin.palette.ink1
          ..strokeWidth = 1,
        dash: 4,
        gap: 4,
      );
    }

    // ── The comparison, behind the subject: dashed Truffle at 1.5dp.
    final other = comparison;
    if (other != null) {
      _series(
        canvas,
        other.readings,
        x: x,
        y: y,
        count: count,
        paint: Paint()
          ..color = skin.palette.comparison
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
        dashed: true,
      );
    }

    // ── The subject: solid chartNeutral at 2dp.
    _series(
      canvas,
      readings,
      x: x,
      y: y,
      count: count,
      paint: Paint()
        ..color = skin.palette.chartNeutral
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
      dashed: false,
    );

    // ── The scrub line and its dot. ink-1, never amber.
    final at = scrub;
    if (at != null && at < count) {
      final sx = x(at);
      canvas.drawLine(
        Offset(sx, plot.top),
        Offset(sx, plot.bottom),
        Paint()
          ..color = skin.palette.ink1
          ..strokeWidth = 1,
      );
      final value = readings[at].value;
      if (value != null) {
        canvas.drawCircle(
          Offset(sx, y(value)),
          4,
          Paint()..color = skin.palette.ink1,
        );
      }
    }

    // ── The axis labels. First, last, and the scrubbed one — an axis with a
    // label per bucket at 2.0x is a grey smear.
    final wanted = <int>{0, count - 1, ?at};
    for (final index in wanted) {
      if (index < 0 || index >= count) continue;
      final painter = TextPainter(
        text: TextSpan(text: readings[index].label, style: axisStyle),
        textDirection: textDirection,
        maxLines: 1,
      )..layout(maxWidth: math.max(plot.width / 2, 24));
      var left = x(index) - painter.width / 2;
      left = left.clamp(0.0, math.max(plot.width - painter.width, 0.0));
      painter.paint(canvas, Offset(left, plot.bottom + (band - painter.height) / 2));
      painter.dispose();
    }
  }

  void _series(
    Canvas canvas,
    List<ChartReading> readings, {
    required double Function(int) x,
    required double Function(double) y,
    required int count,
    required Paint paint,
    required bool dashed,
  }) {
    // One run per unbroken stretch: a null breaks the path rather than being
    // interpolated across.
    var path = Path();
    var open = false;
    var drawn = 0;
    for (var i = 0; i < readings.length && i < count; i++) {
      final value = readings[i].value;
      if (value == null) {
        if (open && drawn > 1) _stroke(canvas, path, paint, dashed);
        // A single point with gaps either side gets a dot, because a path of
        // one point strokes nothing and a measured week must not vanish.
        if (open && drawn == 1) {
          canvas.drawCircle(
            _lastPoint!,
            paint.strokeWidth,
            Paint()..color = paint.color,
          );
        }
        path = Path();
        open = false;
        drawn = 0;
        continue;
      }
      final point = Offset(x(i), y(value));
      if (!open) {
        path.moveTo(point.dx, point.dy);
        open = true;
      } else {
        path.lineTo(point.dx, point.dy);
      }
      _lastPoint = point;
      drawn++;
    }
    if (open && drawn > 1) {
      _stroke(canvas, path, paint, dashed);
    } else if (open && drawn == 1) {
      canvas.drawCircle(
        _lastPoint!,
        paint.strokeWidth,
        Paint()..color = paint.color,
      );
    }
  }

  Offset? _lastPoint;

  void _stroke(Canvas canvas, Path path, Paint paint, bool dashed) {
    canvas.drawPath(dashed ? _dash(path, 6, 4) : path, paint);
  }

  void _dashedLine(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    final total = (to - from).distance;
    if (total <= 0) return;
    final direction = (to - from) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final end = math.min(travelled + dash, total);
      canvas.drawLine(
        from + direction * travelled,
        from + direction * end,
        paint,
      );
      travelled = end + gap;
    }
  }

  /// [source] cut into [dash]-long strokes separated by [gap].
  Path _dash(Path source, double dash, double gap) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        out.addPath(metric.extractPath(distance, end), Offset.zero);
        distance = end + gap;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(TrendChartPainter old) =>
      old.skin != skin ||
      old.subject != subject ||
      old.comparison != comparison ||
      old.threshold != threshold ||
      old.scrub != scrub ||
      old.axisScale != axisScale;
}

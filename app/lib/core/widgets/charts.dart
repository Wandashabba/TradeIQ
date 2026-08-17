import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/tiq_colors.dart';

/// The console's chart set. Hand-rolled on [CustomPainter] — the shapes needed
/// are simple, and a package would still have to be fought into this spec.
///
/// Rules baked in, so a caller cannot easily break them:
///
/// * **One series, one hue.** No chart here cycles or generates colours; a
///   value-ramp on nominal categories is not expressible.
/// * **Recessive chrome.** Gridlines and axes are solid hairlines one shade off
///   the surface. Never dashed — except a genuine *threshold* rule, which is
///   what a dashed line actually means.
/// * **Selective labels.** The endpoint gets a direct label; every other value
///   lives on the axis, in the tooltip, or in the table-view twin.
/// * **Hit areas beat marks.** Hover snaps to the nearest point across the full
///   plot, not to an 8px dot.

/// One (label, value) pair. Deliberately not tied to the trends DTO so charts
/// stay usable from any feature.
typedef ChartPoint = ({String label, double value});

/// The redesign's one "glass" area recipe — [brand] fading 28% → 0%, top to
/// bottom. Shared by the hero [LineChart] and the KPI [Sparkline] so the two
/// can never drift apart; the stops are pinned by charts_test.dart.
LinearGradient glassAreaGradient(Color brand) => LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [brand.withValues(alpha: 0.28), brand.withValues(alpha: 0.0)],
);

TextStyle _labelStyle(TiqColors c) => TextStyle(fontSize: 10, color: c.ink3);

TextPainter _text(String s, {required TextStyle style}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  return tp;
}

/// Rounds a range out to "nice" bounds so the axis ticks land on round numbers
/// instead of on the data's raw min/max.
({double min, double max, double step}) _niceScale(
  Iterable<double> values, {
  int ticks = 4,
  double? forceMin,
}) {
  var lo = values.isEmpty ? 0.0 : values.reduce(math.min);
  var hi = values.isEmpty ? 1.0 : values.reduce(math.max);
  if (forceMin != null) lo = math.min(lo, forceMin);
  if (hi - lo < 1e-9) {
    hi = lo + 1;
  }
  // Pad so the line never rides the top or bottom edge of the plot.
  final pad = (hi - lo) * 0.18;
  lo -= pad;
  hi += pad;

  final raw = (hi - lo) / ticks;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final norm = raw / mag;
  final step =
      (norm <= 1
          ? 1
          : norm <= 2
          ? 2
          : norm <= 5
          ? 5
          : 10) *
      mag;

  final niceMin = (lo / step).floor() * step;
  final niceMax = (hi / step).ceil() * step;
  return (min: niceMin, max: niceMax, step: step);
}

// ═══════════════════════════════════════════════════════════════════════
// Line chart — trend over time, with an optional target rule and a
// crosshair that snaps to the nearest point.
// ═══════════════════════════════════════════════════════════════════════

class LineChart extends StatefulWidget {
  const LineChart({
    super.key,
    required this.points,
    this.target,
    this.height = 208,
    this.valueSuffix = '',
    this.seriesName = '',
    this.lineWidth = 2,
    this.gradientFill = false,
    this.comparison = const [],
    this.comparisonName = '',
  });

  final List<ChartPoint> points;
  final double? target;
  final double height;
  final String valueSuffix;
  final String seriesName;

  /// Stroke weight of the series. The dataviz rules cap marks at 2–2.5px —
  /// a hero chart may take 2.5; nothing may go heavier.
  final double lineWidth;

  /// When true the area under the line fades brand 28% → 0% top-to-bottom —
  /// the redesign's "glass" recipe — instead of the flat series wash.
  final bool gradientFill;

  /// A second series drawn beside the first — the same metric over an earlier
  /// window, which is the comparison that replaces exporting twice and
  /// overlaying the two in Excel.
  ///
  /// **This does not break "one series, one hue."** That rule forbids *cycling
  /// or generating* colours across nominal categories; two named series take
  /// the palette's two fixed series slots, and the widget refuses to draw a
  /// third. The comparison takes [TiqColors.series2], gets no area fill and no
  /// endpoint label — the current period stays the figure being read, and the
  /// comparison is the reference behind it.
  ///
  /// **Aligned by position, not by date.** The two windows are different
  /// stretches of calendar with their own bucket labels, and a bucket with no
  /// visits produces no point at all, so nth-against-nth is the only alignment
  /// available — the same one a period-over-period overlay has always used.
  /// The scrub readout names both buckets so that alignment is visible rather
  /// than assumed.
  ///
  /// Empty (the default) means every existing caller is byte-for-byte
  /// unchanged: no legend row, no second stroke, no scale contribution.
  final List<ChartPoint> comparison;

  /// What the comparison is, for the legend and the readout — "the month before
  /// this one". Colour is never the only carrier of which line is which.
  final String comparisonName;

  @override
  State<LineChart> createState() => _LineChartState();
}

class _LineChartState extends State<LineChart> {
  int? _hover;

  @override
  Widget build(BuildContext context) {
    if (widget.points.length < 2) {
      return _EmptyPlot(
        height: widget.height,
        message: 'Not enough data to plot',
      );
    }

    final colors = context.colors;
    final scale = _niceScale(
      // Both series, or the comparison rides off the top of the plot on the
      // first month it beat the current one.
      [...widget.points, ...widget.comparison].map((p) => p.value),
      forceMin: widget.target,
    );

    final plot = SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The series DRAWS ITSELF left to right on load and whenever the range
          // changes. It is not decoration: it makes the direction of the data the
          // first thing you perceive, before you have read a single axis label.
          // Keyed on the data, so switching 30d -> 90d re-draws rather than
          // silently swapping one line for another.
          return TweenAnimationBuilder<double>(
            key: ValueKey(widget.points.length),
            tween: Tween(begin: 0, end: 1),
            duration: _reduceMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 620),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) {
              final painter = _LinePainter(
                points: widget.points,
                comparison: widget.comparison,
                scale: scale,
                target: widget.target,
                hover: _hover,
                valueSuffix: widget.valueSuffix,
                progress: t,
                colors: colors,
                lineWidth: widget.lineWidth,
                gradientFill: widget.gradientFill,
              );

              return MouseRegion(
                onHover: (e) => _updateHover(
                  e.localPosition,
                  constraints.maxWidth,
                  painter,
                ),
                onExit: (_) => setState(() => _hover = null),
                child: GestureDetector(
                  // Scrub: press and drag along the series to read every point.
                  // Touch gets exactly what the mouse gets.
                  onTapDown: (e) => _updateHover(
                    e.localPosition,
                    constraints.maxWidth,
                    painter,
                  ),
                  onHorizontalDragStart: (e) => _updateHover(
                    e.localPosition,
                    constraints.maxWidth,
                    painter,
                  ),
                  onHorizontalDragUpdate: (e) => _updateHover(
                    e.localPosition,
                    constraints.maxWidth,
                    painter,
                  ),
                  onHorizontalDragEnd: (_) => setState(() => _hover = null),
                  onTapUp: (_) => setState(() => _hover = null),
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, widget.height),
                    painter: painter,
                    child: _hover == null
                        ? null
                        : _ScrubReadout(
                            point: widget.points[_hover!],
                            // The change from the previous point, coloured. A
                            // value alone says where you are; a delta says which
                            // way you are going.
                            previous: _hover! > 0
                                ? widget.points[_hover! - 1].value
                                : null,
                            against: _comparisonAt(_hover!),
                            againstName: widget.comparisonName,
                            suffix: widget.valueSuffix,
                            seriesName: widget.seriesName,
                            x: painter.xFor(_hover!, constraints.maxWidth),
                            plotWidth: constraints.maxWidth,
                          ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );

    if (widget.comparison.isEmpty) return plot;

    // Two lines need a legend, always: the palette's series slots are the only
    // thing distinguishing them on the canvas, and colour may not be the sole
    // carrier of meaning. Added only in the comparison case, so a single-series
    // caller keeps exactly the footprint it had.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 38, bottom: 6),
          child: Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _LegendItem(
                color: colors.series1,
                label: widget.seriesName.isEmpty
                    ? 'This period'
                    : widget.seriesName,
              ),
              _LegendItem(
                color: colors.series2,
                label: widget.comparisonName.isEmpty
                    ? 'Comparison'
                    : widget.comparisonName,
              ),
            ],
          ),
        ),
        plot,
      ],
    );
  }

  /// The comparison point that sits under index [i] of the main series.
  ///
  /// Positional, and deliberately: see [LineChart.comparison]. Returns null
  /// when there is no comparison rather than reaching for a nearby bucket —
  /// a value the user cannot trace back to a date is worse than a gap.
  ChartPoint? _comparisonAt(int i) {
    final other = widget.comparison;
    if (other.isEmpty) return null;
    if (other.length == 1) return other.first;
    if (widget.points.length < 2) return other.first;
    final t = i / (widget.points.length - 1);
    return other[(t * (other.length - 1)).round().clamp(0, other.length - 1)];
  }

  void _updateHover(Offset local, double width, _LinePainter painter) {
    final i = painter.nearestIndex(local.dx, width);
    if (i != _hover) setState(() => _hover = i);
  }
}

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.points,
    required this.scale,
    required this.target,
    required this.hover,
    required this.valueSuffix,
    required this.colors,
    this.comparison = const [],
    this.progress = 1,
    this.lineWidth = 2,
    this.gradientFill = false,
  });

  final List<ChartPoint> points;

  /// The second series, spanning the same plot width. Empty for every
  /// single-series caller.
  final List<ChartPoint> comparison;
  final ({double min, double max, double step}) scale;
  final double? target;
  final int? hover;
  final String valueSuffix;
  final TiqColors colors;
  final double lineWidth;
  final bool gradientFill;

  /// 0 → 1 as the series draws itself in. The chrome (grid, axes, target rule)
  /// is painted immediately: the frame of reference should never be the thing
  /// that is animating.
  final double progress;

  static const _pad = EdgeInsets.fromLTRB(38, 12, 46, 24);

  double xFor(int i, double width) {
    final inner = width - _pad.left - _pad.right;
    return _pad.left + (i / (points.length - 1)) * inner;
  }

  double _yFor(double v, double height) {
    final inner = height - _pad.top - _pad.bottom;
    final t = (v - scale.min) / (scale.max - scale.min);
    return _pad.top + inner - t * inner;
  }

  int nearestIndex(double dx, double width) {
    final inner = width - _pad.left - _pad.right;
    final step = inner / (points.length - 1);
    final i = ((dx - _pad.left) / step).round();
    return i.clamp(0, points.length - 1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final innerW = size.width - _pad.left - _pad.right;
    final baseY = size.height - _pad.bottom;

    final hair = Paint()
      ..color = colors.grid
      ..strokeWidth = 1;

    // y gridlines + ticks
    for (var v = scale.min; v <= scale.max + 1e-9; v += scale.step) {
      final y = _yFor(v, size.height);
      canvas.drawLine(
        Offset(_pad.left, y),
        Offset(_pad.left + innerW, y),
        hair,
      );
      final tp = _text(_trim(v), style: _labelStyle(colors));
      tp.paint(canvas, Offset(_pad.left - 8 - tp.width, y - tp.height / 2));
    }

    // Target: the one legitimate dashed rule — it *is* a threshold.
    if (target != null) {
      final y = _yFor(target!, size.height);
      final dash = Paint()
        // ink4: a stroke, not text — 3:1 is the bar, and the quieter weight
        // keeps the rule behind the data.
        ..color = colors.ink4
        ..strokeWidth = 1;
      for (var x = _pad.left; x < _pad.left + innerW; x += 6) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 3, _pad.left + innerW), y),
          dash,
        );
      }
      final tp = _text('Target', style: _labelStyle(colors));
      tp.paint(canvas, Offset(_pad.left + innerW + 5, y - tp.height / 2));
    }

    // The comparison, under everything else and inside the same reveal clip.
    // No fill: two washes over one plot muddy both, and the current period is
    // the figure being read — the comparison is the reference behind it.
    if (comparison.length > 1) {
      final other = Path();
      for (var i = 0; i < comparison.length; i++) {
        final inner = size.width - _pad.left - _pad.right;
        final o = Offset(
          _pad.left + (i / (comparison.length - 1)) * inner,
          _yFor(comparison[i].value, size.height),
        );
        i == 0 ? other.moveTo(o.dx, o.dy) : other.lineTo(o.dx, o.dy);
      }
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(_pad.left, 0, innerW * progress.clamp(0, 1), size.height),
      );
      canvas.drawPath(
        other,
        Paint()
          ..color = colors.series2
          ..style = PaintingStyle.stroke
          ..strokeWidth = lineWidth
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }

    // Area + line, revealed left-to-right by `progress`.
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(
        xFor(i, size.width),
        _yFor(points[i].value, size.height),
      );
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    final area = Path.from(path)
      ..lineTo(xFor(points.length - 1, size.width), baseY)
      ..lineTo(_pad.left, baseY)
      ..close();

    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(_pad.left, 0, innerW * progress.clamp(0, 1), size.height),
    );
    final areaPaint = Paint();
    if (gradientFill) {
      // Brand, not series1: the gradient fill is the accent's one chart
      // moment (spec §Sub-project 2 — `#0A6CF0` at 28% → 0%).
      areaPaint.shader = glassAreaGradient(colors.brand).createShader(
        Rect.fromLTRB(_pad.left, _pad.top, _pad.left + innerW, baseY),
      );
    } else {
      areaPaint.color = colors.series1.withValues(alpha: 0.14);
    }
    canvas.drawPath(area, areaPaint);
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.series1
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    // Baseline + x ticks: first, middle, last only.
    canvas.drawLine(
      Offset(_pad.left, baseY),
      Offset(_pad.left + innerW, baseY),
      Paint()
        ..color = colors.axis
        ..strokeWidth = 1,
    );
    for (final i in {0, points.length ~/ 2, points.length - 1}) {
      final tp = _text(points[i].label, style: _labelStyle(colors));
      final x = xFor(i, size.width);
      final dx = i == 0
          ? x
          : i == points.length - 1
          ? x - tp.width
          : x - tp.width / 2;
      tp.paint(canvas, Offset(dx, size.height - _pad.bottom + 7));
    }

    // Endpoint marker + the one direct label — only once the line has arrived
    // there, so the label never floats ahead of its own data.
    if (progress < 0.995) return;
    final last = points.length - 1;
    final lastO = Offset(
      xFor(last, size.width),
      _yFor(points[last].value, size.height),
    );
    canvas.drawCircle(lastO, 4, Paint()..color = colors.series1);
    canvas.drawCircle(
      lastO,
      4,
      Paint()
        ..color = colors.surface1
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final lbl = _text(
      '${_trim(points[last].value)}$valueSuffix',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: colors.ink2,
      ),
    );
    lbl.paint(canvas, Offset(lastO.dx - lbl.width, lastO.dy - lbl.height - 7));

    // Crosshair
    if (hover != null) {
      final hx = xFor(hover!, size.width);
      canvas.drawLine(
        Offset(hx, _pad.top),
        Offset(hx, baseY),
        Paint()
          ..color = colors.axis
          ..strokeWidth = 1,
      );
      final ho = Offset(hx, _yFor(points[hover!].value, size.height));
      canvas.drawCircle(ho, 4.5, Paint()..color = colors.series1);
      canvas.drawCircle(
        ho,
        4.5,
        Paint()
          ..color = colors.surface1
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.points != points ||
      old.comparison != comparison ||
      old.hover != hover ||
      old.target != target ||
      old.progress != progress ||
      old.colors != colors ||
      old.lineWidth != lineWidth ||
      old.gradientFill != gradientFill;
}

// ═══════════════════════════════════════════════════════════════════════
// Column chart — a value per period.
// ═══════════════════════════════════════════════════════════════════════

class ColumnChart extends StatefulWidget {
  const ColumnChart({
    super.key,
    required this.points,
    this.height = 208,
    this.valueSuffix = '',
    this.seriesName = '',
  });

  final List<ChartPoint> points;
  final double height;
  final String valueSuffix;
  final String seriesName;

  @override
  State<ColumnChart> createState() => _ColumnChartState();
}

class _ColumnChartState extends State<ColumnChart>
    with SingleTickerProviderStateMixin {
  int? _hover;
  late AnimationController _c;
  double _progress = 1;

  @override
  void initState() {
    super.initState();
    // Columns rise from the baseline. Growth is the one motion a bar chart can
    // carry without lying: it starts at zero, which is where the axis is.
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    )..addListener(() => setState(() => _progress = _c.value));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _progress = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void didUpdateWidget(ColumnChart old) {
    super.didUpdateWidget(old);
    // New data — a new range — re-draws rather than morphing one series into
    // another, which would imply a continuity that is not there.
    if (old.points != widget.points) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return _EmptyPlot(height: widget.height, message: 'No data in range');
    }
    final colors = context.colors;
    final scale = _niceScale(widget.points.map((p) => p.value));

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = _ColumnPainter(
            points: widget.points,
            scale: scale,
            hover: _hover,
            progress: _progress,
            colors: colors,
          );
          return MouseRegion(
            onHover: (e) {
              final i = painter.indexAt(
                e.localPosition.dx,
                constraints.maxWidth,
              );
              if (i != _hover) setState(() => _hover = i);
            },
            onExit: (_) => setState(() => _hover = null),
            child: CustomPaint(
              size: Size(constraints.maxWidth, widget.height),
              painter: painter,
              child: _hover == null
                  ? null
                  : _Tooltip(
                      point: widget.points[_hover!],
                      suffix: widget.valueSuffix,
                      seriesName: widget.seriesName,
                      x: painter.centerOf(_hover!, constraints.maxWidth),
                      plotWidth: constraints.maxWidth,
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _ColumnPainter extends CustomPainter {
  _ColumnPainter({
    required this.points,
    required this.scale,
    required this.hover,
    required this.colors,
    this.progress = 1,
  });

  final List<ChartPoint> points;
  final ({double min, double max, double step}) scale;
  final int? hover;
  final double progress;
  final TiqColors colors;

  static const _pad = EdgeInsets.fromLTRB(38, 12, 10, 24);

  double _stepWidth(double width) =>
      (width - _pad.left - _pad.right) / points.length;

  double centerOf(int i, double width) =>
      _pad.left + (i + 0.5) * _stepWidth(width);

  int? indexAt(double dx, double width) {
    final i = ((dx - _pad.left) / _stepWidth(width)).floor();
    return (i < 0 || i >= points.length) ? null : i;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final innerW = size.width - _pad.left - _pad.right;
    final baseY = size.height - _pad.bottom;
    final step = _stepWidth(size.width);
    // The 2px surface gap between adjacent bars is the separator — never a border.
    final barW = math.min(30.0, step - 8);

    final hair = Paint()
      ..color = colors.grid
      ..strokeWidth = 1;

    for (var v = scale.min; v <= scale.max + 1e-9; v += scale.step) {
      final t = (v - scale.min) / (scale.max - scale.min);
      final y = _pad.top + (baseY - _pad.top) - t * (baseY - _pad.top);
      canvas.drawLine(
        Offset(_pad.left, y),
        Offset(_pad.left + innerW, y),
        hair,
      );
      final tp = _text(_trim(v), style: _labelStyle(colors));
      tp.paint(canvas, Offset(_pad.left - 8 - tp.width, y - tp.height / 2));
    }

    for (var i = 0; i < points.length; i++) {
      final t = (points[i].value - scale.min) / (scale.max - scale.min);
      final h = t * (baseY - _pad.top) * progress.clamp(0, 1);
      final x = centerOf(i, size.width) - barW / 2;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, baseY - h, barW, h),
        // 4px rounded data-end, anchored square to the baseline.
        // 2px, not 4. A column is a measurement, not a lozenge.
        topLeft: const Radius.circular(2),
        topRight: const Radius.circular(2),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = hover == null || hover == i
              ? colors.series1
              : colors.series1.withValues(alpha: 0.55),
      );

      final tp = _text(points[i].label, style: _labelStyle(colors));
      tp.paint(
        canvas,
        Offset(
          centerOf(i, size.width) - tp.width / 2,
          size.height - _pad.bottom + 7,
        ),
      );
    }

    canvas.drawLine(
      Offset(_pad.left, baseY),
      Offset(_pad.left + innerW, baseY),
      Paint()
        ..color = colors.axis
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_ColumnPainter old) =>
      old.points != points ||
      old.hover != hover ||
      old.progress != progress ||
      old.colors != colors;
}

// ═══════════════════════════════════════════════════════════════════════
// Horizontal bars — ranked categories against a target.
// ═══════════════════════════════════════════════════════════════════════

/// Bars below [target] take the *critical* status hue, not a second series hue:
/// "below target" is a state, not an identity. Callers must show the legend
/// ([BarChart.legend]) so the colour is never the only carrier of that meaning.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.points,
    required this.target,
    this.max = 100,
  });

  final List<ChartPoint> points;
  final double target;
  final double max;

  static Widget legend() => Builder(
    builder: (context) {
      final colors = context.colors;
      return Row(
        children: [
          _LegendItem(color: colors.series1, label: 'Meets target'),
          const SizedBox(width: 14),
          _LegendItem(color: colors.crit, label: 'Below target'),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _EmptyPlot(height: 120, message: 'No territories in range');
    }

    // Bars fill from the axis. Same rule as the columns: the animation starts at
    // zero, which is where the measurement starts.
    return SizedBox(
      height: points.length * 30 + 28,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(points.length),
        tween: Tween(begin: 0, end: 1),
        duration: _reduceMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 560),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => CustomPaint(
          size: Size.infinite,
          painter: _BarPainter(
            points: points,
            target: target,
            max: max,
            progress: t,
            colors: context.colors,
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.points,
    required this.target,
    required this.max,
    required this.colors,
    this.progress = 1,
  });

  final List<ChartPoint> points;
  final double target;
  final double max;
  final double progress;
  final TiqColors colors;

  static const _pad = EdgeInsets.fromLTRB(92, 6, 46, 22);
  static const _rowH = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    final innerW = size.width - _pad.left - _pad.right;
    if (innerW <= 0) return;
    double x(double v) => _pad.left + (v / max) * innerW;
    final plotH = points.length * _rowH;

    final hair = Paint()
      ..color = colors.grid
      ..strokeWidth = 1;

    for (final v in [0.0, max * .25, max * .5, max * .75, max]) {
      canvas.drawLine(
        Offset(x(v), _pad.top),
        Offset(x(v), _pad.top + plotH),
        hair,
      );
      final tp = _text(_trim(v), style: _labelStyle(colors));
      tp.paint(canvas, Offset(x(v) - tp.width / 2, _pad.top + plotH + 6));
    }

    // Target rule. ink4: a stroke, not text — 3:1 suffices, quiet by design.
    final dash = Paint()
      ..color = colors.ink4
      ..strokeWidth = 1;
    for (var y = _pad.top; y < _pad.top + plotH; y += 6) {
      canvas.drawLine(
        Offset(x(target), y),
        Offset(x(target), math.min(y + 3, _pad.top + plotH)),
        dash,
      );
    }

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final y = _pad.top + i * _rowH + 7;
      const barH = 14.0;

      final name = _text(
        p.label,
        style: TextStyle(fontSize: 11.5, color: colors.ink2),
      );
      name.paint(
        canvas,
        Offset(_pad.left - 10 - name.width, y + (barH - name.height) / 2),
      );

      // Track
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(_pad.left, y, innerW, barH),
          const Radius.circular(1),
        ),
        Paint()..color = colors.grid,
      );
      final grown = (x(p.value) - _pad.left) * progress.clamp(0, 1);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(_pad.left, y, math.max(2, grown), barH),
          const Radius.circular(1),
        ),
        Paint()..color = p.value < target ? colors.crit : colors.series1,
      );

      // The figure only appears once its bar has arrived under it.
      if (progress < 0.9) continue;

      final val = _text(
        p.value.toStringAsFixed(1),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colors.ink2,
        ),
      );
      val.paint(canvas, Offset(x(p.value) + 7, y + (barH - val.height) / 2));
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.points != points ||
      old.target != target ||
      old.progress != progress ||
      old.colors != colors;
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 9, height: 9, color: color),
        const SizedBox(width: 6),
        // Flexible, because the label is not ours to bound.
        //
        // A `Wrap` hands each child the full line width as its maximum, and an
        // inflexible `Text` then takes its natural width regardless — so one
        // legend label longer than the line overflowed the Row rather than
        // wrapping onto the next. That is a yellow-and-black stripe across the
        // chart, and it was reachable: comparison labels are sentences the
        // server writes ("the month to date before this one"), and a phone in
        // portrait is 390 wide. Found by the breakpoint tests at 113px over.
        //
        // Ellipsis rather than a second line: the legend sits directly above
        // the plot and growing it downward would shift the chart under the
        // reader's eyes at exactly the widths where there is least room.
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: colors.ink2),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Sparkline — a trend cue with no axes. The tile carries the value.
// ═══════════════════════════════════════════════════════════════════════

class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.width = 96,
    this.height = 22,
    this.gradient = false,
  });

  final List<double> values;

  /// Null means "fill the available width" — the KPI tiles stretch their
  /// micro-trend across the card; inline callers keep the fixed 96. Fill
  /// mode needs a width-bounded parent: under unbounded constraints (a Row
  /// without Expanded, an unconstrained scroller) the infinite width throws.
  final double? width;
  final double height;

  /// When true the line gains an area fill fading brand 28% → 0% — the same
  /// glass recipe as [LineChart.gradientFill], at micro-trend scale.
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    // Too few points to draw — but the box must keep the same footprint as
    // the drawn case (fill mode included), or a tile's layout would jump the
    // day its series shrinks below two points.
    if (values.length < 2) {
      return SizedBox(width: width ?? double.infinity, height: height);
    }
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: CustomPaint(
        painter: _SparkPainter(values, context.colors, gradient: gradient),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.colors, {this.gradient = false});

  final List<double> values;
  final TiqColors colors;
  final bool gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final range = (hi - lo).abs() < 1e-9 ? 1.0 : hi - lo;

    Offset at(int i) => Offset(
      (i / (values.length - 1)) * (size.width - 2) + 1,
      size.height - 2 - ((values[i] - lo) / range) * (size.height - 5),
    );

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    if (gradient) {
      final area = Path.from(path)
        ..lineTo(at(values.length - 1).dx, size.height)
        ..lineTo(at(0).dx, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = glassAreaGradient(
            colors.brand,
          ).createShader(Offset.zero & size),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.series1
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      at(values.length - 1),
      2.5,
      Paint()..color = colors.series1,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.values != values || old.colors != colors || old.gradient != gradient;
}

// ═══════════════════════════════════════════════════════════════════════
// Shared bits
// ═══════════════════════════════════════════════════════════════════════

/// Hover readout. It *enhances* — every value it shows is also reachable from
/// the axis or the table-view twin, so nothing is gated behind a pointer.
///
/// The readout surface is deliberately the fixed dark instrument panel in both
/// themes (matching tooltipTheme in app_theme.dart) — an inverted readout on a
/// light chart is the premium convention, and it keeps hover legible without a
/// second derivation. Hence AppColors statics, not context.colors.
class _Tooltip extends StatelessWidget {
  const _Tooltip({
    required this.point,
    required this.suffix,
    required this.seriesName,
    required this.x,
    required this.plotWidth,
  });

  final ChartPoint point;
  final String suffix;
  final String seriesName;
  final double x;
  final double plotWidth;

  @override
  Widget build(BuildContext context) {
    const w = 136.0;
    final left = (x + 12).clamp(0.0, math.max(0.0, plotWidth - w)).toDouble();
    return Stack(
      children: [
        Positioned(
          left: left,
          top: 6,
          child: Container(
            width: w,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF05060A),
              border: Border.all(color: AppColors.lineStrong),
              borderRadius: BorderRadius.circular(AppColors.radiusControl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  point.label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.6,
                    color: AppColors.ink3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_trim(point.value)}$suffix',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (seriesName.isNotEmpty)
                  Text(
                    seriesName,
                    style: const TextStyle(fontSize: 11, color: AppColors.ink3),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyPlot extends StatelessWidget {
  const _EmptyPlot({required this.height, required this.message});

  final double height;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: height,
      child: Center(
        child: Text(
          message,
          style: TextStyle(fontSize: 12, color: colors.ink3),
        ),
      ),
    );
  }
}

/// Drops a trailing `.0` so axis ticks read `92` rather than `92.0`.
String _trim(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// The readout that follows the scrub.
///
/// A value tells you where you are. A DELTA tells you which way you are going —
/// and that is the thing a manager is actually looking for, so it is coloured:
/// green for up, red for down. (These KPIs are all "higher is better". A metric
/// where down is good must not reuse this without inverting it.)
class _ScrubReadout extends StatelessWidget {
  const _ScrubReadout({
    required this.point,
    required this.previous,
    required this.suffix,
    required this.seriesName,
    required this.x,
    required this.plotWidth,
    this.against,
    this.againstName = '',
  });

  final ChartPoint point;
  final double? previous;
  final String suffix;
  final String seriesName;
  final double x;
  final double plotWidth;

  /// The comparison series' point under the caret, when there is one. It shows
  /// its own LABEL as well as its value: the two series are aligned by
  /// position, not by date, and the reader is entitled to see which bucket
  /// they are being shown rather than assume it is the same day.
  final ChartPoint? against;
  final String againstName;

  @override
  Widget build(BuildContext context) {
    const w = 176.0;
    final left = (x + 12).clamp(0.0, math.max(0.0, plotWidth - w)).toDouble();
    final delta = previous == null ? null : point.value - previous!;

    return Stack(
      children: [
        Positioned(
          left: left,
          top: 6,
          child: Container(
            width: w,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF05060A),
              border: Border.all(color: AppColors.lineStrong),
              borderRadius: BorderRadius.circular(AppColors.radiusControl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  point.label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.6,
                    color: AppColors.ink3,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${_trim(point.value)}$suffix',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink1,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (delta != null && delta.abs() >= 0.05) ...[
                      const SizedBox(width: 7),
                      DeltaBadge(value: delta, suffix: suffix),
                    ],
                  ],
                ),
                if (seriesName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      seriesName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.ink3,
                      ),
                    ),
                  ),
                if (against != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${_trim(against!.value)}$suffix · ${against!.label}'
                      '${againstName.isEmpty ? '' : ' ($againstName)'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.ink3,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The **chart-scrub-tooltip** delta: an arrow icon + the absolute magnitude +
/// an optional [suffix] (e.g. a unit), painted in the theme's good/crit colours.
/// Used only inside the scrub readout ([_ScrubReadout]) to annotate the value
/// under the caret.
///
/// Up is green, down is red — and the sign is spelled out, so the direction
/// survives greyscale, print, and colour-vision deficiency. Colour reinforces
/// the sign; it never replaces it.
///
/// Do NOT confuse this with [DeltaPill] (`delta_pill.dart`), the status pill
/// used across the console (▲/▼/– glyph + fixed [DeltaTone] washes, no suffix).
/// The two are intentionally distinct — a tooltip annotation vs. a status pill —
/// not a fork waiting to be merged.
class DeltaBadge extends StatelessWidget {
  const DeltaBadge({
    super.key,
    required this.value,
    this.suffix = '',
    this.fontSize = 11.5,
  });

  final double value;
  final String suffix;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final up = value >= 0;
    final color = up ? context.colors.good : context.colors.crit;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.arrow_upward : Icons.arrow_downward,
            size: fontSize,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '${value.abs().toStringAsFixed(1)}$suffix',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

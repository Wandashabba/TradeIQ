import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../../design/tiq_number.dart';
import '../../../../theme/torchlight/tiq_skin.dart';
import '../curve.dart';
import '../sample_threshold.dart';
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
    required this.dashedWord,
    this.sampleKind,
    this.lowSampleWord,
    this.gapNote,
    this.veldReplacement,
    this.scrubHint,
  }) : assert(series.length > 0, 'A chart with no series is not a chart.'),
       assert(
         sampleKind == null || lowSampleWord != null,
         'TrendChart: a chart that steps a thin bucket down needs the words '
         'for it. Ink-2 is not a channel a screen reader has.',
       );

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

  /// The word the legend uses for a dashed swatch — "dashed", "gestippel".
  /// Required and localised by the caller; see [ChartLegend.dashedWord].
  final String dashedWord;

  /// What kind of quantity these readings are. Non-null makes the scrub
  /// readout read [ChartReading.sampleSize] and step a thin bucket down to
  /// ink-2; null is today's behaviour. See [TableTwin.sampleKind].
  final MetricKind? sampleKind;

  /// The words a thin bucket is announced with in the scrub readout.
  /// Required alongside [sampleKind].
  final String? lowSampleWord;

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

  void _scrubTo(Offset local, double width, TrendChartPainter painter) {
    final index = painter.indexAt(local.dx, width);
    if (index != null && index != _scrub) setState(() => _scrub = index);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final legend = ChartLegend(
      series: widget.series,
      dashedWord: widget.dashedWord,
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

    // Nobody measured anything, in any series. There is no plot to draw: a
    // scale invented from an empty set is a 0–1 axis across an empty grid,
    // which is a picture of nothing dressed as a chart. The legend and its
    // gap note are the whole of the information, and 208dp of ruled blank
    // under them is not a second way of saying it.
    if (!widget.series.any((s) => s.hasData)) return legend;

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
              final painter = TrendChartPainter(
                skin: skin,
                subject: subject,
                comparison: _comparison,
                threshold: widget.threshold,
                scrub: scrubIndex,
                unit: widget.unit,
                decimals: widget.decimals,
                number: TiqNumber.of(context),
                axisStyle: skin.text.axisLabel.style(
                  color: skin.palette.ink3,
                ),
                figureStyle: skin.text.figureS.style(
                  color: skin.palette.ink1,
                ),
                axisScale:
                    TiqTextScale.sizeOf(
                      MediaQuery.maybeTextScalerOf(context) ??
                          TextScaler.noScaling,
                      skin.text.axisLabel,
                    ) /
                    skin.text.axisLabel.size,
                textDirection: Directionality.of(context),
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) =>
                    _scrubTo(d.localPosition, width, painter),
                onHorizontalDragUpdate: (d) =>
                    _scrubTo(d.localPosition, width, painter),
                onHorizontalDragEnd: (_) => setState(() => _scrub = null),
                onHorizontalDragCancel: () => setState(() => _scrub = null),
                onTapDown: (d) => _scrubTo(d.localPosition, width, painter),
                onTapUp: (_) => setState(() => _scrub = null),
                onTapCancel: () => setState(() => _scrub = null),
                child: SizedBox(
                  height: height,
                  child: CustomPaint(
                    painter: painter,
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
                    lowSample:
                        widget.sampleKind != null &&
                        TiqSample.isLow(
                          widget.sampleKind!,
                          s.readings[scrubIndex].sampleSize,
                        ),
                  ),
            ],
            unit: widget.unit,
            decimals: widget.decimals,
            notMeasuredWord: widget.notMeasuredWord,
            lowSampleWord: widget.lowSampleWord,
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


/// THE PLOT. Public so its arithmetic can be exercised without a widget tree.
///
/// ## What makes this read as an instrument rather than as a drawing
///
/// The first Torchlight plot drew four straight polylines edge to edge on a
/// canvas with no gutters, no value labels and no emphasis, and the owner's
/// word for the result was *cartoonish*. Every choice below is one of the
/// reasons it was:
///
/// * **Gutters.** The plot is inset left for the value labels, right for the
///   end dot, top for the end dot's own label and bottom for the period band.
///   Without them the first and last readings sit *on* the canvas edge and the
///   last one is sliced in half by the clip — which is what was shipping.
/// * **A value axis.** Every gridline carries its number, in the declared mono
///   figure role, tabular, right-aligned in the gutter. A percentage chart
///   nobody can read a percentage off is decoration.
/// * **A curve that cannot lie.** [monotonePath] — Fritsch–Carlson monotone
///   cubic, whose extrema are the data's own extrema. See `curve.dart` for why
///   a Catmull-Rom would have been a fabricated reading.
/// * **An area that fades.** One `LinearGradient` in the existing draw call,
///   the subject's hue at 22% under the first gridline falling to nothing at
///   the baseline. Never a flat slab, never a second layer, never a
///   `saveLayer`.
/// * **Chrome quieter than the data.** Gridlines and the baseline are
///   hairlines snapped to the pixel grid so they are one crisp row rather than
///   two half-lit ones; the threshold is ink-2, not ink-1, so the three
///   horizontal lines on the plot stop competing with each other and with the
///   run. The old build painted the baseline in ink-1 — the loudest line in
///   the palette — under a 2dp data stroke in `chart-neutral`, so the frame
///   shouted over the figure.
/// * **The end emphasised, once.** A filled dot with a ground-coloured ring at
///   the last measured reading, and one direct label above it. One label, not
///   eight: a number on every point is the thing nobody reads.
class TrendChartPainter extends CustomPainter {
  TrendChartPainter({
    required this.skin,
    required this.subject,
    required this.comparison,
    required this.threshold,
    required this.scrub,
    required this.unit,
    required this.decimals,
    required this.number,
    required this.axisStyle,
    required this.figureStyle,
    required this.axisScale,
    required this.textDirection,
  });

  final TiqSkin skin;
  final ChartSeries subject;
  final ChartSeries? comparison;
  final ChartThreshold? threshold;
  final int? scrub;

  /// What the endpoint's one direct label is measured in.
  final TiqUnit unit;
  final int? decimals;
  final TiqNumber number;

  final TextStyle axisStyle;

  /// The end dot's direct label — `figure.s`, so the one number on the plot is
  /// set in the same face as every other number in the app.
  final TextStyle figureStyle;

  final double axisScale;
  final TextDirection textDirection;

  /// How much room the period labels take under the plot.
  static const double axisBand = 20;

  /// The air above the plot, for the end dot's direct label.
  static const double labelBand = 18;

  /// Between a value label and the gridline it names.
  static const double tickGap = 6;

  /// The end dot, and the air kept clear around it at the plot's right edge.
  ///
  /// **No ring.** The dataviz rule puts a 2dp surface-coloured ring on an
  /// overlapping marker, and this marker overlaps nothing: it caps a stroke
  /// that arrives from one side and is the same hue as it, so the ring would
  /// be a donut drawn for its own sake. It cannot be a *gap* either — a break
  /// in this stroke is the one thing that means "nobody measured that week",
  /// and spending it on decoration would make an emphasis read as an absence.
  /// The end reads as the end because it is a disc twice the stroke's width.
  static const double endRadius = 3.5;
  static const double endAir = 2;

  /// The subject's stroke. The comparison's is [comparisonStroke] — a real
  /// weight difference, so the two runs are told apart by more than hue even
  /// before the dash is counted.
  static const double subjectStroke = 2;
  static const double comparisonStroke = 1.5;

  /// The scale, and the value labels it implies. Computed once and reused by
  /// [gutterFor] and by [paint], because the left gutter is a function of the
  /// widest label and the widest label is a function of the scale.
  late final ({double min, double max, double step}) scale = niceScale(
    <double>[
      for (final r in subject.readings) ?r.value,
      if (comparison != null)
        for (final r in comparison!.readings) ?r.value,
    ],
    include: threshold?.value,
  );

  /// The axis style at the live text scale.
  ///
  /// `axisScale` arrives beside the style rather than baked into it because
  /// the band is reserved from it too; applying it in one place here is what
  /// keeps a 2.0× reader's labels, gutter and band the same size as each
  /// other. The previous build reserved a doubled band and then drew 12dp
  /// labels into it.
  late final TextStyle _axis = axisStyle.copyWith(
    fontSize: (axisStyle.fontSize ?? TrendChartPainter.axisBand / 2) *
        axisScale,
  );

  late final TextStyle _figure = figureStyle.copyWith(
    fontSize: (figureStyle.fontSize ?? 16) * axisScale,
  );

  /// The affixes of a figure are language, so they are set in the prose face
  /// beside the mono digits — `FigureSlot`'s rule, applied to the one figure
  /// this painter sets itself.
  late final TextStyle _figureAffix = _figure.copyWith(
    fontFamily: TiqFonts.prose,
    fontFamilyFallback: TiqFonts.proseFallback,
  );

  /// The tick values, low to high. Bounded: a scale whose step has been
  /// rounded to nothing would otherwise spin here.
  late final List<double> ticks = <double>[
    for (
      var v = scale.min, guard = 0;
      v <= scale.max + 1e-9 && guard < 24;
      v += scale.step, guard++
    )
      v,
  ];

  /// The width the value labels need, plus the air between them and the plot.
  late final double gutter = () {
    if (scale.step <= 0) return 0.0;
    var widest = 0.0;
    for (final v in ticks) {
      final p = _layout(_tickLabel(v), _axis);
      widest = math.max(widest, p.width);
      p.dispose();
    }
    return widest + tickGap;
  }();

  /// Where reading [index] sits horizontally, in painter coordinates.
  double xFor(int index, double width) {
    final left = gutter;
    final right = math.max(width - _rightInset, left + 1);
    final count = subject.readings.length;
    if (count <= 1) return (left + right) / 2;
    return left + (right - left) * index / (count - 1);
  }

  /// Which reading the thumb at [dx] is over, or null when there is nothing to
  /// scrub. Clamped to the ends, so a thumb in the value gutter reads the
  /// first bucket rather than nothing.
  int? indexAt(double dx, double width) {
    final count = subject.readings.length;
    if (count == 0) return null;
    if (count == 1) return 0;
    final left = gutter;
    final right = math.max(width - _rightInset, left + 1);
    final step = (right - left) / (count - 1);
    return ((dx - left) / step).round().clamp(0, count - 1);
  }

  double get _rightInset => endRadius + endAir;

  @override
  void paint(Canvas canvas, Size size) {
    final readings = subject.readings;
    if (readings.isEmpty) return;

    final band = axisBand * axisScale;
    final top = labelBand * axisScale;
    final plot = Rect.fromLTRB(
      gutter,
      top,
      math.max(size.width - _rightInset, gutter + 1),
      math.max(size.height - band, top + 1),
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    double y(double value) {
      final span = scale.max - scale.min;
      if (span <= 0) return plot.bottom;
      return plot.bottom -
          ((value - scale.min) / span).clamp(0.0, 1.0) * plot.height;
    }

    final count = readings.length;
    double x(int index) => xFor(index, size.width);

    // ── Gridlines. Horizontal only, hairline, and snapped to the pixel grid:
    // a 1dp line drawn at an integer coordinate straddles two device rows and
    // lights both at half alpha, which is the difference between a ruled line
    // and a smudge. `lifted` on a dark ground and `hairline` on a light one —
    // unify §1.17 names `lifted`, which *is* the one-step-off-surface line in
    // Night; in Day that token is the dark navy a track is filled with, and a
    // navy gridline over Palladian paper is louder than the run it is meant to
    // sit behind. Same ruling, resolved per ground.
    final grid = Paint()
      ..color = skin.brightness == Brightness.dark
          ? skin.palette.lifted
          : skin.palette.hairline
      ..strokeWidth = 1
      ..isAntiAlias = false;
    for (final v in ticks) {
      final gy = _crisp(y(v));
      // The bottom tick lands on the baseline, which is about to be drawn in a
      // stronger ink. Two lines in one row is one line and a wasted draw.
      if (gy >= _crisp(plot.bottom)) continue;
      canvas.drawLine(Offset(plot.left, gy), Offset(plot.right, gy), grid);
    }

    // ── The area under the subject: the series hue at 22% at the run's own
    // crest, fading to nothing at the baseline. One gradient, in the draw call
    // that was already happening — no layer, no blur, no shadow.
    //
    // Anchored to the **crest and the baseline**, not to the plot rectangle. A
    // ramp measured from the top of an empty plot puts a run that lives in the
    // lower third under 5% alpha for its whole height, which is a flat slab of
    // nearly nothing — the fill has to fade across the band the data actually
    // occupies or it is not a fade at all.
    var crest = plot.bottom;
    for (final r in readings) {
      final v = r.value;
      if (v != null) crest = math.min(crest, y(v));
    }
    final wash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          skin.palette.chartNeutral.withValues(alpha: 0.26),
          skin.palette.chartNeutral.withValues(alpha: 0.08),
          skin.palette.chartNeutral.withValues(alpha: 0),
        ],
        // A mid stop, so the wash falls away quickly under the run and is
        // genuinely gone by the baseline. A straight two-stop ramp over a
        // 170dp band leaves 11% alpha across the middle third, which reads as
        // a tinted block with a soft top rather than as a fade.
        stops: const <double>[0, 0.55, 1],
      ).createShader(
        Rect.fromLTRB(
          plot.left,
          crest,
          plot.right,
          math.max(crest + 1, plot.bottom),
        ),
      );
    _runs(readings, x: x, y: y, count: count, onRun: (points) {
      if (points.length < 2) return;
      canvas.drawPath(
        monotonePath(points)
          ..lineTo(points.last.dx, plot.bottom)
          ..lineTo(points.first.dx, plot.bottom)
          ..close(),
        wash,
      );
    });

    // ── The baseline. `edge-structure`, not ink-1: an axis is chrome, and
    // chrome painted in the brightest ink in the palette outshouts a 2dp data
    // stroke in chart-neutral. Still a real rule, still solid, still never
    // amber (unify §1.1).
    canvas.drawLine(
      Offset(plot.left, _crisp(plot.bottom)),
      Offset(plot.right, _crisp(plot.bottom)),
      Paint()
        ..color = skin.palette.edgeStructure
        ..strokeWidth = 1
        ..isAntiAlias = false,
    );

    // ── The threshold, dashed, ink-2. A dash is what a threshold *means* in
    // this system; ink-2 rather than ink-1 is what keeps it from being the
    // loudest mark on a plot whose subject is the run.
    final rule = threshold;
    if (rule != null && rule.value >= scale.min && rule.value <= scale.max) {
      final ry = _crisp(y(rule.value));
      canvas.drawPath(
        dashedPath(
          Path()
            ..moveTo(plot.left, ry)
            ..lineTo(plot.right, ry),
          dash: 4,
          gap: 4,
        ),
        Paint()
          ..color = skin.palette.ink2
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt,
      );
    }

    // ── The comparison, behind the subject: dashed Truffle at 1.5dp, butt
    // caps. A round cap on a 4dp dash turns every dash into a lozenge, which
    // is half of what made the old plot read as a toy.
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
          ..strokeWidth = comparisonStroke
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt
          ..strokeJoin = StrokeJoin.round,
        dashed: true,
      );
    }

    // ── The subject: solid chart-neutral at 2dp, round join and cap.
    _series(
      canvas,
      readings,
      x: x,
      y: y,
      count: count,
      paint: Paint()
        ..color = skin.palette.chartNeutral
        ..strokeWidth = subjectStroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
      dashed: false,
    );

    // ── "You are here": the last measured reading, emphasised once.
    final lastMeasured = _lastMeasured(readings, count);
    if (lastMeasured != null) {
      canvas.drawCircle(
        Offset(x(lastMeasured), y(readings[lastMeasured].value!)),
        endRadius,
        Paint()..color = skin.palette.chartNeutral,
      );
    }

    // ── The scrub line and its dot. ink-1, never amber — this one *is* the
    // reader's own mark, so it is allowed to be the loudest thing on the plot
    // while the thumb is down.
    final at = scrub;
    if (at != null && at < count) {
      final sx = x(at);
      canvas.drawLine(
        Offset(_crisp(sx), plot.top),
        Offset(_crisp(sx), plot.bottom),
        Paint()
          ..color = skin.palette.ink1
          ..strokeWidth = 1
          ..isAntiAlias = false,
      );
      final value = readings[at].value;
      if (value != null) {
        // ink-1 against a chart-neutral run: a hue apart from everything it
        // sits on, so it needs no ring to be found.
        canvas.drawCircle(
          Offset(sx, y(value)),
          endRadius,
          Paint()..color = skin.palette.ink1,
        );
      }
    }

    _paintValueAxis(canvas, plot, y);
    _paintEndLabel(canvas, size, plot, x, y, lastMeasured);
    _paintPeriodAxis(canvas, size, plot, band, x, count);
  }

  // ── The chrome that is words ──────────────────────────────────────────

  /// Every gridline's value, right-aligned in the gutter, vertically centred
  /// on its line. Mono and tabular by the role's own declaration, so the
  /// column of numbers is a column.
  void _paintValueAxis(Canvas canvas, Rect plot, double Function(double) y) {
    if (gutter <= 0) return;
    var lastBottom = double.negativeInfinity;
    // Top down, so the one that gets dropped in a crowd is the lower of the
    // pair rather than whichever happened to be second.
    for (final v in ticks.reversed) {
      final p = _layout(_tickLabel(v), _axis);
      // Held inside the plot. The bottom tick is centred on the baseline, so
      // half of it would sit in the period band and collide with the first
      // period label — which is what "50" over "W30" looked like.
      final top = (y(v) - p.height / 2)
          .clamp(0.0, math.max(plot.bottom - p.height, 0.0))
          .toDouble();
      if (top < lastBottom + 2) {
        p.dispose();
        continue;
      }
      p.paint(canvas, Offset(plot.left - tickGap - p.width, top));
      lastBottom = top + p.height;
      p.dispose();
    }
  }

  /// The one direct label on the plot: the last measured reading, above its
  /// dot, nudged so it never leaves the canvas.
  void _paintEndLabel(
    Canvas canvas,
    Size size,
    Rect plot,
    double Function(int) x,
    double Function(double) y,
    int? lastMeasured,
  ) {
    if (lastMeasured == null) return;
    final value = subject.readings[lastMeasured].value!;
    final figure = number.split(value, unit: unit, decimals: decimals);
    final p = TextPainter(
      text: TextSpan(
        children: <InlineSpan>[
          if (figure.prefix.isNotEmpty)
            TextSpan(text: figure.prefix, style: _figureAffix),
          TextSpan(text: figure.run, style: _figure),
          if (figure.suffix.isNotEmpty)
            TextSpan(text: figure.suffix, style: _figureAffix),
        ],
      ),
      textDirection: textDirection,
      maxLines: 1,
    )..layout();

    final dot = Offset(x(lastMeasured), y(value));
    // Right-aligned on the dot, so an eight-week run ends with its figure over
    // the run rather than hanging off the canvas.
    var left = dot.dx - p.width;
    left = left.clamp(0.0, math.max(size.width - p.width, 0.0));
    var top = dot.dy - endRadius - endAir - p.height;
    // Under the dot instead, if the reading is high enough that the label
    // would climb out of the frame.
    if (top < 0) top = dot.dy + endRadius + endAir;
    p
      ..paint(canvas, Offset(left, top))
      ..dispose();
  }

  /// The period labels: first, last, and the scrubbed one. An axis with a
  /// label per bucket at 2.0× is a grey smear, and the table twin holds every
  /// period in full anyway.
  ///
  /// The scrubbed label wins every collision: it is the one the reader's thumb
  /// asked for.
  void _paintPeriodAxis(
    Canvas canvas,
    Size size,
    Rect plot,
    double band,
    double Function(int) x,
    int count,
  ) {
    final readings = subject.readings;
    final at = scrub;
    final placed = <Rect>[];

    void place(int index, {required bool mandatory}) {
      if (index < 0 || index >= count) return;
      final p = _layout(
        readings[index].label,
        _axis,
        maxWidth: math.max(plot.width / 2, 24),
      );
      var left = x(index) - p.width / 2;
      left = left.clamp(0.0, math.max(size.width - p.width, 0.0));
      final box = Rect.fromLTWH(left, 0, p.width, p.height).inflate(3);
      if (!mandatory && placed.any(box.overlaps)) {
        p.dispose();
        return;
      }
      p
        ..paint(canvas, Offset(left, plot.bottom + (band - p.height) / 2))
        ..dispose();
      placed.add(box);
    }

    if (at != null) place(at, mandatory: true);
    place(0, mandatory: false);
    place(count - 1, mandatory: false);
  }

  // ── The runs ──────────────────────────────────────────────────────────

  /// Walk [readings], handing [onRun] each unbroken stretch of measured
  /// points. A null reading ends the run: the trends endpoints omit an empty
  /// bucket rather than sending a zero, and joining across one would draw a
  /// straight line through a week nobody measured.
  void _runs(
    List<ChartReading> readings, {
    required double Function(int) x,
    required double Function(double) y,
    required int count,
    required void Function(List<Offset>) onRun,
  }) {
    var run = <Offset>[];
    for (var i = 0; i < readings.length && i < count; i++) {
      final value = readings[i].value;
      if (value == null) {
        if (run.isNotEmpty) onRun(run);
        run = <Offset>[];
        continue;
      }
      run.add(Offset(x(i), y(value)));
    }
    if (run.isNotEmpty) onRun(run);
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
    _runs(readings, x: x, y: y, count: count, onRun: (points) {
      if (points.length == 1) {
        // A path of one point strokes nothing, and a measured week must not
        // vanish because the weeks either side of it were not measured. It
        // gets a dot — round, the same width as the stroke it stands in for.
        canvas.drawCircle(
          points.first,
          paint.strokeWidth,
          Paint()..color = paint.color,
        );
        return;
      }
      final path = monotonePath(points);
      canvas.drawPath(
        dashed ? dashedPath(path, dash: 6, gap: 4) : path,
        paint,
      );
    });
  }

  int? _lastMeasured(List<ChartReading> readings, int count) {
    for (var i = math.min(readings.length, count) - 1; i >= 0; i--) {
      if (readings[i].value != null) return i;
    }
    return null;
  }

  // ── Small mechanics ───────────────────────────────────────────────────

  String _tickLabel(double v) {
    final rounded = (v * 100).roundToDouble() / 100;
    if (rounded == rounded.roundToDouble()) {
      return number.format(rounded.round());
    }
    return number.format(rounded, decimals: 1);
  }

  TextPainter _layout(String text, TextStyle style, {double? maxWidth}) =>
      TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: textDirection,
        maxLines: 1,
      )..layout(maxWidth: maxWidth ?? double.infinity);

  /// A hairline's coordinate, moved onto the half-pixel so a 1dp stroke fills
  /// exactly one device row instead of lighting two at half alpha.
  static double _crisp(double v) => v.floorToDouble() + 0.5;

  @override
  bool shouldRepaint(TrendChartPainter old) =>
      old.skin != skin ||
      old.subject != subject ||
      old.comparison != comparison ||
      old.threshold != threshold ||
      old.scrub != scrub ||
      old.unit != unit ||
      old.decimals != decimals ||
      old.number != number ||
      old.axisScale != axisScale;
}

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import '../mark/severity_mark.dart';
import 'curve.dart';

/// THE 64×20 SLOT.
///
/// A shape, not a chart: no axis, no gridline, no label, no tooltip. It says
/// *which way this has been going* beside a number that says where it is now,
/// and the moment it tries to say more it needs a legend and becomes a trend
/// chart.
///
/// Three rules it does not bend:
///
/// * **Fewer than two points draws nothing.** A single reading is a dot, and a
///   dot drawn as a flat line is a fabricated trend. The slot collapses and
///   the figure beside it moves to the row's edge — [DecisionRow] is built for
///   exactly that.
/// * **The whole shape carries the verdict, and the verdict is never amber.**
///   A sparkline that is always `chartNeutral` is a grey scribble: it says
///   *there is a shape here* and nothing about whether the shape is good news.
///   Since 28 September 2026 the **stroke** takes the standing as well as the
///   dot — green where the run is where it should be, crimson where it is not,
///   `chartNeutral` where there is nothing to judge it against. Colour is not
///   the only signal and cannot be: the shape *is* the direction, drawn, and
///   every caller already prints a word, a delta or a standing beside it.
///   Five rows of amber last-dots is the repeated fill the amber law bans by
///   name, and amber is not a verdict in any case.
/// * **It caches.** The geometry becomes a [ui.Picture] once per (points,
///   size, skin) and is replayed inside a [RepaintBoundary]. A `ListView` of
///   five of these repainting on every scroll frame is the budget gone.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.points,
    this.severity,
    this.semanticsLabel,
  });

  /// Oldest first. The value scale is the series' own range — this is a shape,
  /// and a shape anchored to zero flattens every real movement.
  final List<double> points;

  /// The run's standing. Colours the **stroke and the last dot**: null draws
  /// both in `chartNeutral` — a series with no verdict attached still gets its
  /// shape and its "you are here", in plain neutral, because a shape with
  /// nothing to be judged against is not good news or bad news.
  final SeverityMarkKind? severity;

  final String? semanticsLabel;

  /// The slot [DecisionRow] reserves.
  static const Size slot = Size(64, 20);

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();
    final skin = context.skin;

    // THE STROKE AND THE DOT COME FROM THE SAME VERDICT.
    //
    // The stroke takes the **word grade** (`good` / `bad`) rather than the
    // mark grade: a 1.5dp line is a hairline, and Night's `badSolid` at
    // 3.21:1 on `raised` is a hairline that disappears on a 6-bit panel. The
    // dot keeps the mark grade, because a 5dp disc is a mark and reads as one
    // of the two commitment levels the severity set has.
    final verdict = severity;
    final line = switch (verdict) {
      SeverityMarkKind.critical || SeverityMarkKind.watch => skin.palette.bad,
      SeverityMarkKind.onTarget => skin.palette.good,
      // `held` and `notMeasured` are not verdicts. A series that nobody could
      // judge draws the neutral it has always drawn.
      _ => skin.palette.chartNeutral,
    };
    final dot = verdict == null
        ? skin.palette.chartNeutral
        : SeverityMarkToken.of(skin, verdict).ink;

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      child: RepaintBoundary(
        child: CustomPaint(
          size: slot,
          painter: SparklinePainter(points: points, line: line, dot: dot),
          isComplex: false,
          willChange: false,
        ),
      ),
    );
  }
}

/// The painter, public so its arithmetic can be unit-tested without a widget
/// tree and so the cached [ui.Picture] contract is visible.
class SparklinePainter extends CustomPainter {
  SparklinePainter({
    required this.points,
    required this.line,
    required this.dot,
  });

  final List<double> points;
  final Color line;
  final Color dot;

  /// The stroke, and the radius of the last dot. Both fixed: a sparkline is a
  /// decorative mark that happens to be true, and a meaning-bearing glyph that
  /// grows with the text is a different object — this one is dropped at 1.6x
  /// rather than scaled.
  static const double strokeWidth = 1.5;
  static const double dotRadius = 2.5;

  ui.Picture? _cached;
  Size? _cachedSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || size.isEmpty) return;
    if (_cached == null || _cachedSize != size) {
      _cached?.dispose();
      _cached = _record(size);
      _cachedSize = size;
    }
    canvas.drawPicture(_cached!);
  }

  ui.Picture _record(Size size) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Inset by the dot so the last point is not clipped by the slot's edge.
    final inset = dotRadius + strokeWidth / 2;
    final w = size.width - inset * 2;
    final h = size.height - inset * 2;

    var lo = points.first;
    var hi = points.first;
    for (final p in points) {
      if (p < lo) lo = p;
      if (p > hi) hi = p;
    }
    final span = hi - lo;

    Offset at(int i) {
      final x = inset + (w * i) / (points.length - 1);
      // A flat series draws through the middle rather than along the floor:
      // "no change" is a horizontal line, not a value of zero.
      final t = span == 0 ? 0.5 : (points[i] - lo) / span;
      return Offset(x, inset + h * (1 - t));
    }

    // A monotone cubic, not a polyline: eight readings in 64dp is eight hard
    // corners, and a shape whose job is *which way this has been going* should
    // read as a movement rather than as a sawtooth. Monotone because the curve
    // may not invent a peak — see `curve.dart`; the extrema of this path are
    // the extrema of the series.
    final path = monotonePath(<Offset>[
      for (var i = 0; i < points.length; i++) at(i),
    ]);

    canvas.drawPath(
      // Trimmed short of the end dot, so the dot sits in a gap rather than on
      // top of the stroke. The usual fix is a 2dp ring in the surface colour,
      // which this painter cannot draw: a sparkline rides an arbitrary row and
      // does not know what is behind it. A gap is true on any ground.
      trimEnd(path, dotRadius + 0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = line,
    );

    // "You are here", in the severity the row is carrying.
    canvas.drawCircle(at(points.length - 1), dotRadius, Paint()..color = dot);

    return recorder.endRecording();
  }

  @override
  bool shouldRepaint(SparklinePainter old) {
    final same =
        old.line == line &&
        old.dot == dot &&
        old.points.length == points.length &&
        _sameValues(old.points, points);
    if (same) {
      // Carry the recording across the rebuild — a new painter instance for an
      // unchanged series is the common case in a scrolling list, and
      // re-recording it there is the cost this class exists to avoid.
      _cached = old._cached;
      _cachedSize = old._cachedSize;
      old._cached = null;
    }
    return !same;
  }

  static bool _sameValues(List<double> a, List<double> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

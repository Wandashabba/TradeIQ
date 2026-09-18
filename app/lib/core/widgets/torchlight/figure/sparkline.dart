import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import '../mark/severity_mark.dart';

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
/// * **The last dot is severity-coloured, and severity is never amber.** It is
///   the one mark in the shape that carries a verdict, so it takes the crimson
///   the rest of the system uses for one. Five rows of amber last-dots is the
///   repeated fill the amber law bans by name.
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

  /// Colours the last dot. Null draws it in `chartNeutral` — a series with no
  /// verdict attached still gets its "you are here".
  final SeverityMarkKind? severity;

  final String? semanticsLabel;

  /// The slot [DecisionRow] reserves.
  static const Size slot = Size(64, 20);

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();
    final skin = context.skin;

    // Veld draws no sparklines at all — a grey zigzag is under the 9:1 floor
    // by construction, and Veld has no token under 9:1. The row drops it too;
    // this is the belt for that brace, so a sparkline placed directly on a
    // Veld surface cannot appear.
    if (skin.density == TiqDensity.veld) return const SizedBox.shrink();

    final line = skin.palette.chartNeutral;
    final dot = severity == null
        ? skin.palette.chartNeutral
        : SeverityMarkToken.of(skin, severity!).ink;

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

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      final o = at(i);
      path.lineTo(o.dx, o.dy);
    }

    canvas.drawPath(
      path,
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

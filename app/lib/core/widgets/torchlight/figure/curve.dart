import 'dart:math' as math;
import 'dart:ui';

/// THE ONE CURVE IN THE FIGURE KIT.
///
/// A run of readings joined by straight segments is a true picture and an ugly
/// one: every reading becomes a corner, and eight corners in 200dp read as a
/// zigzag rather than as a trend. A curve fixes that — and the wrong curve
/// lies.
///
/// ## Why monotone cubic and not a Catmull-Rom or a `quadraticBezierTo`
///
/// A Catmull-Rom spline through 64, 61, 68 dips **below 61** and rises **above
/// 68** before it arrives: it invents a worse week and a better week than
/// anybody measured. So does the usual "midpoint quadratic" smoothing trick.
/// On a scorecard that is not a rendering choice, it is a fabricated reading,
/// and somebody is paid on it.
///
/// Fritsch–Carlson monotone cubic Hermite interpolation cannot do that. It
/// picks each knot's tangent from the neighbouring secants and then **clamps
/// it** so the cubic between two readings stays inside the interval those two
/// readings bound. Between a rise and a fall the tangent is forced to zero, so
/// the curve turns at the reading rather than past it. Formally: the
/// interpolant is monotone on every interval where the data is monotone, and
/// its extrema are the data's own extrema — which is exactly the promise a
/// chart has to keep.
///
/// Fritsch, F. N. and Carlson, R. E., *Monotone Piecewise Cubic
/// Interpolation*, SIAM J. Numer. Anal. 17(2), 1980.
///
/// Two points degenerate to the straight line between them, as they must: a
/// curve through two readings would be a shape nobody measured.
Path monotonePath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points.first.dx, points.first.dy);
  if (points.length == 1) return path;
  if (points.length == 2) {
    path.lineTo(points[1].dx, points[1].dy);
    return path;
  }

  final n = points.length;

  // The secant slope of each interval, and its run. A zero or negative run
  // would be two readings at the same x, which the chart's own geometry
  // cannot produce — guarded anyway, because a divide by zero here is a NaN
  // that propagates into a Path and takes the frame with it.
  final run = List<double>.filled(n - 1, 0);
  final secant = List<double>.filled(n - 1, 0);
  for (var i = 0; i < n - 1; i++) {
    run[i] = points[i + 1].dx - points[i].dx;
    secant[i] = run[i] == 0 ? 0 : (points[i + 1].dy - points[i].dy) / run[i];
  }

  // The initial tangents: one-sided at the ends, the average of the two
  // neighbouring secants inside.
  final tangent = List<double>.filled(n, 0);
  tangent[0] = secant[0];
  tangent[n - 1] = secant[n - 2];
  for (var i = 1; i < n - 1; i++) {
    tangent[i] = (secant[i - 1] + secant[i]) / 2;
  }

  // The clamp. This is the whole of the monotonicity guarantee.
  for (var i = 0; i < n - 1; i++) {
    if (secant[i] == 0) {
      // Two equal readings: the curve is flat across them, full stop. Without
      // this the averaged tangents bow the line off a plateau.
      tangent[i] = 0;
      tangent[i + 1] = 0;
      continue;
    }
    final a = tangent[i] / secant[i];
    final b = tangent[i + 1] / secant[i];
    // A tangent pointing against its secant is a turn *between* two readings
    // — an overshoot. Flatten it.
    if (a < 0) tangent[i] = 0;
    if (b < 0) tangent[i + 1] = 0;
    final s = a * a + b * b;
    if (s > 9) {
      // Fritsch–Carlson's circle of monotonicity: project (a, b) back onto it.
      final t = 3 / math.sqrt(s);
      tangent[i] = t * a * secant[i];
      tangent[i + 1] = t * b * secant[i];
    }
  }

  // Hermite → cubic Bézier: the control points sit a third of the run along
  // each tangent.
  for (var i = 0; i < n - 1; i++) {
    final third = run[i] / 3;
    path.cubicTo(
      points[i].dx + third,
      points[i].dy + tangent[i] * third,
      points[i + 1].dx - third,
      points[i + 1].dy - tangent[i + 1] * third,
      points[i + 1].dx,
      points[i + 1].dy,
    );
  }
  return path;
}

/// [source] cut into [dash]-long strokes separated by [gap].
///
/// Shared so the trend chart's comparison run, its threshold rule and the
/// legend's swatch cannot drift into three different dash patterns.
Path dashedPath(Path source, {required double dash, required double gap}) {
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

/// [source] with its last [by] logical pixels removed.
///
/// The surface gap under an end-dot, without a surface colour. A dot drawn
/// over a stroke that runs under it has no separation, and the usual fix — a
/// 2dp ring in the background colour — needs the painter to know what is
/// behind it, which a sparkline in an arbitrary row does not. Trimming the
/// path instead leaves a real gap whatever the ground is, and costs no layer.
Path trimEnd(Path source, double by) {
  if (by <= 0) return source;
  final out = Path();
  for (final metric in source.computeMetrics()) {
    final end = metric.length - by;
    // A run shorter than the trim keeps its first pixel rather than vanishing:
    // the dot still lands on it, and a disappearing stroke is worse than a
    // short one.
    if (end <= 0) continue;
    out.addPath(metric.extractPath(0, end), Offset.zero);
  }
  return out;
}

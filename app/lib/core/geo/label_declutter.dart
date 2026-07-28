import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:latlong2/latlong.dart';

/// Screen-space label decluttering for map markers (#197).
///
/// Two stops at outlets ~20m apart render their marker boxes on top of each
/// other, and the luminous labels draw over one another as garbled text. Which
/// labels collide is a *screen-space* property — it depends on the live zoom,
/// since the same two outlets are indistinguishable at zoom 13 and clearly
/// separate at zoom 19. So this cannot be decided once at build time.
///
/// Pure functions on purpose — no `BuildContext`, no `MapController`, no
/// widget — so the geometry is unit-testable without a running map, exactly
/// like [fitFor] in `mercator_fit.dart`.
///
/// **Why observing the camera here is safe**, given `agent_trail_screen`
/// deliberately refuses to hold a `MapController`: that rule exists because
/// *seeding* the camera from flutter_map (at `onMapReady`, when its internal
/// size was still zero) silently produced a near-world zoom centred nowhere
/// near the data. Nothing here feeds back into centre/zoom — the camera is
/// read only to decide which labels to draw. The worst failure mode is a
/// wrongly-hidden label, not a map pointed at the wrong continent.

/// Pixel offset of [point] from [center], for a map at [zoom].
///
/// Standard slippy-map maths, matching what flutter_map draws: the world is
/// `256 * 2^zoom` pixels square, longitude maps linearly across its full 360°
/// and Mercator-y across its full 2π. Screen y grows downward, so a point
/// further north has a negative `dy`.
///
/// No antimeridian handling: a single agent's day of stops does not wrap the
/// globe, and pretending to handle a case that cannot occur would be dead code.
Offset screenOffset({
  required LatLng center,
  required LatLng point,
  required double zoom,
}) {
  final worldSize = 256 * math.pow(2, zoom).toDouble();
  return Offset(
    _worldX(point.longitude, worldSize) - _worldX(center.longitude, worldSize),
    _worldY(point.latitude, worldSize) - _worldY(center.latitude, worldSize),
  );
}

/// Which labels survive, one flag per entry of [points], in input order.
///
/// [priority] gives each point a rank — **lower wins**. Points are considered
/// in priority order and a label is kept only if its box clears every label
/// already kept, so the most important label in a cluster always survives and
/// the rest drop. Discs are never hidden by this: only the label is
/// suppressed, so no stop ever vanishes from the map.
///
/// [labelRect] is the label's box *relative to the marker's geographic point*
/// — e.g. `Rect.fromLTWH(-64, 20, 128, 35)` for a 128-wide label hanging 20px
/// below the point. Using the full marker-box width rather than the measured
/// text width is deliberate: it is conservative (it hides slightly more than
/// strictly necessary) and it is deterministic, needing no text layout pass.
List<bool> declutterLabels({
  required List<LatLng> points,
  required List<int> priority,
  required LatLng center,
  required double zoom,
  required Rect labelRect,
}) {
  assert(
    points.length == priority.length,
    'declutterLabels needs one priority per point '
    '(${points.length} points, ${priority.length} priorities)',
  );

  final visible = List<bool>.filled(points.length, false);
  if (points.isEmpty) return visible;

  final order = List<int>.generate(points.length, (i) => i)
    ..sort((a, b) => priority[a].compareTo(priority[b]));

  final kept = <Rect>[];
  for (final index in order) {
    final offset = screenOffset(
      center: center,
      point: points[index],
      zoom: zoom,
    );
    final rect = labelRect.shift(offset);
    if (kept.any((other) => other.overlaps(rect))) continue;
    kept.add(rect);
    visible[index] = true;
  }

  return visible;
}

double _worldX(double lngDegrees, double worldSize) =>
    (lngDegrees + 180) / 360 * worldSize;

double _worldY(double latDegrees, double worldSize) =>
    (1 - _mercatorY(latDegrees) / math.pi) / 2 * worldSize;

/// Web Mercator (EPSG:3857) latitude transform in radians — `ln(tan(π/4 + φ/2))`.
///
/// Deliberately duplicated from `mercator_fit.dart` rather than exported from
/// it: that file's docstring is emphatic that it is a self-contained pure
/// fit calculation, and widening its public surface to share one three-line
/// formula would couple two modules that have no other reason to know about
/// each other. Both are pinned by their own tests.
double _mercatorY(double latDegrees) {
  final latRad = latDegrees * math.pi / 180;
  return math.log(math.tan(math.pi / 4 + latRad / 2));
}

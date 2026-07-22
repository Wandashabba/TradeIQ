import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:latlong2/latlong.dart';

/// Fits [points] inside [size] (minus [padding] on every side) using plain
/// Web Mercator maths — EPSG:3857, the same projection flutter_map itself
/// draws in — computed entirely in Dart with no dependency on flutter_map's
/// own camera/viewport state.
///
/// This exists because flutter_map's own fit machinery (`CameraFit.bounds`,
/// whether applied via `initialCameraFit` or from `onMapReady`) computes
/// against ITS OWN internal camera size — which, on the running Flutter web
/// build, was confirmed still zero at the moment `onMapReady` fires, even
/// with correct points, a real `CameraFit.bounds`, and a non-degenerate
/// widget viewport already measured. That produces a silent, non-crashing
/// fit against a zero-size camera: a near-world zoom centred nowhere near
/// the data. Computing the centre/zoom ourselves, from the real pixel [size]
/// this code already has in hand, and handing the result to flutter_map as
/// plain `initialCenter`/`initialZoom` removes the race entirely — there is
/// nothing left for flutter_map to compute late.
///
/// A pure function on purpose — no `BuildContext`, no `MapController`, no
/// widget — so it is unit-testable without a running map, and its answer is
/// identical on the Dart VM and on web: there is no longer any platform
/// timing involved, just arithmetic.
///
/// [singleZoom] is used verbatim when [points] has only one distinct
/// location (one point, or several that are exactly coincident — e.g.
/// several agents whose latest stop is the same outlet). A bounds fit
/// against a zero-area box is undefined (and, historically, flutter_map's
/// own attempt at this produced a non-finite zoom) — so that case skips the
/// maths entirely rather than special-casing a division by zero.
///
/// [maxZoom] caps how far a very tight cluster is allowed to zoom in — two
/// points a few metres apart would otherwise solve for an enormous zoom,
/// which reads as "zoomed into the void" once real tiles are drawn.
(LatLng, double) fitFor(
  List<LatLng> points, {
  required Size size,
  double padding = 24,
  double singleZoom = 13,
  double maxZoom = 16,
}) {
  assert(points.isNotEmpty, 'fitFor needs at least one point');

  // Coincident points (including the trivial one-point case) have a
  // zero-area bounds box — nothing to fit, so centre on the shared point at
  // a sensible default rather than dividing by a zero span.
  final distinct = points.toSet();
  if (distinct.length <= 1) {
    return (points.first, singleZoom);
  }

  final lats = [for (final p in points) p.latitude];
  final lngs = [for (final p in points) p.longitude];
  final latMin = lats.reduce(math.min);
  final latMax = lats.reduce(math.max);
  final lngMin = lngs.reduce(math.min);
  final lngMax = lngs.reduce(math.max);

  // The centre is the midpoint of the bounds IN MERCATOR SPACE, not a plain
  // average of the raw latitudes: Mercator's y-axis compresses distance
  // increasingly toward the poles, so a naive lat average skews the visual
  // centre away from the equator. Longitude is linear under this
  // projection, so a plain average is already correct there.
  final centerLat = _inverseMercatorY(
    (_mercatorY(latMin) + _mercatorY(latMax)) / 2,
  );
  final centerLng = (lngMin + lngMax) / 2;

  // Guard against a degenerate (near-zero or negative, if padding exceeds
  // the available space) viewport rather than feeding log() a value that
  // turns the whole calculation into NaN or -infinity.
  final availableWidth = math.max(size.width - 2 * padding, 1.0);
  final availableHeight = math.max(size.height - 2 * padding, 1.0);

  // Standard slippy-map tile maths: the whole world is `256 * 2^zoom`
  // pixels wide at any zoom, and both longitude and (Mercator) latitude map
  // linearly onto that width — longitude over its full 360°, Mercator-y
  // over its full 2π. Solving "world pixels for this span == available
  // pixels" for zoom gives the largest zoom that still fits; the smaller of
  // the two axes' answers is the zoom that fits both.
  final lngSpan = lngMax - lngMin;
  final mercSpan = _mercatorY(latMax) - _mercatorY(latMin);

  final zoomX = lngSpan <= 0
      ? double.infinity
      : _log2(availableWidth * 360 / (256 * lngSpan));
  final zoomY = mercSpan <= 0
      ? double.infinity
      : _log2(availableHeight * 2 * math.pi / (256 * mercSpan));

  final zoom = math.min(zoomX, zoomY).clamp(0.0, maxZoom);

  return (LatLng(centerLat, centerLng), zoom);
}

double _log2(double x) => math.log(x) / math.ln2;

/// The standard Web Mercator (EPSG:3857) latitude transform, in radians —
/// `ln(tan(π/4 + φ/2))`. Monotonic and linear-under-tile-scaling, which is
/// the property [fitFor] relies on for both the Mercator-space midpoint and
/// the zoom-to-fit calculation.
double _mercatorY(double latDegrees) {
  final latRad = latDegrees * math.pi / 180;
  return math.log(math.tan(math.pi / 4 + latRad / 2));
}

/// Inverse of [_mercatorY]: Mercator-y back to a latitude in degrees.
double _inverseMercatorY(double mercatorY) =>
    (2 * math.atan(math.exp(mercatorY)) - math.pi / 2) * 180 / math.pi;

import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tradeiq_app/core/geo/mercator_fit.dart';

void main() {
  group('fitFor', () {
    test('fits two points a few km apart in a wide-short viewport', () {
      // Real coordinates from the dashboard's own API response — two
      // Johannesburg check-ins about 5km apart.
      final points = [
        const LatLng(-26.1929, 28.0305),
        const LatLng(-26.1467, 28.0436),
      ];
      final (center, zoom) = fitFor(points, size: const Size(862, 260));

      // Both agents are close to the midpoint, and the fit must be a real,
      // legible zoom — not the near-world view (z ≈ 2.5) the flutter_map
      // race produced.
      expect(center.latitude, closeTo(-26.1698, 0.01));
      expect(center.longitude, closeTo(28.03705, 0.01));
      expect(zoom, inInclusiveRange(11, 13));
    });

    test('a single point uses the default zoom, centred on it', () {
      const point = LatLng(-26.10, 28.05);
      final (center, zoom) = fitFor(
        [point],
        size: const Size(862, 260),
        singleZoom: 13,
      );

      expect(center, point);
      expect(zoom, 13);
    });

    test('two identical points do not produce infinity or NaN', () {
      const point = LatLng(-26.10, 28.05);
      final (center, zoom) = fitFor(
        [point, point],
        size: const Size(862, 260),
        singleZoom: 11,
      );

      expect(center, point);
      expect(zoom, 11);
      expect(zoom.isFinite, isTrue);
    });

    test('three points where two are coincident still fits the real spread', () {
      final points = [
        const LatLng(-26.10, 28.05),
        const LatLng(-26.10, 28.05),
        const LatLng(-26.14, 28.09),
      ];
      final (center, zoom) = fitFor(points, size: const Size(862, 260));

      expect(zoom.isFinite, isTrue);
      expect(center.latitude, closeTo(-26.12, 0.01));
      expect(center.longitude, closeTo(28.07, 0.01));
    });

    test('a pair spanning a very large distance clamps zoom low, no crash', () {
      // Johannesburg to Cape Town — roughly 1,270km apart.
      final points = [const LatLng(-26.10, 28.05), const LatLng(-33.90, 18.42)];
      final (center, zoom) = fitFor(points, size: const Size(862, 260));

      expect(zoom.isFinite, isTrue);
      expect(zoom, lessThan(8));
      expect(zoom, greaterThanOrEqualTo(0));
      expect(center.latitude, closeTo(-30, 3));
      expect(center.longitude, closeTo(23, 5));
    });

    test('zoom never exceeds maxZoom for a very tight cluster', () {
      final points = [
        const LatLng(-26.100000, 28.050000),
        const LatLng(-26.100001, 28.050001),
      ];
      final (_, zoom) = fitFor(
        points,
        size: const Size(862, 260),
        maxZoom: 16,
      );

      expect(zoom, lessThanOrEqualTo(16));
      expect(zoom.isFinite, isTrue);
    });

    test('a near-degenerate viewport (padding exceeding size) still returns a finite zoom', () {
      final points = [const LatLng(-26.10, 28.05), const LatLng(-26.14, 28.09)];
      final (_, zoom) = fitFor(
        points,
        size: const Size(10, 10),
        padding: 24,
      );

      expect(zoom.isFinite, isTrue);
    });
  });
}

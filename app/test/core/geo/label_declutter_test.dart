import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tradeiq_app/core/geo/label_declutter.dart';

// Johannesburg, where the demo outlets sit.
const _center = LatLng(-26.1076, 28.0567);

/// ~20m east of [_center] — the collision distance #197 reports.
const _twentyMetresEast = LatLng(-26.1076, 28.056900);

/// ~2km north — never collides at a city zoom.
const _farAway = LatLng(-26.0896, 28.0567);

void main() {
  group('screenOffset', () {
    test('puts the centre point at the origin', () {
      final offset = screenOffset(center: _center, point: _center, zoom: 14);
      expect(offset.dx.abs(), lessThan(0.001));
      expect(offset.dy.abs(), lessThan(0.001));
    });

    test('places an eastward point to the right, a northward point above', () {
      final east = screenOffset(
        center: _center,
        point: const LatLng(-26.1076, 28.0600),
        zoom: 14,
      );
      expect(east.dx, greaterThan(0));

      // Screen y grows downward, so further north is a NEGATIVE dy.
      final north = screenOffset(center: _center, point: _farAway, zoom: 14);
      expect(north.dy, lessThan(0));
    });

    test('doubles the pixel separation for each zoom level', () {
      final atZoom14 = screenOffset(
        center: _center,
        point: _farAway,
        zoom: 14,
      ).dy.abs();
      final atZoom15 = screenOffset(
        center: _center,
        point: _farAway,
        zoom: 15,
      ).dy.abs();

      expect(atZoom15 / atZoom14, closeTo(2.0, 0.01));
    });

    test('is finite for every zoom the map can reach', () {
      for (var zoom = 0.0; zoom <= 20; zoom += 1) {
        final offset = screenOffset(center: _center, point: _farAway, zoom: zoom);
        expect(offset.dx.isFinite, isTrue);
        expect(offset.dy.isFinite, isTrue);
      }
    });
  });

  group('declutterLabels', () {
    // The marker geometry from agent_trail_screen: a 128-wide label box
    // hanging below the disc.
    const labelRect = Rect.fromLTWH(-64, 20, 128, 35);

    test('keeps every label when nothing overlaps', () {
      final visible = declutterLabels(
        points: const [_center, _farAway],
        priority: const [0, 1],
        center: _center,
        zoom: 14,
        labelRect: labelRect,
      );
      expect(visible, [true, true]);
    });

    // The exact bug: two stops ~20m apart at a city zoom.
    test('hides the lower-priority label when two stops collide', () {
      final visible = declutterLabels(
        points: const [_center, _twentyMetresEast],
        priority: const [0, 1],
        center: _center,
        zoom: 14,
        labelRect: labelRect,
      );
      expect(visible, [true, false]);
    });

    test('keeps the higher-priority label regardless of list order', () {
      // Same two stops, but the SECOND one is the important one.
      final visible = declutterLabels(
        points: const [_center, _twentyMetresEast],
        priority: const [1, 0],
        center: _center,
        zoom: 14,
        labelRect: labelRect,
      );
      expect(visible, [false, true]);
    });

    // Zoom-awareness is the whole reason this is computed live rather than
    // once: two outlets 20m apart are genuinely distinct once you zoom in,
    // and permanently hiding one would be wrong.
    //
    // Zoom 20, not 19, and the arithmetic is worth recording. At this latitude
    // a zoom-19 pixel is ~0.27m, so 20m of ground is only ~75px — narrower than
    // the 128px label box, so the labels genuinely still overlap there. They
    // separate just above zoom ~19.8. The practical consequence: stops closer
    // than ~34m keep one label suppressed even at maximum zoom. That is
    // acceptable (the disc is never hidden, and tapping gives the detail) but
    // it is a real limit of a fixed-width label box, not an oversight.
    test('reveals the hidden label once zoom separates the stops', () {
      final zoomedOut = declutterLabels(
        points: const [_center, _twentyMetresEast],
        priority: const [0, 1],
        center: _center,
        zoom: 14,
        labelRect: labelRect,
      );
      final zoomedIn = declutterLabels(
        points: const [_center, _twentyMetresEast],
        priority: const [0, 1],
        center: _center,
        zoom: 20,
        labelRect: labelRect,
      );

      expect(zoomedOut, [true, false]);
      expect(zoomedIn, [true, true]);
    });

    test('never hides every label in a colliding cluster', () {
      final visible = declutterLabels(
        points: const [_center, _center, _center],
        priority: const [0, 1, 2],
        center: _center,
        zoom: 14,
        labelRect: labelRect,
      );
      expect(visible.where((v) => v).length, 1);
      expect(visible.first, isTrue);
    });

    test('handles a single stop', () {
      expect(
        declutterLabels(
          points: const [_center],
          priority: const [0],
          center: _center,
          zoom: 14,
          labelRect: labelRect,
        ),
        [true],
      );
    });

    test('handles no stops', () {
      expect(
        declutterLabels(
          points: const [],
          priority: const [],
          center: _center,
          zoom: 14,
          labelRect: labelRect,
        ),
        isEmpty,
      );
    });

    test('returns one flag per point, in the input order', () {
      final visible = declutterLabels(
        points: const [_center, _twentyMetresEast, _farAway],
        priority: const [2, 0, 1],
        center: _center,
        zoom: 14,
        labelRect: labelRect,
      );
      expect(visible, hasLength(3));
    });

    test('rejects a priority list that does not match the points', () {
      expect(
        () => declutterLabels(
          points: const [_center, _farAway],
          priority: const [0],
          center: _center,
          zoom: 14,
          labelRect: labelRect,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}

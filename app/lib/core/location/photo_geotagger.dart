import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'location_service.dart';

/// Reads where the device is at the moment an audit photo is taken, as the
/// photo's `gpsTag` (#310).
///
/// The fraud engine reads that tag in `photo_gps_divergence`,
/// `stock_outside_outlet` (#248) and `capture_timeline_gap` (#246). Its reader
/// (`readCoords` in `fraud.service.ts`) takes numeric `lat` and `lng` from the
/// JSON object and ignores anything else. `accuracy` (metres) and `fixedAt`
/// (ISO-8601 UTC) ride along so a stale or coarse fix can be judged. The
/// backend stores `gpsTag` as an opaque JSON object, so the extra keys are safe.
///
/// A tag is evidence, never a gate. Refusal, disabled services, errors and a
/// slow fix all come back as an empty tag, in bounded time, and the photo is
/// kept either way.
class PhotoGeotagger {
  PhotoGeotagger({required this.location, this.timeout = defaultTimeout});

  final LocationService location;

  /// How long a capture will wait for a fix. Long enough for a warm GPS (the
  /// agent was just located at check-in), short enough that a dead aisle does
  /// not hold the agent's shot hostage.
  final Duration timeout;

  static const defaultTimeout = Duration(seconds: 4);

  /// The `gpsTag` for right now: `{lat, lng, accuracy?, fixedAt?}` or `{}`.
  Future<Map<String, dynamic>> tag() async {
    try {
      final result = await location.getPositionIfPermitted().timeout(timeout);
      return switch (result) {
        LocationGranted() => gpsTagFor(result),
        LocationDenied() || LocationError() => <String, dynamic>{},
      };
    } catch (_) {
      // A timeout or anything else unexpected: no tag, not a failed capture.
      return <String, dynamic>{};
    }
  }
}

/// The `gpsTag` JSON for a granted fix, in the shape the backend reads.
Map<String, dynamic> gpsTagFor(LocationGranted fix) => <String, dynamic>{
  'lat': fix.lat,
  'lng': fix.lng,
  if (fix.accuracy != null && fix.accuracy!.isFinite) 'accuracy': fix.accuracy,
  if (fix.fixedAt != null) 'fixedAt': fix.fixedAt!.toUtc().toIso8601String(),
};

final photoGeotaggerProvider = Provider<PhotoGeotagger>(
  (ref) => PhotoGeotagger(location: ref.read(locationServiceProvider)),
);

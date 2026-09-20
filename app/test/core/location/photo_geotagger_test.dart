import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/location/location_service.dart';
import 'package:tradeiq_app/core/location/photo_geotagger.dart';

/// Answers the no-prompt lookup with whatever the test hands it, and fails the
/// test if the PROMPTING lookup is ever used for a geotag.
class _FakeLocation extends LocationService {
  _FakeLocation(this._answer);

  final Future<LocationResult> Function() _answer;

  @override
  Future<LocationResult> getPositionIfPermitted() => _answer();

  @override
  Future<LocationResult> getCurrentPosition() =>
      throw StateError('a geotag must never raise the permission prompt');
}

void main() {
  test('a granted fix becomes {lat, lng, accuracy, fixedAt} — the keys the '
      'fraud reader takes as numbers, plus staleness context', () async {
    final tagger = PhotoGeotagger(
      location: _FakeLocation(
        () async => LocationGranted(
          -26.2041,
          28.0473,
          accuracy: 12.5,
          // A local-zone fix time: the tag carries it as UTC.
          fixedAt: DateTime.utc(2026, 9, 15, 8, 30).toLocal(),
        ),
      ),
    );

    final tag = await tagger.tag();

    expect(tag, {
      'lat': -26.2041,
      'lng': 28.0473,
      'accuracy': 12.5,
      'fixedAt': '2026-09-15T08:30:00.000Z',
    });
    // readCoords (fraud.service.ts) requires finite numbers, not strings.
    expect(tag['lat'], isA<double>());
    expect(tag['lng'], isA<double>());
  });

  test('a fix with no accuracy or time still tags lat/lng only', () async {
    final tagger = PhotoGeotagger(
      location: _FakeLocation(() async => LocationGranted(1.5, 2.5)),
    );

    expect(await tagger.tag(), {'lat': 1.5, 'lng': 2.5});
  });

  test('refused location is no tag, not an error', () async {
    final tagger = PhotoGeotagger(
      location: _FakeLocation(() async => LocationDenied()),
    );

    expect(await tagger.tag(), isEmpty);
  });

  test('unavailable location is no tag, not an error', () async {
    final tagger = PhotoGeotagger(
      location: _FakeLocation(
        () async => LocationError('Location services are disabled'),
      ),
    );

    expect(await tagger.tag(), isEmpty);
  });

  test('a throwing lookup is no tag, not an error', () async {
    final tagger = PhotoGeotagger(
      location: _FakeLocation(() async => throw Exception('platform')),
    );

    expect(await tagger.tag(), isEmpty);
  });

  test('a fix that never arrives gives up at the timeout with no tag', () async {
    final tagger = PhotoGeotagger(
      location: _FakeLocation(() => Completer<LocationResult>().future),
      timeout: const Duration(milliseconds: 50),
    );

    final watch = Stopwatch()..start();
    final tag = await tagger.tag();
    watch.stop();

    expect(tag, isEmpty);
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test('the default wait is short — seconds, not the check-in fix timeout', () {
    expect(
      PhotoGeotagger.defaultTimeout,
      lessThanOrEqualTo(const Duration(seconds: 5)),
    );
  });
}

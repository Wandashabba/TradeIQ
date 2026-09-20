import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tradeiq_app/core/location/geolocator_gateway.dart';
import 'package:tradeiq_app/core/location/location_service.dart';

Position _fakePosition(double lat, double lng) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime(2026, 1, 1),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class _FakeGateway implements GeolocatorGateway {
  _FakeGateway({
    this.initialPermission = LocationPermission.always,
    this.requestedPermission,
    this.serviceEnabled = true,
    this.position,
  });

  final LocationPermission initialPermission;
  final LocationPermission? requestedPermission;
  final bool serviceEnabled;
  final Position? position;

  @override
  Future<LocationPermission> checkPermission() async => initialPermission;

  @override
  Future<LocationPermission> requestPermission() async =>
      requestedPermission ?? initialPermission;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<Position> getCurrentPosition() async {
    if (position == null) throw Exception('no fake position provided');
    return position!;
  }
}

class _ThrowingPermissionGateway implements GeolocatorGateway {
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;

  @override
  Future<LocationPermission> requestPermission() async => throw Exception(
    "Permission definitions not found in the app's Info.plist.",
  );

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Position> getCurrentPosition() async => throw UnimplementedError();
}

/// A gateway that answers permission questions but never delivers a fix.
///
/// This is not hypothetical: on macOS and on a phone indoors, CoreLocation
/// and the Android fused provider can both accept the request and then simply
/// never call back. Geolocator only bounds that if it is given a time limit.
class _NeverFixesGateway implements GeolocatorGateway {
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Position> getCurrentPosition() => Completer<Position>().future;
}

/// A gateway whose permission request never returns — the macOS failure mode
/// where the authorization status stays `notDetermined`, so geolocator's
/// delegate callback never fires.
class _NeverAnswersPermissionGateway implements GeolocatorGateway {
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;

  @override
  Future<LocationPermission> requestPermission() =>
      Completer<LocationPermission>().future;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Position> getCurrentPosition() async => throw UnimplementedError();
}

void main() {
  group('getPositionIfPermitted (photo geotags, #310)', () {
    test(
      'never raises the permission prompt — undecided is simply denied',
      () async {
        // This gateway THROWS if asked to request permission, which would come
        // back as a LocationError. LocationDenied proves it was never asked.
        final service = LocationService(gateway: _ThrowingPermissionGateway());

        expect(await service.getPositionIfPermitted(), isA<LocationDenied>());
      },
    );

    test('an undeterminable permission is denied here, where a fix request '
        'would itself prompt — check-in keeps its old behaviour', () async {
      final gateway = _FakeGateway(
        initialPermission: LocationPermission.unableToDetermine,
        position: _fakePosition(1, 2),
      );

      expect(
        await LocationService(gateway: gateway).getPositionIfPermitted(),
        isA<LocationDenied>(),
      );
      expect(
        await LocationService(gateway: gateway).getCurrentPosition(),
        isA<LocationGranted>(),
      );
    });

    test('with permission already granted, returns the fix', () async {
      final service = LocationService(
        gateway: _FakeGateway(
          initialPermission: LocationPermission.whileInUse,
          position: _fakePosition(-26.2, 28.0),
        ),
      );

      final result = await service.getPositionIfPermitted();

      expect(result, isA<LocationGranted>());
      expect((result as LocationGranted).lat, -26.2);
    });
  });

  test('a granted fix carries the platform accuracy and fix time', () async {
    final service = LocationService(
      gateway: _FakeGateway(position: _fakePosition(-26.2, 28.0)),
    );

    final result = await service.getCurrentPosition() as LocationGranted;

    expect(result.accuracy, 5);
    expect(result.fixedAt, DateTime(2026, 1, 1));
  });

  test(
    'returns LocationError instead of hanging when the fix never arrives',
    () async {
      final service = LocationService(
        gateway: _NeverFixesGateway(),
        fixTimeout: const Duration(milliseconds: 20),
      );

      // The outer timeout is the assertion's teeth: without a bound inside the
      // service this future never completes and the test hangs rather than fails.
      final result = await service.getCurrentPosition().timeout(
        const Duration(seconds: 5),
      );

      expect(result, isA<LocationError>());
      expect((result as LocationError).message, contains('location'));
    },
  );

  test(
    'returns LocationError instead of hanging when the permission request never returns',
    () async {
      final service = LocationService(
        gateway: _NeverAnswersPermissionGateway(),
        permissionTimeout: const Duration(milliseconds: 20),
      );

      final result = await service.getCurrentPosition().timeout(
        const Duration(seconds: 5),
      );

      expect(result, isA<LocationError>());
    },
  );

  test(
    'returns LocationGranted with the device coordinates when permission is already granted',
    () async {
      final service = LocationService(
        gateway: _FakeGateway(
          initialPermission: LocationPermission.whileInUse,
          position: _fakePosition(-26.1076, 28.0567),
        ),
      );

      final result = await service.getCurrentPosition();

      expect(result, isA<LocationGranted>());
      expect((result as LocationGranted).lat, -26.1076);
      expect(result.lng, 28.0567);
    },
  );

  test(
    'requests permission when initially denied, then succeeds if granted',
    () async {
      final service = LocationService(
        gateway: _FakeGateway(
          initialPermission: LocationPermission.denied,
          requestedPermission: LocationPermission.whileInUse,
          position: _fakePosition(-26.1076, 28.0567),
        ),
      );

      final result = await service.getCurrentPosition();

      expect(result, isA<LocationGranted>());
    },
  );

  test(
    'returns LocationDenied when permission is denied even after requesting',
    () async {
      final service = LocationService(
        gateway: _FakeGateway(
          initialPermission: LocationPermission.denied,
          requestedPermission: LocationPermission.denied,
        ),
      );

      final result = await service.getCurrentPosition();

      expect(result, isA<LocationDenied>());
    },
  );

  test(
    'returns LocationDenied when permission is permanently denied',
    () async {
      final service = LocationService(
        gateway: _FakeGateway(
          initialPermission: LocationPermission.deniedForever,
        ),
      );

      final result = await service.getCurrentPosition();

      expect(result, isA<LocationDenied>());
    },
  );

  test('returns LocationError when location services are disabled', () async {
    final service = LocationService(
      gateway: _FakeGateway(
        initialPermission: LocationPermission.whileInUse,
        serviceEnabled: false,
      ),
    );

    final result = await service.getCurrentPosition();

    expect(result, isA<LocationError>());
  });

  test('returns LocationError when fetching the position throws', () async {
    final service = LocationService(
      gateway: _FakeGateway(initialPermission: LocationPermission.whileInUse),
    );

    final result = await service.getCurrentPosition();

    expect(result, isA<LocationError>());
  });

  test(
    'returns LocationError instead of throwing when requesting permission itself throws',
    () async {
      final service = LocationService(gateway: _ThrowingPermissionGateway());

      final result = await service.getCurrentPosition();

      expect(result, isA<LocationError>());
    },
  );
}

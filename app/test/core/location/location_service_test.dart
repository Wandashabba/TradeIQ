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
  Future<LocationPermission> requestPermission() async => requestedPermission ?? initialPermission;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<Position> getCurrentPosition() async {
    if (position == null) throw Exception('no fake position provided');
    return position!;
  }
}

void main() {
  test('returns LocationGranted with the device coordinates when permission is already granted', () async {
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
  });

  test('requests permission when initially denied, then succeeds if granted', () async {
    final service = LocationService(
      gateway: _FakeGateway(
        initialPermission: LocationPermission.denied,
        requestedPermission: LocationPermission.whileInUse,
        position: _fakePosition(-26.1076, 28.0567),
      ),
    );

    final result = await service.getCurrentPosition();

    expect(result, isA<LocationGranted>());
  });

  test('returns LocationDenied when permission is denied even after requesting', () async {
    final service = LocationService(
      gateway: _FakeGateway(
        initialPermission: LocationPermission.denied,
        requestedPermission: LocationPermission.denied,
      ),
    );

    final result = await service.getCurrentPosition();

    expect(result, isA<LocationDenied>());
  });

  test('returns LocationDenied when permission is permanently denied', () async {
    final service = LocationService(
      gateway: _FakeGateway(initialPermission: LocationPermission.deniedForever),
    );

    final result = await service.getCurrentPosition();

    expect(result, isA<LocationDenied>());
  });

  test('returns LocationError when location services are disabled', () async {
    final service = LocationService(
      gateway: _FakeGateway(initialPermission: LocationPermission.whileInUse, serviceEnabled: false),
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
}

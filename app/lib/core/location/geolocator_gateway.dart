import 'package:geolocator/geolocator.dart';

/// Thin wrapper around the static [Geolocator] calls this app needs, so
/// [LocationService] can be unit-tested with a fake instead of mocking
/// geolocator's platform-channel internals.
abstract class GeolocatorGateway {
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<bool> isLocationServiceEnabled();
  Future<Position> getCurrentPosition();
}

class RealGeolocatorGateway implements GeolocatorGateway {
  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<Position> getCurrentPosition() => Geolocator.getCurrentPosition();
}

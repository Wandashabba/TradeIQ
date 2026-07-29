import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'geolocator_gateway.dart';

sealed class LocationResult {}

class LocationGranted extends LocationResult {
  LocationGranted(this.lat, this.lng);
  final double lat;
  final double lng;
}

class LocationDenied extends LocationResult {}

class LocationError extends LocationResult {
  LocationError(this.message);
  final String message;
}

class LocationService {
  LocationService({
    GeolocatorGateway? gateway,
    this.permissionTimeout = _defaultPermissionTimeout,
    this.fixTimeout = _defaultFixTimeout,
  }) : _gateway = gateway ?? RealGeolocatorGateway();

  final GeolocatorGateway _gateway;
  final Duration permissionTimeout;
  final Duration fixTimeout;

  /// Long enough for someone to read the system dialog and decide.
  static const _defaultPermissionTimeout = Duration(seconds: 60);

  /// A cold GPS fix outdoors can take ten or fifteen seconds; past this it is
  /// not slow, it is not coming.
  static const _defaultFixTimeout = Duration(seconds: 25);

  /// Resolves to a [LocationResult] — always, and in bounded time.
  ///
  /// Every call below is bounded because none of them are guaranteed to come
  /// back. `getCurrentPosition` waits on a platform callback that a device
  /// with no fix simply never makes, and on macOS the permission request waits
  /// on a CoreLocation delegate that stays silent while the authorization
  /// status remains `notDetermined`. Unbounded, either one leaves the check-in
  /// screen on its locating radar forever — the app looking like it is still
  /// working when it has, in fact, stopped.
  Future<LocationResult> getCurrentPosition() async {
    try {
      var permission =
          await _gateway.checkPermission().timeout(permissionTimeout);
      if (permission == LocationPermission.denied) {
        permission =
            await _gateway.requestPermission().timeout(permissionTimeout);
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return LocationDenied();
      }

      if (!await _gateway.isLocationServiceEnabled().timeout(permissionTimeout)) {
        return LocationError('Location services are disabled');
      }

      final position = await _gateway.getCurrentPosition().timeout(fixTimeout);
      return LocationGranted(position.latitude, position.longitude);
    } on TimeoutException {
      return LocationError(
        'Timed out waiting for your location. Check that location is switched '
        'on for TradeIQ, then try again.',
      );
    } catch (e) {
      return LocationError('Failed to get current location: $e');
    }
  }
}

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

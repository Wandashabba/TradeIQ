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
  LocationService({GeolocatorGateway? gateway}) : _gateway = gateway ?? RealGeolocatorGateway();

  final GeolocatorGateway _gateway;

  Future<LocationResult> getCurrentPosition() async {
    var permission = await _gateway.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _gateway.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return LocationDenied();
    }

    if (!await _gateway.isLocationServiceEnabled()) {
      return LocationError('Location services are disabled');
    }

    try {
      final position = await _gateway.getCurrentPosition();
      return LocationGranted(position.latitude, position.longitude);
    } catch (e) {
      return LocationError('Failed to get current location: $e');
    }
  }
}

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

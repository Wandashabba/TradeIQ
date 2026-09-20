import 'dart:math';

class Coordinates {
  const Coordinates({required this.lat, required this.lng});
  final double lat;
  final double lng;
}

const _earthRadiusMeters = 6371000.0;

const defaultGeofenceRadiusMeters = 50.0;

double _toRadians(double degrees) => degrees * pi / 180;

double haversineDistanceMeters(Coordinates a, Coordinates b) {
  final dLat = _toRadians(b.lat - a.lat);
  final dLng = _toRadians(b.lng - a.lng);
  final lat1 = _toRadians(a.lat);
  final lat2 = _toRadians(b.lat);

  final h =
      pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLng / 2), 2);

  return 2 * _earthRadiusMeters * asin(sqrt(h));
}

bool isWithinGeofence(
  Coordinates outlet,
  Coordinates checkin, {
  double radiusMeters = defaultGeofenceRadiusMeters,
}) {
  return haversineDistanceMeters(outlet, checkin) <= radiusMeters;
}

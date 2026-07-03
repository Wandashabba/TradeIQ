import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/geo/geofence.dart';

void main() {
  group('isWithinGeofence', () {
    test('returns true when within 50m of the outlet', () {
      const outlet = Coordinates(lat: -26.2041, lng: 28.0473);
      const checkin = Coordinates(lat: -26.20400, lng: 28.0473); // ~11m north
      expect(isWithinGeofence(outlet, checkin), isTrue);
    });

    test('returns false when more than 50m from the outlet', () {
      const outlet = Coordinates(lat: -26.2041, lng: 28.0473);
      const checkin = Coordinates(lat: -26.2100, lng: 28.0473); // ~650m away
      expect(isWithinGeofence(outlet, checkin), isFalse);
    });
  });
}

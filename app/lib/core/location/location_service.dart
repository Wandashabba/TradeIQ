import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'geolocator_gateway.dart';

sealed class LocationResult {}

class LocationGranted extends LocationResult {
  LocationGranted(this.lat, this.lng, {this.accuracy, this.fixedAt});
  final double lat;
  final double lng;

  /// The platform's horizontal accuracy estimate, in metres, when it gave one.
  final double? accuracy;

  /// When the platform took this fix. A cached last-known fix can be minutes
  /// old, so this is what lets a reader judge staleness.
  final DateTime? fixedAt;
}

class LocationDenied extends LocationResult {}

/// Why a [LocationError] happened, for callers that word it themselves (the
/// check-in screen, in the agent's language).
enum LocationErrorKind { servicesDisabled, timedOut, failed }

class LocationError extends LocationResult {
  LocationError(this.message, {this.kind, this.detail});

  /// English description.
  final String message;

  /// Null for an error this service has no code for.
  final LocationErrorKind? kind;

  /// The underlying failure, for [LocationErrorKind.failed].
  final String? detail;
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
  Future<LocationResult> getCurrentPosition() => _resolve(askPermission: true);

  /// Like [getCurrentPosition], but never raises the permission prompt: if
  /// location is not already granted this is simply [LocationDenied].
  ///
  /// For background readings (a photo's geotag, #310) where the agent did not
  /// ask to be located. They decided about location at check-in; a system
  /// dialog popping over the camera is not the place to ask again.
  Future<LocationResult> getPositionIfPermitted() =>
      _resolve(askPermission: false);

  Future<LocationResult> _resolve({required bool askPermission}) async {
    try {
      var permission =
          await _gateway.checkPermission().timeout(permissionTimeout);
      if (askPermission && permission == LocationPermission.denied) {
        permission =
            await _gateway.requestPermission().timeout(permissionTimeout);
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return LocationDenied();
      }
      // Some browsers cannot say whether location is allowed, and asking for a
      // fix is then what raises their prompt — so the no-prompt path stops here.
      if (!askPermission &&
          permission == LocationPermission.unableToDetermine) {
        return LocationDenied();
      }

      if (!await _gateway.isLocationServiceEnabled().timeout(permissionTimeout)) {
        return LocationError(
          'Location services are disabled',
          kind: LocationErrorKind.servicesDisabled,
        );
      }

      final position = await _gateway.getCurrentPosition().timeout(fixTimeout);
      return LocationGranted(
        position.latitude,
        position.longitude,
        accuracy: position.accuracy,
        fixedAt: position.timestamp,
      );
    } on TimeoutException {
      return LocationError(
        'Took too long. Check location is on for TradeIQ, then try again.',
        kind: LocationErrorKind.timedOut,
      );
    } catch (e) {
      return LocationError(
        'Failed to get current location: $e',
        kind: LocationErrorKind.failed,
        detail: '$e',
      );
    }
  }
}

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

/// One fix, shared by every screen that is looking at the same moment.
///
/// A cold GPS fix outdoors costs ten or fifteen seconds, and two screens that
/// each ask for their own spend it twice — the agent's day route and the map of
/// their stores would take half a minute between them to say the same two
/// numbers. This is the one place either of them asks.
///
/// It is a [FutureProvider], so it lives exactly as long as something is
/// watching it: leaving both screens drops the fix, and coming back takes a new
/// one. A position cached for the life of the app is a position that is wrong
/// by the time it matters, which is worse than a slow one.
///
/// It never throws. [LocationService.getCurrentPosition] resolves to a
/// [LocationResult] — granted, denied, or an error with a reason — in bounded
/// time, and the screens word each of those themselves.
final currentFixProvider = FutureProvider<LocationResult>(
  (ref) => ref.read(locationServiceProvider).getCurrentPosition(),
);

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'geolocator_gateway.dart';

sealed class LocationResult {}

class LocationGranted extends LocationResult {
  LocationGranted(
    this.lat,
    this.lng, {
    this.accuracy,
    this.fixedAt,
    this.isMocked = false,
  });
  final double lat;
  final double lng;

  /// The platform's horizontal accuracy estimate, in metres, when it gave one.
  final double? accuracy;

  /// When the platform took this fix. A cached last-known fix can be minutes
  /// old, so this is what lets a reader judge staleness.
  final DateTime? fixedAt;

  /// Whether the PLATFORM says this fix came from a mock provider (#386).
  ///
  /// Reported, never enforced here: a mocked fix still checks in, because a
  /// client-side refusal is a refusal the client can simply not perform. It
  /// travels to the server, which records it on the attempt, and a manager is
  /// then refused when they try to adopt that coordinate as an outlet's pin.
  /// Defaults false because the platform defaults it false; iOS never reports
  /// true, which is why the server treats it as evidence and not as a verdict.
  final bool isMocked;
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
      var permission = await _gateway.checkPermission().timeout(
        permissionTimeout,
      );
      if (askPermission && permission == LocationPermission.denied) {
        permission = await _gateway.requestPermission().timeout(
          permissionTimeout,
        );
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

      if (!await _gateway.isLocationServiceEnabled().timeout(
        permissionTimeout,
      )) {
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
        isMocked: position.isMocked,
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

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);

/// One fix, shared by every screen that is looking at the same moment.
///
/// A cold GPS fix outdoors costs ten or fifteen seconds, and two screens that
/// each ask for their own spend it twice — the agent's day route and the map of
/// their stores would take half a minute between them to say the same two
/// numbers. This is the one place either of them asks.
///
/// ## It does not expire on its own
///
/// This is a plain [FutureProvider], and in Riverpod 3 that is **not**
/// auto-disposing: once read, the answer is kept for the life of the app
/// unless somebody drops it. Leaving a screen does not. A position cached for
/// the life of the app is a position that is wrong by the time it matters —
/// and a cached refusal or time-out is worse, because it keeps an agent who
/// has since turned location on without distances until they restart.
///
/// So it is dropped, explicitly, at the two moments a fresh one is owed:
///
/// * **when the route reloads** — `invalidateRouteProgress`, run when a
///   submitted visit reaches the server. The agent has walked to another store
///   since the route was built, and before this provider existed the route
///   asked the phone again on every rebuild;
/// * **when the Map is opened** — `AgentMapScreen`, whose whole question is
///   *where am I*, and whose "check in here" circle arms for the store the fix
///   says the agent is standing in.
///
/// It is not made auto-disposing instead: `todayRouteProvider` and
/// `agentMapProvider` are kept alive and watch it, so it would never be
/// disposed anyway, and an invalidation says *when* in one line.
///
/// It never throws. [LocationService.getCurrentPosition] resolves to a
/// [LocationResult] — granted, denied, or an error with a reason — in bounded
/// time, and the screens word each of those themselves.
final currentFixProvider = FutureProvider<LocationResult>(
  (ref) => ref.read(locationServiceProvider).getCurrentPosition(),
);

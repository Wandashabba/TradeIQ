import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../auth/session_controller.dart';
import '../storage/local_db.dart';
import '../sync/sync_service.dart';
import 'location_sharing.dart';

/// Background location tracking between stores — #153 T2, **Android only**.
///
/// While the agent has accepted the *separate* background notice, Android has
/// granted "Allow all the time", and the client's working window is open, an
/// Android foreground service takes a fix every ten minutes and queues it in
/// the offline outbox. It keeps running when TradeIQ is not on screen; that is
/// the whole point of the tier, and the reason it asks for its own consent.
///
/// Four things bound it, and every one of them is load-bearing:
///
/// - **A notice of its own.** Accepting foreground sharing does not imply this.
///   Nothing starts until the agent taps accept on this notice, and its answer
///   is recorded against its own consent kind on the server.
/// - **Working hours.** The window comes from the server as two instants
///   ([BackgroundSettings.windowOpensAt] / [BackgroundSettings.windowClosesAt]),
///   resolved in the client's own timezone. The app starts and stops on those
///   edges, and the server re-checks every ping on arrival, so a wrong phone
///   clock cannot widen the window.
/// - **A permanent notification.** Android requires one for a location
///   foreground service, and it is also the honest thing to show: "am I being
///   tracked right now" must have an answer the agent can see without opening
///   the app.
/// - **Android only.** [backgroundLocationGatewayProvider] is null on every
///   other platform, so on iOS and on the web this controller is inert and the
///   app keeps exactly today's foreground-only behaviour. That is a decision,
///   not an accident — see `ios/Runner/Info.plist`.
///
/// Logging out rebuilds this into the inert non-agent state, and the rebuild
/// disposes the subscription, which is what stops the service and clears its
/// notification.

/// One background fix, decoupled from geolocator's `Position` so the controller
/// can be tested without a platform channel.
@immutable
class BackgroundFix {
  const BackgroundFix({
    required this.lat,
    required this.lng,
    this.accuracyM,
    this.fixedAt,
  });

  final double lat;
  final double lng;

  /// The platform's horizontal accuracy estimate in metres, when it gave one.
  final double? accuracyM;

  /// When the platform took the fix. A background fix can be minutes old by the
  /// time it is delivered, and the server orders everything by this.
  final DateTime? fixedAt;
}

/// The words on the permanent Android notification, in the agent's language.
@immutable
class BackgroundNotificationText {
  const BackgroundNotificationText({
    required this.title,
    required this.body,
    required this.channelName,
  });

  final String title;
  final String body;
  final String channelName;

  /// Used only if the service somehow starts before a localised frame has been
  /// built. English beats an empty notification, which Android would replace
  /// with a bare app name that says nothing about what is happening.
  static const fallback = BackgroundNotificationText(
    title: 'TradeIQ is recording your route',
    body: 'Working hours only. Turn it off in TradeIQ.',
    channelName: 'Route tracking',
  );

  @override
  bool operator ==(Object other) =>
      other is BackgroundNotificationText &&
      other.title == title &&
      other.body == body &&
      other.channelName == channelName;

  @override
  int get hashCode => Object.hash(title, body, channelName);
}

/// The platform calls this controller needs. A fake stands in for it in tests;
/// on anything but Android there is no implementation at all.
abstract class BackgroundLocationGateway {
  Future<LocationPermission> checkPermission();

  Future<LocationPermission> requestPermission();

  /// Opens this app's system settings page — the only route to "Allow all the
  /// time" from Android 11 onwards.
  Future<bool> openAppSettings();

  /// A stream of fixes from an Android foreground service. Cancelling the
  /// subscription stops the service and removes its notification.
  Stream<BackgroundFix> positions({
    required Duration interval,
    required BackgroundNotificationText notification,
  });
}

class GeolocatorBackgroundLocationGateway implements BackgroundLocationGateway {
  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Stream<BackgroundFix> positions({
    required Duration interval,
    required BackgroundNotificationText notification,
  }) => Geolocator.getPositionStream(
    locationSettings: AndroidSettings(
      // Balanced rather than best: the question this tier answers is "did they
      // travel between these stores", which a fused-provider fix answers at a
      // fraction of the battery of a GPS lock (#153 risk 5). A background ping
      // is never allowed to claim the agent is IN a store anyway, so the extra
      // precision would buy nothing it is permitted to say.
      accuracy: LocationAccuracy.medium,
      // Zero, deliberately. A distance filter suppresses emissions until the
      // phone has moved that far — so an agent standing in one shop for two
      // hours would produce nothing at all, and the ten-minute floor the notice
      // promises would quietly not exist. The interval is the rule; Android
      // decides for itself how cheaply to serve each fix.
      distanceFilter: 0,
      intervalDuration: interval,
      foregroundNotificationConfig: ForegroundNotificationConfig(
        notificationTitle: notification.title,
        notificationText: notification.body,
        notificationChannelName: notification.channelName,
        // The system may doze between fixes; without this the ten-minute
        // cadence collapses into a burst whenever the phone next wakes.
        enableWakeLock: true,
        // Non-dismissable. Android requires a notification for a location
        // foreground service, and an agent must not be able to swipe away the
        // one thing telling them their route is being recorded.
        setOngoing: true,
      ),
    ),
  ).map(
    (position) => BackgroundFix(
      lat: position.latitude,
      lng: position.longitude,
      accuracyM: position.accuracy,
      fixedAt: position.timestamp,
    ),
  );
}

/// The gateway, or **null on every platform but Android**.
///
/// This null is where "Android only" is actually enforced. iOS ships no Always
/// permission and no `UIBackgroundModes: location`, so even if this code ran it
/// could collect nothing; returning null makes that explicit here rather than
/// leaving it to a plist somebody might later "fix".
final backgroundLocationGatewayProvider = Provider<BackgroundLocationGateway?>((
  ref,
) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  return GeolocatorBackgroundLocationGateway();
});

/// What the agent is shown, and what the controller is doing.
enum BackgroundTrackingStep {
  /// Not an Android field agent, or the settings are not known yet. Nothing is
  /// shown at all.
  unavailable,

  /// The background notice is open, waiting for an answer.
  notice,

  /// Not on — never asked for, or declined. A quiet offer, never a wall.
  off,

  /// Accepted, but Android has not granted "Allow all the time".
  needsPermission,

  /// Accepted and permitted, but the working window is shut.
  outsideHours,

  /// The foreground service is up and pings are being queued.
  running,
}

@immutable
class BackgroundLocationState {
  const BackgroundLocationState({
    this.supported = false,
    this.settings,
    this.permission,
    this.running = false,
    this.lastPingAt,
    this.showingNotice = false,
    this.permissionRefused = false,
    this.now,
  });

  /// An Android field agent is signed in. Nothing below applies to anyone else.
  final bool supported;

  /// The server's background block; null until settings have been read.
  final BackgroundSettings? settings;

  /// Android's latest answer about location permission; null until checked.
  final LocationPermission? permission;

  /// The foreground service is running.
  final bool running;

  /// When the last background ping was queued.
  final DateTime? lastPingAt;

  /// The notice is open — because the agent asked to see it.
  final bool showingNotice;

  /// The agent was taken through the permission flow and did not end up with
  /// "Allow all the time". Not an error: everything else keeps working.
  final bool permissionRefused;

  /// The clock the window is judged against. Injected so the step is a pure
  /// function of the state in tests.
  final DateTime? now;

  bool get accepted =>
      settings?.decision?.consent == LocationConsent.acknowledged;

  /// Android has granted background location.
  bool get permitted => permission == LocationPermission.always;

  /// The agent has never answered the background notice, either way.
  bool get unanswered => settings != null && settings!.decision == null;

  /// Whether the client's working window is open, judged against [now].
  bool get windowOpen {
    final s = settings;
    if (s == null || !s.withinWorkingHours) return false;
    final closes = s.windowClosesAt;
    final at = now;
    if (closes == null || at == null) return s.withinWorkingHours;
    return at.isBefore(closes);
  }

  BackgroundTrackingStep get step {
    if (!supported || settings == null) return BackgroundTrackingStep.unavailable;
    if (showingNotice) return BackgroundTrackingStep.notice;
    if (!accepted) return BackgroundTrackingStep.off;
    if (!permitted) return BackgroundTrackingStep.needsPermission;
    if (!windowOpen) return BackgroundTrackingStep.outsideHours;
    return BackgroundTrackingStep.running;
  }

  BackgroundLocationState copyWith({
    BackgroundSettings? settings,
    bool clearSettings = false,
    LocationPermission? permission,
    bool? running,
    DateTime? lastPingAt,
    bool? showingNotice,
    bool? permissionRefused,
    DateTime? now,
  }) => BackgroundLocationState(
    supported: supported,
    settings: clearSettings ? null : (settings ?? this.settings),
    permission: permission ?? this.permission,
    running: running ?? this.running,
    lastPingAt: lastPingAt ?? this.lastPingAt,
    showingNotice: showingNotice ?? this.showingNotice,
    permissionRefused: permissionRefused ?? this.permissionRefused,
    now: now ?? this.now,
  );
}

/// Owns the foreground service's whole lifecycle.
class BackgroundLocationController extends Notifier<BackgroundLocationState> {
  StreamSubscription<BackgroundFix>? _subscription;
  Timer? _windowTimer;
  AppLifecycleListener? _lifecycle;
  Object _generation = Object();
  bool _disposed = false;
  String? _userId;
  DateTime? _lastRecordedAt;
  BackgroundNotificationText _notification = BackgroundNotificationText.fallback;

  @override
  BackgroundLocationState build() {
    final role = ref.watch(sessionControllerProvider).value?.role;
    final generation = Object();
    _generation = generation;
    _disposed = false;
    _lastRecordedAt = null;
    ref.onDispose(() {
      _disposed = true;
      _stopStream();
      _windowTimer?.cancel();
      _windowTimer = null;
      _lifecycle?.dispose();
      _lifecycle = null;
    });

    // No gateway means no Android, and no Android means nothing here runs.
    final gateway = ref.read(backgroundLocationGatewayProvider);
    if (role != 'field_agent' || gateway == null) {
      _userId = null;
      return const BackgroundLocationState();
    }
    _userId = currentLocalUserId;
    _lifecycle = AppLifecycleListener(onStateChange: handleLifecycle);

    // The settings come from the foreground controller, which already owns the
    // one GET /locations/settings call and its offline cache. Listening for the
    // background block only — rather than watching the whole state — matters:
    // the foreground state changes every couple of minutes as the heartbeat
    // fires, and rebuilding on that would tear the service down and start it
    // again all day long.
    ref.listen(locationSharingControllerProvider, (previous, next) {
      final after = next.settings?.background;
      if (previous?.settings?.background == after) return;
      state = state.copyWith(settings: after, now: _now());
      _reconcile();
    });

    Future.microtask(() {
      if (!_alive(generation)) return;
      unawaited(_refreshPermission());
    });

    return BackgroundLocationState(
      supported: true,
      settings: ref.read(locationSharingControllerProvider).settings?.background,
      now: _now(),
    );
  }

  bool _alive(Object generation) =>
      !_disposed && identical(generation, _generation);

  DateTime _now() => ref.read(locationClockProvider)();

  // ── The agent's controls ───────────────────────────────────────────────────

  /// Opens the background notice. Nothing is collected by opening it.
  void showNotice() {
    if (!state.supported || state.settings == null) return;
    state = state.copyWith(showingNotice: true);
  }

  void dismissNotice() => state = state.copyWith(showingNotice: false);

  /// "Turn on route tracking" — accept the notice, then ask Android.
  ///
  /// In that order, always. The acceptance is recorded first so that a phone
  /// that dies inside the system permission dialog still has the agent's answer
  /// on record, and so no permission prompt is ever raised before they have
  /// been told what it is for.
  Future<void> enable() async {
    if (!state.supported || state.settings == null) return;
    state = state.copyWith(showingNotice: false);
    await ref.read(locationSharingControllerProvider.notifier).acceptBackground();
    await requestPermission();
  }

  /// "Stop route tracking" — the control that is deliberately SEPARATE from the
  /// foreground "Stop sharing". Declining here writes a background decline and
  /// leaves the heartbeat exactly as it was.
  Future<void> stop() async {
    state = state.copyWith(showingNotice: false);
    await ref.read(locationSharingControllerProvider.notifier).declineBackground();
  }

  /// Android's two-step background-location flow.
  ///
  /// Step one is the ordinary while-in-use prompt. Step two is "Allow all the
  /// time", and from Android 11 the system will not show a dialog for it at
  /// all: `requestPermission` simply returns `whileInUse` however many times it
  /// is called, and the only way through is the app's own settings page. So it
  /// is asked for exactly once — which is the real prompt on Android 10 and a
  /// harmless no-op above it — and anything short of `always` leaves
  /// [BackgroundLocationState.permissionRefused] set for the UI to offer
  /// settings. A refusal stops nothing else in the app.
  Future<void> requestPermission() async {
    final gateway = ref.read(backgroundLocationGatewayProvider);
    if (gateway == null) return;
    final generation = _generation;
    var permission = await gateway.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await gateway.requestPermission();
    }
    if (permission == LocationPermission.whileInUse) {
      final escalated = await gateway.requestPermission();
      if (escalated == LocationPermission.always) permission = escalated;
    }
    if (!_alive(generation)) return;
    state = state.copyWith(
      permission: permission,
      permissionRefused: permission != LocationPermission.always,
      now: _now(),
    );
    _reconcile();
  }

  /// Sends the agent to the system settings page for this app. Returning from
  /// it resumes the app, and [handleLifecycle] re-checks what they chose.
  Future<void> openSettings() async {
    await ref.read(backgroundLocationGatewayProvider)?.openAppSettings();
  }

  /// The notification's words, in the agent's language.
  ///
  /// Pushed in from the banner, which is the only place with a `BuildContext`
  /// and therefore the only place that can localise them. A change does not
  /// restart a running service: the notification is built when the service
  /// starts, and dropping an agent's tracking mid-shift to restyle a string
  /// would be a worse trade than a stale word until the window next opens.
  void setNotificationText(BackgroundNotificationText text) {
    _notification = text;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Wired to [AppLifecycleListener]; public so tests can drive it directly.
  ///
  /// Note what this does NOT do: leaving the foreground does not stop tracking.
  /// That is the difference between T1 and T2, and it is what the notice says.
  @visibleForTesting
  void handleLifecycle(AppLifecycleState lifecycle) {
    if (!state.supported || lifecycle != AppLifecycleState.resumed) return;
    // They may have come back from the settings page having just granted
    // "Allow all the time", and the working window may have opened or shut
    // while the app was away.
    unawaited(_refreshPermission());
    unawaited(ref.read(locationSharingControllerProvider.notifier).refresh());
  }

  Future<void> _refreshPermission() async {
    final gateway = ref.read(backgroundLocationGatewayProvider);
    if (gateway == null) return;
    final generation = _generation;
    final permission = await gateway.checkPermission();
    if (!_alive(generation)) return;
    state = state.copyWith(permission: permission, now: _now());
    _reconcile();
  }

  // ── Running ────────────────────────────────────────────────────────────────

  /// Starts or stops the service to match the state, and arms the timer for the
  /// next edge of the working window.
  void _reconcile() {
    if (_disposed) return;
    _scheduleWindowTimer();
    final shouldRun =
        state.supported &&
        state.accepted &&
        state.permitted &&
        state.windowOpen &&
        _userId != null &&
        currentLocalUserId == _userId;
    if (shouldRun) {
      _startStream();
    } else {
      _stopStream();
    }
  }

  void _startStream() {
    if (_subscription != null) return;
    final gateway = ref.read(backgroundLocationGatewayProvider);
    final settings = state.settings;
    if (gateway == null || settings == null) return;
    final generation = _generation;
    _subscription = gateway
        .positions(interval: settings.interval, notification: _notification)
        .listen(
          (fix) => unawaited(_record(fix, generation)),
          // A stream that errors is a missed ping, never a crash. Android drops
          // it when location services are switched off mid-shift.
          onError: (Object _) {},
          cancelOnError: false,
        );
    state = state.copyWith(running: true);
  }

  void _stopStream() {
    final subscription = _subscription;
    _subscription = null;
    // Cancelling is what tears down the foreground service and removes its
    // notification — so the notification's presence is always the truth about
    // whether anything is being collected.
    unawaited(subscription?.cancel());
    if (!_disposed && state.running) state = state.copyWith(running: false);
  }

  void _scheduleWindowTimer() {
    _windowTimer?.cancel();
    _windowTimer = null;
    final settings = state.settings;
    if (settings == null) return;
    final edge = state.windowOpen
        ? settings.windowClosesAt
        : settings.windowOpensAt;
    if (edge == null) return;
    final wait = edge.difference(_now());
    // A minute past the edge, and then ASK rather than decide: the server owns
    // the window, so the app re-reads the settings and lets the answer come
    // back. That also keeps a phone whose clock is adrift from starting the day
    // early — it would only fetch settings that still say the window is shut.
    final delay = wait.isNegative
        ? const Duration(minutes: 1)
        : wait + const Duration(minutes: 1);
    _windowTimer = Timer(delay, () {
      unawaited(ref.read(locationSharingControllerProvider.notifier).refresh());
    });
  }

  Future<void> _record(BackgroundFix fix, Object generation) async {
    if (!_alive(generation)) return;
    final userId = _userId;
    if (userId == null || currentLocalUserId != userId) return;

    // The window can close between two fixes. Checking here as well as on the
    // timer means the last fix of the day is dropped rather than queued, and
    // the server would ignore it anyway.
    state = state.copyWith(now: _now());
    if (!state.windowOpen) {
      _reconcile();
      return;
    }

    final settings = state.settings;
    if (settings == null) return;

    // The FIX time, not now: a background fix can be minutes old by delivery,
    // and the server orders and ages everything by this. Millisecond precision,
    // matching what the server stores, so a redelivered fix is the same ping.
    final at = (fix.fixedAt ?? _now()).toUtc();
    final recordedAt = DateTime.fromMillisecondsSinceEpoch(
      at.millisecondsSinceEpoch,
      isUtc: true,
    );
    final last = _lastRecordedAt;
    if (last != null) {
      if (!recordedAt.isAfter(last)) return;
      // Android may deliver more often than asked when a fix is cheaply to
      // hand. Taking those is free accuracy on a moving agent, but a floor of
      // half the interval keeps a chatty platform from turning ~60 points a day
      // into several hundred queued rows.
      if (recordedAt.difference(last) < settings.minimumGap) return;
    }
    _lastRecordedAt = recordedAt;

    await ref
        .read(localDbProvider)
        .enqueue(
          entityType: locationBackgroundPingEntity,
          entityId: recordedAt.toIso8601String(),
          payloadJson: jsonEncode({
            'lat': fix.lat,
            'lng': fix.lng,
            'accuracyM': fix.accuracyM,
            'recordedAt': recordedAt.toIso8601String(),
          }),
        );
    if (!_alive(generation)) return;
    state = state.copyWith(lastPingAt: _now());
    unawaited(_flush());
  }

  Future<void> _flush() async {
    try {
      await ref.read(syncServiceProvider).flushLocationQueue();
    } catch (_) {
      // Recorded on the rows; the next fix tries again.
    }
  }
}

final backgroundLocationControllerProvider =
    NotifierProvider<BackgroundLocationController, BackgroundLocationState>(
      BackgroundLocationController.new,
    );

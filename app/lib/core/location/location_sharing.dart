import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/session_controller.dart';
import '../network/api_client.dart' as api_client;
import '../storage/local_db.dart';
import '../storage/secure_storage.dart';
import '../sync/sync_service.dart';
import 'location_service.dart';

/// Foreground location sharing — the agent side of #153 T1.
///
/// While the app is open, the agent is signed in, and they have acknowledged
/// the location notice, a timer takes a location fix every server-set interval
/// and queues it in the offline outbox. Nothing runs in the background: the
/// timer stops the moment the app leaves the foreground, and T2 (background
/// tracking) is a separate, POPIA-gated decision this code does not make.

/// The agent's answer to the location notice.
enum LocationConsent { acknowledged, declined }

class LocationDecision {
  const LocationDecision({
    required this.consent,
    required this.noticeVersion,
    required this.decidedAt,
  });

  final LocationConsent consent;
  final String noticeVersion;
  final DateTime decidedAt;

  Map<String, dynamic> toJson() => {
    'decision': consent == LocationConsent.acknowledged
        ? 'acknowledged'
        : 'declined',
    'noticeVersion': noticeVersion,
    'decidedAt': decidedAt.toUtc().toIso8601String(),
  };

  static LocationDecision? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final consent = switch (json['decision']) {
      'acknowledged' => LocationConsent.acknowledged,
      'declined' => LocationConsent.declined,
      _ => null,
    };
    final version = json['noticeVersion'];
    final decidedAt = DateTime.tryParse('${json['decidedAt']}');
    if (consent == null || version is! String || decidedAt == null) return null;
    return LocationDecision(
      consent: consent,
      noticeVersion: version,
      decidedAt: decidedAt,
    );
  }
}

/// GET /locations/settings, as the app uses it.
class LocationSettings {
  const LocationSettings({
    required this.intervalSeconds,
    required this.noticeVersion,
    this.decision,
  });

  final int intervalSeconds;
  final String noticeVersion;

  /// The agent's answer to THIS notice version; null when unanswered.
  final LocationDecision? decision;

  LocationSettings withDecision(LocationDecision? next) => LocationSettings(
    intervalSeconds: intervalSeconds,
    noticeVersion: noticeVersion,
    decision: next,
  );

  factory LocationSettings.fromJson(Map<String, dynamic> json) {
    final version = json['noticeVersion'] as String;
    final decision = LocationDecision.fromJson(json['consent']);
    return LocationSettings(
      intervalSeconds: (json['intervalSeconds'] as num).round(),
      noticeVersion: version,
      decision: decision?.noticeVersion == version ? decision : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'intervalSeconds': intervalSeconds,
    'noticeVersion': noticeVersion,
    'consent': decision?.toJson(),
  };
}

abstract class LocationSharingRepository {
  Future<LocationSettings> fetchSettings();
}

class DioLocationSharingRepository implements LocationSharingRepository {
  @override
  Future<LocationSettings> fetchSettings() async {
    final res = await api_client.dio.get<Map<String, dynamic>>(
      '/locations/settings',
    );
    return LocationSettings.fromJson(res.data ?? const {});
  }
}

final locationSharingRepositoryProvider = Provider<LocationSharingRepository>(
  (ref) => DioLocationSharingRepository(),
);

/// The last settings this agent saw, so a restart with no signal still knows
/// the interval and their answer. Per user: a shared phone must not carry one
/// agent's answer over to the next.
abstract class LocationSharingStore {
  Future<LocationSettings?> read(String userId);
  Future<void> write(String userId, LocationSettings settings);
}

class SecureLocationSharingStore implements LocationSharingStore {
  SecureLocationSharingStore({FlutterSecureStorage? storage})
    : _storage = storage ?? appSecureStorage;

  final FlutterSecureStorage _storage;

  String _key(String userId) => 'tiq.locationSharing.$userId';

  @override
  Future<LocationSettings?> read(String userId) async {
    try {
      final raw = await _storage.read(key: _key(userId));
      if (raw == null) return null;
      return LocationSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // unreadable → ask the server, never crash
    }
  }

  @override
  Future<void> write(String userId, LocationSettings settings) async {
    try {
      await _storage.write(
        key: _key(userId),
        value: jsonEncode(settings.toJson()),
      );
    } catch (_) {
      // Best-effort: the in-memory state still applies for this run.
    }
  }
}

final locationSharingStoreProvider = Provider<LocationSharingStore>(
  (ref) => SecureLocationSharingStore(),
);

/// The clock the heartbeat stamps decisions with, injectable for tests.
final locationClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The shortest interval the app will run, whatever it is told. Mirrors the
/// server clamp; a bad value must not be able to drain a phone (risk 5).
const minPingInterval = Duration(seconds: 60);

class LocationSharingState {
  const LocationSharingState({
    this.isAgent = false,
    this.settings,
    this.foreground = true,
    this.running = false,
    this.lastPingAt,
    this.noFix = false,
    this.reconsidering = false,
  });

  /// A field agent is signed in. Nothing below applies to anyone else.
  final bool isAgent;

  /// Null until the server (or the cached copy) has answered.
  final LocationSettings? settings;

  /// The app is in the foreground (`AppLifecycleState.resumed`).
  final bool foreground;

  /// The heartbeat timer is running — the one thing the indicator reports.
  final bool running;

  /// When the last ping was queued.
  final DateTime? lastPingAt;

  /// The last attempt got no fix: permission off, GPS off, no signal. Not an
  /// error — sharing is still on, the phone just is not giving a position.
  final bool noFix;

  /// The agent who declined tapped to change their mind; show the notice again.
  final bool reconsidering;

  LocationConsent? get consent => settings?.decision?.consent;

  /// The notice must be answered before anything is sent.
  bool get needsNotice => isAgent && settings != null && consent == null;

  bool get acknowledged => consent == LocationConsent.acknowledged;

  Duration get interval {
    final seconds = settings?.intervalSeconds ?? minPingInterval.inSeconds;
    final d = Duration(seconds: seconds);
    return d < minPingInterval ? minPingInterval : d;
  }

  LocationSharingState copyWith({
    LocationSettings? settings,
    bool? foreground,
    bool? running,
    DateTime? lastPingAt,
    bool? noFix,
    bool? reconsidering,
  }) => LocationSharingState(
    isAgent: isAgent,
    settings: settings ?? this.settings,
    foreground: foreground ?? this.foreground,
    running: running ?? this.running,
    lastPingAt: lastPingAt ?? this.lastPingAt,
    noFix: noFix ?? this.noFix,
    reconsidering: reconsidering ?? this.reconsidering,
  );
}

/// Owns the heartbeat's whole lifecycle.
///
/// - **Gated on the notice.** No timer exists until the agent has
///   acknowledged the current notice version.
/// - **Foreground only.** Listens to the app lifecycle; anything other than
///   `resumed` stops the timer, and `resumed` starts it again.
/// - **Stops on logout.** It watches the session, so signing out rebuilds it
///   into the inert non-agent state, and the rebuild cancels the timer.
/// - **No new permission flows.** It uses [LocationService.getPositionIfPermitted],
///   which never raises a prompt; a refusal simply means no ping.
/// - **Offline-first.** Pings and answers go into the outbox, so an agent in a
///   dead zone keeps a queue that flushes in batches when signal returns.
class LocationSharingController extends Notifier<LocationSharingState> {
  Timer? _timer;
  Duration? _timerInterval;
  AppLifecycleListener? _lifecycle;
  Object _generation = Object();
  bool _disposed = false;
  bool _ticking = false;
  String? _userId;
  DateTime? _lastRecordedAt;

  @override
  LocationSharingState build() {
    final role = ref.watch(sessionControllerProvider).value?.role;
    final generation = Object();
    _generation = generation;
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _stopTimer();
      _lifecycle?.dispose();
      _lifecycle = null;
    });

    if (role != 'field_agent') {
      _userId = null;
      return const LocationSharingState();
    }

    _userId = currentLocalUserId;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _lifecycle = AppLifecycleListener(onStateChange: handleLifecycle);
    Future.microtask(() => _load(generation));
    return LocationSharingState(
      isAgent: true,
      foreground: lifecycle == null || lifecycle == AppLifecycleState.resumed,
    );
  }

  bool _alive(Object generation) =>
      !_disposed && identical(generation, _generation);

  /// Cached settings first (a restart in a dead zone), then the server's.
  Future<void> _load(Object generation) async {
    final userId = _userId;
    if (userId == null) return;
    final store = ref.read(locationSharingStoreProvider);
    final cached = await store.read(userId);
    if (!_alive(generation)) return;
    if (cached != null && state.settings == null) _apply(cached);

    try {
      final remote = await ref
          .read(locationSharingRepositoryProvider)
          .fetchSettings();
      if (!_alive(generation)) return;
      final merged = _merge(remote, state.settings);
      _apply(merged);
      await store.write(userId, merged);
    } catch (_) {
      // Offline, or the server is unreachable: whatever was cached stands.
    }
  }

  /// The server's settings, except that an answer made on this phone which the
  /// server has not heard yet (it is still in the outbox) is not overwritten by
  /// the server's older view.
  LocationSettings _merge(LocationSettings remote, LocationSettings? local) {
    final mine = local?.decision;
    final theirs = remote.decision;
    final keepMine =
        mine != null &&
        mine.noticeVersion == remote.noticeVersion &&
        (theirs == null || mine.decidedAt.isAfter(theirs.decidedAt));
    return keepMine ? remote.withDecision(mine) : remote;
  }

  void _apply(LocationSettings settings) {
    state = state.copyWith(settings: settings);
    _reconcile();
  }

  /// Starts, restarts or stops the timer to match the state.
  void _reconcile() {
    final shouldRun =
        state.isAgent &&
        state.acknowledged &&
        state.foreground &&
        _userId != null &&
        currentLocalUserId == _userId;
    if (!shouldRun) {
      if (_timer != null || state.running) {
        _stopTimer();
        state = state.copyWith(running: false);
      }
      return;
    }
    final interval = state.interval;
    if (_timer != null && _timerInterval == interval) return;
    _stopTimer();
    _timerInterval = interval;
    _timer = Timer.periodic(interval, (_) => _tick());
    state = state.copyWith(running: true);
    // Resuming after a short trip to another app should not fire a burst.
    final last = state.lastPingAt;
    final now = ref.read(locationClockProvider)();
    if (last == null || now.difference(last) >= interval) unawaited(_tick());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _timerInterval = null;
  }

  Future<void> _tick() async {
    if (_ticking) return;
    final generation = _generation;
    final userId = _userId;
    _ticking = true;
    try {
      final fix = await ref
          .read(locationServiceProvider)
          .getPositionIfPermitted();
      if (!_alive(generation) || !state.running) return;
      if (userId == null || currentLocalUserId != userId) return;
      if (fix is! LocationGranted) {
        if (!state.noFix) state = state.copyWith(noFix: true);
        return;
      }
      // The FIX time, not now: a cached fix can be minutes old, and the server
      // orders and ages everything by this. Millisecond precision, matching
      // what the server stores, so a re-read of the same cached fix is the
      // same ping.
      final at = (fix.fixedAt ?? ref.read(locationClockProvider)()).toUtc();
      final recordedAt = DateTime.fromMillisecondsSinceEpoch(
        at.millisecondsSinceEpoch,
        isUtc: true,
      );
      if (recordedAt == _lastRecordedAt) return;
      _lastRecordedAt = recordedAt;

      await ref
          .read(localDbProvider)
          .enqueue(
            entityType: locationPingEntity,
            entityId: recordedAt.toIso8601String(),
            payloadJson: jsonEncode({
              'lat': fix.lat,
              'lng': fix.lng,
              'accuracyM': fix.accuracy,
              'recordedAt': recordedAt.toIso8601String(),
            }),
          );
      if (!_alive(generation)) return;
      state = state.copyWith(
        lastPingAt: ref.read(locationClockProvider)(),
        noFix: false,
      );
      unawaited(_flush());
    } catch (_) {
      // A failed tick is a missed ping, never a crash.
    } finally {
      _ticking = false;
    }
  }

  Future<void> _flush() async {
    try {
      await ref.read(syncServiceProvider).flushLocationQueue();
    } catch (_) {
      // Recorded on the rows; the next tick tries again.
    }
  }

  /// Wired to [AppLifecycleListener]; public so tests can drive it directly.
  @visibleForTesting
  void handleLifecycle(AppLifecycleState lifecycle) {
    if (!state.isAgent) return;
    final foreground = lifecycle == AppLifecycleState.resumed;
    if (foreground == state.foreground) return;
    state = state.copyWith(foreground: foreground);
    _reconcile();
    // Back in the foreground: the interval or the notice may have changed.
    if (foreground) unawaited(_load(_generation));
  }

  /// "I understand, share my location."
  Future<void> acknowledge() => _decide(LocationConsent.acknowledged);

  /// "Don't share" — or "Stop sharing" from the indicator.
  Future<void> decline() => _decide(LocationConsent.declined);

  /// Shows the notice again to an agent who declined.
  void reconsider() {
    if (state.consent == LocationConsent.declined) {
      state = state.copyWith(reconsidering: true);
    }
  }

  void cancelReconsider() => state = state.copyWith(reconsidering: false);

  Future<void> _decide(LocationConsent consent) async {
    final settings = state.settings;
    final userId = _userId;
    if (settings == null || userId == null || currentLocalUserId != userId) {
      return;
    }
    final generation = _generation;
    final decision = LocationDecision(
      consent: consent,
      noticeVersion: settings.noticeVersion,
      decidedAt: ref.read(locationClockProvider)(),
    );
    final db = ref.read(localDbProvider);
    if (consent == LocationConsent.declined) {
      // Pings still waiting to send were taken while they had agreed, but they
      // have just said stop — so they never leave the phone.
      await (db.delete(db.syncQueueItems)..where(
            (t) =>
                t.entityType.equals(locationPingEntity) &
                t.synced.equals(false) &
                t.userId.equals(userId),
          ))
          .go();
    }
    await db.enqueue(
      entityType: locationConsentEntity,
      entityId: decision.decidedAt.toUtc().toIso8601String(),
      payloadJson: jsonEncode(decision.toJson()),
    );
    if (!_alive(generation)) return;
    final next = settings.withDecision(decision);
    state = state.copyWith(settings: next, reconsidering: false, noFix: false);
    _reconcile();
    await ref.read(locationSharingStoreProvider).write(userId, next);
    unawaited(_flush());
  }
}

final locationSharingControllerProvider =
    NotifierProvider<LocationSharingController, LocationSharingState>(
      LocationSharingController.new,
    );

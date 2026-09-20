import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/location/location_service.dart';
import 'package:tradeiq_app/core/location/location_sharing.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';

/// #153 T1 — the foreground heartbeat: gated on the notice, foreground only,
/// stopped by logout, and queued through the outbox.
class _Session extends SessionController {
  _Session(this.role);
  final String? role;

  @override
  Future<SessionState> build() async =>
      SessionState(role: role, token: role == null ? null : 'token');

  void signOut() => state = const AsyncData(SessionState());
}

class _Repo implements LocationSharingRepository {
  _Repo(this.settings);
  LocationSettings settings;
  int calls = 0;

  @override
  Future<LocationSettings> fetchSettings() async {
    calls++;
    return settings;
  }
}

class _Store implements LocationSharingStore {
  final Map<String, LocationSettings> saved = {};

  @override
  Future<LocationSettings?> read(String userId) async => saved[userId];

  @override
  Future<void> write(String userId, LocationSettings settings) async =>
      saved[userId] = settings;
}

class _Location extends LocationService {
  _Location();
  int calls = 0;
  bool permitted = true;

  @override
  Future<LocationResult> getPositionIfPermitted() async {
    calls++;
    if (!permitted) return LocationDenied();
    return LocationGranted(
      -26.1,
      28.05,
      accuracy: 9,
      // A distinct fix each time, as a moving phone would give.
      fixedAt: DateTime.utc(2026, 9, 15, 8).add(Duration(minutes: calls)),
    );
  }
}

class _NoopFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async {}
}

LocationSettings _settings({LocationConsent? consent, int interval = 120}) =>
    LocationSettings(
      intervalSeconds: interval,
      noticeVersion: 'v1',
      decision: consent == null
          ? null
          : LocationDecision(
              consent: consent,
              noticeVersion: 'v1',
              decidedAt: DateTime.utc(2026, 9, 15, 7),
            ),
    );

class _Harness {
  _Harness(
    this.container,
    this.db,
    this.repo,
    this.store,
    this.location,
    this.clock,
  );
  final ProviderContainer container;
  final LocalDb db;
  final _Repo repo;
  final _Store store;
  final _Location location;
  final _Clock clock;

  LocationSharingState get state =>
      container.read(locationSharingControllerProvider);
  LocationSharingController get controller =>
      container.read(locationSharingControllerProvider.notifier);

  Future<List<SyncQueueItem>> rows(WidgetTester tester, String type) async =>
      (await tester.runAsync(
        () => (db.select(
          db.syncQueueItems,
        )..where((t) => t.entityType.equals(type))).get(),
      ))!;
}

class _Clock {
  DateTime now = DateTime(2026, 9, 15, 10);
}

Future<_Harness> _start(
  WidgetTester tester, {
  required LocationSettings settings,
  String? role = 'field_agent',
  _Store? store,
}) async {
  final db = LocalDb(NativeDatabase.memory());
  final repo = _Repo(settings);
  final theStore = store ?? _Store();
  final location = _Location();
  final clock = _Clock();
  final container = ProviderContainer(
    overrides: [
      sessionControllerProvider.overrideWith(() => _Session(role)),
      locationSharingRepositoryProvider.overrideWithValue(repo),
      locationSharingStoreProvider.overrideWithValue(theStore),
      locationServiceProvider.overrideWithValue(location),
      locationClockProvider.overrideWithValue(() => clock.now),
      localDbProvider.overrideWithValue(db),
      // No ping sender: pings stay in the outbox where the tests can see them.
      syncServiceProvider.overrideWithValue(
        SyncService(db: db, flusher: _NoopFlusher()),
      ),
    ],
  );
  addTearDown(() async {
    // Normally disposed at the end of the test body (see _heartbeatTest);
    // this only catches a test that failed before getting there.
    if (identical(_container, container)) {
      container.dispose();
      _container = null;
    }
    await tester.runAsync(db.close);
  });
  container.listen(locationSharingControllerProvider, (_, _) {});
  _container = container;
  await _settle(tester);
  return _Harness(container, db, repo, theStore, location, clock);
}

ProviderContainer? _container;

/// A heartbeat test. Disposes the container — and with it the heartbeat's
/// periodic timer — at the end of the body, because the test framework checks
/// for pending timers before any tearDown runs.
void _heartbeatTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    await body(tester);
    _container?.dispose();
    _container = null;
    await tester.pump();
  });
}

Future<void> _lifecycle(
  WidgetTester tester,
  List<AppLifecycleState> steps,
) async {
  for (final step in steps) {
    tester.binding.handleAppLifecycleStateChanged(step);
  }
  await _settle(tester);
}

/// Lets the session build, the settings load and any queued writes land.
///
/// Reads the controller between pumps, as the banner on every agent screen
/// does each frame: under the test clock, Riverpod applies a pending rebuild
/// when the provider is next read.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    _container?.read(locationSharingControllerProvider);
    await tester.pump();
    _container?.read(locationSharingControllerProvider);
    await tester.pump();
    // The in-memory database answers on the real event loop.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  await tester.pump();
}

void main() {
  setUp(() => currentLocalUserId = 'agent-1');
  tearDown(() => currentLocalUserId = null);

  _heartbeatTest(
    'the notice gates pings: nothing is sent until the agent acknowledges',
    (tester) async {
      final h = await _start(tester, settings: _settings());

      expect(h.state.isAgent, isTrue);
      expect(h.state.needsNotice, isTrue);
      expect(h.state.running, isFalse);

      await tester.pump(const Duration(minutes: 10));
      await _settle(tester);
      expect(h.location.calls, 0);
      expect(await h.rows(tester, locationPingEntity), isEmpty);

      await tester.runAsync(h.controller.acknowledge);
      await _settle(tester);

      expect(h.state.acknowledged, isTrue);
      expect(h.state.running, isTrue);
      final answers = await h.rows(tester, locationConsentEntity);
      expect(answers, hasLength(1));
      expect(jsonDecode(answers.single.payloadJson), {
        'decision': 'acknowledged',
        'noticeVersion': 'v1',
        'decidedAt': h.clock.now.toUtc().toIso8601String(),
      });
      expect(
        h.store.saved['agent-1']?.decision?.consent,
        LocationConsent.acknowledged,
      );
      // The first ping goes straight away, then one per interval.
      expect(await h.rows(tester, locationPingEntity), hasLength(1));
    },
  );

  _heartbeatTest('queues one ping per server-set interval through the outbox', (
    tester,
  ) async {
    final h = await _start(
      tester,
      settings: _settings(consent: LocationConsent.acknowledged, interval: 300),
    );
    expect(h.state.running, isTrue);
    expect(await h.rows(tester, locationPingEntity), hasLength(1));

    await tester.pump(const Duration(minutes: 2));
    await _settle(tester);
    expect(await h.rows(tester, locationPingEntity), hasLength(1));

    await tester.pump(const Duration(minutes: 3));
    await _settle(tester);
    final pings = await h.rows(tester, locationPingEntity);
    expect(pings, hasLength(2));
    expect(pings.every((p) => p.userId == 'agent-1' && !p.synced), isTrue);
    final payload = jsonDecode(pings.last.payloadJson) as Map<String, dynamic>;
    expect(payload, {
      'lat': -26.1,
      'lng': 28.05,
      'accuracyM': 9.0,
      'recordedAt': '2026-09-15T08:02:00.000Z',
    });
  });

  _heartbeatTest('pauses in the background and resumes in the foreground', (
    tester,
  ) async {
    final h = await _start(
      tester,
      settings: _settings(consent: LocationConsent.acknowledged),
    );
    expect(h.state.running, isTrue);
    expect(h.location.calls, 1);

    // Through the states the platform really passes, in order.
    await _lifecycle(tester, [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    expect(h.state.foreground, isFalse);
    expect(h.state.running, isFalse);

    await tester.pump(const Duration(minutes: 20));
    await _settle(tester);
    expect(h.location.calls, 1, reason: 'no fix is taken in the background');

    h.clock.now = h.clock.now.add(const Duration(minutes: 20));
    await _lifecycle(tester, [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    expect(h.state.running, isTrue);
    expect(h.location.calls, 2);
    expect(h.repo.calls, 2, reason: 'settings are re-read on return');
  });

  _heartbeatTest('stops on logout', (tester) async {
    final h = await _start(
      tester,
      settings: _settings(consent: LocationConsent.acknowledged),
    );
    expect(h.state.running, isTrue);
    final before = h.location.calls;

    (h.container.read(sessionControllerProvider.notifier) as _Session)
        .signOut();
    currentLocalUserId = null;
    await _settle(tester);

    expect(h.state.isAgent, isFalse);
    expect(h.state.running, isFalse);
    await tester.pump(const Duration(minutes: 30));
    await _settle(tester);
    expect(h.location.calls, before);
  });

  _heartbeatTest(
    'a refused or missing location is not an error: nothing queues, noFix is set',
    (tester) async {
      final h = await _start(
        tester,
        settings: _settings(consent: LocationConsent.acknowledged),
      );
      expect(await h.rows(tester, locationPingEntity), hasLength(1));

      h.location.permitted = false;
      await tester.pump(const Duration(minutes: 2));
      await _settle(tester);

      expect(h.state.running, isTrue);
      expect(h.state.noFix, isTrue);
      expect(await h.rows(tester, locationPingEntity), hasLength(1));
    },
  );

  _heartbeatTest(
    'declining stops the timer and drops pings that had not sent',
    (tester) async {
      final h = await _start(
        tester,
        settings: _settings(consent: LocationConsent.acknowledged),
      );
      expect(await h.rows(tester, locationPingEntity), hasLength(1));

      await tester.runAsync(h.controller.decline);
      await _settle(tester);

      expect(h.state.running, isFalse);
      expect(h.state.consent, LocationConsent.declined);
      expect(await h.rows(tester, locationPingEntity), isEmpty);
      final answer = (await h.rows(tester, locationConsentEntity)).single;
      expect(jsonDecode(answer.payloadJson)['decision'], 'declined');

      h.controller.reconsider();
      expect(h.state.reconsidering, isTrue);
    },
  );

  _heartbeatTest(
    'an answer given offline is kept over a server that has not heard it yet',
    (tester) async {
      final store = _Store()
        ..saved['agent-1'] = _settings(consent: LocationConsent.acknowledged);
      final h = await _start(tester, settings: _settings(), store: store);
      expect(h.state.acknowledged, isTrue);
      expect(h.state.running, isTrue);
    },
  );

  _heartbeatTest('does nothing at all for a manager', (tester) async {
    final h = await _start(
      tester,
      settings: _settings(consent: LocationConsent.acknowledged),
      role: 'manager',
    );
    expect(h.state.isAgent, isFalse);
    expect(h.repo.calls, 0);
    await tester.pump(const Duration(minutes: 10));
    expect(h.location.calls, 0);
  });
}

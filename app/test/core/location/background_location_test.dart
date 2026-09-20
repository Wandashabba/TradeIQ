import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// Only the permission enum. Geolocator exports a `LocationSettings` of its own,
// which would otherwise clash with the app's settings model below.
import 'package:geolocator/geolocator.dart' show LocationPermission;
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/location/background_location.dart';
import 'package:tradeiq_app/core/location/location_service.dart';
import 'package:tradeiq_app/core/location/location_sharing.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';

/// #153 T2 — background tracking between stores.
///
/// Four gates, and the tests are mostly about what does NOT happen when one of
/// them is shut: its own notice, Android's background permission, the client's
/// working hours, and an Android device at all.

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

/// The heartbeat's location source. Never used by these tests — the foreground
/// notice is left unanswered so the heartbeat stays out of the way — but the
/// provider has to resolve to something that will not touch a platform channel.
class _Location extends LocationService {
  @override
  Future<LocationResult> getPositionIfPermitted() async => LocationDenied();
}

class _NoopFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async {}
}

class _Clock {
  DateTime now = DateTime.utc(2026, 9, 17, 9);
}

/// A fake Android. Counts starts and cancellations, so a test can prove the
/// foreground service was actually torn down rather than merely marked stopped.
class _Gateway implements BackgroundLocationGateway {
  _Gateway({this.permission = LocationPermission.always});

  LocationPermission permission;
  int permissionRequests = 0;
  int settingsOpened = 0;
  int starts = 0;
  int cancels = 0;
  BackgroundNotificationText? notification;
  Duration? interval;

  final _fixes = StreamController<BackgroundFix>.broadcast();

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<bool> openAppSettings() async {
    settingsOpened++;
    return true;
  }

  @override
  Stream<BackgroundFix> positions({
    required Duration interval,
    required BackgroundNotificationText notification,
  }) {
    this.interval = interval;
    this.notification = notification;
    starts++;
    late StreamController<BackgroundFix> controller;
    StreamSubscription<BackgroundFix>? inner;
    controller = StreamController<BackgroundFix>(
      onListen: () => inner = _fixes.stream.listen(controller.add),
      onCancel: () async {
        cancels++;
        await inner?.cancel();
      },
    );
    return controller.stream;
  }

  void emit(BackgroundFix fix) => _fixes.add(fix);

  Future<void> close() => _fixes.close();
}

LocationDecision _decision(LocationConsent consent, String version) =>
    LocationDecision(
      consent: consent,
      noticeVersion: version,
      decidedAt: DateTime.utc(2026, 9, 17, 6),
    );

LocationSettings _settings({
  LocationConsent? background,
  LocationConsent? foreground,
  bool withinWorkingHours = true,
  DateTime? closesAt,
  DateTime? opensAt,
  int intervalSeconds = 600,
  bool withBackgroundBlock = true,
}) => LocationSettings(
  intervalSeconds: 120,
  noticeVersion: 'fg-v1',
  decision: foreground == null ? null : _decision(foreground, 'fg-v1'),
  background: !withBackgroundBlock
      ? null
      : BackgroundSettings(
          intervalSeconds: intervalSeconds,
          noticeVersion: 'bg-v1',
          workingHours: WorkingHours.fallback,
          withinWorkingHours: withinWorkingHours,
          decision: background == null ? null : _decision(background, 'bg-v1'),
          windowClosesAt: closesAt,
          windowOpensAt: opensAt,
        ),
);

class _Harness {
  _Harness(this.container, this.db, this.repo, this.gateway, this.clock);

  final ProviderContainer container;
  final LocalDb db;
  final _Repo repo;
  final _Gateway gateway;
  final _Clock clock;

  BackgroundLocationState get state =>
      container.read(backgroundLocationControllerProvider);

  BackgroundLocationController get controller =>
      container.read(backgroundLocationControllerProvider.notifier);

  LocationSharingState get sharing =>
      container.read(locationSharingControllerProvider);

  Future<List<SyncQueueItem>> rows(WidgetTester tester, String type) async =>
      (await tester.runAsync(
        () => (db.select(
          db.syncQueueItems,
        )..where((t) => t.entityType.equals(type))).get(),
      ))!;
}

ProviderContainer? _container;

Future<_Harness> _start(
  WidgetTester tester, {
  required LocationSettings settings,
  String? role = 'field_agent',
  _Gateway? gateway,
  bool android = true,
}) async {
  final db = LocalDb(NativeDatabase.memory());
  final repo = _Repo(settings);
  final theGateway = gateway ?? _Gateway();
  final clock = _Clock();
  final container = ProviderContainer(
    overrides: [
      sessionControllerProvider.overrideWith(() => _Session(role)),
      locationSharingRepositoryProvider.overrideWithValue(repo),
      locationSharingStoreProvider.overrideWithValue(_Store()),
      locationServiceProvider.overrideWithValue(_Location()),
      locationClockProvider.overrideWithValue(() => clock.now),
      localDbProvider.overrideWithValue(db),
      // Null is how "this is not an Android phone" is expressed.
      backgroundLocationGatewayProvider.overrideWithValue(
        android ? theGateway : null,
      ),
      syncServiceProvider.overrideWithValue(
        SyncService(db: db, flusher: _NoopFlusher()),
      ),
    ],
  );
  addTearDown(() async {
    if (identical(_container, container)) {
      container.dispose();
      _container = null;
    }
    await theGateway.close();
    await tester.runAsync(db.close);
  });
  container.listen(locationSharingControllerProvider, (_, _) {});
  container.listen(backgroundLocationControllerProvider, (_, _) {});
  _container = container;
  await _settle(tester);
  return _Harness(container, db, repo, theGateway, clock);
}

/// Disposes the container — and with it any pending window timer — inside the
/// test body, because the framework checks for live timers before tearDown.
void _trackingTest(
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

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    _container?.read(locationSharingControllerProvider);
    _container?.read(backgroundLocationControllerProvider);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  await tester.pump();
}

void main() {
  setUp(() => currentLocalUserId = 'agent-1');
  tearDown(() => currentLocalUserId = null);

  final closesAt = DateTime.utc(2026, 9, 17, 15);
  final opensAt = DateTime.utc(2026, 9, 18, 5);

  BackgroundFix fixAt(DateTime at) =>
      BackgroundFix(lat: -26.1, lng: 28.05, accuracyM: 14, fixedAt: at);

  group('nothing runs until every gate is open', () {
    _trackingTest(
      'before the background notice is accepted, nothing is collected',
      (tester) async {
        final h = await _start(tester, settings: _settings(closesAt: closesAt));

        expect(h.state.supported, isTrue);
        expect(h.state.unanswered, isTrue);
        expect(h.state.step, BackgroundTrackingStep.off);
        expect(h.state.running, isFalse);
        // No service, so no notification and no permission prompt either — the
        // agent has not been told what it is for yet.
        expect(h.gateway.starts, 0);
        expect(h.gateway.permissionRequests, 0);

        h.gateway.emit(fixAt(DateTime.utc(2026, 9, 17, 9, 30)));
        await _settle(tester);
        expect(await h.rows(tester, locationBackgroundPingEntity), isEmpty);
      },
    );

    _trackingTest('a decline keeps it off', (tester) async {
      final h = await _start(
        tester,
        settings: _settings(
          background: LocationConsent.declined,
          closesAt: closesAt,
        ),
      );
      expect(h.state.step, BackgroundTrackingStep.off);
      expect(h.gateway.starts, 0);
    });

    _trackingTest('outside working hours, nothing is collected', (
      tester,
    ) async {
      final h = await _start(
        tester,
        settings: _settings(
          background: LocationConsent.acknowledged,
          withinWorkingHours: false,
          opensAt: opensAt,
        ),
      );

      expect(h.state.accepted, isTrue);
      expect(h.state.permitted, isTrue);
      expect(h.state.step, BackgroundTrackingStep.outsideHours);
      expect(h.state.running, isFalse);
      expect(h.gateway.starts, 0);

      h.gateway.emit(fixAt(DateTime.utc(2026, 9, 17, 22)));
      await _settle(tester);
      expect(await h.rows(tester, locationBackgroundPingEntity), isEmpty);
    });

    _trackingTest(
      'without Android’s background permission, nothing is collected',
      (tester) async {
        final h = await _start(
          tester,
          settings: _settings(
            background: LocationConsent.acknowledged,
            closesAt: closesAt,
          ),
          gateway: _Gateway(permission: LocationPermission.whileInUse),
        );

        expect(h.state.permitted, isFalse);
        expect(h.state.step, BackgroundTrackingStep.needsPermission);
        expect(h.state.running, isFalse);
        expect(h.gateway.starts, 0);
      },
    );

    _trackingTest('on anything but Android it is inert', (tester) async {
      final h = await _start(
        tester,
        settings: _settings(
          background: LocationConsent.acknowledged,
          closesAt: closesAt,
        ),
        android: false,
      );

      expect(h.state.supported, isFalse);
      expect(h.state.step, BackgroundTrackingStep.unavailable);
      expect(h.state.running, isFalse);
    });

    _trackingTest('nobody but a field agent is tracked', (tester) async {
      final h = await _start(
        tester,
        settings: _settings(
          background: LocationConsent.acknowledged,
          closesAt: closesAt,
        ),
        role: 'manager',
      );
      expect(h.state.step, BackgroundTrackingStep.unavailable);
      expect(h.gateway.starts, 0);
    });
  });

  group('inside working hours, with consent', () {
    _trackingTest(
      'runs a foreground service and queues pings through the outbox',
      (tester) async {
        final h = await _start(
          tester,
          settings: _settings(
            background: LocationConsent.acknowledged,
            closesAt: closesAt,
          ),
        );

        expect(h.state.step, BackgroundTrackingStep.running);
        expect(h.state.running, isTrue);
        expect(h.gateway.starts, 1);
        expect(h.gateway.interval, const Duration(minutes: 10));
        // Whatever words it carries, the notification is non-dismissable — that
        // is set on the config the real gateway builds, and the fake proves only
        // that one was supplied at all.
        expect(h.gateway.notification, isNotNull);

        final at = DateTime.utc(2026, 9, 17, 9, 30);
        h.gateway.emit(fixAt(at));
        await _settle(tester);

        final rows = await h.rows(tester, locationBackgroundPingEntity);
        expect(rows, hasLength(1));
        expect(jsonDecode(rows.single.payloadJson), {
          'lat': -26.1,
          'lng': 28.05,
          'accuracyM': 14,
          'recordedAt': at.toIso8601String(),
        });
        // The foreground lane stays empty: these are not heartbeat pings, and the
        // two are posted in separate requests with separate sources.
        expect(await h.rows(tester, locationPingEntity), isEmpty);
      },
    );

    _trackingTest('stamps the FIX time, not the moment it was delivered', (
      tester,
    ) async {
      final h = await _start(
        tester,
        settings: _settings(
          background: LocationConsent.acknowledged,
          closesAt: closesAt,
        ),
      );
      // A fix taken eight minutes before the phone handed it over.
      final taken = DateTime.utc(2026, 9, 17, 9, 2);
      h.clock.now = DateTime.utc(2026, 9, 17, 9, 10);
      h.gateway.emit(fixAt(taken));
      await _settle(tester);

      final rows = await h.rows(tester, locationBackgroundPingEntity);
      expect(
        (jsonDecode(rows.single.payloadJson) as Map)['recordedAt'],
        taken.toIso8601String(),
      );
    });

    _trackingTest('throttles a chatty platform to one ping per half-interval', (
      tester,
    ) async {
      final h = await _start(
        tester,
        settings: _settings(
          background: LocationConsent.acknowledged,
          closesAt: closesAt,
        ),
      );

      h.gateway.emit(fixAt(DateTime.utc(2026, 9, 17, 9, 0)));
      await _settle(tester);
      // One minute later: taken, but dropped by the five-minute floor.
      h.gateway.emit(fixAt(DateTime.utc(2026, 9, 17, 9, 1)));
      await _settle(tester);
      expect(await h.rows(tester, locationBackgroundPingEntity), hasLength(1));

      h.gateway.emit(fixAt(DateTime.utc(2026, 9, 17, 9, 6)));
      await _settle(tester);
      expect(await h.rows(tester, locationBackgroundPingEntity), hasLength(2));
    });

    _trackingTest('drops a fix that arrives after the window has closed', (
      tester,
    ) async {
      final h = await _start(
        tester,
        settings: _settings(
          background: LocationConsent.acknowledged,
          closesAt: closesAt,
        ),
      );
      expect(h.state.running, isTrue);

      // The working day ends while the service is still up.
      h.clock.now = DateTime.utc(2026, 9, 17, 15, 5);
      h.gateway.emit(fixAt(DateTime.utc(2026, 9, 17, 15, 5)));
      await _settle(tester);

      expect(await h.rows(tester, locationBackgroundPingEntity), isEmpty);
      expect(h.state.running, isFalse);
      expect(h.gateway.cancels, 1);
    });
  });

  group('the two notices are independent', () {
    _trackingTest(
      'accepting background records its own answer and starts the service',
      (tester) async {
        final h = await _start(tester, settings: _settings(closesAt: closesAt));
        expect(h.state.step, BackgroundTrackingStep.off);

        await tester.runAsync(h.controller.enable);
        await _settle(tester);

        expect(h.state.accepted, isTrue);
        expect(h.state.step, BackgroundTrackingStep.running);
        expect(h.gateway.starts, 1);

        final answers = await h.rows(tester, locationConsentEntity);
        expect(answers, hasLength(1));
        final payload = jsonDecode(answers.single.payloadJson) as Map;
        expect(payload['kind'], 'background');
        expect(payload['decision'], 'acknowledged');
        expect(payload['noticeVersion'], 'bg-v1');

        // The foreground notice is untouched — still unanswered.
        expect(h.sharing.settings?.decision, isNull);
        expect(h.sharing.running, isFalse);
      },
    );

    _trackingTest(
      'the permission is only asked for AFTER the notice is accepted',
      (tester) async {
        final h = await _start(
          tester,
          settings: _settings(closesAt: closesAt),
          gateway: _Gateway(permission: LocationPermission.denied),
        );
        expect(h.gateway.permissionRequests, 0);

        await tester.runAsync(h.controller.enable);
        await _settle(tester);
        expect(h.gateway.permissionRequests, greaterThan(0));
      },
    );

    _trackingTest(
      'stopping background tracking leaves foreground sharing alone',
      (tester) async {
        final h = await _start(
          tester,
          settings: _settings(
            background: LocationConsent.acknowledged,
            foreground: LocationConsent.acknowledged,
            closesAt: closesAt,
          ),
        );
        expect(h.state.running, isTrue);
        expect(h.sharing.acknowledged, isTrue);

        h.gateway.emit(fixAt(DateTime.utc(2026, 9, 17, 9, 30)));
        await _settle(tester);
        expect(
          await h.rows(tester, locationBackgroundPingEntity),
          hasLength(1),
        );

        await tester.runAsync(h.controller.stop);
        await _settle(tester);

        expect(h.state.accepted, isFalse);
        expect(h.state.step, BackgroundTrackingStep.off);
        expect(h.state.running, isFalse);
        expect(h.gateway.cancels, 1);
        // The queued route points never leave the phone...
        expect(await h.rows(tester, locationBackgroundPingEntity), isEmpty);
        // ...and foreground sharing is exactly where it was.
        expect(h.sharing.acknowledged, isTrue);
        expect(
          h.sharing.settings?.decision?.consent,
          LocationConsent.acknowledged,
        );
      },
    );

    _trackingTest(
      'stopping foreground sharing leaves background tracking running',
      (tester) async {
        final h = await _start(
          tester,
          settings: _settings(
            background: LocationConsent.acknowledged,
            foreground: LocationConsent.acknowledged,
            closesAt: closesAt,
          ),
        );
        expect(h.state.running, isTrue);

        await tester.runAsync(
          h.container.read(locationSharingControllerProvider.notifier).decline,
        );
        await _settle(tester);

        expect(h.sharing.acknowledged, isFalse);
        expect(h.state.accepted, isTrue);
        expect(h.state.step, BackgroundTrackingStep.running);
        expect(h.gateway.cancels, 0);
      },
    );
  });

  group('a refusal stops this and nothing else', () {
    _trackingTest(
      'whileInUse offers the settings page rather than asking again forever',
      (tester) async {
        final gateway = _Gateway(permission: LocationPermission.whileInUse);
        final h = await _start(
          tester,
          settings: _settings(
            background: LocationConsent.acknowledged,
            foreground: LocationConsent.acknowledged,
            closesAt: closesAt,
          ),
          gateway: gateway,
        );

        await tester.runAsync(h.controller.requestPermission);
        await _settle(tester);

        expect(h.state.permissionRefused, isTrue);
        expect(h.state.step, BackgroundTrackingStep.needsPermission);
        expect(h.gateway.starts, 0);
        // The heartbeat is entirely unaffected by the refusal.
        expect(h.sharing.acknowledged, isTrue);

        await tester.runAsync(h.controller.openSettings);
        expect(h.gateway.settingsOpened, 1);
      },
    );

    _trackingTest(
      'granting it from the settings page starts tracking on resume',
      (tester) async {
        final gateway = _Gateway(permission: LocationPermission.whileInUse);
        final h = await _start(
          tester,
          settings: _settings(
            background: LocationConsent.acknowledged,
            closesAt: closesAt,
          ),
          gateway: gateway,
        );
        expect(h.state.running, isFalse);

        // They came back from Android's settings having chosen "Allow all the
        // time"; the app only finds out by looking again.
        gateway.permission = LocationPermission.always;
        h.controller.handleLifecycle(AppLifecycleState.resumed);
        await _settle(tester);

        expect(h.state.permitted, isTrue);
        expect(h.state.running, isTrue);
        expect(h.gateway.starts, 1);
      },
    );

    _trackingTest('a hard denial is not an error, it is just no tracking', (
      tester,
    ) async {
      final h = await _start(
        tester,
        settings: _settings(
          background: LocationConsent.acknowledged,
          closesAt: closesAt,
        ),
        gateway: _Gateway(permission: LocationPermission.deniedForever),
      );
      expect(h.state.step, BackgroundTrackingStep.needsPermission);
      expect(h.gateway.starts, 0);
    });
  });

  _trackingTest('logging out stops the service cleanly', (tester) async {
    final h = await _start(
      tester,
      settings: _settings(
        background: LocationConsent.acknowledged,
        closesAt: closesAt,
      ),
    );
    expect(h.state.running, isTrue);
    expect(h.gateway.starts, 1);

    h.container.read(sessionControllerProvider.notifier);
    (h.container.read(sessionControllerProvider.notifier) as _Session)
        .signOut();
    currentLocalUserId = null;
    await _settle(tester);

    expect(h.state.supported, isFalse);
    expect(h.state.running, isFalse);
    // The subscription is cancelled, which is what tears down the Android
    // service and removes its notification.
    expect(h.gateway.cancels, 1);

    // And a fix arriving afterwards queues nothing.
    h.gateway.emit(fixAt(DateTime.utc(2026, 9, 17, 9, 30)));
    await _settle(tester);
    expect(await h.rows(tester, locationBackgroundPingEntity), isEmpty);
  });

  _trackingTest('a server that predates T2 offers nothing at all', (
    tester,
  ) async {
    final h = await _start(
      tester,
      settings: _settings(withBackgroundBlock: false),
    );
    expect(h.state.settings, isNull);
    expect(h.state.step, BackgroundTrackingStep.unavailable);
    expect(h.gateway.starts, 0);
  });

  test('the gateway is null on every platform but Android', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(container.read(backgroundLocationGatewayProvider), isNull);
  });
}

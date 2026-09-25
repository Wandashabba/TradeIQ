import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/location/location_sharing.dart';
import 'package:tradeiq_app/core/push/push_config.dart';
import 'package:tradeiq_app/core/push/push_repository.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/notifications/presentation/notification_preferences_screen.dart';

import '../../core/design/amber_golden.dart';
import '../clientadmin_harness.dart';

class _NoLocationSharing extends LocationSharingController {
  @override
  LocationSharingState build() => const LocationSharingState();
}

/// A `StateError`, never a bare `Exception`: Riverpod 3 retries anything that
/// is not an `Error` with an exponential backoff, and a widget test then sits
/// on the skeleton for ~12 seconds and never reaches the error branch.
class _FakePushRepository implements PushRepository {
  _FakePushRepository([this.prefs = const NotificationPreferences()]);

  NotificationPreferences prefs;
  bool failSave = false;
  bool failLoad = false;
  final List<Map<NotificationCategory, bool>> updates =
      <Map<NotificationCategory, bool>>[];

  @override
  Future<NotificationPreferences> fetchPreferences() async {
    if (failLoad) throw StateError('SocketException: api.tradeiq.co.za');
    return prefs;
  }

  @override
  Future<NotificationPreferences> updatePreferences(
    Map<NotificationCategory, bool> changes,
  ) async {
    updates.add(changes);
    if (failSave) throw StateError('SocketException: api.tradeiq.co.za');
    for (final e in changes.entries) {
      prefs = prefs.withValue(e.key, e.value);
    }
    return prefs;
  }

  @override
  Future<void> registerDevice({
    required String token,
    required PushPlatform platform,
  }) async {}

  @override
  Future<void> unregisterDevice(
    String token, {
    required String authToken,
  }) async {}
}

Future<void> _pump(
  WidgetTester tester,
  _FakePushRepository repository, {
  required String role,
  Locale? locale,
  TiqSkin? skin,
  double textScale = 1.0,
  bool settle = true,
}) async {
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);
  await pumpConsole(
    tester,
    const NotificationPreferencesScreen(),
    path: '/notifications',
    locale: locale,
    skin: skin,
    textScale: textScale,
    settle: settle,
    overrides: <Override>[
      sessionAs(role),
      pushRepositoryProvider.overrideWithValue(repository),
      localDbProvider.overrideWithValue(db),
      // Drift's watch() reschedules a zero-duration timer on every tick, so a
      // real stream here would make `pumpAndSettle` hang for ten minutes.
      syncStatusProvider.overrideWith((ref) => Stream.value(SyncStatus.empty)),
      locationSharingControllerProvider.overrideWith(_NoLocationSharing.new),
    ],
  );
}

bool _toggleValue(WidgetTester tester, NotificationCategory category) => tester
    .widget<TorchToggle>(keyed('push-pref-${category.name}'))
    .value;

TorchToggle _toggle(WidgetTester tester, NotificationCategory category) =>
    tester.widget<TorchToggle>(keyed('push-pref-${category.name}'));

void main() {
  group('the field agent, in Afrikaans', () {
    testWidgets('renders translated, offers no alerts, and saves a toggle', (
      tester,
    ) async {
      final repository = _FakePushRepository(
        const NotificationPreferences(messages: false),
      );
      await _pump(
        tester,
        repository,
        role: 'field_agent',
        locale: const Locale('af'),
      );

      expect(find.text('Kennisgewings'), findsWidgets);
      expect(find.text('Kies wat na hierdie foon kom'), findsOneWidget);
      expect(find.text('Take wat aan jou toegewys is'), findsOneWidget);
      expect(find.text('Boodskappe en aankondigings'), findsOneWidget);
      expect(find.text('Agterstallige take'), findsOneWidget);
      // Alerts go to managers only, so an agent is not offered them.
      expect(keyed('push-pref-alerts'), findsNothing);
      // An English string inside an Afrikaans screen is a defect.
      expect(find.text('Notifications'), findsNothing);
      expect(find.text('On'), findsNothing);
      expect(find.text('Off'), findsNothing);

      expect(_toggleValue(tester, NotificationCategory.messages), isFalse);
      expect(_toggleValue(tester, NotificationCategory.sla), isTrue);

      await scrollConsoleTo(tester, keyed('push-pref-sla'));
      await tester.tap(keyed('push-pref-sla'));
      await tester.pumpAndSettle();

      expect(repository.updates, <Map<NotificationCategory, bool>>[
        <NotificationCategory, bool>{NotificationCategory.sla: false},
      ]);
      expect(_toggleValue(tester, NotificationCategory.sla), isFalse);
    });

    testWidgets('the state word is mandatory, and it is in Afrikaans', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakePushRepository(const NotificationPreferences(messages: false)),
        role: 'field_agent',
        locale: const Locale('af'),
      );

      final tasks = _toggle(tester, NotificationCategory.tasks);
      expect(tasks.onWord, 'Aan');
      expect(tasks.offWord, 'Af');
      // The word is on screen beside the control, not only in the API.
      expect(find.text('Aan'), findsWidgets);
      expect(find.text('Af'), findsOneWidget);
    });

    testWidgets('push being unconfigured is said plainly, not as an error', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakePushRepository(),
        role: 'field_agent',
        locale: const Locale('af'),
      );
      expect(keyed('push-not-set-up'), findsOneWidget);
      expect(find.byType(ErrorState), findsNothing);
    });

    testWidgets('a failed save flips the toggle back and says so', (
      tester,
    ) async {
      final repository = _FakePushRepository()..failSave = true;
      await _pump(
        tester,
        repository,
        role: 'field_agent',
        locale: const Locale('af'),
      );

      await scrollConsoleTo(tester, keyed('push-pref-tasks'));
      await tester.tap(keyed('push-pref-tasks'));
      await tester.pumpAndSettle();

      // The toggle never lies about the server.
      expect(_toggleValue(tester, NotificationCategory.tasks), isTrue);
      expect(find.byType(TorchToast), findsOneWidget);
      expect(
        find.text(
          'Kon dit nie stoor nie. Kyk of jy verbinding het en probeer weer.',
        ),
        findsOneWidget,
      );
      await settleToasts(tester);
    });

    testWidgets('a failed load offers a retry and still shows the way to a '
        'password', (tester) async {
      final repository = _FakePushRepository()..failLoad = true;
      await _pump(
        tester,
        repository,
        role: 'field_agent',
        locale: const Locale('af'),
      );

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Kon nie jou kennisgewing-instellings laai nie'),
          findsOneWidget);
      // #400: a preferences load that fails must never hide this.
      await scrollConsoleTo(tester, keyed('account-change-password'));
      expect(keyed('account-change-password'), findsOneWidget);

      repository.failLoad = false;
      await tester.tap(keyed('push-prefs-retry'));
      await tester.pumpAndSettle();
      expect(find.text('Agterstallige take'), findsOneWidget);
    });
  });

  group('the manager console', () {
    testWidgets('renders every category and saves a toggle', (tester) async {
      final repository = _FakePushRepository(
        const NotificationPreferences(sla: false),
      );
      await _pump(tester, repository, role: 'manager');

      expect(find.text('Notifications'), findsWidgets);
      expect(find.text('Push notifications'.toUpperCase()), findsOneWidget);
      for (final label in <String>[
        'Alerts',
        'Tasks assigned to you',
        'Messages and announcements',
        'Overdue tasks',
      ]) {
        await scrollConsoleTo(tester, find.text(label));
        expect(find.text(label), findsOneWidget);
      }
      expect(_toggleValue(tester, NotificationCategory.sla), isFalse);

      await scrollConsoleTo(tester, keyed('push-pref-alerts'));
      await tester.tap(keyed('push-pref-alerts'));
      await tester.pumpAndSettle();

      expect(repository.updates, <Map<NotificationCategory, bool>>[
        <NotificationCategory, bool>{NotificationCategory.alerts: false},
      ]);
      expect(_toggleValue(tester, NotificationCategory.alerts), isFalse);
      await settleToasts(tester);
    });

    testWidgets('the way to a password survives a failed load', (tester) async {
      final repository = _FakePushRepository()..failLoad = true;
      await _pump(tester, repository, role: 'manager');

      expect(find.byType(ErrorState), findsOneWidget);
      await scrollConsoleTo(tester, keyed('account-change-password'));
      expect(keyed('account-change-password'), findsOneWidget);
    });

    testWidgets('loading is a skeleton with its own section markers', (
      tester,
    ) async {
      final repository = _FakePushRepository();
      await _pump(tester, repository, role: 'manager');
      expect(find.byType(SectionRule), findsWidgets);
    });
  });

  group('the amber census, both roles, every skin', () {
    for (final skin in <TiqSkin>[
      TiqSkin.night(),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      // The agent's branch is pushed, so there is no nav and no tab — and it
      // declares no claim, because a preference saves itself on the flip.
      testWidgets('${skin.mode.name}, the agent: 0', (tester) async {
        await _pump(
          tester,
          _FakePushRepository(),
          role: 'field_agent',
          skin: skin,
        );
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'notifications (agent)',
          phase: 'loaded',
        );
        expect(census.objectCount, 0, reason: census.describe());
      });

      // The manager's is a tab root, so Night paints the nav's active tab.
      final lit = skin.mode == SkinMode.night ? 1 : 0;
      for (final phase in <String, Future<void> Function(WidgetTester)>{
        'loaded': (t) =>
            _pump(t, _FakePushRepository(), role: 'manager', skin: skin),
        'error': (t) => _pump(
          t,
          _FakePushRepository()..failLoad = true,
          role: 'manager',
          skin: skin,
        ),
      }.entries) {
        testWidgets('${skin.mode.name}, the manager, ${phase.key}: $lit', (
          tester,
        ) async {
          await phase.value(tester);
          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'notifications (console)',
            phase: phase.key,
          );
          expect(census.objectCount, lit, reason: census.describe());
        });
      }
    }
  });

  group('2.0x text', () {
    testWidgets('the agent’s Afrikaans screen survives at 2.0x', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakePushRepository(),
        role: 'field_agent',
        locale: const Locale('af'),
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
      await scrollConsoleTo(tester, keyed('account-change-password'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the console survives at 2.0x', (tester) async {
      await _pump(
        tester,
        _FakePushRepository(),
        role: 'manager',
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
      await scrollConsoleTo(tester, keyed('account-change-password'));
      expect(tester.takeException(), isNull);
    });
  });
}

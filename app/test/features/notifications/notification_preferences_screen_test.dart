import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/location/location_sharing.dart';
import 'package:tradeiq_app/core/push/push_config.dart';
import 'package:tradeiq_app/core/push/push_repository.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/agent_kit.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/notifications/presentation/notification_preferences_screen.dart';

import '../../helpers/routed_app.dart';

class _FixedSession extends SessionController {
  _FixedSession(this.role);
  final String role;

  @override
  Future<SessionState> build() async =>
      SessionState(role: role, token: 'session-token');
}

class _NoLocationSharing extends LocationSharingController {
  @override
  LocationSharingState build() => const LocationSharingState();
}

class _FakePushRepository implements PushRepository {
  _FakePushRepository([this.prefs = const NotificationPreferences()]);

  NotificationPreferences prefs;
  bool failSave = false;
  bool failLoad = false;
  final updates = <Map<NotificationCategory, bool>>[];

  @override
  Future<NotificationPreferences> fetchPreferences() async {
    if (failLoad) throw Exception('offline');
    return prefs;
  }

  @override
  Future<NotificationPreferences> updatePreferences(
    Map<NotificationCategory, bool> changes,
  ) async {
    updates.add(changes);
    if (failSave) throw Exception('offline');
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

Widget _screen(
  _FakePushRepository repository, {
  required String role,
  Locale? locale,
  ThemeData? theme,
}) {
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);
  return routedApp(
    const NotificationPreferencesScreen(),
    path: '/notifications',
    locale: locale,
    theme: theme,
    overrides: [
      sessionControllerProvider.overrideWith(() => _FixedSession(role)),
      pushRepositoryProvider.overrideWithValue(repository),
      localDbProvider.overrideWithValue(db),
      syncStatusProvider.overrideWith((ref) => Stream.value(SyncStatus.empty)),
      locationSharingControllerProvider.overrideWith(_NoLocationSharing.new),
    ],
  );
}

bool _toggleValue(WidgetTester tester, NotificationCategory category) => tester
    .widget<AgentToggle>(find.byKey(ValueKey('push-pref-${category.name}')))
    .value;

/// #67 — the notification preferences screen: the field agent's, translated,
/// and the manager's console page.
void main() {
  group('field agent, in Afrikaans', () {
    testWidgets('renders translated, offers no alerts, and saves a toggle', (
      tester,
    ) async {
      final repository = _FakePushRepository(
        const NotificationPreferences(messages: false),
      );
      await tester.pumpWidget(
        _screen(repository, role: 'field_agent', locale: const Locale('af')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kennisgewings'), findsOneWidget);
      expect(find.text('Kies wat na hierdie foon kom'), findsOneWidget);
      expect(find.text('Take wat aan jou toegewys is'), findsOneWidget);
      expect(find.text('Boodskappe en aankondigings'), findsOneWidget);
      expect(find.text('Agterstallige take'), findsOneWidget);
      // Push is unconfigured in tests: said plainly, not as an error.
      expect(
        find.text('Kennisgewings is nog nie aangeskakel nie'),
        findsOneWidget,
      );
      expect(find.text('Notifications'), findsNothing);
      expect(find.byKey(const ValueKey('push-pref-alerts')), findsNothing);
      expect(find.byType(GlassPane), findsWidgets);

      expect(_toggleValue(tester, NotificationCategory.messages), isFalse);
      expect(_toggleValue(tester, NotificationCategory.sla), isTrue);

      await tester.tap(find.byKey(const ValueKey('push-pref-sla')));
      await tester.pumpAndSettle();

      expect(repository.updates, [
        {NotificationCategory.sla: false},
      ]);
      expect(_toggleValue(tester, NotificationCategory.sla), isFalse);
    });

    testWidgets('a failed save flips the toggle back and says so', (
      tester,
    ) async {
      final repository = _FakePushRepository()..failSave = true;
      await tester.pumpWidget(
        _screen(repository, role: 'field_agent', locale: const Locale('af')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('push-pref-tasks')));
      await tester.pumpAndSettle();

      expect(_toggleValue(tester, NotificationCategory.tasks), isTrue);
      expect(
        find.text(
          'Kon dit nie stoor nie. Kyk of jy verbinding het en probeer weer.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a failed load offers a retry', (tester) async {
      final repository = _FakePushRepository()..failLoad = true;
      await tester.pumpWidget(
        _screen(repository, role: 'field_agent', locale: const Locale('af')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Kon nie jou kennisgewing-instellings laai nie'),
        findsOneWidget,
      );

      repository.failLoad = false;
      await tester.tap(find.byKey(const ValueKey('push-prefs-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Agterstallige take'), findsOneWidget);
    });
  });

  group('manager, night theme', () {
    testWidgets(
      'renders every category on the dark console and saves a toggle',
      (tester) async {
        final repository = _FakePushRepository(
          const NotificationPreferences(sla: false),
        );
        await tester.pumpWidget(
          _screen(repository, role: 'manager', theme: AppTheme.dark()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Push notifications'), findsOneWidget);
        for (final label in [
          'Alerts',
          'Tasks assigned to you',
          'Messages and announcements',
          'Overdue tasks',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(
          Theme.of(tester.element(find.text('Alerts'))).brightness,
          Brightness.dark,
        );
        expect(find.byKey(const ValueKey('push-not-set-up')), findsOneWidget);
        expect(find.byType(GlassPane), findsWidgets);
        expect(_toggleValue(tester, NotificationCategory.sla), isFalse);

        await tester.tap(find.byKey(const ValueKey('push-pref-alerts')));
        await tester.pumpAndSettle();

        expect(repository.updates, [
          {NotificationCategory.alerts: false},
        ]);
        expect(_toggleValue(tester, NotificationCategory.alerts), isFalse);
      },
    );
  });
}

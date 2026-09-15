import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tradeiq_app/core/l10n/app_language_controller.dart';
import 'package:tradeiq_app/core/theme/theme_mode_controller.dart';
import 'package:tradeiq_app/core/widgets/agent_scaffold.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

class FakeAppLanguageStore implements AppLanguageStore {
  FakeAppLanguageStore([this.stored]);
  AppLanguage? stored;

  @override
  Future<AppLanguage?> read() async => stored;

  @override
  Future<void> write(AppLanguage language) async => stored = language;
}

class _FakeThemeModeStore implements ThemeModeStore {
  @override
  Future<ThemeMode?> read() async => null;

  @override
  Future<void> write(ThemeMode mode) async {}
}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// Wired exactly like the root `MaterialApp.router` in main.dart.
class _App extends ConsumerWidget {
  const _App({required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    locale: ref.watch(appLanguageProvider).locale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    localeListResolutionCallback: resolveAppLocale,
    home: home,
  );
}

/// Shows which translation is active.
class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) =>
      Text(context.l10n.languageMenuTooltip, textDirection: TextDirection.ltr);
}

void main() {
  ProviderContainer withStore(AppLanguageStore store) {
    final container = ProviderContainer(
      overrides: [appLanguageStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('AppLanguageController', () {
    test('follows the device when nothing is stored', () async {
      final container = withStore(FakeAppLanguageStore());
      expect(container.read(appLanguageProvider), AppLanguage.system);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(appLanguageProvider), AppLanguage.system);
      expect(AppLanguage.system.locale, isNull);
    });

    test('restores a persisted override', () async {
      final container = withStore(FakeAppLanguageStore(AppLanguage.afrikaans));
      // Synchronous first read follows the device — restore is async.
      expect(container.read(appLanguageProvider), AppLanguage.system);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(appLanguageProvider), AppLanguage.afrikaans);
    });

    test('select applies and persists the choice', () async {
      final store = FakeAppLanguageStore();
      final container = withStore(store);
      await container
          .read(appLanguageProvider.notifier)
          .select(AppLanguage.afrikaans);
      expect(container.read(appLanguageProvider), AppLanguage.afrikaans);
      expect(store.stored, AppLanguage.afrikaans);
      await container
          .read(appLanguageProvider.notifier)
          .select(AppLanguage.system);
      expect(store.stored, AppLanguage.system);
    });

    test('a choice made before the restore lands is not clobbered', () async {
      final container = withStore(FakeAppLanguageStore(AppLanguage.afrikaans));
      await container
          .read(appLanguageProvider.notifier)
          .select(AppLanguage.english);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(appLanguageProvider), AppLanguage.english);
    });
  });

  group('SecureAppLanguageStore', () {
    test('maps stored strings and ignores unknown ones', () async {
      final storage = _MockSecureStorage();
      final store = SecureAppLanguageStore(storage: storage);
      when(
        () => storage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => 'af');
      expect(await store.read(), AppLanguage.afrikaans);
      when(
        () => storage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => 'zz');
      expect(await store.read(), isNull);
    });

    test('an unreadable store yields null — the device locale wins', () async {
      final storage = _MockSecureStorage();
      when(
        () => storage.read(key: any(named: 'key')),
      ).thenThrow(PlatformException(code: 'boom'));
      expect(await SecureAppLanguageStore(storage: storage).read(), isNull);
    });

    test('writes under tiq.language', () async {
      final storage = _MockSecureStorage();
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      await SecureAppLanguageStore(
        storage: storage,
      ).write(AppLanguage.afrikaans);
      verify(() => storage.write(key: 'tiq.language', value: 'af')).called(1);
    });
  });

  group('locale resolution', () {
    test('a supported device language wins, regardless of region', () {
      expect(
        resolveAppLocale(const [Locale('af', 'ZA')], appSupportedLocales),
        const Locale('af'),
      );
      expect(
        resolveAppLocale(const [
          Locale('fr'),
          Locale('af'),
        ], appSupportedLocales),
        const Locale('af'),
      );
    });

    test('an unsupported device language falls back to English', () {
      expect(
        resolveAppLocale(const [Locale('zu', 'ZA')], appSupportedLocales),
        const Locale('en'),
      );
      expect(resolveAppLocale(null, appSupportedLocales), const Locale('en'));
    });

    testWidgets('Afrikaans device → Afrikaans UI', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('af', 'ZA')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLanguageStoreProvider.overrideWithValue(FakeAppLanguageStore()),
          ],
          child: const _App(home: _Probe()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Taal'), findsOneWidget);
    });

    testWidgets('unsupported device locale → English UI', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('zu', 'ZA')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLanguageStoreProvider.overrideWithValue(FakeAppLanguageStore()),
          ],
          child: const _App(home: _Probe()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsOneWidget);
    });

    testWidgets('a persisted override wins over the device locale', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = const [Locale('af', 'ZA')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLanguageStoreProvider.overrideWithValue(
              FakeAppLanguageStore(AppLanguage.english),
            ),
          ],
          child: const _App(home: _Probe()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Taal'), findsNothing);
    });
  });

  group('the agent app-bar language menu', () {
    testWidgets('choosing Afrikaans switches the UI and persists it', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'ZA')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final store = FakeAppLanguageStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLanguageStoreProvider.overrideWithValue(store),
            themeModeStoreProvider.overrideWithValue(_FakeThemeModeStore()),
          ],
          child: const _App(
            home: AgentScaffold(
              title: 'Today',
              body: SizedBox.shrink(),
              showSyncChip: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Language'), findsOneWidget);
      expect(find.byTooltip('Log out'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('agent-language-menu')));
      await tester.pumpAndSettle();
      expect(find.text('System'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('agent-language-af')));
      await tester.pumpAndSettle();

      expect(store.stored, AppLanguage.afrikaans);
      expect(find.byTooltip('Taal'), findsOneWidget);
      expect(find.byTooltip('Teken uit'), findsOneWidget);

      // Back to following the device (English here).
      await tester.tap(find.byKey(const ValueKey('agent-language-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('agent-language-system')));
      await tester.pumpAndSettle();
      expect(store.stored, AppLanguage.system);
      expect(find.byTooltip('Language'), findsOneWidget);
    });
  });
}

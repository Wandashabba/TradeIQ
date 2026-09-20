import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tradeiq_app/core/theme/theme_mode_controller.dart';

class FakeThemeModeStore implements ThemeModeStore {
  FakeThemeModeStore([this.stored]);
  ThemeMode? stored;

  @override
  Future<ThemeMode?> read() async => stored;

  @override
  Future<void> write(ThemeMode mode) async => stored = mode;
}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  ProviderContainer withStore(ThemeModeStore store) {
    final container = ProviderContainer(
      overrides: [themeModeStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ThemeModeController', () {
    test('defaults to light when nothing is stored', () async {
      // default flipped by the 2026-07-24 premium-ui redesign
      final container = withStore(FakeThemeModeStore());
      expect(container.read(themeModeProvider), ThemeMode.light);
      await Future<void>.delayed(Duration.zero); // let the restore settle
      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('restores a persisted dark mode', () async {
      final container = withStore(FakeThemeModeStore(ThemeMode.dark));
      // Synchronous first read is light — restore is async by design.
      // default flipped by the 2026-07-24 premium-ui redesign
      expect(container.read(themeModeProvider), ThemeMode.light);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('toggle flips the mode and persists it', () async {
      final store = FakeThemeModeStore();
      final container = withStore(store);
      await container.read(themeModeProvider.notifier).toggle();
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(store.stored, ThemeMode.dark);
      await container.read(themeModeProvider.notifier).toggle();
      expect(container.read(themeModeProvider), ThemeMode.light);
      expect(store.stored, ThemeMode.light);
    });

    test('a toggle made before the restore lands is not clobbered by it', () async {
      final container = withStore(FakeThemeModeStore(ThemeMode.light));
      await container.read(themeModeProvider.notifier).toggle(); // → dark
      await Future<void>.delayed(Duration.zero); // restore resolves 'light'
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });
  });

  group('SecureThemeModeStore', () {
    test('maps stored strings to modes and unknown values to null', () async {
      final storage = _MockSecureStorage();
      final store = SecureThemeModeStore(storage: storage);
      when(() => storage.read(key: any(named: 'key')))
          .thenAnswer((_) async => 'light');
      expect(await store.read(), ThemeMode.light);
      when(() => storage.read(key: any(named: 'key')))
          .thenAnswer((_) async => 'banana');
      expect(await store.read(), isNull);
    });

    test('an unreadable store yields null — caller keeps dark', () async {
      final storage = _MockSecureStorage();
      when(() => storage.read(key: any(named: 'key')))
          .thenThrow(PlatformException(code: 'boom'));
      expect(await SecureThemeModeStore(storage: storage).read(), isNull);
    });

    test('writes under the spec key tiq.themeMode', () async {
      final storage = _MockSecureStorage();
      when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});
      await SecureThemeModeStore(storage: storage).write(ThemeMode.light);
      verify(() => storage.write(key: 'tiq.themeMode', value: 'light')).called(1);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/pinned_dark.dart';
import 'package:tradeiq_app/core/theme/theme_mode_controller.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';

class _MemoryStore implements ThemeModeStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String mode) async => value = mode;
}

void main() {
  test('defaults to dark when nothing is stored', () async {
    final container = ProviderContainer(overrides: [
      themeModeStoreProvider.overrideWithValue(_MemoryStore()),
    ]);
    addTearDown(container.dispose);
    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  test('toggle flips to light and persists', () async {
    final store = _MemoryStore();
    final container = ProviderContainer(overrides: [
      themeModeStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);

    await container.read(themeModeProvider.notifier).toggle();
    expect(container.read(themeModeProvider), ThemeMode.light);
    expect(store.value, 'light');

    await container.read(themeModeProvider.notifier).toggle();
    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(store.value, 'dark');
  });

  test('restores a stored light preference', () async {
    final store = _MemoryStore()..value = 'light';
    final container = ProviderContainer(overrides: [
      themeModeStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);

    await container.read(themeModeProvider.notifier).restore();
    expect(container.read(themeModeProvider), ThemeMode.light);
  });

  test('an unreadable store still yields dark', () async {
    final container = ProviderContainer(overrides: [
      themeModeStoreProvider.overrideWithValue(_ThrowingStore()),
    ]);
    addTearDown(container.dispose);

    await container.read(themeModeProvider.notifier).restore();
    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  testWidgets('themeMode flips the active scaffold palette', (tester) async {
    final container = ProviderContainer(overrides: [
      themeModeStoreProvider.overrideWithValue(_MemoryStore()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: Consumer(builder: (context, ref, _) {
        return MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ref.watch(themeModeProvider),
          home: const Scaffold(body: SizedBox()),
        );
      }),
    ));

    Color bg() => Theme.of(tester.element(find.byType(Scaffold)))
        .scaffoldBackgroundColor;

    expect(bg(), TiqColors.dark.plane);
    await container.read(themeModeProvider.notifier).toggle();
    await tester.pumpAndSettle();
    expect(bg(), TiqColors.light.plane);
  });

  testWidgets('PinnedDark keeps its subtree dark under a light ambient theme',
      (tester) async {
    late TiqColors seen;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: PinnedDark(
        child: Builder(builder: (context) {
          seen = context.colors;
          return const SizedBox();
        }),
      ),
    ));
    expect(seen, same(TiqColors.dark));
  });
}

class _ThrowingStore implements ThemeModeStore {
  @override
  Future<String?> read() async => throw Exception('keychain unavailable');
  @override
  Future<void> write(String mode) async => throw Exception('keychain unavailable');
}

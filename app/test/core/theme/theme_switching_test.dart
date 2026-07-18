import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/theme_mode_controller.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/agent_scaffold.dart';
import 'package:tradeiq_app/core/widgets/manager_scaffold.dart';

class FakeThemeModeStore implements ThemeModeStore {
  FakeThemeModeStore([this.stored]);
  ThemeMode? stored;

  @override
  Future<ThemeMode?> read() async => stored;

  @override
  Future<void> write(ThemeMode mode) async => stored = mode;
}

void main() {
  testWidgets('an agent screen stays dark while themeMode is light', (
    tester,
  ) async {
    // showSyncChip: false — the chip opens the local DB (see routed_app.dart);
    // this test is about theming, not sync.
    final router = GoRouter(
      initialLocation: '/screen',
      routes: [
        GoRoute(
          path: '/screen',
          builder: (context, state) => const AgentScaffold(
            title: 'Agent',
            body: SizedBox(),
            showSyncChip: false,
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.light, // the app-level mode is LIGHT
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Inside the agent shell the ambient theme must still be the dark one.
    final ctx = tester.element(find.byType(AppBar));
    expect(Theme.of(ctx).brightness, Brightness.dark);
    expect(ctx.colors, same(TiqColors.dark));
  });

  Widget managerApp(ThemeModeStore store) {
    // Router hoisted OUTSIDE the Consumer so a theme rebuild never recreates it.
    final router = GoRouter(
      initialLocation: '/screen',
      routes: [
        GoRoute(
          path: '/screen',
          builder: (context, state) =>
              const ManagerScaffold(title: 'T', body: SizedBox()),
        ),
      ],
    );
    return ProviderScope(
      overrides: [themeModeStoreProvider.overrideWithValue(store)],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ref.watch(themeModeProvider),
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets('theme-toggle flips the console between the dark and light planes '
      'and persists the choice', (tester) async {
    final store = FakeThemeModeStore();
    await tester.pumpWidget(managerApp(store));
    await tester.pumpAndSettle();

    Color? plane() =>
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor;

    expect(plane(), TiqColors.dark.plane);
    expect(find.byTooltip('Switch to light theme'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();

    expect(plane(), TiqColors.light.plane);
    expect(store.stored, ThemeMode.light); // persisted
    expect(find.byTooltip('Switch to dark theme'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();

    expect(plane(), TiqColors.dark.plane);
    expect(store.stored, ThemeMode.dark);
  });

  testWidgets('a persisted light mode restores on startup', (tester) async {
    await tester.pumpWidget(managerApp(FakeThemeModeStore(ThemeMode.light)));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
      TiqColors.light.plane,
    );
  });
}

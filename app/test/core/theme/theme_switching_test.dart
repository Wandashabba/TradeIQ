import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/theme_mode_controller.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/agent_scaffold.dart';

class FakeThemeModeStore implements ThemeModeStore {
  FakeThemeModeStore([this.stored]);
  ThemeMode? stored;

  @override
  Future<ThemeMode?> read() async => stored;

  @override
  Future<void> write(ThemeMode mode) async => stored = mode;
}

void main() {
  testWidgets('an agent screen now FOLLOWS the app theme (premium-ui sub5a)', (
    tester,
  ) async {
    // Sub-5a dropped PinnedDark: the agent shell is theme-aware, so under a
    // light app-level mode it resolves the LIGHT palette — not the old pinned
    // dark. showSyncChip: false — the chip opens the local DB (routed_app.dart);
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

    // Inside the agent shell the ambient theme is now the LIGHT one.
    final ctx = tester.element(find.byType(AppBar));
    expect(Theme.of(ctx).brightness, Brightness.light);
    expect(ctx.colors, same(TiqColors.light));
  });

  // THE TWO CONSOLE CASES WENT WITH `ManagerScaffold`. They asserted that the
  // theme toggle flipped the console's plane and persisted the choice. Both
  // halves are still owned and still tested: the Torchlight menu sheet's theme
  // row is covered by `menu_sheet_test.dart`, and the toggle and its
  // persistence by `theme_mode_controller_test.dart`. What is gone is the
  // shell that used to carry the control, not the behaviour.
}

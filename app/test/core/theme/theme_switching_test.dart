import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/agent_scaffold.dart';

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
}

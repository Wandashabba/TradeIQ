import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/theme_mode_controller.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/agent_kit.dart';
import 'package:tradeiq_app/core/widgets/agent_scaffold.dart';

import '../theme/tiq_colors_test.dart' show contrastRatio;

// AgentScaffold reads GoRouterState.of guardedly (a try/catch), so a plain
// MaterialApp with `home:` is enough — no GoRouter stub needed. The sync chip
// opens the outbox DB, so it is turned off in these theme-focused pumps.
const _scaffold = AgentScaffold(
  title: 'Today',
  body: SizedBox.shrink(),
  showSyncChip: false,
);

Widget _fixed(ThemeMode mode) => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: mode,
    home: _scaffold,
  ),
);

/// Themed by the live [themeModeProvider], so tapping the in-app toggle flips
/// the whole tree — exactly as the root [MaterialApp.router] wires it.
class _Live extends ConsumerWidget {
  const _Live();

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: ref.watch(themeModeProvider),
    home: _scaffold,
  );
}

Color _bg(WidgetTester tester) =>
    tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor!;

IconData _toggleIcon(WidgetTester tester) => tester
    .widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('agent-theme-toggle')),
        matching: find.byType(Icon),
      ),
    )
    .icon!;

void main() {
  group('AgentScaffold is theme-aware, not pinned dark', () {
    testWidgets('light theme paints the light plane', (tester) async {
      await tester.pumpWidget(_fixed(ThemeMode.light));
      await tester.pumpAndSettle();
      expect(_bg(tester), TiqColors.light.plane);
    });

    testWidgets('dark theme paints the dark plane', (tester) async {
      await tester.pumpWidget(_fixed(ThemeMode.dark));
      await tester.pumpAndSettle();
      expect(_bg(tester), TiqColors.dark.plane);
    });
  });

  group('the app-bar theme toggle flips the app theme', () {
    testWidgets('tapping swaps light.plane→dark.plane and swaps the icon', (
      tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: _Live()));
      await tester.pumpAndSettle();

      // Default is light (ThemeModeController.build): light plane, and the
      // toggle offers the *destination* — a moon to go dark.
      expect(_bg(tester), TiqColors.light.plane);
      expect(_toggleIcon(tester), Icons.dark_mode);

      await tester.tap(find.byKey(const ValueKey('agent-theme-toggle')));
      await tester.pumpAndSettle();

      expect(_bg(tester), TiqColors.dark.plane);
      expect(_toggleIcon(tester), Icons.light_mode);
    });
  });

  group('StatusBanner contrast holds in BOTH themes', () {
    // The sync chip renders the banner on the scaffold body — the `plane`
    // ground. Reproduce that exact composite (the level's wash at 12% over
    // plane) so the guard measures what an agent actually reads, and kills any
    // level whose token happens to clear 4.5:1 in only one theme.
    for (final (name, colors, brightness) in [
      ('light', TiqColors.light, Brightness.light),
      ('dark', TiqColors.dark, Brightness.dark),
    ]) {
      test('$name: every BannerLevel title clears 4.5:1 on its wash', () {
        for (final level in BannerLevel.values) {
          final wash = Color.alphaBlend(level.wash(colors), colors.plane);
          final ratio = contrastRatio(
            level.textColor(colors, brightness),
            wash,
          );
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '$name BannerLevel.$level title is $ratio:1 on its wash over '
                'plane — every status line has to be readable.',
          );
        }
      });

      test('$name: the app-bar title (ink1) clears 4.5:1 on plane', () {
        expect(
          contrastRatio(colors.ink1, colors.plane),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  });
}

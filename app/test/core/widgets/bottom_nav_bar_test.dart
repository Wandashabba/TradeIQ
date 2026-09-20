import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/bottom_nav_bar.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

import '../theme/tiq_colors_test.dart' show contrastRatio;

/// The bar is injected by ManagerScaffold below 1080 — here we pump it
/// directly to test its own contract. The ProviderScope exists for the menu
/// sheet, whose theme-toggle and sign-out rows are riverpod Consumers.
Widget _app({
  String activeRoute = '/dashboard',
  ThemeData? theme,
  Locale? locale,
}) => ProviderScope(
  child: MaterialApp(
    theme: theme,
    locale: locale,
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: appSupportedLocales,
    home: Scaffold(
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TiqBottomNavBar(activeRoute: activeRoute),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  // The open-sheet count is an app-wide static, and the menu tests here end
  // with the menu up. Without this the NEXT test's `showTorchSheet` asserts
  // that a second sheet was opened over an existing one.
  setUp(TorchSheets.resetForTest);
  tearDown(TorchSheets.resetForTest);

  testWidgets('shows the five slots with the active tab pilled', (
    tester,
  ) async {
    await tester.pumpWidget(_app(activeRoute: '/dashboard'));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bottom-nav-pill-/dashboard')),
      findsOneWidget,
    );
  });

  /// The five slots were five hardcoded English strings — 'Home', 'Tasks',
  /// 'Alerts', 'Map', 'Menu' — read straight off a `const` record and printed.
  /// The menu sheet this same bar opens has been translated since #437, so an
  /// Afrikaans manager got a translated sheet hanging off an English bar.
  ///
  /// Four of the five keys already existed; only "Home" was missing, and the
  /// bar keeps the short word where the rail says "The Floor" because five
  /// slots share a phone's width on one line.
  testWidgets('the slots are translated, not five English constants', (
    tester,
  ) async {
    await tester.pumpWidget(_app(locale: const Locale('af')));
    await tester.pumpAndSettle();

    expect(find.text('Tuis'), findsOneWidget);
    expect(find.text('Take'), findsOneWidget);
    expect(find.text('Waarskuwings'), findsOneWidget);
    expect(find.text('Kaart'), findsOneWidget);
    expect(find.text('Kieslys'), findsOneWidget);

    for (final english in <String>['Home', 'Tasks', 'Alerts', 'Map', 'Menu']) {
      expect(
        find.text(english),
        findsNothing,
        reason: '"$english" is untranslated English on an Afrikaans bar',
      );
    }
  });

  testWidgets('the pill sits on the slot matching the active route', (
    tester,
  ) async {
    await tester.pumpWidget(_app(activeRoute: '/agents/activity'));

    expect(
      find.byKey(const ValueKey('bottom-nav-pill-/agents/activity')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('bottom-nav-pill-/dashboard')),
      findsNothing,
    );
  });

  testWidgets('menu slot opens the one Torchlight menu, sign-out included', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();

    // Sentence case: the section rule replaced the uppercase eyebrow, and
    // "OPERATE" read out letter by letter is not a word.
    expect(find.text('Operate'), findsOneWidget);
    expect(find.text('Insight'), findsOneWidget);
    expect(find.text('Configure'), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-sign-out')), findsOneWidget);
  });

  // ── Theme treatment (premium-ui sub2) ──────────────────────────────────
  // All read off the RENDERED tree, not the token table — so a widget that
  // stops consuming the tokens fails these even if the table stays right.

  /// The bar's frosted surface: the explicit DecoratedBox directly under the
  /// BackdropFilter (the blur is what the 92%-alpha fill sits on).
  BoxDecoration barDecoration(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(BackdropFilter),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    return box.decoration as BoxDecoration;
  }

  testWidgets(
    'dark theme is night glass: faint white bar, cool rim, uppercase mono slots',
    (tester) async {
      await tester.pumpWidget(
        _app(activeRoute: '/dashboard', theme: AppTheme.dark()),
      );

      final bar = barDecoration(tester);
      expect(bar.color, TiqColors.night.navBarBg);
      expect((bar.border as Border?)?.top.color, TiqColors.night.navBarLine);

      final pill = tester.widget<Container>(
        find.byKey(const ValueKey('bottom-nav-pill-/dashboard')),
      );
      final pillDeco = pill.decoration! as BoxDecoration;
      expect(pillDeco.color, TiqColors.night.navActivePillBg);
      expect((pillDeco.border! as Border).top.color, LumenPalette.dark.pillRim);

      final home = tester.widget<Text>(find.text('HOME'));
      expect(home.style!.fontFamily, 'JetBrains Mono');
      final activeInk = home.style!.color;
      final inactiveInk = tester.widget<Text>(find.text('TASKS')).style!.color;
      expect(activeInk, TiqColors.night.navActiveInk);
      // Night lifts the inactive slots to ink2 — see the AA test below.
      expect(inactiveInk, TiqColors.night.ink2);
      // Icons carry the same ink as their labels — never colour drift.
      expect(
        tester.widget<Icon>(find.byIcon(Icons.home_outlined)).color,
        activeInk,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.task_alt)).color,
        inactiveInk,
      );
    },
  );

  testWidgets('dark theme: nav inks clear WCAG AA on the bar over its '
      'lightest ground', (tester) async {
    await tester.pumpWidget(
      _app(activeRoute: '/dashboard', theme: AppTheme.dark()),
    );

    // A LIGHT ink over a translucent bar: the worst case is the LIGHTEST
    // ground it can meet, so composite over surface3 before measuring.
    final barOnGround = Color.alphaBlend(
      barDecoration(tester).color!,
      TiqColors.night.surface3,
    );
    final inactive = tester.widget<Text>(find.text('TASKS')).style!.color!;
    expect(
      contrastRatio(inactive, barOnGround),
      greaterThanOrEqualTo(4.5),
      reason: 'inactive labels are 10px text on the glass bar',
    );

    final pillBg =
        (tester
                    .widget<Container>(
                      find.byKey(const ValueKey('bottom-nav-pill-/dashboard')),
                    )
                    .decoration
                as BoxDecoration)
            .color!;
    final pillOnBar = Color.alphaBlend(pillBg, barOnGround);
    final active = tester.widget<Text>(find.text('HOME')).style!.color!;
    expect(
      contrastRatio(active, pillOnBar),
      greaterThanOrEqualTo(4.5),
      reason: 'active label on the active pill is 10px text — AA is 4.5:1',
    );
  });

  testWidgets(
    'light theme is Lumen Glass: half-white bar, lit rim, uppercase mono slots',
    (tester) async {
      await tester.pumpWidget(
        _app(activeRoute: '/dashboard', theme: AppTheme.light()),
      );

      final bar = barDecoration(tester);
      expect(bar.color, const Color(0x80FFFFFF));
      expect((bar.border as Border?)?.top.color, const Color(0xCCFFFFFF));
      final pill = tester.widget<Container>(
        find.byKey(const ValueKey('bottom-nav-pill-/dashboard')),
      );
      expect(
        (pill.decoration as BoxDecoration?)?.color,
        const Color(0xC7FFFFFF),
      );
      // Glass sets the slots as the handoff's uppercase mono tab labels.
      final home = tester.widget<Text>(find.text('HOME'));
      expect(home.style!.color, const Color(0xFF241F47));
      expect(home.style!.fontFamily, 'JetBrains Mono');
      expect(
        tester.widget<Text>(find.text('TASKS')).style!.color,
        const Color(0xFF5B5F75),
      );
    },
  );

  testWidgets('light theme: slot inks clear AA on the bar over its darkest '
      'ground', (tester) async {
    await tester.pumpWidget(
      _app(activeRoute: '/dashboard', theme: AppTheme.light()),
    );

    // A DARK ink over a translucent bar: the worst case is the DARKEST ground
    // it can meet, so composite over surface3 before measuring.
    final barOnGround = Color.alphaBlend(
      barDecoration(tester).color!,
      TiqColors.light.surface3,
    );
    final inactive = tester.widget<Text>(find.text('TASKS')).style!.color!;
    expect(
      contrastRatio(inactive, barOnGround),
      greaterThanOrEqualTo(4.5),
      reason: 'inactive labels are 10px text on the glass bar',
    );
    final pillOnBar = Color.alphaBlend(
      TiqColors.light.navActivePillBg,
      barOnGround,
    );
    final active = tester.widget<Text>(find.text('HOME')).style!.color!;
    expect(contrastRatio(active, pillOnBar), greaterThanOrEqualTo(4.5));
  });

  testWidgets('the Lumen bar opens the SAME sheet the console frame does', (
    tester,
  ) async {
    // The seam worth testing: this bar is still painted in Lumen and lives on
    // unmigrated manager routes, and `AppTheme.dark()` registers a `TiqSkin`,
    // so the Torchlight menu resolves its tokens from the ambient theme
    // rather than needing a route of its own. Two menus for one nav is what
    // lost the app its sign-out; one menu is the fix.
    await tester.pumpWidget(_app(theme: AppTheme.dark()));

    await tester.tap(find.text('MENU'));
    await tester.pumpAndSettle();

    expect(find.byType(TorchSheet), findsOneWidget);
    expect(find.byType(GlassPane), findsNothing);
    expect(find.byKey(const ValueKey('menu-/dashboard')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-sign-out')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-theme')), findsOneWidget);
  });
}

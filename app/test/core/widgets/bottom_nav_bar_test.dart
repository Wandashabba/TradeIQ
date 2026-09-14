import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/bottom_nav_bar.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';

import '../theme/tiq_colors_test.dart' show contrastRatio;

/// The bar is injected by ManagerScaffold below 1080 — here we pump it
/// directly to test its own contract. The ProviderScope exists for the menu
/// sheet, whose theme-toggle and sign-out rows are riverpod Consumers.
Widget _app({String activeRoute = '/dashboard', ThemeData? theme}) =>
    ProviderScope(
      child: MaterialApp(
        theme: theme,
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

  testWidgets('menu slot opens the grouped sheet with sign-out', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();

    expect(find.text('OPERATE'), findsOneWidget);
    expect(find.text('INSIGHT'), findsOneWidget);
    expect(find.text('CONFIGURE'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
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

  testWidgets('dark theme: menu sheet is the night glass sheet — surface1 '
      'ground, night rim, AA kickers, glass tiles', (tester) async {
    await tester.pumpWidget(_app(theme: AppTheme.dark()));

    await tester.tap(find.text('MENU'));
    await tester.pumpAndSettle();

    // The sheet's panel is the top-rounded Container — the opaque night
    // surface1 under the night panel rim, not a hardcoded paper value.
    final panel = tester.widget<Container>(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).borderRadius ==
                const BorderRadius.vertical(
                  top: Radius.circular(LumenGlass.radiusScore),
                ),
      ),
    );
    final panelDeco = panel.decoration! as BoxDecoration;
    expect(panelDeco.color, TiqColors.night.surface1);
    expect((panelDeco.border! as Border).top.color, LumenPalette.dark.panelRim);

    // Group headers are the night kicker, and stay AA-readable on the sheet
    // surface they actually sit on.
    final heading = tester.widget<Text>(find.text('OPERATE')).style!.color!;
    expect(heading, LumenPalette.dark.kicker);
    expect(
      contrastRatio(heading, TiqColors.night.surface1),
      greaterThanOrEqualTo(4.5),
      reason: 'sheet group labels are 9.5px text on surface1',
    );

    // Destination tiles are no-blur glass tiles; the divider is the hairline.
    final tile = tester.widget<GlassPane>(
      find.ancestor(
        of: find.byKey(const ValueKey('nav-sheet-/dashboard')),
        matching: find.byType(GlassPane),
      ),
    );
    expect(tile.kind, GlassKind.tile);
    expect(tile.blur, isFalse);
    final divider = tester.widget<Divider>(find.byType(Divider).first);
    expect(divider.color, TiqColors.night.line);
  });
}

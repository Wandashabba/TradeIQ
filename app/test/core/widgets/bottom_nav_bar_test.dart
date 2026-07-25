import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/bottom_nav_bar.dart';

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

  testWidgets('dark theme: bar surface, hairline, pill and inks', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(activeRoute: '/dashboard', theme: AppTheme.dark()),
    );

    final bar = barDecoration(tester);
    expect(bar.color, const Color(0xEB12151C)); // rgba(18,21,28,.92)
    // Semantic floor, not just a hex pin: a mostly-transparent bar would let
    // scrolling content wash out the labels — the frost stays ≥90% opaque.
    expect(bar.color!.a, greaterThanOrEqualTo(0.9));
    expect((bar.border as Border?)?.top.color, const Color(0xFF262B33));

    final pill = tester.widget<Container>(
      find.byKey(const ValueKey('bottom-nav-pill-/dashboard')),
    );
    expect((pill.decoration as BoxDecoration?)?.color, const Color(0xFF12305C));

    final activeInk = tester.widget<Text>(find.text('Home')).style!.color;
    final inactiveInk = tester.widget<Text>(find.text('Tasks')).style!.color;
    expect(activeInk, const Color(0xFF6DB4FF));
    expect(inactiveInk, const Color(0xFF8A94A6));
    // Icons carry the same ink as their labels — never colour drift.
    expect(
      tester.widget<Icon>(find.byIcon(Icons.home_outlined)).color,
      activeInk,
    );
    expect(tester.widget<Icon>(find.byIcon(Icons.task_alt)).color, inactiveInk);
  });

  testWidgets('dark theme: nav inks clear WCAG AA on their grounds', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(activeRoute: '/dashboard', theme: AppTheme.dark()),
    );

    final activeInk = tester.widget<Text>(find.text('Home')).style!.color!;
    final pillBg =
        (tester
                    .widget<Container>(
                      find.byKey(const ValueKey('bottom-nav-pill-/dashboard')),
                    )
                    .decoration
                as BoxDecoration)
            .color!;
    expect(
      contrastRatio(activeInk, pillBg),
      greaterThanOrEqualTo(4.5),
      reason: 'active label on the active pill is 10.5px text — AA is 4.5:1',
    );

    // The bar fill is 92% alpha over whatever scrolls beneath. For a LIGHT
    // ink the worst case is the LIGHTEST ground it can meet — composite over
    // surface3 (the palest real dark surface) before measuring.
    final inactiveInk = tester.widget<Text>(find.text('Tasks')).style!.color!;
    final barOnSurface3 = Color.alphaBlend(
      barDecoration(tester).color!,
      TiqColors.dark.surface3,
    );
    expect(
      contrastRatio(inactiveInk, barOnSurface3),
      greaterThanOrEqualTo(4.5),
      reason: 'inactive labels are 10.5px text on the frosted bar',
    );
  });

  testWidgets('light theme: rendered bar values are the shipped light set', (
    tester,
  ) async {
    // Byte-for-byte the sub-1 treatment — the theme system must be a no-op
    // for light. Pinned off the rendered tree under AppTheme.light().
    await tester.pumpWidget(
      _app(activeRoute: '/dashboard', theme: AppTheme.light()),
    );

    final bar = barDecoration(tester);
    expect(bar.color, const Color(0xEBFFFFFF));
    expect((bar.border as Border?)?.top.color, const Color(0xFFE3E5EA));
    expect(
      (tester
                  .widget<Container>(
                    find.byKey(const ValueKey('bottom-nav-pill-/dashboard')),
                  )
                  .decoration
              as BoxDecoration?)
          ?.color,
      const Color(0xFFEAF2FF),
    );
    expect(
      tester.widget<Text>(find.text('Home')).style!.color,
      const Color(0xFF0A6CF0),
    );
    expect(
      tester.widget<Text>(find.text('Tasks')).style!.color,
      const Color(0xFF5C6470),
    );
  });

  testWidgets('dark theme: menu sheet reads the dark surface and inks', (
    tester,
  ) async {
    await tester.pumpWidget(_app(theme: AppTheme.dark()));

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();

    // The sheet's panel is the top-rounded Container — it must carry the
    // dark surface token, not a hardcoded paper value.
    final panel = tester.widget<Container>(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).borderRadius ==
                const BorderRadius.vertical(top: Radius.circular(18)),
      ),
    );
    expect((panel.decoration! as BoxDecoration).color, TiqColors.dark.surface1);

    // Group headers carry the muted ink token, and stay AA-readable on the
    // sheet surface they actually sit on.
    final heading = tester.widget<Text>(find.text('OPERATE')).style!.color!;
    expect(heading, TiqColors.dark.ink3);
    expect(
      contrastRatio(heading, TiqColors.dark.surface1),
      greaterThanOrEqualTo(4.5),
      reason: 'sheet group labels are 10px text on surface1',
    );

    // Destination tiles + divider follow the hairline token.
    final tile = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const ValueKey('nav-sheet-/dashboard')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      ((tile.decoration! as BoxDecoration).border! as Border).top.color,
      TiqColors.dark.line,
    );
    final divider = tester.widget<Divider>(find.byType(Divider).first);
    expect(divider.color, TiqColors.dark.line);
  });
}

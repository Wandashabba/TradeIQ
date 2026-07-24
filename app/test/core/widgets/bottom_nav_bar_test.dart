import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/widgets/bottom_nav_bar.dart';

/// The bar is injected by ManagerScaffold below 1080 — here we pump it
/// directly to test its own contract. The ProviderScope exists for the menu
/// sheet, whose theme-toggle and sign-out rows are riverpod Consumers.
Widget _app({String activeRoute = '/dashboard'}) => ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Stack(children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: TiqBottomNavBar(activeRoute: activeRoute),
            ),
          ]),
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
}

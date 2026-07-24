import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/widgets/bottom_nav_bar.dart';
import 'package:tradeiq_app/core/widgets/manager_scaffold.dart';

import '../../helpers/routed_app.dart';

/// Drives the shell at a chosen viewport width. The shell's whole job is to
/// respond to width, so every test here sets one explicitly.
Future<void> _pumpAt(
  WidgetTester tester,
  double width, {
  String path = '/dashboard',
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    routedApp(
      const ManagerScaffold(title: 'Execution overview', body: Text('body')),
      path: path,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('at desktop width the rail is visible with its labels', (
    tester,
  ) async {
    await _pumpAt(tester, 1400);

    // No bottom bar — navigation is always on screen in the sidebar.
    expect(find.byType(TiqBottomNavBar), findsNothing);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
    // Grouped by verb, so the menu is scannable rather than a flat list of 20.
    expect(find.text('OPERATE'), findsOneWidget);
    expect(find.text('INSIGHT'), findsOneWidget);
    expect(find.text('CONFIGURE'), findsOneWidget);
  });

  testWidgets('below the breakpoint the rail gives way to the floating bar', (
    tester,
  ) async {
    await _pumpAt(tester, 900);

    // No rail, no drawer — the floating bar carries navigation.
    expect(find.byType(TiqBottomNavBar), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
    expect(find.byKey(const ValueKey('nav-/dashboard')), findsNothing);
    expect(find.text('OPERATE'), findsNothing);
    // The scaffold feeds the router location into the bar: Home is pilled.
    expect(
      find.byKey(const ValueKey('bottom-nav-pill-/dashboard')),
      findsOneWidget,
    );
  });

  testWidgets('phone width is the same bar mode — still no drawer', (
    tester,
  ) async {
    await _pumpAt(tester, 600);

    expect(find.byType(TiqBottomNavBar), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget);
  });

  testWidgets('every destination keeps its nav-<route> key on the rail', (
    tester,
  ) async {
    await _pumpAt(tester, 1400);

    for (final route in const [
      '/dashboard',
      '/tasks',
      '/alerts',
      '/orders',
      '/beatplans',
      '/reports',
      '/trends',
      '/territories',
      '/users',
      '/client-config',
    ]) {
      expect(
        find.byKey(ValueKey('nav-$route')),
        findsOneWidget,
        reason: 'missing destination $route',
      );
    }
  });

  testWidgets('the bar\'s Menu opens the sheet with every destination', (
    tester,
  ) async {
    await _pumpAt(tester, 900);

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();

    // The sidebar's full list, same three groups, now in the sheet.
    expect(find.text('OPERATE'), findsOneWidget);
    expect(find.text('INSIGHT'), findsOneWidget);
    expect(find.text('CONFIGURE'), findsOneWidget);
    expect(find.text('Webhooks'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('under reduced motion the pill does not animate', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await _pumpAt(tester, 900);

    final align = tester.widget<AnimatedAlign>(
      find.descendant(
        of: find.byType(TiqBottomNavBar),
        matching: find.byType(AnimatedAlign),
      ),
    );
    expect(align.duration, Duration.zero);
  });

  testWidgets('the persistent rail never animates its rows', (tester) async {
    await _pumpAt(tester, 1400);

    // The rail is furniture, not an event — its rows are never animated.
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('nav-/dashboard')), findsOneWidget);
  });

  testWidgets('page actions render alongside logout', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      routedApp(
        ManagerScaffold(
          title: 'Execution overview',
          actions: [TextButton(onPressed: () {}, child: const Text('Export CSV'))],
          body: const Text('body'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Export CSV'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsWidgets);
  });
}

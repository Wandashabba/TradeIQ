import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/manager_scaffold.dart';

import '../../helpers/routed_app.dart';

/// Drives the shell at a chosen viewport width. The rail's whole job is to
/// respond to width, so every test here sets one explicitly.
Future<void> _pumpAt(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    routedApp(
      const ManagerScaffold(title: 'Execution overview', body: Text('body')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('at desktop width the rail is visible with its labels', (
    tester,
  ) async {
    await _pumpAt(tester, 1400);

    // No drawer to open — navigation is always on screen.
    expect(find.byType(Drawer), findsNothing);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
    // Grouped by verb, so the menu is scannable rather than a flat list of 19.
    expect(find.text('OPERATE'), findsOneWidget);
    expect(find.text('INSIGHT'), findsOneWidget);
    expect(find.text('CONFIGURE'), findsOneWidget);
  });

  testWidgets('between the breakpoints the rail collapses to icons', (
    tester,
  ) async {
    await _pumpAt(tester, 900);

    // Still no drawer — the rail is present, just wordless.
    expect(find.byType(Drawer), findsNothing);
    expect(find.byKey(const ValueKey('nav-/dashboard')), findsOneWidget);
    // Labels are gone; the destination survives as an icon + tooltip.
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('OPERATE'), findsNothing);
  });

  testWidgets('at phone width it falls back to an overlay drawer', (
    tester,
  ) async {
    await _pumpAt(tester, 600);

    expect(find.byType(Drawer), findsNothing, reason: 'closed until opened');

    final scaffold = tester.firstState<ScaffoldState>(find.byType(Scaffold));
    scaffold.openDrawer();
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsOneWidget);
    // Same rows, same order, same keys as the rail.
    expect(find.byKey(const ValueKey('nav-/dashboard')), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('every destination keeps its nav-<path> key', (tester) async {
    await _pumpAt(tester, 1400);

    for (final path in const [
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
        find.byKey(ValueKey('nav-$path')),
        findsOneWidget,
        reason: 'missing destination $path',
      );
    }
  });

  testWidgets('the drawer scrim comes from the theme, not Flutter\'s default', (
    tester,
  ) async {
    await _pumpAt(tester, 600);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    // Dark keeps black54 — identical to the default, so dark is unchanged.
    // Light swaps in a deeper slate, which is the point of reading the token.
    expect(scaffold.drawerScrimColor, TiqColors.dark.scrim);
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

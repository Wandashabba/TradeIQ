import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/torch_press.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/dashboard/presentation/first_run_board.dart';
import 'package:tradeiq_app/features/dashboard/presentation/the_floor_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import 'floor_harness.dart';

/// THE FLOOR'S CHROME, PRESSED ON THE REAL SCREEN.
///
/// `chrome_test.dart` already presses a [TorchNavPill] in isolation and a
/// [TorchNavCircle] in isolation, and both pass — which is exactly why The
/// Floor shipped with four dead nav slots and a dead standing action. A pill
/// handed `onSelect: (i) => picked = i` reports its index perfectly; the pill
/// The Floor actually built was handed `(_) {}`, and `FloorScaffold`'s one
/// `onSelectSlot` seam was never filled in by either of its two callers.
///
/// So these tests stand the **route** up inside a router and press what a
/// manager's thumb presses. The assertion is never "the widget is there" or
/// "no exception was thrown" — it is where the app ended up.
///
/// The slots are found by their spoken label rather than their printed one on
/// purpose: in a widget test the fallback font is square-glyph, every nav
/// label overflows its measured slot, and the bar goes correctly icon-only.
/// A finder that needed the word "Work" would be testing the font.
void main() {
  final twoOutlets = <Outlet>[
    outlet('o1', 'Kasi Corner Spaza'),
    outlet('o2', 'Shoprite Klipspruit Mall'),
  ];

  final populated = <AlertItem>[
    alert(
      id: 'crit',
      message: 'Out of stock since Tuesday',
      outletId: 'o1',
      createdAt: DateTime.utc(2026, 9, 18, 6),
    ),
    alert(
      id: 'watch',
      severity: 'warning',
      message: 'Price above the published band',
      outletId: 'o2',
      createdAt: DateTime.utc(2026, 9, 18, 12),
    ),
  ];

  group('the nav pill navigates from The Floor', () {
    for (final (label, destination) in <(String, String)>[
      ('Work', '/tasks'),
      ('Ask', '/assistant'),
    ]) {
      testWidgets('$label goes to $destination', (tester) async {
        final handle = tester.ensureSemantics();
        final router = await pumpFloorRoute(
          tester,
          alerts: populated,
          outlets: twoOutlets,
        );

        await tester.tap(navSlot(label));
        await tester.pumpAndSettle();

        expect(
          currentRoute(router),
          destination,
          reason:
              'The nav pill on The Floor was handed a no-op closure, so every '
              'slot pressed, buzzed and went nowhere.',
        );
        handle.dispose();
      });
    }

    testWidgets('Floor, the active slot, stays where it is', (tester) async {
      final handle = tester.ensureSemantics();
      final router = await pumpFloorRoute(
        tester,
        alerts: populated,
        outlets: twoOutlets,
      );

      await tester.tap(navSlot('Floor'));
      await tester.pumpAndSettle();

      expect(currentRoute(router), '/dashboard');
      expect(find.byType(TheFloorScreen), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Menu opens the console menu sheet', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpFloorRoute(tester, alerts: populated, outlets: twoOutlets);

      await tester.tap(navSlot('Menu'));
      await tester.pumpAndSettle();

      // The menu's own rows, which exist nowhere else on this route.
      expect(
        find.byKey(const ValueKey<String>('menu-/outlets')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('menu-sign-out')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the first-run board carries the same live nav', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      // Nothing on the books at all: The Floor hands off to the board, which
      // wears the same `FloorScaffold` — and wore the same dead nav.
      final router = await pumpFloorRoute(tester, current: firstRunKpis());
      expect(find.byType(FirstRunBoard), findsOneWidget);

      await tester.tap(navSlot('Work'));
      await tester.pumpAndSettle();

      expect(currentRoute(router), '/tasks');
      handle.dispose();
    });
  });

  group('the standing action', () {
    testWidgets('the + circle opens the standing-action sheet', (tester) async {
      await pumpFloorRoute(tester, alerts: populated, outlets: twoOutlets);

      await tester.tap(find.byType(TorchNavCircle));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('floor-standing-raise-task')),
        findsOneWidget,
        reason:
            'The circle was handed `onPressed: () {}` — it pressed, it buzzed '
            'and nothing opened.',
      );
      expect(
        find.byKey(const ValueKey<String>('floor-standing-assign-visit')),
        findsOneWidget,
      );
    });

    testWidgets('choosing Assign a visit leaves for dispatch', (tester) async {
      final router = await pumpFloorRoute(
        tester,
        alerts: populated,
        outlets: twoOutlets,
      );

      await tester.tap(find.byType(TorchNavCircle));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('floor-standing-assign-visit')),
      );
      await tester.pumpAndSettle();

      expect(currentRoute(router), '/dispatch');
    });
  });

  group('nothing is painted over the chrome', () {
    testWidgets('every nav target clears the tap floor and wins the hit test '
        'at its own centre', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpFloorRoute(tester, alerts: populated, outlets: twoOutlets);

      final skin = TiqSkin.night();
      final targets = <String, Finder>{
        for (final label in const <String>['Floor', 'Work', 'Ask', 'Menu'])
          label: find.descendant(
            of: navSlot(label),
            matching: find.byType(TorchPressable),
          ),
        'the + circle': find.descendant(
          of: find.byType(TorchNavCircle),
          matching: find.byType(TorchPressable),
        ),
      };

      targets.forEach((name, finder) {
        expect(finder, findsOneWidget, reason: '$name has no pressable');
        final size = tester.getSize(finder);
        expect(
          size.height,
          greaterThanOrEqualTo(skin.space.tapTarget),
          reason: '$name is only ${size.height}dp tall',
        );
        // The thing under the target's own centre has to be the target. A
        // scrolling body painted over the nav, a full-bleed scrim without an
        // `IgnorePointer`, or a `Positioned` hanging outside its `Stack` would
        // all show up right here as a different hit-test victim.
        final render = tester.renderObject(finder);
        expect(
          tester
              .hitTestOnBinding(tester.getCenter(finder))
              .path
              .any((entry) => entry.target == render),
          isTrue,
          reason: '$name is covered by something above it',
        );
      });
      handle.dispose();
    });
  });
}

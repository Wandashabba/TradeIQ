import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/torch_press.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/features/dashboard/presentation/first_run_board.dart';
import 'package:tradeiq_app/features/dashboard/presentation/the_floor_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../assistant/ask_harness.dart' show ScriptedRepository, rankedTurn;
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

  /// ── THE DESTINATIONS, AFTER THE NAV PILL LEFT ──────────────────────
  ///
  /// The Floor gave up its nav pill on 30 September 2026 so the composer could
  /// have the bottom of the screen. Every destination it carried is still one
  /// tap away, through a labelled control on the plate — and that is what
  /// these tests press. They are the old nav-pill tests with the chrome
  /// changed under them: the assertion is still never "the widget is there",
  /// it is still where the app ended up.
  group('the destinations open from the plate', () {
    testWidgets('the Menu control opens the destinations sheet', (
      tester,
    ) async {
      await pumpFloorRoute(tester, alerts: populated, outlets: twoOutlets);

      await tester.tap(
        find.byKey(const ValueKey<String>('floor-destinations')),
      );
      await tester.pumpAndSettle();

      // The two slots the pill carried that this screen is not, with their
      // own live numbers on them — which is what makes the control worth
      // pressing rather than an icon a manager has to learn.
      expect(
        find.byKey(const ValueKey<String>('floor-destination-work')),
        findsOneWidget,
      );
      expect(find.text('2 things need a decision'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('floor-destination-overview')),
        findsOneWidget,
      );

      // …and the console's own menu underneath, unchanged: one destination
      // list, read from `managerDestinations`, not a second copy.
      expect(
        find.byKey(const ValueKey<String>('menu-/outlets')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('menu-sign-out')),
        findsOneWidget,
      );

      // Put the sheet away before the test ends: `TorchSheets` counts open
      // sheets process-wide so it can refuse a second one, and a sheet left
      // standing when the tree is torn down makes the NEXT test's sheet the
      // illegal second.
      await tester.tapAt(const Offset(180, 8));
      await tester.pumpAndSettle();
    });

    for (final (key, destination) in const <(String, String)>[
      ('floor-destination-work', '/tasks'),
      ('floor-destination-overview', '/dashboard/overview'),
      ('floor-standing-raise-task', '/tasks'),
      ('floor-standing-assign-visit', '/dispatch'),
    ]) {
      testWidgets('$key goes to $destination', (tester) async {
        final router = await pumpFloorRoute(
          tester,
          alerts: populated,
          outlets: twoOutlets,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('floor-destinations')),
        );
        await tester.pumpAndSettle();
        // The sheet is a scroll view and carries the whole console menu under
        // these rows, so the standing-action pair is below its fold on a
        // 640dp phone. Scroll to the row rather than tapping where it would
        // have been — a tap into empty space reports the same failure as a
        // dead row and means something completely different.
        final row = find.byKey(ValueKey<String>(key));
        await tester.scrollUntilVisible(row, 120, scrollable: find.descendant(
          of: find.byType(TorchSheet),
          matching: find.byType(Scrollable),
        ).first);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();

        expect(
          currentRoute(router),
          destination,
          reason:
              'The destinations sheet is the only way off this screen now '
              'that the nav pill has gone. A row that opens nothing is the '
              'dead nav slot defect again, one layer down.',
        );
      });
    }

    /// ── WHERE THE DECISION LIST IS REACHED FROM, NOW THAT IT IS GONE ────
    ///
    /// The approved arrangement replaces the list with the briefing. "Nothing
    /// becomes unreachable" is only a claim until something presses it, and
    /// this is the press: three routes in, all above the fold, all off the
    /// same `FloorView.decisions` the list was drawn from.
    group('the decisions are still one tap away', () {
      for (final (key, destination, what) in const <(String, String, String)>[
        ('floor-brief-overdue', '/tasks', 'the count opens the worklist'),
        (
          'floor-brief-worst-outlet',
          '/alerts',
          'the worst outlet opens its own finding',
        ),
      ]) {
        testWidgets(what, (tester) async {
          final router = await pumpFloorRoute(
            tester,
            alerts: populated,
            outlets: twoOutlets,
          );

          await tester.tap(find.byKey(ValueKey<String>(key)));
          await tester.pumpAndSettle();

          expect(
            currentRoute(router),
            destination,
            reason:
                'A briefing line that cannot be opened is the end of the road '
                'for a fact, and this one replaced five rows that each opened '
                'something.',
          );
        });
      }

      testWidgets('and the Menu row carries the live count', (tester) async {
        await pumpFloorRoute(tester, alerts: populated, outlets: twoOutlets);
        await tester.tap(
          find.byKey(const ValueKey<String>('floor-destinations')),
        );
        await tester.pumpAndSettle();
        expect(find.text('2 things need a decision'), findsOneWidget);
        await tester.tapAt(const Offset(180, 8));
        await tester.pumpAndSettle();
      });
    });

    testWidgets('the controls leave the plate while an answer is read, and '
        'Back to the briefing is one tap to both', (tester) async {
      // THE OTHER HALF OF "NOTHING BECOMES UNREACHABLE". The approved mockup
      // draws the shrunken plate bare — there is no band above its strip light
      // to put a 44dp control in (`floor_proportion_test.dart` has the
      // arithmetic) — and the first fix for that put the pair on the ground
      // under the plate, which is the second header the owner rejected.
      //
      // So they are simply not drawn while answering, and the way back to them
      // is the control that is drawn: `Back to the briefing`, directly above
      // the transcript.
      await pumpFloorRoute(
        tester,
        alerts: populated,
        outlets: twoOutlets,
        size: const Size(390, 844),
        assistant: ScriptedRepository(rankedTurn()),
      );

      expect(find.byKey(const ValueKey<String>('floor-scope-chip')),
          findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('ask-composer-field')),
        'Why is 72 down?',
      );
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('floor-scope-chip')),
        findsNothing,
        reason:
            'a control under the shrunken plate is the stacked-header defect; '
            'a control ON it splits the strip light in two',
      );
      expect(
        find.byKey(const ValueKey<String>('floor-destinations')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('floor-clear-answers')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('floor-scope-chip')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('floor-destinations')),
        findsOneWidget,
      );
    });

    testWidgets('the scope chip still opens the scope sheet', (tester) async {
      await pumpFloorRoute(tester, alerts: populated, outlets: twoOutlets);

      await tester.tap(find.byKey(const ValueKey<String>('floor-scope-chip')));
      await tester.pumpAndSettle();

      // The overview's own range chips, which is what this chip has always
      // opened and still does — one filter for both screens, so two figures
      // can never silently disagree about which slice of time they show.
      expect(
        find.byKey(const ValueKey<String>('scope-range-last30')),
        findsOneWidget,
      );

      await tester.tapAt(const Offset(180, 8));
      await tester.pumpAndSettle();
    });

    testWidgets('the first-run board KEEPS its nav pill', (tester) async {
      final handle = tester.ensureSemantics();
      // Nothing on the books at all: The Floor hands off to the board, which
      // wears the same `FloorScaffold` — and is deliberately NOT the Ask
      // landing. It has no composer, nothing to ask about and no briefing to
      // stand on, so it keeps the four labelled tabs. The seam that decides
      // this is `FloorScaffold.showNavPill`.
      final router = await pumpFloorRoute(tester, current: firstRunKpis());
      expect(find.byType(FirstRunBoard), findsOneWidget);
      expect(find.byType(TorchNavPill), findsOneWidget);

      await tester.tap(navSlot('Work'));
      await tester.pumpAndSettle();

      expect(currentRoute(router), '/tasks');
      handle.dispose();
    });

    testWidgets('The Floor proper has no nav pill and no circle', (
      tester,
    ) async {
      await pumpFloorRoute(tester, alerts: populated, outlets: twoOutlets);

      expect(find.byType(TheFloorScreen), findsOneWidget);
      expect(
        find.byType(TorchNavPill),
        findsNothing,
        reason:
            'The pill is what made this arrangement cost an amber grant to '
            'chrome. Its absence is the change, and it is asserted rather '
            'than left to a render nobody diffs.',
      );
      expect(find.byType(TorchNavCircle), findsNothing);
    });
  });

  group('nothing is painted over the chrome', () {
    /// THE TARGETS CHANGED; THE RULE DID NOT.
    ///
    /// This walked the four nav slots and the `+` circle. Both are gone from
    /// this route, so it walks what replaced them: the two controls on the
    /// plate's top band, and then the composer separately.
    ///
    /// The composer is the one worth having here. It is a `TorchShell.band` —
    /// a pinned sibling of the scroll view rather than an overlay — and the
    /// failure it is exposed to is precisely the one the nav row used to be:
    /// a body that scrolls over the thing pinned beneath it.
    testWidgets('every fixed target clears the tap floor and wins the hit '
        'test at its own centre', (tester) async {
      await pumpFloorRoute(tester, alerts: populated, outlets: twoOutlets);

      final skin = TiqSkin.night();
      final targets = <String, Finder>{
        'the scope chip': find.descendant(
          of: find.byKey(const ValueKey<String>('floor-scope-chip')),
          matching: find.byType(TorchPressable),
        ),
        'the Menu control': find.descendant(
          of: find.byKey(const ValueKey<String>('floor-destinations')),
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
        // scrolling body painted over the composer, a full-bleed scrim
        // without an `IgnorePointer`, or a `Positioned` hanging outside its
        // `Stack` would all show up right here as a different hit-test
        // victim.
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
    });

    testWidgets('the composer sits above the scroll view, not under it', (
      tester,
    ) async {
      await pumpFloorRoute(tester, alerts: populated, outlets: twoOutlets);

      final field = find.byKey(const ValueKey<String>('ask-composer-field'));
      expect(field, findsOneWidget);

      // The trough's own centre belongs to the trough. The plate, the
      // briefing and the decision list all scroll behind it, and the band is
      // a sibling rather than an overlay precisely so this cannot go wrong at
      // 2.0x — where the region is taller than the tokens that would have
      // been used to reserve room for it.
      final render = tester.renderObject(field);
      expect(
        tester
            .hitTestOnBinding(tester.getCenter(field))
            .path
            .any((entry) => entry.target == render),
        isTrue,
        reason: 'the scroll view is painted over the composer',
      );
    });
  });
}

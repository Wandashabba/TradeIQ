import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/widgets/torchlight/console_palette.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';

import 'floor_harness.dart';
import 'seeded_territories.dart';

/// THE MENU ON A DESK IS A PALETTE, AND IT CARRIES THE TERRITORIES.
///
/// > *"I don't like this menu on desktop… make it dynamic and very creative"*
/// > and *"Also on the desktop we can't change territories"* — the owner,
/// > 6 October 2026, choosing **B, the command palette**.
///
/// Two complaints with one cause. The menu and the scope were both phone
/// bottom-sheets stretched across the window — measured on the live console, a
/// province row ran from x=20 to x=1420, a 1400dp line with one word on it.
/// The palette replaces the first and absorbs the second, so the two questions
/// a manager has are answered by one keystroke.
///
/// The phone is untouched and the first group of tests is what says so.
void main() {
  Future<void> openMenu(WidgetTester tester, Size size) async {
    await pumpFloorRoute(
      tester,
      size: size,
      current: kpis(),
      previous: kpis(),
      byTerritory: <String, DashboardKpis>{'t-gp-tsh': kpis(execution: 51)},
      territories: seededTerritories,
    );
    await tester.tap(find.byKey(const ValueKey<String>('floor-destinations')));
    await tester.pumpAndSettle();
  }

  group('the phone keeps its sheet', () {
    testWidgets('360x640 opens the menu sheet, not a palette', (tester) async {
      await openMenu(tester, const Size(360, 640));
      expect(find.byType(ConsolePalette), findsNothing);
      expect(find.byType(TorchSheet), findsOneWidget);
      // Leave nothing open: TorchSheets.openCount is process-wide.
      await tester.tapAt(const Offset(180, 20));
      await tester.pumpAndSettle();
    });
  });

  group('the desk gets the palette', () {
    const desk = Size(1440, 900);

    testWidgets('1440x900 opens a palette and no sheet', (tester) async {
      await openMenu(tester, desk);
      expect(find.byType(ConsolePalette), findsOneWidget);
      expect(find.byType(TorchSheet), findsNothing);
    });

    testWidgets('it is a column, not a stretched row', (tester) async {
      // The complaint in one number. The scope sheet drew its rows the full
      // width of the window; the palette is capped so a line of text is a line
      // of text rather than a metre of ground with one word on it.
      await openMenu(tester, desk);
      final box = tester.getRect(find.byKey(const ValueKey<String>('palette-card')));
      expect(
        box.width,
        lessThanOrEqualTo(700),
        reason: 'a palette row must not run the width of a 1440dp window',
      );
    });

    testWidgets('typing reaches a territory, which is how scope is changed '
        'on a desk at all', (tester) async {
      await openMenu(tester, desk);

      // TYPED, NOT SCROLLED, and that is the palette working rather than a
      // concession to the test. The scope rows sit below fourteen
      // destinations, so reaching them by eye means scrolling a list; reaching
      // them by name is two keystrokes and is the entire argument for this
      // shape over a grid.
      await tester.enterText(
        find.byKey(const ValueKey<String>('palette-query')),
        'Tshwane',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('palette-row-scope-t-gp-tsh')),
        findsOneWidget,
        reason: 'a territory is reachable by typing its name',
      );
      // And the destinations that do not match are gone, which is what makes
      // the one that matters findable at all.
      expect(
        find.byKey(const ValueKey<String>('palette-row-dest-/tasks')),
        findsNothing,
      );
    });

    testWidgets('choosing a territory closes the palette and applies it', (
      tester,
    ) async {
      await openMenu(tester, desk);
      await tester.enterText(
        find.byKey(const ValueKey<String>('palette-query')),
        'Tshwane',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('palette-row-scope-t-gp-tsh')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(ConsolePalette),
        findsNothing,
        reason: 'choosing a scope closes the palette',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('destinations are reachable by typing too', (tester) async {
      await openMenu(tester, desk);
      // Below the fold at rest, because the thirteen territories lead — so
      // reached the same way a territory is, by name.
      await tester.enterText(
        find.byKey(const ValueKey<String>('palette-query')),
        'Tasks',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('palette-row-dest-/tasks')),
        findsOneWidget,
      );
    });
  });

  group('it is drawn, not merely present', () {
    const desk = Size(1440, 900);

    testWidgets('no row inherits the debug fallback style', (tester) async {
      // THE BUG THIS SHIPPED WITH, pinned so it cannot come back.
      //
      // `TorchShell` wraps every screen in a `DefaultTextStyle`; a palette is
      // pushed with `showGeneralDialog` and lands outside it, where `Text`
      // merges onto `DefaultTextStyle.fallback()` — yellow, double-underlined,
      // Flutter's way of saying nobody told it how to draw this. A style passed
      // to `Text` overrides the colour and NOT the decoration, so the first
      // build looked deliberately painted rather than broken, and the owner saw
      // it before I did.
      //
      // The decoration is the tell, so the decoration is what is asserted.
      await openMenu(tester, desk);

      final texts = tester.widgetList<Text>(find.byType(Text));
      expect(texts, isNotEmpty);
      for (final text in texts) {
        final resolved = text.style;
        expect(
          resolved?.decoration,
          anyOf(isNull, TextDecoration.none),
          reason: 'row "${text.data}" is drawing with an underline, which '
              'means it is inheriting the debug fallback style',
        );
      }
    });

    testWidgets('the search line says what it is for when empty', (
      tester,
    ) async {
      // `EditableText` is the raw control and draws nothing at all when empty.
      // The palette opens empty by definition, so without a hint the first
      // thing anyone sees is a blank strip where the search should be — which
      // is exactly what shipped.
      await openMenu(tester, desk);
      expect(find.text('Go to, or scope to…'), findsOneWidget);
    });

    testWidgets('scope comes before destinations', (tester) async {
      // The desk already carries a permanent left rail with every destination
      // on it. A palette that repeats that rail first, and pushes the
      // territories below the fold, is duplicating what is on screen while
      // burying the one thing a manager cannot otherwise reach.
      await openMenu(tester, desk);
      // Narrowed so both sections fit the viewport at once: "Free State" is
      // the only territory that matches and "Perfect Store" the only
      // destination, so their order on screen IS the order of the sections.
      await tester.enterText(
        find.byKey(const ValueKey<String>('palette-query')),
        'st',
      );
      await tester.pumpAndSettle();

      final scope = tester.getRect(
        find.byKey(const ValueKey<String>('palette-row-scope-t-fs')),
      );
      final dest = tester.getRect(
        find.byKey(const ValueKey<String>('palette-row-dest-/dashboard/overview')),
      );
      expect(
        scope.top,
        lessThan(dest.top),
        reason: 'the territories lead; the rail already has the destinations',
      );
    });
  });
}

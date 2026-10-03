import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/nav_destinations.dart';
import 'package:tradeiq_app/core/widgets/torchlight/console_desk.dart';
import 'package:tradeiq_app/core/widgets/torchlight/menu_sheet.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';
import 'package:tradeiq_app/features/alerts/presentation/alerts_screen.dart';
import 'package:tradeiq_app/features/assistant/answer/composer.dart';
import 'package:tradeiq_app/features/webhooks/presentation/webhooks_screen.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

import '../../design/amber_golden.dart';
import 'console_desk_harness.dart';

/// THE DESK, PINNED — the measurements, as against the pictures.
///
/// `console_desk_look_test.dart` produces images and does not run in CI. This
/// is the half that does: the threshold's arithmetic, the rail's contents, the
/// claim that nothing below the threshold moved, the two seamlessness
/// promises, and the amber census.
void main() {
  final night = TiqSkin.night();
  final day = TiqSkin.day();

  setUpAll(loadDeskFonts);

  // ── THE THRESHOLD ────────────────────────────────────────────────────
  group('the threshold is derived, and the derivation is printed', () {
    test('deskMinWidth is the sum of its seven terms, and it is 1132', () {
      for (final (name, skin) in <(String, TiqSkin)>[
        ('night', night),
        ('day', day),
      ]) {
        final space = skin.space;
        final sum =
            2 * space.gutterWide +
            ConsoleDesk.railWidth +
            2 * space.blockGap +
            ConsoleDesk.listMinWidth +
            TiqSpace.readingWidth;
        // ignore: avoid_print
        print(
          'deskMinWidth [$name] = '
          '2×${space.gutterWide} gutterWide + ${ConsoleDesk.railWidth} rail + '
          '2×${space.blockGap} blockGap + ${ConsoleDesk.listMinWidth} list + '
          '${TiqSpace.readingWidth} readingWidth = $sum',
        );
        expect(ConsoleDesk.deskMinWidth(skin), sum);
        expect(sum, 1132);
      }
    });

    test(
      'the desk cannot exist where the shell still spends a phone gutter',
      () {
        // `TiqSpace.gutterFor` switches at 1080. If the threshold ever fell
        // below it the derivation would be using a gutter the shell is not
        // actually drawing, and every pane would be 20dp out.
        for (final skin in <TiqSkin>[night, day]) {
          final at = ConsoleDesk.deskMinWidth(skin);
          expect(
            skin.space.gutterFor(at).left,
            skin.space.gutterWide,
            reason:
                'At the threshold ($at) the shell is still on its phone gutter, '
                'so deskMinWidth is self-inconsistent: it is computed from '
                'gutterWide and drawn with gutter.',
          );
        }
      },
    );

    test(
      'deskMinHeight is what the panes need, and it is not EntryFrame\'s 900',
      () {
        for (final (name, skin) in <(String, TiqSkin)>[
          ('night', night),
          ('day', day),
        ]) {
          final h = ConsoleDesk.deskMinHeight(skin);
          // ignore: avoid_print
          print(
            'deskMinHeight [$name] = 24 top + 72 header + 24 gap + '
            '3×${skin.space.rowMinHeight} rows + ${skin.space.blockGap} + '
            '${QuestionComposer.barExtent} bar + ${skin.space.blockGap} = $h',
          );
          expect(h, 348);
          // THE NUMBER THAT WOULD HAVE COST SOMETHING. A 1280×800 laptop is the
          // commonest small desktop viewport there is; `EntryFrame.pageMinHeight`
          // would have handed it the phone column on a 1280dp window.
          expect(
            ConsoleDesk.isDesk(skin, const Size(1280, 800)),
            isTrue,
            reason:
                'A 1280×800 laptop must get the desk. Quoting EntryFrame\'s 900 '
                'instead of its method is what would stop it.',
          );
        }
      },
    );

    test('the two approved widths are desks and the phones are not', () {
      for (final skin in <TiqSkin>[night, day]) {
        expect(ConsoleDesk.isDesk(skin, const Size(1440, 900)), isTrue);
        expect(ConsoleDesk.isDesk(skin, const Size(1280, 900)), isTrue);
        expect(ConsoleDesk.isDesk(skin, const Size(390, 844)), isFalse);
        expect(ConsoleDesk.isDesk(skin, const Size(360, 640)), isFalse);
        // A phone in landscape. `EntryFrame` needed a height test to exclude
        // these; at 1120 the width test already does, which is the whole of
        // why this file does not quote 900.
        expect(ConsoleDesk.isDesk(skin, const Size(852, 393)), isFalse);
        expect(ConsoleDesk.isDesk(skin, const Size(1024, 768)), isFalse);
        // One pixel either side of the line.
        final w = ConsoleDesk.deskMinWidth(skin);
        expect(ConsoleDesk.isDesk(skin, Size(w, 900)), isTrue);
        expect(ConsoleDesk.isDesk(skin, Size(w - 1, 900)), isFalse);
      }
    });
  });

  // ── THE RAIL'S WIDTH, MEASURED ───────────────────────────────────────
  //
  // `entry_width_test.dart`'s method, applied to the one new width this
  // change introduces: lay every destination label out with a `TextPainter` in
  // the app's own face and print the widest, so the next type-scale move fails
  // with the new number in the failure rather than drifting quietly.
  test('every destination label fits the rail on one line at 1.0x', () {
    final l10n = englishLocalizations;
    // The row's structure, from `MenuDestinationRow`: two indents, its own
    // padding on both sides, the glyph and the gap after it.
    const structure =
        2 * MenuDestinationRow.indent +
        2 * TiqSpace.s3 +
        MenuDestinationRow.glyph +
        TiqSpace.s3;
    final available = ConsoleDesk.railWidth - structure;
    final style = night.text.bodyStrong.style(color: const Color(0xFF000000));

    var widest = 0.0;
    var widestLabel = '';
    final over = <String>[];
    for (final destination in managerDestinations) {
      final label = destination.labelIn(l10n);
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = painter.width;
      if (w > widest) {
        widest = w;
        widestLabel = label;
      }
      if (w > available) over.add('$label (${w.toStringAsFixed(1)}dp)');
      painter.dispose();
    }

    // The group markers go through the same column.
    for (final group in NavGroup.values) {
      final painter = TextPainter(
        text: TextSpan(
          text: menuGroupLabel(l10n, group).toUpperCase(),
          style: night.text.eyebrow.style(color: const Color(0xFF000000)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      if (painter.width > ConsoleDesk.railWidth) {
        over.add('marker ${menuGroupLabel(l10n, group)}');
      }
      painter.dispose();
    }

    // ignore: avoid_print
    print(
      'THE RAIL, MEASURED: railWidth ${ConsoleDesk.railWidth} '
      '− $structure of structure = ${available.toStringAsFixed(1)}dp for a '
      'label. The widest of the 24 is "$widestLabel" at '
      '${widest.toStringAsFixed(2)}dp in Schibsted Grotesk at '
      '${night.text.bodyStrong.size}, which leaves '
      '${(available - widest).toStringAsFixed(2)}dp.',
    );
    expect(
      over,
      isEmpty,
      reason:
          'These destination labels do not fit ${ConsoleDesk.railWidth}dp of '
          'rail on one line: ${over.join(', ')}. Either the type scale moved '
          'or a destination was named longer than the rail — re-derive '
          'ConsoleDesk.railWidth from the number printed above rather than '
          'rounding it up.',
    );
  });

  // ── THE RAIL IS THE MENU, UN-COLLAPSED ───────────────────────────────
  group('the rail', () {
    testWidgets('is the same groups, the same names and the same counts', (
      tester,
    ) async {
      await pumpDesk(
        tester,
        const AlertsScreen(),
        size: const Size(1440, 900),
        path: '/alerts',
        overrides: deskAlertOverrides(),
        users: deskPeople(),
      );

      // EVERY DESTINATION, ONCE — collected by scrolling the rail.
      //
      // The rail is a `ListView`, which is the whole point: 27 rows at the
      // 44dp floor is 1,188dp and a 900dp window does not hold them. So a row
      // below the fold is not in the tree, and asserting `findsOneWidget` on
      // all 24 at once would be asserting that the rail does NOT scroll.
      final seen = <String>{};
      final markers = <String>{};
      final rail = find.byKey(const ValueKey<String>('console-rail'));
      for (var step = 0; step < 24; step++) {
        for (final row in tester.widgetList<MenuDestinationRow>(
          find.descendant(of: rail, matching: find.byType(MenuDestinationRow)),
        )) {
          seen.add(row.destination.route);
        }
        // The markers scroll off with their groups, so they are collected on
        // the way past rather than read off the last frame.
        for (final marker in tester.widgetList<SectionRule>(
          find.descendant(of: rail, matching: find.byType(SectionRule)),
        )) {
          markers.add(marker.name);
        }
        if (seen.length == managerDestinations.length) break;
        await tester.drag(rail, const Offset(0, -200));
        await tester.pump();
      }
      expect(
        seen,
        containsAll(managerDestinations.map((d) => d.route)),
        reason:
            'A destination is in managerDestinations and not in the rail. The '
            'rail IS that list; a destination that appears in the menu sheet '
            'and not here is the second navigation this change exists not to '
            'create. Missing: '
            '${managerDestinations.map((d) => d.route).where((r) => !seen.contains(r)).join(', ')}',
      );
      expect(seen, hasLength(managerDestinations.length));

      // The three markers, with the sheet's own counts, not invented ones.
      for (final group in NavGroup.values) {
        final label = menuGroupLabel(englishLocalizations, group);
        expect(
          // `SectionRule` uppercases for DISPLAY, so the rendered `Text` is
          // not this string. The widget's own `name` is, which is also the
          // string a screen reader is handed.
          markers,
          contains(label),
          reason: 'The rail prints "$label" exactly as the fold header does.',
        );
      }
      // ignore: avoid_print
      print(
        'THE RAIL: ${managerDestinations.length} destinations under '
        '${NavGroup.values.map((g) => menuGroupLabel(englishLocalizations, g)).join(', ')}',
      );
    });

    testWidgets('marks the destination the route is standing on, and only it', (
      tester,
    ) async {
      await pumpDesk(
        tester,
        const AlertsScreen(),
        size: const Size(1440, 900),
        path: '/alerts',
        overrides: deskAlertOverrides(),
        users: deskPeople(),
      );
      final here = tester
          .widgetList<MenuDestinationRow>(find.byType(MenuDestinationRow))
          .where((r) => r.here)
          .toList();
      expect(here, hasLength(1));
      expect(here.single.destination.route, '/alerts');
    });

    testWidgets('every rail row clears the tap-target floor', (tester) async {
      await pumpDesk(
        tester,
        const AlertsScreen(),
        size: const Size(1440, 900),
        path: '/alerts',
        overrides: deskAlertOverrides(),
        users: deskPeople(),
      );
      final floor = night.space.tapTarget;
      var smallest = double.infinity;
      for (final destination in managerDestinations) {
        final finder = find.byKey(
          ValueKey<String>('rail-${destination.route}'),
        );
        // The rail scrolls, so a row below the fold has no box to measure.
        if (tester.widgetList(finder).isEmpty) continue;
        final rect = tester.getRect(finder);
        if (rect.height == 0) continue;
        smallest = rect.height < smallest ? rect.height : smallest;
        expect(
          rect.height,
          greaterThanOrEqualTo(floor),
          reason:
              '${destination.route} is ${rect.height}dp tall against a '
              '${floor}dp floor. WCAG 2.5.5 is not a design axis.',
        );
      }
      // ignore: avoid_print
      print('THE RAIL\'S SHORTEST ROW ON SCREEN: ${smallest}dp (floor $floor)');
    });
  });

  // ── BELOW THE THRESHOLD, NOTHING CHANGES ─────────────────────────────
  group('below the threshold', () {
    for (final (name, size) in <(String, Size)>[
      ('390x844', Size(390, 844)),
      ('360x640', Size(360, 640)),
    ]) {
      testWidgets('$name renders no rail and no pane at all', (tester) async {
        await pumpDesk(
          tester,
          const AlertsScreen(),
          size: size,
          path: '/alerts',
          overrides: deskAlertOverrides(),
          users: deskPeople(),
        );
        expect(find.byType(ConsoleRail), findsNothing);
        expect(
          find.byKey(const ValueKey<String>('console-rail')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('console-list')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('console-detail')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('console-column')),
          findsNothing,
        );
        // And the phone's own ask bar is still the shell's band.
        expect(find.byType(QuestionComposer), findsOneWidget);
      });
    }
  });

  // ── A ROUTE THAT IS NOT A LIST ───────────────────────────────────────
  testWidgets('a non-list route gets the rail and ONE centred column', (
    tester,
  ) async {
    await pumpDesk(
      tester,
      const WebhooksScreen(),
      size: const Size(1440, 900),
      path: '/webhooks',
      overrides: deskWebhookOverrides(),
    );
    expect(find.byType(ConsoleRail), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('console-column')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('console-detail')),
      findsNothing,
      reason:
          'Webhooks has no record detail — its rows expand in place. A third '
          'pane here would be a pane whose content is an apology.',
    );
    final column = tester.getRect(
      find.byKey(const ValueKey<String>('console-column')),
    );
    // ignore: avoid_print
    print(
      'THE ONE-COLUMN ROUTE: the column pane is ${column.width}dp wide and its '
      'content is capped at '
      '${ConsoleDeskBody.columnMaxWidth(night)}dp — the space the list and '
      'detail panes occupy together at the threshold.',
    );
  });

  // ── SMOOTH AND SEAMLESS, AS TWO MEASUREMENTS ─────────────────────────
  group('seamless', () {
    testWidgets('selecting a record does not refetch anything', (tester) async {
      final repository = CountingAlerts();
      await pumpDesk(
        tester,
        const AlertsScreen(),
        size: const Size(1440, 900),
        path: '/alerts',
        overrides: deskAlertOverrides(alerts: repository),
        users: deskPeople(),
      );
      final before = repository.listCalls;
      expect(before, greaterThan(0));

      await tester.tap(find.byKey(const ValueKey<String>('console-record-a2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('console-record-a1')));
      await tester.pumpAndSettle();

      expect(
        repository.listCalls,
        before,
        reason:
            'Choosing a record asked the server again. The detail is a '
            'WidgetBuilder over data the list already had; nothing in '
            'console_desk.dart may touch a repository.',
      );
      // ignore: avoid_print
      print(
        'SELECTION: $before list call(s) before two selections, '
        '${repository.listCalls} after.',
      );
    });

    testWidgets('crossing the threshold keeps the selection and does not throw', (
      tester,
    ) async {
      await pumpDesk(
        tester,
        const AlertsScreen(),
        size: const Size(1440, 900),
        path: '/alerts',
        overrides: deskAlertOverrides(),
        users: deskPeople(),
      );
      await tester.tap(find.byKey(const ValueKey<String>('console-record-a2')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('alert-detail-a2')),
        findsOneWidget,
      );

      // Down to a phone, and back. The two arms are different widget types, so
      // this is the drag that unmounts one element tree and mounts the other.
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.byType(ConsoleRail), findsNothing);

      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('alert-detail-a2')),
        findsOneWidget,
        reason:
            'The selection did not survive the window crossing the threshold. '
            'ConsoleDeskScope is outside the LayoutBuilder for exactly this.',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'a selected record that leaves the list is deselected, not stale',
      (tester) async {
        await pumpDesk(
          tester,
          const AlertsScreen(),
          size: const Size(1440, 900),
          path: '/alerts',
          overrides: deskAlertOverrides(),
          users: deskPeople(),
        );
        // a3 is the acknowledged one, so it is not in the default `Open` slice.
        await tester.tap(
          find.byKey(const ValueKey<String>('console-record-a2')),
        );
        await tester.pumpAndSettle();
        // Narrow the filter to Critical: a2 is a warning and drops out.
        await tester.tap(find.byKey(const ValueKey<String>('filter-critical')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('alert-detail-a2')),
          findsNothing,
          reason:
              'The detail pane is still showing a record the list no longer '
              'contains, which is worse than showing nothing: it is a record '
              'the manager can no longer find.',
        );
        expect(
          find.byKey(const ValueKey<String>('console-detail-at-rest')),
          findsOneWidget,
        );
      },
    );
  });

  // ── THE AMBER CENSUS ─────────────────────────────────────────────────
  //
  // Night budgets 2, Day 1. The desk adds a rail, a list pane and a detail
  // pane and should add no light: a rail is navigation, a selection is not a
  // commit, and the one lit object on a console screen is the ask bar's Send.
  group('the amber census, at desk width', () {
    for (final (skinName, skin) in <(String, TiqSkin)>[
      ('night', night),
      ('day', day),
    ]) {
      for (final (phase, selected) in <(String, bool)>[
        ('at rest', false),
        ('a record open', true),
      ]) {
        testWidgets('$skinName, $phase', (tester) async {
          await pumpDesk(
            tester,
            const AlertsScreen(),
            size: const Size(1440, 900),
            skin: skin,
            path: '/alerts',
            overrides: deskAlertOverrides(),
            users: deskPeople(),
          );
          if (selected) {
            await tester.tap(
              find.byKey(const ValueKey<String>('console-record-a2')),
            );
            await tester.pumpAndSettle();
          }
          final census = await amberCensus(tester);
          // ignore: avoid_print
          print('DESK 1440x900 $skinName / $phase: ${census.describe()}');
          expectWithinAmberBudget(
            census,
            skin,
            route: 'exceptions (desk)',
            phase: phase,
          );
        });
      }

      testWidgets('$skinName, a one-column route', (tester) async {
        await pumpDesk(
          tester,
          const WebhooksScreen(),
          size: const Size(1440, 900),
          skin: skin,
          path: '/webhooks',
          overrides: deskWebhookOverrides(),
        );
        final census = await amberCensus(tester);
        // ignore: avoid_print
        print('DESK 1440x900 $skinName / webhooks: ${census.describe()}');
        expectWithinAmberBudget(
          census,
          skin,
          route: 'webhooks (desk)',
          phase: 'loaded',
        );
      });
    }
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/theme/theme_mode_controller.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/nav_destinations.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/console_desk.dart';
import 'package:tradeiq_app/core/widgets/torchlight/menu_sheet.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';
import 'package:tradeiq_app/features/alerts/presentation/alerts_screen.dart';
import 'package:tradeiq_app/features/assistant/answer/composer.dart';
import 'package:tradeiq_app/features/dashboard/presentation/dashboard_shell_screen.dart';
import 'package:tradeiq_app/features/webhooks/presentation/webhooks_screen.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

import '../../design/amber_golden.dart';
// THE NON-LIST ROUTE'S OWN FAKES, reused rather than re-invented. Prefixed
// because this harness exports a dozen record types and two of them share a
// name with `worklist_harness.dart`'s.
import '../../../features/dashboard/overview_harness.dart' as oh;
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
    // UPDATED 3 OCTOBER 2026, FROM 1132 AND SEVEN TERMS TO 1212 AND NINE.
    //
    // The two new terms are the panes' own gutters. They are not a widening
    // for its own sake: with no gutter inside a pane there is nothing for a
    // `SoftRow` list to bleed back out to, so every row in every pane was laid
    // out `2 × gutterWide` wider than the viewport that clips it and the
    // right-hand figure was cut (measured, before: viewport 462→1246, row
    // 422→1286 at 1440×900 on Orders). The old assertion was pinning a
    // derivation that produced clipped rows; it is re-stated rather than
    // deleted so the arithmetic is still printed and still checked.
    test('deskMinWidth is the sum of its nine terms, and it is 1212', () {
      for (final (name, skin) in <(String, TiqSkin)>[
        ('night', night),
        ('day', day),
      ]) {
        final space = skin.space;
        final sum =
            2 * space.gutterWide +
            ConsoleDesk.railWidth +
            2 * space.blockGap +
            (ConsoleDesk.listMinWidth + 2 * ConsoleDesk.paneGutter) +
            (TiqSpace.readingWidth + 2 * ConsoleDesk.paneGutter);
        // ignore: avoid_print
        print(
          'deskMinWidth [$name] = '
          '2×${space.gutterWide} gutterWide + ${ConsoleDesk.railWidth} rail + '
          '2×${space.blockGap} blockGap + '
          '(${ConsoleDesk.listMinWidth} list + 2×${ConsoleDesk.paneGutter} '
          'paneGutter) + (${TiqSpace.readingWidth} readingWidth + '
          '2×${ConsoleDesk.paneGutter} paneGutter) = $sum',
        );
        expect(ConsoleDesk.deskMinWidth(skin), sum);
        expect(sum, 1212);
      }
    });

    // THE PANE GUTTER IS THE PHONE'S GUTTER, AND IT HAS TO STAY THAT WAY.
    //
    // `ConsoleDesk.paneGutter` is written as `TiqSpace.s5` because
    // `deskMinWidth` needs a compile-time constant, and `space.gutter` is an
    // instance field. If a skin ever moves its phone gutter off s5 the two
    // disagree silently and every bleeding row in a pane is out by the
    // difference — so they are checked rather than assumed.
    test('a pane spends the phone\'s own gutter, in both skins', () {
      for (final (name, skin) in <(String, TiqSkin)>[
        ('night', night),
        ('day', day),
      ]) {
        expect(
          ConsoleDesk.paneGutter,
          skin.space.gutter,
          reason:
              'ConsoleDesk.paneGutter (${ConsoleDesk.paneGutter}) and '
              '$name space.gutter (${skin.space.gutter}) have to be the same '
              'number: the pane pads by the constant and TorchGutter publishes '
              'it, so a bleed gives back exactly what was spent.',
        );
      }
    });

    // THE DETAIL PANE IS A WIDTH, NOT A SHARE, AND AT THE THRESHOLD THE
    // ARITHMETIC CLOSES ON ITSELF.
    test('at deskMinWidth the list pane is exactly a 360dp phone', () {
      for (final skin in <TiqSkin>[night, day]) {
        final left =
            ConsoleDesk.deskMinWidth(skin) -
            2 * skin.space.gutterWide -
            ConsoleDesk.railWidth -
            2 * skin.space.blockGap -
            ConsoleDesk.detailWidth(skin);
        // ignore: avoid_print
        print(
          'AT THE THRESHOLD: detail pane ${ConsoleDesk.detailWidth(skin)}dp '
          '(readingWidth + 2 × paneGutter), list pane ${left}dp — which is '
          '${ConsoleDesk.listMinWidth} of content between two '
          '${ConsoleDesk.paneGutter}dp gutters, i.e. a 360dp phone.',
        );
        expect(left, ConsoleDesk.listMinWidth + 2 * ConsoleDesk.paneGutter);
        expect(left, 360);
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
        // these; at 1212 the width test already does, which is the whole of
        // why this file does not quote 900.
        expect(ConsoleDesk.isDesk(skin, const Size(852, 393)), isFalse);
        expect(ConsoleDesk.isDesk(skin, const Size(1024, 768)), isFalse);
        // 1920×1080 — the owner's own window, and the width at which the
        // 8 : 11 split left a quarter of the screen as ground.
        expect(ConsoleDesk.isDesk(skin, const Size(1920, 1080)), isTrue);
        // THE 79dp BAND THE GUTTER COST. A window here used to get the desk
        // and now gets the phone column. It is asserted rather than regretted:
        // no standard laptop viewport is in it, and the alternative was panes
        // that cut their rows.
        expect(ConsoleDesk.isDesk(skin, const Size(1132, 900)), isFalse);
        expect(ConsoleDesk.isDesk(skin, const Size(1211, 900)), isFalse);
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
  //
  // THE EXAMPLE USED TO BE WEBHOOKS, AND WEBHOOKS IS NOW A LIST.
  //
  // This test pumped `WebhooksScreen` and asserted `console-detail` was
  // absent, on the argument written into its own `reason`: *"Webhooks has no
  // record detail — its rows expand in place"*. The rows expanding in place is
  // precisely what made it a list with a detail pane — the thing they expand
  // to show is the delivery log, and on the desk that log is the third pane.
  // So Webhooks passes a `ConsoleDeskRecords` now and the old assertion is
  // false about this route rather than wrong about the layout. It is
  // **re-aimed, not deleted**: the one-column shape still has to be pinned,
  // and the route that has it is the Perfect Store scorecard — a figure block,
  // a trend and two lists of cards, with no record to select. The Webhooks
  // case is directly below, asserting the opposite.
  testWidgets('a non-list route gets the rail and ONE centred column', (
    tester,
  ) async {
    await pumpDesk(
      tester,
      const DashboardShellScreen(),
      size: const Size(1440, 900),
      path: '/dashboard/overview',
      overrides: oh.overviewOverrides(
        current: oh.kpis(),
        previous: oh.kpis(execution: 66),
      ),
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
          'The scorecard has no records to select. A third pane here would be '
          'a pane whose content is an apology.',
    );
    final column = tester.getRect(
      find.byKey(const ValueKey<String>('console-column')),
    );
    // THE COLUMN FILLS WHAT IS LEFT AFTER THE RAIL, AND THE CAP IS GONE.
    //
    // It used to be capped at 784 and centred, which at 1440 left 154dp of
    // ground between the rail and the content and 194 on the other side. The
    // owner photographed the same shape at about 2000dp and called it empty.
    final expected =
        1440 -
        2 * night.space.gutterWide -
        ConsoleDesk.railWidth -
        night.space.blockGap;
    // ignore: avoid_print
    print(
      'THE ONE-COLUMN ROUTE: the column pane is ${column.width}dp wide at '
      '1440×900 — everything after the rail and its gap, with no cap and no '
      'centring. Expected $expected.',
    );
    expect(column.width, expected);
    expect(column.right, 1440 - night.space.gutterWide);
  });

  // ── AND THE ROUTE THAT USED TO BE THE EXAMPLE ────────────────────────
  //
  // Webhooks, whose rows expand in place on a phone. On the desk the fold is
  // suppressed and `_DeliveriesList` is the detail pane, which is the whole
  // reason a pane exists: on a phone, reading an endpoint's log costs the
  // manager the list they were reading.
  testWidgets('Webhooks gets three panes, and the deliveries are the third', (
    tester,
  ) async {
    await pumpDesk(
      tester,
      const WebhooksScreen(),
      size: const Size(1440, 900),
      path: '/webhooks',
      overrides: deskWebhookOverrides(),
    );
    expect(find.byKey(const ValueKey<String>('console-list')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('console-detail')),
      findsOneWidget,
      reason:
          'Webhooks was the product\'s example of a route that is not a list, '
          'and the example was wrong: the log its rows expand to show is '
          'exactly what a detail pane is for.',
    );
    expect(find.byKey(const ValueKey<String>('console-column')), findsNothing);

    // Nothing selected is the pane at rest, and the log arrives with the
    // record rather than with a second request from the frame.
    expect(
      find.byKey(const ValueKey<String>('console-detail-at-rest')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('console-record-w1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('deliveries-w1')),
      findsOneWidget,
      reason: 'The chosen endpoint\'s delivery log is the pane.',
    );
    // And the row in the list pane no longer carries the fold it used to.
    expect(
      find.byKey(const ValueKey<String>('deliveries-toggle-w1')),
      findsNothing,
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

  // ── THE RAIL'S FOOT ──────────────────────────────────────────────────
  //
  // > *"I cant see theme change on desktop"* — the owner, 4 October 2026.
  //
  // The old design put the brightness, the password and Sign out in the menu
  // sheet, one press of the ask bar's grid key away, and argued that the rail
  // should carry destinations only. The reasoning was sound and the outcome
  // was wrong: nobody presses a navigation-looking grid button to find
  // brightness on a screen that already shows all 24 destinations. These are
  // the pins on the replacement.
  group("the rail's foot", () {
    Finder footer() => find.byKey(const ValueKey<String>('console-rail-footer'));
    Finder account() => find.byKey(const ValueKey<String>('rail-account'));

    Future<void> pumpFoot(
      WidgetTester tester, {
      TiqSkin? skin,
      Size size = const Size(1440, 900),
      double textScale = 1.0,
      List<Override> session = const <Override>[],
    }) => pumpDesk(
      tester,
      const AlertsScreen(),
      size: size,
      skin: skin,
      textScale: textScale,
      path: '/alerts',
      overrides: <Override>[
        ...deskAlertOverrides(),
        ...(session.isEmpty ? deskSession() : session),
      ],
      users: deskPeople(),
    );

    testWidgets('is on screen at rest, at the bottom of the rail', (
      tester,
    ) async {
      await pumpFoot(tester);
      expect(footer(), findsOneWidget);
      expect(account(), findsOneWidget);

      // PINNED, NOT SCROLLED TO. The whole defect was a control a manager had
      // to know about to reach; a foot that lived at the end of a 1,188dp
      // scroller would be the same defect with a nicer address.
      final rail = tester.getRect(
        find.byKey(const ValueKey<String>('console-rail')),
      );
      final row = tester.getRect(account());
      expect(
        row.bottom,
        closeTo(rail.bottom, 0.5),
        reason:
            'The account row is the rail\'s last pixel. rail=$rail row=$row',
      );
      expect(row.height, greaterThanOrEqualTo(night.space.tapTarget));

      // And it stays there when the destinations scroll.
      await tester.drag(
        find.byKey(const ValueKey<String>('console-rail')),
        const Offset(0, -600),
      );
      await tester.pump();
      expect(
        tester.getRect(account()).bottom,
        closeTo(rail.bottom, 0.5),
        reason: 'A pinned foot does not move when the list behind it does.',
      );
      // ignore: avoid_print
      print(
        'THE FOOT AT 1440x900: account row ${row.width}×${row.height}dp, '
        'bottom ${row.bottom} against a rail bottom of ${rail.bottom}',
      );
    });

    testWidgets('names the signed-in address, and speaks the whole of it', (
      tester,
    ) async {
      await pumpFoot(tester);
      final row = tester.widget<MenuFlatRow>(account());
      expect(row.label, 'nhlanhla');
      expect(row.semanticLabel, 'nhlanhla@acme.test');
      // ignore: avoid_print
      print('THE FOOT PRINTS "${row.label}" and says "${row.semanticLabel}"');
    });

    testWidgets('names the app when there is no address to print', (
      tester,
    ) async {
      // The one state the client can genuinely be in and has no name for: a
      // session restored by a build older than the stored address key. It gets
      // a different glyph and the sheet's own words, never a placeholder name.
      await pumpFoot(tester, session: deskSession(email: null));
      final row = tester.widget<MenuFlatRow>(account());
      expect(row.label, englishLocalizations.menuThisApp);
      expect(row.icon, Icons.settings_outlined);
    });

    testWidgets('one press puts the theme control, the password and the way '
        'out on screen', (tester) async {
      await pumpFoot(tester);
      const theme = ValueKey<String>('rail-theme');
      const password = ValueKey<String>('rail-password');
      const signOut = ValueKey<String>('rail-sign-out');

      // Shut: the fold is not in the tree at all, which is what makes "the
      // foot is one row at rest" a fact rather than a claim about opacity.
      expect(find.byKey(theme), findsNothing);
      expect(find.byKey(password), findsNothing);
      expect(find.byKey(signOut), findsNothing);

      await tester.tap(account());
      await tester.pumpAndSettle();

      // ONE PRESS. Not two: `menu_sheet.dart` refused to fold its own "This
      // app" section because that would bury the one irreversible control in
      // the product, and the same rule holds here — the three items are flat
      // under the marker and Sign out is a button among them.
      expect(find.byKey(theme), findsOneWidget);
      expect(find.byKey(password), findsOneWidget);
      expect(find.byKey(signOut), findsOneWidget);
      expect(
        find.descendant(
          of: footer(),
          matching: find.byType(TorchSecondaryButton),
        ),
        findsOneWidget,
        reason: 'Sign out is a button in the foot, not a row in a list.',
      );

      // It opens UPWARD: there is nothing below a foot to grow into, so what
      // the reveal covers is the destinations, not the account row.
      final rail = tester.getRect(
        find.byKey(const ValueKey<String>('console-rail')),
      );
      expect(tester.getRect(account()).bottom, closeTo(rail.bottom, 0.5));
      expect(
        tester.getRect(find.byKey(theme)).top,
        lessThan(tester.getRect(account()).top),
      );

      // Every item clears the target floor.
      for (final key in <ValueKey<String>>[theme, password, signOut]) {
        final rect = tester.getRect(find.byKey(key));
        expect(
          rect.height,
          greaterThanOrEqualTo(night.space.tapTarget),
          reason: '${key.value} is ${rect.height}dp against a '
              '${night.space.tapTarget}dp floor.',
        );
      }

      await tester.tap(account());
      await tester.pumpAndSettle();
      expect(find.byKey(theme), findsNothing);
    });

    testWidgets('the theme control switches the mode, and names the one it '
        'switches TO', (tester) async {
      await pumpFoot(tester);
      await tester.tap(account());
      await tester.pumpAndSettle();

      const theme = ValueKey<String>('rail-theme');
      final before = tester.widget<MenuFlatRow>(find.byKey(theme)).label;
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(theme)),
      );
      final modeBefore = container.read(themeModeProvider);

      await tester.tap(find.byKey(theme));
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider), isNot(modeBefore));
      expect(
        tester.widget<MenuFlatRow>(find.byKey(theme)).label,
        isNot(before),
        reason:
            'The row names the state it switches TO, so pressing it has to '
            'change the words as well as the mode — the sheet\'s own rule.',
      );
      // ignore: avoid_print
      print(
        'THE FOOT\'S BRIGHTNESS: "$before" ($modeBefore) → '
        '"${tester.widget<MenuFlatRow>(find.byKey(theme)).label}" '
        '(${container.read(themeModeProvider)})',
      );
    });

    testWidgets('Sign out signs out', (tester) async {
      final session = _CountingSession();
      await pumpFoot(
        tester,
        session: <Override>[
          sessionControllerProvider.overrideWith(() => session),
        ],
      );
      await tester.tap(account());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('rail-sign-out')));
      await tester.pumpAndSettle();
      expect(
        session.logouts,
        1,
        reason:
            'The one irreversible control in the product, one press from any '
            'desk screen. `menu_sheet.dart` records this capability being lost '
            'to a migration once already.',
      );
    });

    testWidgets('nothing overflows with the foot open at the height floor, '
        'in either skin, at 1.3x', (tester) async {
      // THE FLOOR IS 348dp AND IT IS NOT A DEVICE. `deskMinHeight` is the
      // height below which the list pane stops being a list; at 1212dp of
      // width no viewport produces it. It is pumped anyway, because an open
      // foot is the tallest thing the rail ever holds and a Column that
      // overflows prints a red band rather than failing a number.
      for (final skin in <TiqSkin>[night, day]) {
        for (final scale in <double>[1.0, 1.3]) {
          await pumpFoot(
            tester,
            skin: skin,
            size: Size(
              ConsoleDesk.deskMinWidth(skin),
              ConsoleDesk.deskMinHeight(skin),
            ),
            textScale: scale,
          );
          await tester.tap(account());
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason:
                'The foot open at ${ConsoleDesk.deskMinWidth(skin)}×'
                '${ConsoleDesk.deskMinHeight(skin)} at ${scale}x overflows '
                'the rail.',
          );
        }
      }
    });

    testWidgets('the foot paints no outline while it is shut', (tester) async {
      // `console_wash.dart` rests Night's thin `edgeStructure` margin partly
      // on "the rail paints no `edgeStructure` and no `edgeControl` at all".
      // The foot keeps that true at rest — its rows are flat, like the
      // destinations — and breaks it only while it is open, where the one
      // rimmed object is Sign out's `edgeControl`. That token has 0.379 of
      // alpha before it crosses 3:1 and the wash ships at 0.10, so it is the
      // safe one to spend; `console_wash_test.dart` measures it on the frame.
      await pumpFoot(tester);
      expect(
        find.descendant(
          of: footer(),
          matching: find.byType(TorchSecondaryButton),
        ),
        findsNothing,
      );
    });
  });

  // ── THE ROUTE'S ONE HEADER CONTROL IS NOT IN THE CORNER ──────────────
  //
  // > *"the refresh button is in the wrong place … it reads as a floating
  // > artefact."* — the owner, on Beat plans at 1440dp.
  group('the list pane takes the header\'s one control', () {
    testWidgets('Webhooks: it is on the marker row, not in the header', (
      tester,
    ) async {
      await pumpDesk(
        tester,
        const WebhooksScreen(),
        size: const Size(1440, 900),
        path: '/webhooks',
        overrides: <Override>[...deskWebhookOverrides(), ...deskSession()],
      );

      final refresh = find.byKey(const ValueKey<String>('webhooks-refresh'));
      expect(
        refresh,
        findsOneWidget,
        reason:
            'Lifted or drawn, never both and never neither. Two copies is two '
            'refresh buttons on one screen; none is a capability lost to a '
            'layout.',
      );
      expect(
        find.descendant(of: find.byType(SectionRule), matching: refresh),
        findsOneWidget,
        reason: 'It belongs with the count and the list\'s own verbs.',
      );
      expect(
        find.descendant(of: find.byType(TorchAppHeader), matching: refresh),
        findsNothing,
      );

      // AND IT IS NEAR THE WORDS NOW. That is the whole complaint, as a
      // number: the header's own right edge is the pane's right edge, and the
      // marker's words are at its left.
      final marker = tester.getRect(
        find
            .descendant(
              of: find.byKey(const ValueKey<String>('console-list')),
              matching: find.byType(SectionRule),
            )
            .first,
      );
      final glyph = tester.getRect(refresh);
      // ignore: avoid_print
      print(
        'WEBHOOKS 1440x900: marker x=${marker.left}→${marker.right}, '
        'refresh x=${glyph.left}→${glyph.right}, '
        'same row (marker top ${marker.top}, refresh top ${glyph.top})',
      );
      expect(
        glyph.center.dy,
        closeTo(marker.center.dy, marker.height / 2 + 1),
        reason: 'The control is ON the toolbar row, not above or below it.',
      );
    });

    testWidgets('Exceptions: no marker, so it is on the filter rail', (
      tester,
    ) async {
      await pumpDesk(
        tester,
        const AlertsScreen(),
        size: const Size(1440, 900),
        path: '/alerts',
        overrides: <Override>[...deskAlertOverrides(), ...deskSession()],
        users: deskPeople(),
      );
      final refresh = find.byKey(const ValueKey<String>('alerts-refresh'));
      expect(refresh, findsOneWidget);
      expect(
        find.descendant(of: find.byType(TorchAppHeader), matching: refresh),
        findsNothing,
        reason:
            'This screen deliberately has no section marker — the selected '
            'chip names and counts the slice — so the rail is the row its own '
            'controls live on.',
      );
      final rail = tester.getRect(find.byType(TorchFilterRail).first);
      final glyph = tester.getRect(refresh);
      expect(glyph.center.dy, closeTo(rail.center.dy, rail.height / 2 + 1));
      // ignore: avoid_print
      print(
        'EXCEPTIONS 1440x900: filter rail x=${rail.left}→${rail.right}, '
        'refresh x=${glyph.left}→${glyph.right}',
      );
    });

    testWidgets('a one-column route keeps its control in the header', (
      tester,
    ) async {
      // The Perfect Store scorecard passes no `ConsoleDeskRecords`, so there
      // is no list pane and no toolbar row to lift anything onto. The header
      // is at the top of a column that fills the window, which is where a
      // header control belongs.
      await pumpDesk(
        tester,
        const DashboardShellScreen(),
        size: const Size(1440, 900),
        path: '/dashboard/overview',
        overrides: <Override>[
          // NO `deskSession` HERE: `overviewOverrides` installs a session of
          // its own, and overriding a provider twice in one container is an
          // assert rather than a last-wins. The foot renders its signed-out
          // form on this route, which is not what this test is about.
          ...oh.overviewOverrides(
            current: oh.kpis(),
            previous: oh.kpis(execution: 66),
          ),
        ],
      );
      final header = find.byType(TorchAppHeader);
      final trailing = tester
          .widgetList<TorchAppHeader>(header)
          .map((h) => h.trailing)
          .whereType<Widget>()
          .toList();
      if (trailing.isEmpty) return; // this route carries none; nothing to pin
      expect(
        find.descendant(of: header, matching: find.byWidget(trailing.first)),
        findsOneWidget,
      );
    });

    // ── EVERY DESK SCREEN, READ OFF THE SOURCE ─────────────────────────
    //
    // Nineteen screens, each with its own repositories, its own fakes and its
    // own phases. Pumping all nineteen here would be nineteen harnesses to
    // keep in step for one structural question, so the question is asked of
    // the source instead — the instrument `torchlight_lint_test.dart` already
    // uses on this repository for exactly this shape of rule.
    //
    // The rule has two halves and they have to agree: a pane that says its
    // controls are on the marker must contain exactly one marker that says it
    // is the one, and a pane that says nothing must be a screen whose header
    // has nothing to lift.
    test('every ConsoleDeskRecords declares where its controls are', () {
      final offenders = <String>[];
      final table = <String>[];
      for (final file in Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final src = file.readAsStringSync();
        final panes = 'ConsoleDeskRecords('.allMatches(src).length;
        if (panes == 0) continue;
        final declared = RegExp(
          r'toolbar:\s*ConsoleDeskToolbar\.(\w+)',
        ).allMatches(src).map((m) => m.group(1)!).toList();
        final markers = 'listAction: true'.allMatches(src).length;
        final name = file.path.split('/').skip(2).join('/');
        table.add(
          '$name: $panes pane(s), toolbar ${declared.isEmpty ? "—" : declared.join("+")}'
          ', $markers flagged marker(s)',
        );
        if (declared.length != panes) {
          offenders.add(
            '$name declares ${declared.length} toolbar(s) for $panes '
            'ConsoleDeskRecords. Every pane says where its own controls are '
            '— including ConsoleDeskToolbar.none, which is what a route whose '
            'header has nothing to lift says. Silence is how the owner\'s '
            'complaint comes back on a screen nobody looked at.',
          );
          continue;
        }
        final wantsMarker = declared.where((d) => d == 'marker').length;
        if (wantsMarker > 0 && markers != 1) {
          offenders.add(
            '$name asks for ConsoleDeskToolbar.marker and flags $markers '
            'SectionRule(listAction: true). Exactly one: zero loses the '
            'control, two draws it twice.',
          );
        }
        if (wantsMarker == 0 && markers != 0) {
          offenders.add(
            '$name flags $markers marker(s) and asks for no marker toolbar. '
            'The flag would never fire.',
          );
        }
      }
      // ignore: avoid_print
      print('DESK TOOLBARS\n  ${table.join("\n  ")}');
      expect(offenders, isEmpty, reason: offenders.join('\n'));
      expect(
        table,
        hasLength(19),
        reason:
            'Nineteen screens pass a ConsoleDeskRecords. A twentieth arriving '
            'without a toolbar is the defect this test exists for.',
      );
    });
  });

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

      // WEBHOOKS, WHICH IS NO LONGER THE ONE-COLUMN CASE. It is censused with
      // a record open, because that is the state its pane actually has
      // something in it: a toggle, a destructive tertiary and a delivery log.
      // The budget is unchanged, which is the claim worth pinning — lifting a
      // row's verbs into a pane must not light anything.
      testWidgets('$skinName, a lifted-verb pane adds none', (tester) async {
        await pumpDesk(
          tester,
          const WebhooksScreen(),
          size: const Size(1440, 900),
          skin: skin,
          path: '/webhooks',
          overrides: deskWebhookOverrides(),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('console-record-w1')),
        );
        await tester.pumpAndSettle();
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

/// A session that counts the way out, because the foot's Sign out is the one
/// irreversible control in the product and "it is wired up" is a claim worth
/// a number.
class _CountingSession extends SessionController {
  int logouts = 0;

  @override
  Future<SessionState> build() async => const SessionState(
    role: 'manager',
    token: 't',
    email: 'nhlanhla@acme.test',
  );

  @override
  Future<void> logout({bool expired = false}) async {
    logouts++;
  }
}

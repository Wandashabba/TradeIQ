import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';
import 'package:tradeiq_app/features/dashboard/presentation/dashboard_filters.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';

import '../../core/design/amber_golden.dart';
import '../agent_harness.dart';
import 'floor_harness.dart';
import 'seeded_territories.dart';

/// PROVINCES THAT OPEN — the grouping rule, the two traps in it, and the
/// density it bought.
///
/// The rule is **structural**: the code prefix before the first hyphen, and
/// the longest common name prefix for the group that has no parent. It is
/// deliberately not a table of South African provinces — this is multi-tenant
/// and another tenant's territories will not be provinces — so most of what
/// follows is pure-function arithmetic on names and codes rather than a
/// screenshot.
///
/// The two traps, both of them in the mockup rather than in the code:
///
/// 1. **A group of one is not a group.** Free State and Limpopo were drawn
///    with an expand chevron and a count of "1". A control that does nothing
///    wearing the clothes of one that does something is worse than no control.
/// 2. **The header must never be a selection.** `GP`, `WC` and `KZN` each have
///    a territory whose code IS the prefix, so a tappable header could
///    plausibly select it — and `EC` has none, so the same header would do
///    nothing there. Resolved by making the header always and only an
///    expander, with the parent listed as the first child.
void main() {
  setUpAll(loadAgentFonts);

  // `TorchSheets.openCount` is process-wide, so one test that fails with a
  // sheet up fails the next one too and the failure names the wrong thing.
  setUp(TorchSheets.resetForTest);

  group('the grouping rule', () {
    test('groups by the code prefix, and never by region', () {
      final groups = groupTerritories(seededTerritories);

      // `region` is "Inland"/"Coastal" — the seed's own comment says the
      // province is in the name. Grouping by it would file Gauteng North and
      // the Winelands together (both Inland) and split the Eastern Cape.
      expect(
        groups.map((g) => g.key).toList(),
        <String>['GP', 'WC', 'KZN', 'EC', 'FS', 'LP', 'MP', 'NW'],
        reason: 'the server\'s order, grouped, not re-sorted alphabetically',
      );
      expect(groups.map((g) => g.members.length).toList(), <int>[
        3,
        2,
        2,
        2,
        1,
        1,
        1,
        1,
      ]);
    });

    test('a prefix with one member is not a group', () {
      final groups = groupTerritories(seededTerritories);
      for (final group in groups) {
        expect(
          group.isGroup,
          group.members.length > 1,
          reason: '${group.key} disagrees with its own member count',
        );
      }
      final singles = groups.where((g) => !g.isGroup).map((g) => g.label);
      expect(singles, <String>[
        'Free State',
        'Limpopo',
        'Mpumalanga',
        'North West',
      ]);
    });

    test('a group whose prefix is a whole code is named after it', () {
      final groups = groupTerritories(seededTerritories);
      expect(groups.firstWhere((g) => g.key == 'GP').label, 'Gauteng');
      expect(groups.firstWhere((g) => g.key == 'WC').label, 'Western Cape');
      expect(groups.firstWhere((g) => g.key == 'KZN').label, 'KwaZulu-Natal');
    });

    test('a group with no parent is named from the common name prefix', () {
      // "Eastern Cape – Nelson Mandela Bay" + "Eastern Cape – Buffalo City".
      // The separator is an EN DASH (U+2013), not a hyphen, which is why the
      // trailing-separator trim has to know about more than `-`.
      final ec = groupTerritories(
        seededTerritories,
      ).firstWhere((g) => g.key == 'EC');
      expect(ec.label, 'Eastern Cape');
      expect(ec.label, isNot(contains('–')));
    });

    test('the parent leads its group, then the printed labels sort', () {
      final gp = groupTerritories(
        seededTerritories,
      ).firstWhere((g) => g.key == 'GP');
      expect(
        gp.members.map((t) => territoryChildLabel(gp.label, t.name)).toList(),
        <String>['Gauteng', 'East (Ekurhuleni)', 'North (Tshwane)'],
      );
    });

    test('an unusable common prefix falls back to the code prefix', () {
      // Two names that share only a cut-off word. "Wester" is not a label.
      final groups = groupTerritories(const <Territory>[
        Territory(id: 'a', name: 'Westerly Fields', code: 'ZZ-1'),
        Territory(id: 'b', name: 'Western Edge', code: 'ZZ-2'),
      ]);
      expect(groups.single.label, 'ZZ');
    });

    test('a blank code shares a prefix with nothing', () {
      // One unseeded code must not collect the tenant into a group called "".
      final groups = groupTerritories(const <Territory>[
        Territory(id: 'a', name: 'Alpha', code: ''),
        Territory(id: 'b', name: 'Beta', code: '  '),
        Territory(id: 'c', name: 'Gamma', code: 'GM'),
        Territory(id: 'd', name: 'Delta', code: '-ODD'),
      ]);
      expect(groups.length, 4);
      expect(groups.every((g) => !g.isGroup), isTrue);
      expect(groups.map((g) => g.label).toList(), <String>[
        'Alpha',
        'Beta',
        'Gamma',
        'Delta',
      ]);
    });

    test('two territories under one code keep both rows', () {
      // `identical`, not `code != key`: the second one used to fall off the
      // list when the parent was excluded by value.
      final groups = groupTerritories(const <Territory>[
        Territory(id: 'a', name: 'Dup One', code: 'DP'),
        Territory(id: 'b', name: 'Dup Two', code: 'DP'),
        Territory(id: 'c', name: 'Dup Child', code: 'DP-X'),
      ]);
      // The parent leads, then the PRINTED labels sort: "Dup Child" before
      // "Dup Two". Nothing is dropped, which is the point.
      expect(groups.single.members.map((t) => t.id).toList(), <String>[
        'a',
        'c',
        'b',
      ]);
    });
  });

  group('the child labels read as words', () {
    test('the group\'s name comes off the front', () {
      expect(
        territoryChildLabel('Gauteng', 'Gauteng North (Tshwane)'),
        'North (Tshwane)',
      );
      expect(
        territoryChildLabel('Western Cape', 'Western Cape Winelands'),
        'Winelands',
      );
      expect(
        territoryChildLabel('KwaZulu-Natal', 'KwaZulu-Natal Midlands'),
        'Midlands',
      );
    });

    test('an en dash does not survive the strip', () {
      // The failure this exists to stop is a row reading "– Buffalo City".
      final label = territoryChildLabel(
        'Eastern Cape',
        'Eastern Cape – Buffalo City',
      );
      expect(label, 'Buffalo City');
      expect(label.startsWith('–'), isFalse);
      expect(label.trimLeft(), label);
    });

    test('the parent keeps its whole name', () {
      // Stripping "Gauteng" off "Gauteng" leaves nothing, and a blank row is
      // not a shorter row.
      expect(territoryChildLabel('Gauteng', 'Gauteng'), 'Gauteng');
      expect(territoryChildLabel('Limpopo', 'Limpopo'), 'Limpopo');
    });

    test('a name that is not inside its group is left alone', () {
      expect(territoryChildLabel('Gauteng', 'Free State'), 'Free State');
    });

    test('nothing strips to punctuation', () {
      for (final group in groupTerritories(seededTerritories)) {
        for (final member in group.members) {
          final label = territoryChildLabel(group.label, member.name);
          expect(label, isNotEmpty);
          expect(
            RegExp(r'^[\s\-–—·:;,/|]').hasMatch(label),
            isFalse,
            reason: '"$label" opens on punctuation',
          );
        }
      }
    });

    test('the code prefix is the part before the FIRST hyphen', () {
      expect(territoryCodePrefix('GP-TSH'), 'GP');
      expect(territoryCodePrefix('GP'), 'GP');
      expect(territoryCodePrefix('EC-NMB-X'), 'EC');
      expect(territoryCodePrefix(' KZN-PMB '), 'KZN');
      // A code that opens on a hyphen has an EMPTY prefix, so it groups with
      // nothing. That is the invariant the bucket keys lean on: a real prefix
      // is never empty and never contains a hyphen, which is what lets a
      // codeless territory be keyed `-<id>` without ever colliding.
      expect(territoryCodePrefix('-ORPHAN'), '');
    });
  });

  group('the sheet', () {
    Future<void> pump(
      WidgetTester tester, {
      Size size = const Size(390, 844),
      TiqSkin? skin,
      double textScale = 1.0,
      String? scopedTo,
    }) async {
      await pumpFloorRoute(
        tester,
        size: size,
        skin: skin,
        textScale: textScale,
        current: kpis(),
        previous: kpis(),
        byTerritory: <String, DashboardKpis>{'t-gp-tsh': kpis(execution: 51)},
        territories: seededTerritories,
      );
      await tester.tap(find.byKey(const ValueKey<String>('floor-scope-chip')));
      await tester.pumpAndSettle();
      if (scopedTo != null) {
        await tester.tap(
          find.byKey(const ValueKey<String>('territory-group-GP')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(ValueKey<String>('territory-option-$scopedTo')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('floor-scope-chip')),
        );
        await tester.pumpAndSettle();
      }
    }

    Future<void> close(WidgetTester tester) async {
      // `TorchSheets.openCount` is process-wide, so a test that walks away
      // from an open sheet fails the next one.
      await tester.tap(
        find.byKey(const ValueKey<String>('territory-option-all')),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('opens collapsed, with one row per group', (tester) async {
      await pump(tester);
      for (final key in <String>['GP', 'WC', 'KZN', 'EC']) {
        expect(
          find.byKey(ValueKey<String>('territory-group-$key')),
          findsOneWidget,
        );
      }
      // The four singletons are rows, not headers.
      for (final id in <String>['t-fs', 't-lp', 't-mp', 't-nw']) {
        expect(
          find.byKey(ValueKey<String>('territory-option-$id')),
          findsOneWidget,
        );
      }
      // And a group's members are not on screen until it opens.
      expect(
        find.byKey(const ValueKey<String>('territory-option-t-gp-tsh')),
        findsNothing,
      );
      await close(tester);
    });

    testWidgets('a group header expands and never selects', (tester) async {
      await pump(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('territory-group-GP')),
      );
      await tester.pumpAndSettle();

      // THE TRAP. `GP` has a territory whose code is the prefix, so a header
      // that selected would have selected Gauteng here — and done nothing at
      // all on `EC`, which has no such territory. The sheet is still up and
      // the scope is still unset, which is the whole assertion.
      expect(find.byType(TorchSheet), findsOneWidget);
      // The parent is the first child inside the group, as a real row.
      expect(
        find.byKey(const ValueKey<String>('territory-option-t-gp')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('territory-option-t-gp-tsh')),
        findsOneWidget,
      );

      // The same header shuts it again.
      await tester.tap(
        find.byKey(const ValueKey<String>('territory-group-GP')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('territory-option-t-gp')),
        findsNothing,
      );
      await close(tester);
    });

    testWidgets('the EC header expands too, with nothing to select', (
      tester,
    ) async {
      // The asymmetry the trap is about: this group has no parent territory,
      // so there is no plausible selection for its header to make.
      await pump(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('territory-group-EC')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TorchSheet), findsOneWidget);
      expect(find.text('Buffalo City'), findsOneWidget);
      expect(find.text('Nelson Mandela Bay'), findsOneWidget);
      await close(tester);
    });

    testWidgets('selecting a grouped child scopes the stores to it', (
      tester,
    ) async {
      // #496's bug, on the path that did not exist before: the territory the
      // sheet pops has to reach `dashboardFilterProvider` and move the
      // figures, not just the label.
      await pump(tester);
      expect(find.textContaining('72'), findsWidgets, reason: 'the hero');

      await tester.tap(
        find.byKey(const ValueKey<String>('territory-group-GP')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('territory-option-t-gp-tsh')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TorchSheet), findsNothing, reason: 'it applied');
      expect(find.textContaining('51'), findsWidgets, reason: 'the hero moved');
      expect(find.textContaining('72'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('floor-scope-chip')),
          matching: find.textContaining('Gauteng North (Tshwane)'),
        ),
        findsOneWidget,
        reason: 'the chip prints the WHOLE name, not the stripped label',
      );
    });

    testWidgets('it reopens on the group holding the current scope', (
      tester,
    ) async {
      await pump(tester, scopedTo: 't-gp-tsh');
      // Open, and the chosen row on screen — not three rows below a header
      // the manager has to find and tap again.
      expect(
        find.byKey(const ValueKey<String>('territory-option-t-gp-tsh')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('territory-option-t-wc-win')),
        findsNothing,
        reason: 'only the group that holds the scope opens',
      );
      await close(tester);
    });

    testWidgets('with everything chosen, everything is shut', (tester) async {
      await pump(tester);
      expect(
        find.byKey(const ValueKey<String>('territory-option-t-gp')),
        findsNothing,
      );
      await close(tester);
    });

    testWidgets('the clear still clears', (tester) async {
      await pump(tester, scopedTo: 't-gp-tsh');
      await close(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('floor-scope-chip')),
          matching: find.textContaining('All territories'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('72'), findsWidgets);
    });

    testWidgets('a window chip applies and leaves the sheet up', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey<String>('scope-range-last7')));
      await tester.pumpAndSettle();
      expect(find.byType(TorchSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('floor-scope-chip')),
          matching: find.textContaining('Last 7 days'),
        ),
        findsOneWidget,
      );
      await close(tester);
    });

    testWidgets('the scrim still dismisses without changing anything', (
      tester,
    ) async {
      await pump(tester);
      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();
      expect(find.byType(TorchSheet), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('floor-scope-chip')),
          matching: find.textContaining('All territories'),
        ),
        findsOneWidget,
      );
    });
  });

  group('the geometry', () {
    Future<Rect> rowRect(WidgetTester tester, String key) async =>
        tester.getRect(find.byKey(ValueKey<String>('territory-option-$key')));

    for (final (name, size) in <(String, Size)>[
      ('390x844', Size(390, 844)),
      ('360x640', Size(360, 640)),
    ]) {
      testWidgets('$name: every row clears the 44dp target floor', (
        tester,
      ) async {
        await pumpFloorRoute(
          tester,
          size: size,
          current: kpis(),
          previous: kpis(),
          territories: seededTerritories,
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('floor-scope-chip')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('territory-group-GP')),
        );
        await tester.pumpAndSettle();

        final floor = TiqSkin.night().space.tapTarget;
        expect(floor, 44, reason: 'WCAG 2.5.5, and the row is padded to it');

        for (final key in <String>['all', 't-gp', 't-gp-tsh', 't-fs']) {
          final rect = await rowRect(tester, key);
          expect(
            rect.height,
            greaterThanOrEqualTo(floor),
            reason: '$key is $rect — under the floor is a row people miss',
          );
        }
        for (final key in <String>['GP', 'EC']) {
          expect(
            tester
                .getRect(find.byKey(ValueKey<String>('territory-group-$key')))
                .height,
            greaterThanOrEqualTo(floor),
          );
        }

        // TIGHTER THAN WHAT IT REPLACED. `SoftRow(compact)` in the list form
        // measured 68dp of card on an 80dp pitch here; the floor is the whole
        // of the new number.
        // ADJACENT rows: the group reads Gauteng · East (Ekurhuleni) ·
        // North (Tshwane), so `t-gp` to `t-gp-tsh` is two pitches, not one.
        final a = await rowRect(tester, 't-gp');
        final b = await rowRect(tester, 't-gp-eku');
        expect(
          b.top - a.top,
          lessThanOrEqualTo(48),
          reason: 'the pitch did not come down from the old 80',
        );
        expect(
          b.top - a.top,
          greaterThanOrEqualTo(floor),
          reason: 'rows cannot overlap their own targets',
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('territory-option-all')),
        );
        await tester.pumpAndSettle();
      });
    }

    testWidgets('the rows hang off the same gutter as the label above them', (
      tester,
    ) async {
      // THE DEFECT: `SoftRowForm.list` carries a margin of one gutter, so
      // inside a sheet that already pads by one gutter every card's edge sat
      // at 40dp while `TERRITORY` sat at 20dp. One gutter, not two.
      await pumpFloorRoute(
        tester,
        size: const Size(390, 844),
        current: kpis(),
        previous: kpis(),
        territories: seededTerritories,
      );
      await tester.tap(find.byKey(const ValueKey<String>('floor-scope-chip')));
      await tester.pumpAndSettle();

      final gutter = TiqSkin.night().space.gutter;
      final eyebrow = tester.getRect(find.byType(Eyebrow).first);
      expect(eyebrow.left, gutter);
      for (final key in <String>['all', 't-fs', 't-nw']) {
        expect(
          (await rowRect(tester, key)).left,
          gutter,
          reason: '$key is inset past its own section label',
        );
      }
      expect(
        tester
            .getRect(find.byKey(const ValueKey<String>('territory-group-GP')))
            .left,
        gutter,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('territory-option-all')),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('every window chip is on screen, because they wrap', (
      tester,
    ) async {
      // As a rail two of the five were off the right edge with no affordance:
      // at 390dp "Year to date" was laid out from x=344.3 to x=435.8 and "All
      // time" was never built at all.
      for (final size in <Size>[Size(390, 844), Size(360, 640)]) {
        await pumpFloorRoute(
          tester,
          size: size,
          current: kpis(),
          previous: kpis(),
          territories: seededTerritories,
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('floor-scope-chip')),
        );
        await tester.pumpAndSettle();

        for (final range in DashboardRange.values) {
          final chip = find.byKey(
            ValueKey<String>('scope-range-${range.name}'),
          );
          expect(chip, findsOneWidget, reason: '${range.name} was not built');
          final rect = tester.getRect(chip);
          expect(
            rect.right,
            lessThanOrEqualTo(size.width),
            reason: '${range.name} runs off the right edge at $size',
          );
          expect(rect.left, greaterThanOrEqualTo(0));
        }
        await tester.tap(
          find.byKey(const ValueKey<String>('territory-option-all')),
        );
        await tester.pumpAndSettle();
      }
    });

    testWidgets('the scope you are on is on screen when the sheet opens', (
      tester,
    ) async {
      // THE POINT OF OPENING ON THE CURRENT SCOPE. A sheet that reveals the
      // right group and then puts it below the fold has not revealed it.
      //
      // Measured for all thirteen seeded territories, by scoping through the
      // provider the way a returning manager arrives and then opening the
      // sheet. The old list was fourteen rows at an 80dp pitch, ungrouped, and
      // it did not open on the current scope at all: the first territory row
      // sat at y=324.8 and the fourth at 644.8 of 640, so THREE of the
      // thirteen were reachable without a scroll at 360x640.
      final offScreen = <String, List<String>>{};
      for (final size in <Size>[Size(390, 844), Size(360, 640)]) {
        final missed = <String>[];
        for (final territory in seededTerritories) {
          await pumpFloorRoute(
            tester,
            size: size,
            current: kpis(),
            previous: kpis(),
            territories: seededTerritories,
          );
          final context = tester.element(
            find.byKey(const ValueKey<String>('floor-scope-chip')),
          );
          ProviderScope.containerOf(context)
              .read(dashboardFilterProvider.notifier)
              .set(
                DashboardFilter(
                  range: DashboardRange.last30,
                  territoryId: territory.id,
                ),
              );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey<String>('floor-scope-chip')),
          );
          await tester.pumpAndSettle();

          final rect = tester.getRect(
            find.byKey(ValueKey<String>('territory-option-${territory.id}')),
          );
          if (rect.top < 0 || rect.bottom > size.height) {
            missed.add(
              '${territory.code} (${rect.top.toStringAsFixed(0)}..'
              '${rect.bottom.toStringAsFixed(0)} of ${size.height.toInt()})',
            );
          }
          await tester.tap(
            find.byKey(const ValueKey<String>('territory-option-all')),
          );
          await tester.pumpAndSettle();
        }
        offScreen['$size'] = missed;
      }

      expect(
        offScreen['${Size(390, 844)}'],
        isEmpty,
        reason:
            'every one of the thirteen is reachable without a scroll on a '
            '390dp phone, which is the width the owner reviews on',
      );
      // AND THE SMALL PHONE IS NOT. 13 rows at the 44dp floor plus two lines
      // of window chips is 632dp of content against a 563dp ceiling, so the
      // last two of the eight collapsed rows fall past it — Mpumalanga by one
      // logical pixel and North West by 45. Pinned rather than wished away:
      // the only ways to buy those 45dp are to drop a window chip off the
      // sheet or to put the rows under the 44dp target floor, and both are
      // worse than a scroll. Ten of thirteen needed a scroll before.
      expect(
        offScreen['${Size(360, 640)}'],
        <String>['MP (597..641 of 640)', 'NW (641..685 of 640)'],
        reason: 'the small phone\'s overflow moved — remeasure and say so',
      );
    });

    testWidgets('1.3x: the rows grow, nothing overflows and nothing clips', (
      tester,
    ) async {
      // A list is where text scale bites, and 1.3x is the setting people
      // actually run.
      await pumpFloorRoute(
        tester,
        size: const Size(360, 640),
        textScale: 1.3,
        current: kpis(),
        previous: kpis(),
        territories: seededTerritories,
      );
      await tester.tap(find.byKey(const ValueKey<String>('floor-scope-chip')));
      await tester.pumpAndSettle();
      // At 1.3x on a 360dp phone the list outgrows the sheet's 88% ceiling
      // and the sheet scrolls — which is the designed behaviour, not a
      // failure, so the test scrolls like a thumb would.
      final ec = find.byKey(const ValueKey<String>('territory-group-EC'));
      await tester.ensureVisible(ec);
      await tester.pumpAndSettle();
      await tester.tap(ec);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('territory-option-t-ec-bcm')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('territory-option-all')),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('2.0x: the sheet survives its own ceiling', (tester) async {
      await pumpFloorRoute(
        tester,
        size: const Size(320, 640),
        textScale: 2,
        current: kpis(),
        previous: kpis(),
        territories: seededTerritories,
      );
      await tester.tap(find.byKey(const ValueKey<String>('floor-scope-chip')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byKey(const ValueKey<String>('territory-option-all')),
      );
      await tester.pumpAndSettle();
    });
  });

  group('the sheet costs no amber', () {
    for (final (name, skin) in <(String, TiqSkin)>[
      ('Night', _night),
      ('Day', _day),
    ]) {
      testWidgets('$name: nothing is lit, open, expanded or selected', (
        tester,
      ) async {
        // The mockup drew an amber dot on the selected row. One dot would have
        // FITTED the budget — the sheet paints zero today and Night allows two
        // — and it is still wrong: unify §1.6 says selected is never amber on
        // any screen in any skin, and a row never emits light at all.
        await pumpFloorRoute(
          tester,
          size: const Size(390, 844),
          skin: skin,
          current: kpis(),
          previous: kpis(),
          byTerritory: <String, DashboardKpis>{'t-gp-tsh': kpis()},
          territories: seededTerritories,
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('floor-scope-chip')),
        );
        await tester.pumpAndSettle();
        expect(
          (await amberCensus(tester)).objectCount,
          0,
          reason: 'the sheet, collapsed',
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('territory-group-GP')),
        );
        await tester.pumpAndSettle();
        expect(
          (await amberCensus(tester)).objectCount,
          0,
          reason: 'the sheet, with a group open',
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('territory-option-t-gp-tsh')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('floor-scope-chip')),
        );
        await tester.pumpAndSettle();
        expect(
          (await amberCensus(tester)).objectCount,
          0,
          reason: 'the sheet, with a child selected',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('territory-option-all')),
        );
        await tester.pumpAndSettle();
      });
    }

    testWidgets('the selected row carries a non-colour signal too', (
      tester,
    ) async {
      // The house rule: colour is never the only signal. The fill is a 1.67:1
      // step on the Night ground, so the tick disc and the weight step are
      // what actually carry it.
      final handle = tester.ensureSemantics();
      await pumpFloorRoute(
        tester,
        size: const Size(390, 844),
        current: kpis(),
        previous: kpis(),
        byTerritory: <String, DashboardKpis>{'t-gp-tsh': kpis()},
        territories: seededTerritories,
      );
      await tester.tap(find.byKey(const ValueKey<String>('floor-scope-chip')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('territory-group-GP')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('territory-option-t-gp-tsh')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('floor-scope-chip')));
      await tester.pumpAndSettle();

      final marks = find.descendant(
        of: find.byKey(const ValueKey<String>('territory-option-t-gp-tsh')),
        matching: find.byType(TiqMark),
      );
      expect(marks, findsOneWidget, reason: 'the tick disc');
      expect(
        find.bySemanticsLabel(RegExp(r'Gauteng North \(Tshwane\)\. Selected')),
        findsOneWidget,
        reason: 'and the word, because a tick is silence to a screen reader',
      );
      handle.dispose();
      await tester.tap(
        find.byKey(const ValueKey<String>('territory-option-all')),
      );
      await tester.pumpAndSettle();
    });
  });
}

final TiqSkin _night = TiqSkin.night();
final TiqSkin _day = TiqSkin.day();

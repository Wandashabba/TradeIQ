import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/plate/plate.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';
import 'package:tradeiq_app/features/dashboard/data/floor_repository.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';

import '../../core/design/amber_golden.dart';
import 'floor_harness.dart';

/// THE FLOOR CAN BE SCOPED, AND UNSCOPED — AND YOU CAN SEE HOW.
///
/// The manager's home printed a territory name in the plate's eyebrow and had
/// no way to change it. The old overview has had a working window-and-territory
/// rail since it was built, so the question "how is Gauteng North doing?" could
/// only be answered by leaving the screen that exists to answer it. That is the
/// fifth capability this project has lost to a migration and the fourth one
/// only a test would have caught — so this is the test.
///
/// **PINS MOVED, 28 September 2026.** The control shipped as the eyebrow
/// itself: the words `GAUTENG NORTH · WEEK 38` were the button, with a
/// transparent 48dp band stacked over the cluster as its target, because the
/// owner's reference image has no filter chrome. The owner then looked at the
/// running screen — *"I wouldn't see it if I'm new on the app"* — so it is now
/// a visible chip at the top of the plate (`PlateScopeChip`). Three pins in
/// this file measured the old geometry and have moved with it:
///
/// * the target *was* a band over the cluster; it is now the chip's own box;
/// * the eyebrow *was* two lines the control had to not grow; the eyebrow is
///   gone from the cluster entirely (the chip prints those two facts), and
///   what is asserted instead is that the control sits outside the cluster;
/// * the printed scope *was* uppercase, from the eyebrow role. A chip is a
///   chip, and every chip in this app is sentence case.
///
/// Everything else in this file is behaviour and has not moved a line.
///
/// What it holds down, in order:
///
/// 1. the control is visible, and it says where you are;
/// 2. changing the territory rescopes **every block** — the figures move, not
///    just the label;
/// 3. clearing restores every one of them;
/// 4. the empty result is a designed state and says which slice is empty;
/// 5. a coverage request that fails withholds the list and says so, rather
///    than showing every territory's findings under one territory's name;
/// 6. the amber census is unchanged by the control.
void main() {
  final gautengOutlets = <Outlet>[outlet('o1', 'Kasi Corner Spaza')];
  final outlets = <Outlet>[
    outlet('o1', 'Kasi Corner Spaza'),
    outlet('o2', 'SaveMor Glenwood'),
  ];

  final territories = <Territory>[
    const Territory(id: 't-gn', name: 'Gauteng North', code: 'GN'),
    const Territory(id: 't-ws', name: 'Western Seaboard', code: 'WS'),
  ];

  final alerts = <AlertItem>[
    alert(
      id: 'a1',
      outletId: 'o1',
      photoId: 'p1',
      message: 'Kalahari Cola 2L out of stock',
    ),
    // THE OLDEST, so it is the head of the ranked list and therefore the
    // outlet the briefing's worst-outlet line names. It used to be enough
    // that it appeared anywhere among five rendered rows; one line stands for
    // the list now, so which finding is worst has to be stated rather than
    // left to a tie broken on the id.
    alert(
      id: 'a2',
      outletId: 'o2',
      message: 'Shelf talker missing',
      createdAt: DateTime.utc(2026, 9, 10, 6),
    ),
  ];

  /// Tap the scope chip.
  ///
  /// By its key and not by position: it is an object now, with an edge a
  /// person can see, which is the whole of this change. The previous version
  /// of this helper tapped 8dp inside the top-left of the hero cluster,
  /// because the control was a transparent band stacked over it.
  Future<void> openScope(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey<String>('floor-scope-chip')));
    await tester.pumpAndSettle();
  }

  /// What the chip is printing. The fallback sentence names the scope too —
  /// deliberately, so "no picture of Gauteng North" and "no picture at all"
  /// are different sentences — so a finder for the control says so.
  Finder onTheChip(String text) => find.descendant(
    of: find.byKey(const ValueKey<String>('floor-scope-chip')),
    matching: find.textContaining(text),
  );

  /// Open the scope sheet from the plate's chip and choose [option].
  Future<void> choose(WidgetTester tester, String option) async {
    await openScope(tester);
    await tester.tap(find.byKey(ValueKey<String>('territory-option-$option')));
    await tester.pumpAndSettle();
  }

  Future<void> pump(
    WidgetTester tester, {
    bool coverageFails = false,
    List<AlertItem>? withAlerts,
    Size size = const Size(390, 844),
    ImageProvider<Object>? plateImage,
  }) => pumpFloorRoute(
    tester,
    size: size,
    plateImage: plateImage,
    current: kpis(osa: 61, execution: 73),
    previous: kpis(osa: 64, execution: 92),
    byTerritory: <String, DashboardKpis>{
      't-gn': kpis(osa: 44, execution: 51),
    },
    coverage: <String, List<Outlet>>{
      't-gn': gautengOutlets,
      't-ws': const <Outlet>[],
    },
    coverageFails: coverageFails,
    alerts: withAlerts ?? alerts,
    outlets: outlets,
    territories: territories,
  ).then((_) {});

  group('the scope control is a thing you can see', () {
    testWidgets('it announces itself as a button and names both facts', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      expect(
        find.bySemanticsLabel(
          RegExp('All territories, Last 30 days\\. Change the territory'),
        ),
        findsOneWidget,
        reason:
            'a control a screen reader hears as a caption is a control that '
            'is not there',
      );
      handle.dispose();
    });

    testWidgets('it has an edge, a fill and a 48dp box', (tester) async {
      // PIN MOVED. This asserted that the tap target extended past the words
      // it was drawn behind, because the control WAS the words with a
      // transparent band over them. The band was a real 48dp target and it was
      // still invisible, which is the defect this change exists to fix — so
      // what is measured now is that the control is painted.
      await pump(tester, plateImage: await SyncImage.seededShelf(tester));
      final chip = find.byKey(const ValueKey<String>('floor-scope-chip'));
      expect(chip, findsOneWidget);

      expect(
        tester.getRect(chip).height,
        greaterThanOrEqualTo(TiqSkin.night().space.tapTarget),
        reason: 'a control under the tap target is a control people miss',
      );

      // Painted: a fill and a rounded edge, from the chip grammar. A control
      // on a picture with no fill is a label nobody can read, and a hard
      // rectangle is not this app's card grammar.
      final decoration = tester
          .widgetList<Container>(
            find.descendant(of: chip, matching: find.byType(Container)),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.border != null);
      expect(decoration.color, isNotNull, reason: 'no fill');
      expect(decoration.borderRadius, isNotNull, reason: 'a hard rectangle');

      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('territory-option-all')),
        findsOneWidget,
      );
      // `TorchSheets.openCount` is a process-wide guard against stacking, so
      // a test that walks away from an open sheet fails the next one.
      await tester.tap(
        find.byKey(const ValueKey<String>('territory-option-all')),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('and it costs the hero nothing', (tester) async {
      // PIN MOVED, SAME DEFECT GUARDED. `floor_proportion_test.dart` is where
      // the hero's own face is pinned, at two viewport sizes, and it is the
      // test the FIRST attempt at this control broke: a
      // `ConstrainedBox(minHeight: 48)` round the eyebrow inside the cluster
      // made the cluster overflow the plate's text zone, and the `FittedBox`
      // paid for it by scaling a 66dp hero down to 57.
      //
      // The old fix was an overlay that added no height. The new one is
      // stronger: the control is not in the cluster at all. It sits in the
      // photographic band above the strip light, so it cannot take a single dp
      // off the figure however tall it grows — which is what this measures.
      await pump(tester, plateImage: await SyncImage.seededShelf(tester));
      final chip = tester.getRect(
        find.byKey(const ValueKey<String>('floor-scope-chip')),
      );
      final cluster = tester.getRect(find.byType(PlateHeroCluster));
      expect(
        chip.overlaps(cluster),
        isFalse,
        reason:
            'the control is inside the hero cluster, which is inside the '
            'plate’s FittedBox: every dp it takes comes off the figure',
      );
      expect(
        chip.bottom,
        lessThanOrEqualTo(cluster.top),
        reason: 'the control is above the hero, not beside or under it',
      );
    });

    testWidgets('the window says the window the figures were measured over', (
      tester,
    ) async {
      await pump(tester);
      // It said "Week 38" whatever the filter held — and the filter is shared
      // with the overview, so a manager who picked a window there came back to
      // a label that contradicted the figures under it.
      //
      // Sentence case now, not `LAST 30 DAYS`: that uppercase was the eyebrow
      // role's, and this is a chip.
      expect(onTheChip('Last 30 days'), findsOneWidget);
      expect(find.textContaining('Week'), findsNothing);
    });

    testWidgets('it prints the scope it is showing, filtered or not', (
      tester,
    ) async {
      await pump(tester);
      expect(
        onTheChip('All territories'),
        findsOneWidget,
        reason: 'unfiltered is a scope and has to be printed as one',
      );

      await choose(tester, 't-gn');
      expect(onTheChip('Gauteng North'), findsOneWidget);
    });
  });

  group('changing the territory rescopes every block', () {
    testWidgets('the figures move, not just the label', (tester) async {
      await pump(tester);

      // All territories.
      expect(find.textContaining('73'), findsWidgets, reason: 'the hero');
      expect(find.textContaining('61'), findsWidgets, reason: 'availability');
      // THE LIST LEFT THIS SCREEN on 1 October 2026 and the briefing's
      // worst-outlet line is what names the head of it. Same list, same order,
      // scoped by the same coverage request — what changed is that one line
      // stands for it instead of five rows.
      expect(find.text('SaveMor Glenwood'), findsOneWidget);

      await choose(tester, 't-gn');

      expect(onTheChip('Gauteng North'), findsOneWidget);
      // THE FIGURES, not the caption. This is the whole assertion: a screen
      // that relabels itself and keeps the same numbers is worse than one
      // with no control, because it claims an answer it did not compute.
      expect(find.textContaining('51'), findsWidgets, reason: 'the hero');
      expect(find.textContaining('44'), findsWidgets, reason: 'availability');
      expect(find.textContaining('73'), findsNothing);
      // And the worst outlet, which the server cannot scope for us — the
      // briefing reads `FloorView.decisions`, which the coverage request is
      // what narrows.
      expect(find.text('Kasi Corner Spaza'), findsOneWidget);
      expect(
        find.text('SaveMor Glenwood'),
        findsNothing,
        reason: 'an outlet outside the chosen territory is out of scope',
      );
    });

    testWidgets('the picture is of the territory on screen', (tester) async {
      // PIN MOVED, 28 September 2026. This used to assert that the plate's
      // photograph stopped being SaveMor Glenwood's when SaveMor Glenwood left
      // the list, because the plate carried the shelf photograph of the outlet
      // at the top of it. It does not any more: a shelf directly above a list
      // of shelf decisions is a picture a manager can read as evidence for one
      // of them, and the seeded ones were blocks of random colour.
      //
      // What the plate carries is the PLACE in scope, so what has to be true
      // is that the picture is asked for by territory and named as one — and
      // that nothing on it claims to be a photograph from a visit.
      final handle = tester.ensureSemantics();
      final asked = <String?>[];
      final picture = await SyncImage.solid(tester);
      await pumpFloorRoute(
        tester,
        current: kpis(osa: 61, execution: 73),
        previous: kpis(osa: 64, execution: 92),
        byTerritory: <String, DashboardKpis>{
          't-gn': kpis(osa: 44, execution: 51),
        },
        coverage: <String, List<Outlet>>{
          't-gn': gautengOutlets,
          't-ws': const <Outlet>[],
        },
        alerts: alerts,
        outlets: outlets,
        territories: territories,
        extraOverrides: <Override>[
          plateImageResolverProvider.overrideWithValue((ref, territoryId) {
            asked.add(territoryId);
            return PlatePicture(
              image: picture,
              source: PlaceImageSource.generated,
            );
          }),
        ],
      );

      expect(asked, contains(null), reason: 'the footprint, unfiltered');
      await tester.tap(find.byKey(const ValueKey<String>('floor-scope-chip')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('territory-option-t-gn')),
      );
      await tester.pumpAndSettle();

      expect(
        asked,
        contains('t-gn'),
        reason:
            'the picture is asked for by territory, so it changes when the '
            'scope does — which is what makes the control legible',
      );
      expect(
        find.bySemanticsLabel(
          RegExp('Gauteng North. An illustration of the area'),
        ),
        findsOneWidget,
        reason:
            'a generated view of a place must never be readable as evidence '
            'from a visit',
      );
      expect(
        find.bySemanticsLabel(RegExp('SaveMor Glenwood')),
        findsNothing,
        reason: 'the plate names no outlet at all now',
      );
      handle.dispose();
    });

    testWidgets('clearing restores every block in one tap', (tester) async {
      await pump(tester);
      await choose(tester, 't-gn');
      expect(find.textContaining('51'), findsWidgets);

      await tester.tap(
        find.byKey(const ValueKey<String>('floor-plate-clear-territory')),
      );
      await tester.pumpAndSettle();

      expect(onTheChip('All territories'), findsOneWidget);
      expect(find.textContaining('73'), findsWidgets);
      expect(find.text('SaveMor Glenwood'), findsOneWidget);
    });

    testWidgets('unfiltered, there is no Clear — it would clear nothing', (
      tester,
    ) async {
      await pump(tester);
      expect(
        find.byKey(const ValueKey<String>('floor-plate-clear-territory')),
        findsNothing,
      );
    });
  });

  /// ── THE ABSENCES, AFTER THE LIST LEFT ────────────────────────────────
  ///
  /// These were four sentences printed under the `NEEDS A DECISION` marker,
  /// and the marker went with the list on 1 October 2026. Each one was kept,
  /// and each one moved to the thing it was actually about:
  ///
  /// | absence | where it is said now |
  /// |---|---|
  /// | nothing in THIS territory | the overdue line's own label, which names the territory |
  /// | nothing anywhere | the same label, without a territory in it |
  /// | the outlets are still arriving | [_ScopeNote], under the briefing |
  /// | the outlets did not load | [_ScopeNote], with the retry |
  ///
  /// The first two are spoken rather than printed, because the printed carrier
  /// is now the scope chip on the plate: it names the territory for every
  /// figure under it, including the `0`.
  group('the absences are four different sentences', () {
    testWidgets('this territory, this window, nothing to show', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      await choose(tester, 't-ws');

      expect(
        find.bySemanticsLabel(
          'Overdue work, none. Everything triaged in Western Seaboard.',
        ),
        findsOneWidget,
        reason: 'an empty slice and an empty world are different facts',
      );
      // And the way out of it is on screen — on the plate, beside the health
      // line, which is where it is in every other scoped state too.
      expect(
        find.byKey(const ValueKey<String>('floor-plate-clear-territory')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('unfiltered and empty names no territory', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, withAlerts: const <AlertItem>[]);
      expect(
        find.bySemanticsLabel('Overdue work, none. Everything triaged.'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a coverage failure withholds the COUNT and says why', (
      tester,
    ) async {
      await pump(tester, coverageFails: true);
      await choose(tester, 't-gn');

      expect(
        find.textContaining('did not load'),
        findsOneWidget,
        reason:
            'every territory’s findings counted under one territory’s name is '
            'a lie the reader cannot see',
      );
      // Withheld, not zeroed: a scope whose coverage request failed has an
      // unknown backlog, and "0" is the one reading that is certainly wrong.
      expect(
        find.byKey(const ValueKey<String>('floor-brief-overdue')),
        findsNothing,
      );
      expect(find.text('Kasi Corner Spaza'), findsNothing);
      expect(find.text('SaveMor Glenwood'), findsNothing);
      // The figures came from the server already scoped, so they stay.
      expect(find.textContaining('51'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('floor-retry-scope')),
        findsOneWidget,
      );
    });
  });

  group('the control costs no amber', () {
    testWidgets('the scoped screen lights the same two objects', (
      tester,
    ) async {
      await pump(tester);
      final before = await amberCensus(tester);
      await choose(tester, 't-gn');
      final after = await amberCensus(tester);
      expect(
        after.objectCount,
        before.objectCount,
        reason: 'a filter is a control and a control is not a light',
      );
    });

    testWidgets('the sheet itself emits none', (tester) async {
      await pump(tester);
      await openScope(tester);
      expect(find.byType(TorchFilterChip), findsWidgets);
      final census = await amberCensus(tester);
      expect(
        census.objectCount,
        0,
        reason:
            'while a sheet is up every amber on the route beneath goes out '
            '(unify §1.10), and a chip is never amber on any screen (§1.6)',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('territory-option-all')),
      );
      await tester.pumpAndSettle();
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/plate/plate.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';

import '../../core/design/amber_golden.dart';
import 'floor_harness.dart';

/// THE FLOOR CAN BE SCOPED, AND UNSCOPED.
///
/// The manager's home printed a territory name in the plate's eyebrow and had
/// no way to change it. The old overview has had a working window-and-territory
/// rail since it was built, so the question "how is Gauteng North doing?" could
/// only be answered by leaving the screen that exists to answer it. That is the
/// fifth capability this project has lost to a migration and the fourth one
/// only a test would have caught — so this is the test.
///
/// What it holds down, in order:
///
/// 1. changing the territory rescopes **every block** — the figures move, not
///    just the label;
/// 2. clearing restores every one of them;
/// 3. the empty result is a designed state and says which slice is empty;
/// 4. a coverage request that fails withholds the list and says so, rather
///    than showing every territory's findings under one territory's name;
/// 5. the amber census is unchanged by the control.
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
    alert(id: 'a2', outletId: 'o2', message: 'Shelf talker missing'),
  ];

  /// Tap the eyebrow's target.
  ///
  /// By position, and deliberately: the target is an overlay band across the
  /// top of the hero cluster rather than a box in its column — see
  /// `_Eyebrow` — so tapping *the top of the cluster* is exactly the geometry
  /// under test. The cluster's centre is the hero figure and is not it.
  Future<void> openScope(WidgetTester tester) async {
    final cluster = tester.getTopLeft(find.byType(PlateHeroCluster));
    await tester.tapAt(cluster + const Offset(8, 8));
    await tester.pumpAndSettle();
  }

  /// Open the scope sheet from the plate's eyebrow and choose [option].
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

  group('the eyebrow is the scope control', () {
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

    testWidgets('the target is a band, not just the words', (tester) async {
      await pump(tester, plateImage: await SyncImage.seededShelf(tester));
      final cluster = tester.getRect(find.byType(PlateHeroCluster));
      final eyebrow = tester.getRect(find.textContaining('ALL TERRITORIES'));

      // The words are ~11dp tall. The target runs the declared
      // `space.tapTarget` down from the top of the cluster, so a thumb that
      // lands under the line still lands on the control.
      await tester.tapAt(Offset(cluster.left + 8, eyebrow.bottom + 8));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('territory-option-all')),
        findsOneWidget,
        reason: 'the band extends past the words it is drawn behind',
      );
      // `TorchSheets.openCount` is a process-wide guard against stacking, so
      // a test that walks away from an open sheet fails the next one.
      await tester.tap(
        find.byKey(const ValueKey<String>('territory-option-all')),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('and it costs the hero nothing', (tester) async {
      // `floor_proportion_test.dart` is where the hero's own face is pinned,
      // at two viewport sizes, and it is the test the first attempt at this
      // control broke: a `ConstrainedBox(minHeight: 48)` round the eyebrow in
      // the column made the cluster overflow the plate's text zone, and the
      // `FittedBox` paid for it by scaling a 66dp hero down to 57. The
      // overlay adds no height at all, which is what this asserts here — the
      // eyebrow is exactly as tall as its own two lines.
      await pump(tester, plateImage: await SyncImage.seededShelf(tester));
      final eyebrow = tester.getRect(find.textContaining('ALL TERRITORIES'));
      expect(
        eyebrow.height,
        lessThan(32),
        reason:
            'the eyebrow occupies its own line height in the column; the '
            '48dp target is an overlay stacked over it',
      );
    });

    testWidgets('the window says the window the figures were measured over', (
      tester,
    ) async {
      await pump(tester);
      // It said "Week 38" whatever the filter held — and the filter is shared
      // with the overview, so a manager who picked a window there came back to
      // a label that contradicted the figures under it.
      expect(find.textContaining('LAST 30 DAYS'), findsOneWidget);
      expect(find.textContaining('WEEK'), findsNothing);
    });
  });

  group('changing the territory rescopes every block', () {
    testWidgets('the figures move, not just the label', (tester) async {
      await pump(tester);

      // All territories.
      expect(find.textContaining('73'), findsWidgets, reason: 'the hero');
      expect(find.textContaining('61'), findsWidgets, reason: 'availability');
      expect(find.text('SaveMor Glenwood'), findsOneWidget);

      await choose(tester, 't-gn');

      expect(find.textContaining('GAUTENG NORTH'), findsOneWidget);
      // THE FIGURES, not the caption. This is the whole assertion: a screen
      // that relabels itself and keeps the same numbers is worse than one
      // with no control, because it claims an answer it did not compute.
      expect(find.textContaining('51'), findsWidgets, reason: 'the hero');
      expect(find.textContaining('44'), findsWidgets, reason: 'availability');
      expect(find.textContaining('73'), findsNothing);
      // And the decision list, which the server cannot scope for us.
      expect(find.text('Kasi Corner Spaza'), findsOneWidget);
      expect(
        find.text('SaveMor Glenwood'),
        findsNothing,
        reason: 'an outlet outside the chosen territory is out of scope',
      );
    });

    testWidgets('the plate follows the new list rather than lingering', (
      tester,
    ) async {
      await pump(tester);
      await choose(tester, 't-gn');
      // The plate's photograph belongs to the outlet at the top of the list,
      // and the top of the list is now a different outlet.
      expect(
        find.bySemanticsLabel(RegExp('SaveMor Glenwood')),
        findsNothing,
        reason: 'the plate is a specimen from the territory on screen',
      );
    });

    testWidgets('clearing restores every block in one tap', (tester) async {
      await pump(tester);
      await choose(tester, 't-gn');
      expect(find.textContaining('51'), findsWidgets);

      await tester.tap(
        find.byKey(const ValueKey<String>('floor-plate-clear-territory')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('ALL TERRITORIES'), findsOneWidget);
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

  group('the absences are four different sentences', () {
    testWidgets('this territory, this window, nothing to show', (tester) async {
      await pump(tester);
      await choose(tester, 't-ws');

      expect(
        find.textContaining('Nothing needs a decision in Western Seaboard'),
        findsOneWidget,
      );
      expect(
        find.text('Everything triaged.'),
        findsNothing,
        reason: 'an empty slice and an empty world are different facts',
      );
      // And the way out of it is on screen.
      expect(
        find.byKey(const ValueKey<String>('floor-clear-territory')),
        findsOneWidget,
      );
    });

    testWidgets('unfiltered and empty still says everything triaged', (
      tester,
    ) async {
      await pump(tester, withAlerts: const <AlertItem>[]);
      expect(find.text('Everything triaged.'), findsOneWidget);
    });

    testWidgets('a coverage failure withholds the list and says why', (
      tester,
    ) async {
      await pump(tester, coverageFails: true);
      await choose(tester, 't-gn');

      expect(
        find.textContaining('did not load'),
        findsOneWidget,
        reason:
            'every territory’s findings under one territory’s name is a lie '
            'the reader cannot see',
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

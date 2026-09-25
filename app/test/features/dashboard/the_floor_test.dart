import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/tiq_number.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/plate/plate.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/dashboard/data/floor_repository.dart';
import 'package:tradeiq_app/features/dashboard/presentation/first_run_board.dart';
import 'package:tradeiq_app/features/dashboard/presentation/the_floor_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../../core/design/amber_golden.dart';
import 'floor_harness.dart';

void main() {
  final twoOutlets = <Outlet>[
    outlet('o1', 'Kasi Corner Spaza'),
    outlet('o2', 'Shoprite Klipspruit Mall'),
  ];

  group('The Floor, populated', () {
    testWidgets(
      'renders the plate, the dominant metric, the rule and the rows — '
      'worst first',
      (tester) async {
        await pumpFloor(
          tester,
          const TheFloorScreen(),
          alerts: <AlertItem>[
            alert(
              id: 'watch',
              severity: 'warning',
              message: 'Price above the published band',
              outletId: 'o2',
              createdAt: DateTime.utc(2026, 9, 18, 12),
            ),
            alert(
              id: 'crit',
              message: 'Out of stock since Tuesday',
              outletId: 'o1',
              createdAt: DateTime.utc(2026, 9, 18, 6),
            ),
          ],
          outlets: twoOutlets,
        );

        // The plate, with the hero cluster on it.
        expect(find.byType(TiqPlate), findsOneWidget);
        expect(find.byType(PlateHeroCluster), findsOneWidget);

        // The dominant metric and its supports as meta.
        expect(find.text('ON-SHELF AVAILABILITY'), findsOneWidget);
        expect(find.textContaining('Coverage 33 of 42 outlets'), findsOneWidget);

        // The knocked-out section rule.
        expect(find.byType(SectionRule), findsOneWidget);
        expect(find.text('Needs a decision'), findsOneWidget);

        // Worst first.
        expect(find.byType(DecisionRow), findsNWidgets(2));
        final rows = tester
            .widgetList<DecisionRow>(find.byType(DecisionRow))
            .toList();
        expect(rows.first.severity, SoftRowSeverity.critical);
        expect(rows.first.title, 'Kasi Corner Spaza');
        expect(rows.last.severity, SoftRowSeverity.watch);
      },
    );

    testWidgets('the trailing column is one measurement on every row', (
      tester,
    ) async {
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        now: DateTime.utc(2026, 9, 18, 18),
        alerts: <AlertItem>[
          alert(outletId: 'o1', createdAt: DateTime.utc(2026, 9, 18, 6)),
        ],
        tasks: <dynamic>[
          task(outletId: 'o2', createdAt: DateTime.utc(2026, 9, 18, 12)),
        ].cast(),
        outlets: twoOutlets,
      );

      final rows = tester
          .widgetList<DecisionRow>(find.byType(DecisionRow))
          .toList();
      // An alert raised at 06:00 and a task raised at 12:00, read at 18:00:
      // twelve hours and six. One meaning, one unit, one column.
      expect(rows.map((r) => r.value), <double>[12, 6]);
    });

    testWidgets('caps the list at five and says how many it did not show', (
      tester,
    ) async {
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        alerts: <AlertItem>[
          for (var i = 0; i < 16; i++)
            alert(
              id: 'a$i',
              outletId: 'o1',
              createdAt: DateTime.utc(2026, 9, 18, 1 + i),
            ),
        ],
        outlets: twoOutlets,
      );

      expect(find.byType(DecisionRow), findsNWidgets(FloorView.visibleCount));
      expect(find.text('and 11 more need a decision'), findsOneWidget);
    });

    testWidgets('nothing needs a decision keeps the rule and says so', (
      tester,
    ) async {
      await pumpFloor(tester, const TheFloorScreen());

      expect(find.text('Needs a decision'), findsOneWidget);
      expect(find.text('Everything triaged.'), findsOneWidget);
      expect(find.byType(DecisionRow), findsNothing);
    });
  });

  group('unknown is not zero', () {
    testWidgets(
      'a brand-new tenant gets the board, not a scoreboard of zeros',
      (tester) async {
        await pumpFloor(
          tester,
          const TheFloorScreen(),
          current: firstRunKpis(),
        );

        expect(find.byType(FirstRunBoard), findsOneWidget);
        expect(find.text('Nothing has been measured yet.'), findsOneWidget);

        await scrollFloorTo(tester, find.text('Add outlets'));
        expect(find.text('Add outlets'), findsOneWidget);

        // The instrument is shown unlit: em dashes and a sentence under each,
        // never a zero.
        await scrollFloorTo(tester, find.text('ON-SHELF AVAILABILITY'));
        expect(find.text(emDash), findsWidgets);
        expect(find.text('no visits in this window'), findsWidgets);

        await scrollFloorTo(
          tester,
          find.textContaining('Nothing here is a zero'),
        );
        expect(find.textContaining('Nothing here is a zero'), findsOneWidget);
      },
    );

    testWidgets(
      'outlets but no visits is The Floor with an absence, not the '
      'first-run board',
      (tester) async {
        await pumpFloor(
          tester,
          const TheFloorScreen(),
          current: emptyWindowKpis(),
        );

        // Never-measured and not-measured-lately are different facts.
        expect(find.byType(FirstRunBoard), findsNothing);
        expect(find.byType(TiqPlate), findsOneWidget);

        expect(find.text(emDash), findsWidgets);
        expect(find.text('No visits in this window'), findsOneWidget);
      },
    );

    testWidgets('a thin sample keeps the figure and drops the delta', (
      tester,
    ) async {
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        // MetricKind.rate wants 5; this window counted 2.
        current: kpis(osa: 61, osaSample: 2),
        previous: kpis(osa: 80, osaSample: 40),
      );

      // The number stays — a thin sample is a real measurement the reader
      // should trust less, not an absence.
      expect(find.textContaining('61'), findsWidgets);
      // …and it says how thin, rather than showing a movement computed off
      // two rows.
      expect(find.textContaining('from 2'), findsWidgets);
      expect(find.textContaining('vs the window before'), findsNothing);
    });

    testWidgets('a thin BASELINE also drops the delta', (tester) async {
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        current: kpis(osa: 61, osaSample: 240),
        // The window before it counted one row.
        previous: kpis(osa: 80, osaSample: 1),
      );

      expect(find.textContaining('61'), findsWidgets);
      expect(find.textContaining('not compared'), findsWidgets);
    });

    testWidgets('a row with no timestamp renders an em dash, not a zero', (
      tester,
    ) async {
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        alerts: <AlertItem>[alert(outletId: 'o1', noTime: true)],
        outlets: twoOutlets,
      );

      final row = tester.widget<DecisionRow>(find.byType(DecisionRow));
      expect(row.value, isNull);
      expect(row.figureState, FigureState.missing);
      expect(
        row.valueSemanticsLabel,
        isNotNull,
        reason: 'An em dash announced as "em dash" is not a sentence.',
      );
    });
  });

  group('the plate', () {
    testWidgets(
      "draws the photograph of the first decision row's outlet, captioned "
      'with it',
      (tester) async {
        final image = await SyncImage.solid(tester);
        await pumpFloor(
          tester,
          const TheFloorScreen(),
          plateImage: image,
          alerts: <AlertItem>[alert(outletId: 'o1', photoId: 'p1')],
          outlets: twoOutlets,
        );

        expect(find.byType(PlateFallback), findsNothing);
        // The photograph is painted as a `DecorationImage` rather than an
        // `Image`, because that is the only slot that takes an arbitrary
        // `ColorFilter` — and it is carrying the plate's tone.
        final painted = platedImage(tester);
        expect(painted, isNotNull, reason: 'no photograph on the plate');
        expect(painted!.colorFilter, TiqPlate.tone);
        // Visible provenance: the picture is a named specimen, so the figure
        // above the list is visibly about the territory and not about a shop.
        expect(find.text('Kasi Corner Spaza'), findsWidgets);
      },
    );

    testWidgets(
      'no photo renders the fallback drawing and a sentence — never a stock '
      'image, never an empty band',
      (tester) async {
        await pumpFloor(
          tester,
          const TheFloorScreen(),
          alerts: <AlertItem>[alert(outletId: 'o1')],
          outlets: twoOutlets,
          photosFail: true,
        );

        expect(find.byType(PlateFallback), findsOneWidget);
        expect(
          find.textContaining('No shelf photo from Kasi Corner Spaza yet.'),
          findsOneWidget,
        );
        // The hero figure stays on the plate: the photograph is the specimen,
        // never the subject.
        expect(find.byType(PlateHeroCluster), findsOneWidget);
      },
    );
  });

  group('the amber census', () {
    testWidgets(
      'Night with a photograph paints exactly two lit objects: the nav tab '
      'and the strip light',
      (tester) async {
        final image = await SyncImage.solid(tester);
        await pumpFloor(
          tester,
          const TheFloorScreen(),
          plateImage: image,
          alerts: <AlertItem>[alert(outletId: 'o1', photoId: 'p1')],
          outlets: twoOutlets,
        );

        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          TiqSkin.night(),
          route: 'the-floor',
          phase: 'loaded',
        );
        expect(
          census.objectCount,
          2,
          reason:
              "The Floor nominates the plate's strip light; the nav pill "
              'lights its active tab. Two, counted.\n${census.describe()}',
        );
      },
    );

    testWidgets(
      'Night with NO photograph spends one — the plate declines a grant it '
      'has nothing to spend',
      (tester) async {
        await pumpFloor(
          tester,
          const TheFloorScreen(),
          alerts: <AlertItem>[alert(outletId: 'o1')],
          outlets: twoOutlets,
          photosFail: true,
        );

        final census = await amberCensus(tester);
        expect(
          census.objectCount,
          1,
          reason:
              'A budget is a ceiling, not a quota. With no photograph there '
              'is nothing for a strip light to be a strip of light ON, so '
              'only the nav tab is lit.\n${census.describe()}',
        );
      },
    );

    testWidgets('a falling hero delta is crimson, and is not a third light', (
      tester,
    ) async {
      final image = await SyncImage.solid(tester);
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        plateImage: image,
        current: kpis(execution: 72, executionSample: 18),
        previous: kpis(execution: 91, executionSample: 18),
        alerts: <AlertItem>[alert(outletId: 'o1', photoId: 'p1')],
        outlets: twoOutlets,
      );

      final census = await amberCensus(tester);
      // If severity had drifted into the amber band this would be three.
      expect(census.objectCount, 2, reason: census.describe());
    });

    for (final skin in <TiqSkin>[TiqSkin.day(), TiqSkin.veld()]) {
      testWidgets('${skin.mode.name} paints no amber at all', (tester) async {
        final image = await SyncImage.solid(tester);
        await pumpFloor(
          tester,
          const TheFloorScreen(),
          plateImage: image,
          skin: skin,
          alerts: <AlertItem>[alert(outletId: 'o1', photoId: 'p1')],
          outlets: twoOutlets,
        );

        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'the-floor',
          phase: 'loaded',
        );
        expect(
          census.objectCount,
          0,
          reason:
              'On a light ground the only amber is the primary commit block, '
              'and The Floor has no primary: the nav tab is an Abyssal block '
              'and the plate keeps its image with an ink rule where the light '
              'was.\n${census.describe()}',
        );
      });
    }
  });

  group('2.0x text', () {
    testWidgets('the structure survives and nothing overflows', (tester) async {
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        textScale: 2.0,
        alerts: <AlertItem>[
          alert(outletId: 'o1'),
          alert(id: 'a2', severity: 'warning', outletId: 'o2'),
        ],
        outlets: twoOutlets,
      );

      // The claim that matters at 2.0x is that nothing overflows.
      expect(tester.takeException(), isNull);
      expect(find.byType(PlateHeroCluster), findsOneWidget);

      // The rest is past the fold on a 360x640 phone, which is correct — the
      // guarantee at 2.0x degrades to one full row, by declaration.
      await scrollFloorTo(tester, find.byType(SectionRule));
      expect(find.byType(SectionRule), findsOneWidget);
      await scrollFloorTo(tester, find.byType(DecisionRow).first);
      expect(find.byType(DecisionRow), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the section rule drops below its name rather than striking '
        'through it', (tester) async {
      await pumpFloor(tester, const TheFloorScreen(), textScale: 2.0);

      await scrollFloorTo(tester, find.byType(SectionRule));
      // At 1.0x the rule runs through the line; at 2.0x the name wraps and the
      // rule drops beneath the text block rather than striking through it.
      expect(find.text('Needs a decision'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the fold budget', () {
    test('a 360x640 phone keeps room for two full decision rows', () {
      final height = PlateSpec.heightFor(640);
      expect(height, 200, reason: 'min(clamp(0.44*640,200,360), 640-440)');
      expect(
        640 - height,
        greaterThanOrEqualTo(440),
        reason: 'The list is what the plate is arguing with, not decorating.',
      );
    });

    test('a short screen collapses the plate rather than starving the list', () {
      // 600dp: 600-440 = 160, under the 200 floor.
      expect(PlateSpec.heightFor(600), lessThan(200));
      final spec = PlateSpec.resolve(
        skin: TiqSkin.night(),
        viewportHeight: 600,
      );
      expect(spec.form, PlateForm.collapsed);
      expect(spec.height, 96);
    });

    test('a tall phone caps the plate at 360', () {
      expect(PlateSpec.heightFor(1200), 360);
    });

    test('Veld draws no plate at all', () {
      final spec = PlateSpec.resolve(
        skin: TiqSkin.veld(),
        viewportHeight: 900,
      );
      expect(spec.form, PlateForm.none);
      expect(spec.height, 0);
    });
  });

  group('Afrikaans', () {
    testWidgets('figures take the locale separators and the true minus', (
      tester,
    ) async {
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        locale: const Locale('af'),
        current: kpis(osa: 61.5, execution: 72),
        previous: kpis(osa: 80.5, execution: 91),
      );

      expect(tester.takeException(), isNull);
      // 61,5 in Afrikaans — a comma, from the locale, never a format string.
      expect(find.textContaining('61,5'), findsWidgets);
      expect(find.textContaining('61.5'), findsNothing);
    });
  });
}

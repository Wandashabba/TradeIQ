import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/tiq_number.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/figure/meter.dart';
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

        // The dominant metric and its supports as ONE line of meta. The
        // subordinates are rates, not denominators: "Coverage 79%", not
        // "Coverage 33 of 42 outlets · 42 visits". The card is a reading and
        // the denominators are provenance, one tap away.
        expect(find.text('ON-SHELF AVAILABILITY'), findsOneWidget);
        expect(find.textContaining('Coverage 79%'), findsOneWidget);

        // The section marker: words on the ground, no rule and no count
        // (owner override, 25 September 2026). `Eyebrow` uppercases for
        // display and keeps the sentence-case string in its semantics.
        expect(find.byType(SectionRule), findsNothing);
        expect(find.text('NEEDS A DECISION'), findsOneWidget);

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

    testWidgets('nothing needs a decision keeps the marker and says so', (
      tester,
    ) async {
      await pumpFloor(tester, const TheFloorScreen());

      expect(find.text('NEEDS A DECISION'), findsOneWidget);
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
      // The HERO's baseline, because the hero is where the screen's one
      // delta lives: the lead card's delta line went with the owner's
      // reference, and the rule it was demonstrating did not.
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        current: kpis(execution: 73, executionSample: 18),
        // The window before it scored nothing at all.
        previous: kpis(execution: 92, executionSample: 0),
      );

      expect(find.textContaining('73'), findsWidgets);
      expect(
        find.textContaining('not compared'),
        findsWidgets,
        reason:
            'a delta computed against an empty window is a verdict with no '
            'evidence, and the reader has to be told it was withheld',
      );
    });

    testWidgets('the lead card carries no delta line and no meter', (
      tester,
    ) async {
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        current: kpis(osa: 61, osaSample: 240),
        previous: kpis(osa: 64, osaSample: 240),
      );

      // Owner override, 25 September 2026. Both were saying the figure a
      // second time under a hero that is already the headline; the sparkline
      // carries the shape instead.
      expect(find.byType(Meter), findsNothing);
      expect(find.textContaining('vs the window before'), findsNothing);
      expect(find.textContaining('pts'), findsWidgets, reason: 'the HERO\'s');
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
      "draws the photograph of the first decision row's outlet, attributed "
      'to it',
      (tester) async {
        final handle = tester.ensureSemantics();
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
        // PROVENANCE, IN THE SEMANTICS. It used to print on the plate's first
        // line; the owner's reference of 25 September 2026 has no caption, so
        // the specimen is named where a reader of the screen still gets it
        // and a looker at the screen is not handed a second line of type over
        // a photograph. The picture is still a named specimen, so the figure
        // above the list is still visibly about the territory.
        expect(
          find.text('Kasi Corner Spaza'),
          findsNothing,
          reason: 'no printed caption',
        );
        expect(
          find.bySemanticsLabel(RegExp('Kasi Corner Spaza')),
          findsWidgets,
          reason: 'an unattributed photograph is an assertion',
        );
        handle.dispose();
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
      await scrollFloorTo(tester, find.text('NEEDS A DECISION'));
      expect(find.text('NEEDS A DECISION'), findsOneWidget);
      await scrollFloorTo(tester, find.byType(DecisionRow).first);
      expect(find.byType(DecisionRow), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the section marker wraps rather than clipping', (
      tester,
    ) async {
      await pumpFloor(tester, const TheFloorScreen(), textScale: 2.0);

      // The marker is words on the ground now, and at 2.0x it takes the two
      // lines the eyebrow role allows rather than being cut. The rule it
      // replaced had its own drop-below-the-name behaviour; that component
      // still has it, and `section_rule_test.dart` still asserts it.
      await scrollFloorTo(tester, find.text('NEEDS A DECISION'));
      expect(find.text('NEEDS A DECISION'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the fold budget', () {
    test('a 360x640 phone keeps room for two full decision rows', () {
      final height = PlateSpec.heightFor(640);
      expect(height, 200, reason: 'min(clamp(0.40*640,200,320), 640-440)');
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

    test('a tall phone caps the plate at 320', () {
      // 360 until 25 September 2026. The plate became an inset card, which
      // also spends the shell's top inset and a gap beneath itself, so the
      // same fraction bought a bigger object and the list lost the third row
      // the owner's reference shows. See `PlateSpec.heightFor`.
      expect(PlateSpec.heightFor(1200), 320);
      expect(PlateSpec.heightFor(844), 320);
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
        // A row, so there is a figure on screen that still has a decimal
        // place: the rates are whole numbers by declaration now, and a test
        // about decimal separators needs a decimal to separate. 56.9 hours
        // before the pinned clock.
        alerts: <AlertItem>[
          alert(outletId: 'o1', createdAt: DateTime.utc(2026, 9, 16, 9, 6)),
        ],
        outlets: twoOutlets,
      );

      expect(tester.takeException(), isNull);
      // 56,9 in Afrikaans — a comma, from the locale, never a format string.
      expect(find.textContaining('56,9'), findsWidgets);
      expect(find.textContaining('56.9'), findsNothing);
      // And the true minus on the hero's delta, never a hyphen.
      expect(find.textContaining('\u221219'), findsWidgets);
      expect(find.textContaining('-19'), findsNothing);
    });
  });
}

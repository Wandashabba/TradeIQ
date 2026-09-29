import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/tiq_number.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/figure/meter.dart';
import 'package:tradeiq_app/core/widgets/torchlight/mark/delta.dart';
import 'package:tradeiq_app/core/widgets/torchlight/plate/plate.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/dashboard/data/floor_repository.dart';
import 'package:tradeiq_app/features/dashboard/presentation/first_run_board.dart';
import 'package:tradeiq_app/features/dashboard/presentation/the_floor_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';

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
      // THE PIN MOVED, AND IT MOVED BECAUSE THE UNIT DID.
      //
      // This used to assert `pts` was on screen, as the proof that the hero
      // still had a delta after the lead card lost its own. The owner then
      // read the running hero — `▼ −19 pts` — and cut both redundancies: the
      // minus, because the triangle is the sign (fixed in `Delta` itself, for
      // every screen), and `pts`, because a territory-health score is not
      // measured in anything else and the figure above it carries no suffix
      // either. So the thing this line is really for — "the hero kept its
      // delta" — is asserted as the delta, and the unit is asserted where it
      // went: into the sentence a screen reader gets.
      expect(
        find.descendant(
          of: find.byType(PlateHeroCluster),
          matching: find.byType(Delta),
        ),
        findsOneWidget,
        reason: 'the HERO still carries a delta',
      );
      expect(
        find.textContaining('pts'),
        findsNothing,
        reason: 'the unit is noise beside a score',
      );
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
    testWidgets('draws the place in scope, and says it is an illustration', (
      tester,
    ) async {
      // PIN MOVED, 28 September 2026. This test read "draws the photograph of
      // the first decision row's outlet, attributed to it", and it held down a
      // coupling that has been deliberately cut: the plate carried the shelf
      // photograph of whichever outlet was at the top of the decision list.
      //
      // Two things were wrong with that. The seeded "photographs" are four
      // rows of random colour blocks, so a demo opened on noise — cosmetic.
      // And a shelf directly above a list of shelf decisions is a picture a
      // manager can read as evidence for one of them, when it was at best a
      // specimen of a different finding — not cosmetic at all.
      //
      // The plate carries a view of the TERRITORY now. What has to hold is
      // that it is still painted through the toned decoration, and that
      // nothing about it claims to be a capture.
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
      // The picture is painted as a `DecorationImage` rather than an `Image`,
      // because that is the only slot that takes an arbitrary `ColorFilter` —
      // and it is carrying the plate's tone.
      final painted = platedImage(tester);
      expect(painted, isNotNull, reason: 'no picture on the plate');
      expect(painted!.colorFilter, TiqPlate.tone);
      // WHAT IT IS, IN THE SEMANTICS. The owner's reference of 25 September
      // 2026 has no caption line, so what the picture is gets said where a
      // reader of the screen still gets it. It names the scope and it says
      // "illustration", because the seeded place images are generated and a
      // reader must never be left to assume a photograph.
      expect(
        find.bySemanticsLabel(
          RegExp(
            'All territories. An illustration of the area, not a photograph '
            'from a visit',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Kasi Corner Spaza.*photograph')),
        findsNothing,
        reason: 'the plate attributes itself to no outlet at all now',
      );
      handle.dispose();
    });

    testWidgets(
      'a supplied photograph is called a photograph — and still not evidence',
      (tester) async {
        // PIN ADDED, 29 September 2026. The owner supplied real photographs
        // for twelve of the thirteen territories, and the sentence above went
        // from true to false for those: a screen reader saying "an
        // illustration of the area" over a photograph of the Union Buildings
        // is the same error as the reverse, and this screen refuses it in both
        // directions.
        //
        // What must NOT move is the second clause. `place_images` has no
        // `visitId`, no GPS tag and no capture time whichever way the picture
        // was made, and a real photograph is if anything more mistakable for
        // evidence than a drawing is.
        final handle = tester.ensureSemantics();
        await pumpFloor(
          tester,
          const TheFloorScreen(),
          plateImage: await SyncImage.solid(tester),
          plateImageSource: PlaceImageSource.supplied,
          alerts: <AlertItem>[alert(outletId: 'o1', photoId: 'p1')],
          outlets: twoOutlets,
        );

        expect(
          find.bySemanticsLabel(
            RegExp('All territories. A photograph of the area, not from a visit'),
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp('illustration')),
          findsNothing,
          reason: 'a photograph described as a drawing is as false as the '
              'other way round',
        );
        handle.dispose();
      },
    );

    testWidgets('an origin the server did not state is said to be unstated', (
      tester,
    ) async {
      // The header was absent, or carried a word this build does not know.
      // There is exactly one honest sentence left and it is not either of the
      // other two: defaulting to "illustration" would libel a photograph and
      // defaulting to "photograph" would promote a drawing to a capture. The
      // clause that never moves still holds.
      final handle = tester.ensureSemantics();
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        plateImage: await SyncImage.solid(tester),
        plateImageSource: null,
        alerts: <AlertItem>[alert(outletId: 'o1', photoId: 'p1')],
        outlets: twoOutlets,
      );

      expect(
        find.bySemanticsLabel(
          RegExp(
            'All territories. A picture of the area. Its origin was not '
            'stated, and it is not from a visit',
          ),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('illustration')), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('A photograph of the area')),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets(
      'no picture renders the fallback drawing and a sentence — never a '
      'stock image, never a generated one, never an empty band',
      (tester) async {
        // No `plateImage` override, so the real resolver runs against a fake
        // territories repository with no place image in it — the request
        // fails, exactly as it does for a tenant whose territories have never
        // been pictured.
        await pumpFloor(
          tester,
          const TheFloorScreen(),
          alerts: <AlertItem>[alert(outletId: 'o1')],
          outlets: twoOutlets,
        );

        expect(find.byType(PlateFallback), findsOneWidget);
        // SENTENCE MOVED with the picture it is about: it said "No shelf photo
        // from Kasi Corner Spaza yet." THE RULE IT ENFORCES HAS NOT MOVED — a
        // drawing and a sentence, and never a generated picture standing in
        // for one that is missing.
        expect(
          find.textContaining('No picture of your territories yet.'),
          findsOneWidget,
        );
        expect(
          platedImage(tester),
          isNull,
          reason: 'something was painted where there is nothing to paint',
        );
        // The hero figure stays on the plate: the picture is the ground,
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

    for (final skin in <TiqSkin>[TiqSkin.day()]) {
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

    test('a tall phone caps the plate at 312', () {
      // 360 until 25 September 2026. The plate became an inset card, which
      // also spends the shell's top inset and a gap beneath itself, so the
      // same fraction bought a bigger object and the list lost the third row
      // the owner's reference shows. See `PlateSpec.heightFor`.
      expect(PlateSpec.heightFor(1200), 312);
      expect(PlateSpec.heightFor(844), 312);
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
      // AND NO SIGN AT ALL ON THE HERO'S DELTA — moved 25 September 2026.
      //
      // This pinned the true minus (U+2212, never a hyphen) on `−19`. The
      // minus is gone: the triangle beside it already says "down", and the
      // owner read the two together as one word said twice. The rule the pin
      // was protecting — *this app never prints ASCII hyphen-minus where it
      // means a minus sign* — is not weakened, it is asserted on the whole
      // screen instead of on one figure, which is strictly stronger: after
      // this change nothing on The Floor may carry a hyphen before a digit.
      expect(find.textContaining('19'), findsWidgets);
      expect(find.textContaining('\u221219'), findsNothing);
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        expect(
          RegExp(r'-\d').hasMatch(t.data ?? ''),
          isFalse,
          reason: '"${t.data}" carries an ASCII hyphen before a digit',
        );
      }
      // The true minus itself is still the app's minus, and
      // `tiq_number_test.dart` is where that is pinned at the formatter.
      expect(minusSign, '\u2212');
    });
  });

  // ── The semantic colour, 28 September 2026 ──────────────────────────
  //
  // "Nothing on the screen tells you at a glance whether a number is good or
  // bad, which is the whole job of a manager's home screen." These are the
  // pins on the answer, and the reason they are on THE FLOOR rather than on
  // the components is that the components cannot tell whether a screen
  // applied the rule: a hero that renders in ink-1 is a perfectly valid hero.
  group('a figure carries its standing', () {
    /// The colour of the run that prints [text].
    Color inkOf(WidgetTester tester, String text) {
      for (final widget in tester.widgetList<RichText>(find.byType(RichText))) {
        final span = widget.text;
        if (!span.toPlainText().contains(text)) continue;
        Color? found;
        span.visitChildren((InlineSpan child) {
          if (child is TextSpan &&
              (child.text ?? '').contains(text) &&
              child.style?.color != null) {
            found = child.style!.color;
            return false;
          }
          return true;
        });
        if (found != null) return found!;
      }
      fail('No run printing "$text" was found on The Floor.');
    }

    testWidgets('the hero is crimson under the published standard', (
      tester,
    ) async {
      final skin = TiqSkin.day();
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        skin: skin,
        // 73 against a published 75, and 61% against a published 95.
        current: kpis(osa: 61, execution: 73),
        previous: kpis(osa: 64, execution: 92),
        outlets: twoOutlets,
      );

      expect(
        inkOf(tester, '73'),
        skin.palette.bad,
        reason:
            'Territory health is the execution score and the execution score '
            'is measured against 75. A hero that renders in plain ink says '
            'nothing about whether 73 is good news.',
      );
      expect(
        inkOf(tester, '61'),
        skin.palette.bad,
        reason: 'Availability against the published standard of 95.',
      );
      // AND THE WORDS ARE STILL THERE. Colour is never the only signal: the
      // plate's own delta sentence names the verdict, so a reader who cannot
      // see the hue gets the same reading.
      expect(
        find.bySemanticsLabel(RegExp('which is bad')),
        findsWidgets,
        reason:
            'The delta sentence carries the verdict word. A reader who '
            'cannot see the hue must get the same reading.',
      );
    });

    testWidgets('a hero on target is green, in both grounds', (tester) async {
      for (final skin in <TiqSkin>[TiqSkin.night(), TiqSkin.day()]) {
        await pumpFloor(
          tester,
          const TheFloorScreen(),
          skin: skin,
          // 88 against 75, and 97% against 95.
          current: kpis(osa: 97, execution: 88),
          previous: kpis(osa: 96, execution: 87),
          outlets: twoOutlets,
        );
        expect(
          inkOf(tester, '88'),
          skin.palette.good,
          reason: '${skin.mode.name}: a score over its standard is good news.',
        );
      }
    });

    testWidgets('an unmeasured window colours nothing', (tester) async {
      // THE ONE THAT MATTERS MOST. An em dash is an em dash: a window with no
      // visits has no standing, and a screen that painted one would be
      // inventing a verdict out of an absence.
      final skin = TiqSkin.day();
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        skin: skin,
        current: emptyWindowKpis(),
        outlets: twoOutlets,
      );
      for (final widget in tester.widgetList<RichText>(find.byType(RichText))) {
        final span = widget.text;
        if (!span.toPlainText().contains(emDash)) continue;
        span.visitChildren((InlineSpan child) {
          if (child is TextSpan && (child.text ?? '').contains(emDash)) {
            expect(
              child.style?.color,
              skin.palette.ink3,
              reason: 'An em dash is ink-3, never a verdict.',
            );
          }
          return true;
        });
      }
    });
  });
}

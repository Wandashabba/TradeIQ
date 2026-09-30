import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/figure_slot.dart';
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

import 'package:tradeiq_app/features/assistant/data/assistant_repository.dart';

import '../../core/design/amber_golden.dart';
import '../assistant/ask_harness.dart' show ScriptedRepository, rankedTurn;
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

        // THE DOMINANT METRIC IS BRIEFING LINE TWO NOW, not a stat card.
        //
        // It was `StatTile` under an `ON-SHELF AVAILABILITY` eyebrow, with
        // "Coverage 79% · Price compliance 91%" as one line of meta under it.
        // The figure did not move — it is the same `snapshot.current.osaPct`
        // against the same published 95 — but the card did: printing it twice,
        // once in the briefing and once in a tile eight dp below, is the
        // defect the tile's own doc named when it deleted its meter and its
        // delta line.
        //
        // The supports went with the card, to the overview the card already
        // opened and the briefing line still opens. So this asserts what is
        // now true rather than keeping a string that would have to be drawn
        // somewhere to satisfy it.
        expect(
          find.byKey(const ValueKey<String>('floor-brief-availability')),
          findsOneWidget,
        );
        expect(find.text('On-shelf availability'), findsOneWidget);
        expect(find.textContaining('Coverage 79%'), findsNothing);

        await revealDecisions(tester);

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

      await revealDecisions(tester);
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

      await revealDecisions(tester);
      expect(find.byType(DecisionRow), findsNWidgets(FloorView.visibleCount));
      expect(find.text('and 11 more need a decision'), findsOneWidget);
    });

    testWidgets('nothing needs a decision keeps the marker and says so', (
      tester,
    ) async {
      await pumpFloor(tester, const TheFloorScreen());
      await revealDecisions(tester);

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
        // The availability briefing line STAYS in an unmeasured window and
        // says why, rather than being omitted. An unmeasured window is not a
        // window without availability, it is a window whose availability
        // nobody knows, and unify §4 exists to keep those two apart. This is
        // the same sentence the stat card printed, on the line that replaced
        // it.
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

      // …AND IT IS MARKED AS THIN, on the briefing line that now carries this
      // figure. It used to be the stat card's `FigureSampling`, which drew
      // "from 2" as a line of meta under the tile; the tile went when the
      // briefing took the figure (see the note in the populated test above),
      // and `FigureState.lowSample` is the channel that survived — the slot
      // holds the number at ink-2 rather than printing a second sentence.
      //
      // The fact this test was written to pin has not moved: a thin sample
      // keeps its figure and loses its delta. Only the carrier has.
      final availability = tester.widget<FigureSlot>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('floor-brief-availability')),
          matching: find.byType(FigureSlot),
        ),
      );
      expect(availability.state, FigureState.lowSample);
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
      await revealDecisions(tester);

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
      // The Floor's default skin is Night, so this is Night's tone — the
      // tone is per skin since 29 September 2026 and `TiqPlate.tone` no
      // longer exists, because a tone with no skin is the bug.
      expect(painted!.colorFilter, TiqPlate.toneFor(TiqSkin.night().palette));
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

  /// ── THE AMBER CENSUS, PHASE BY PHASE ────────────────────────────────
  ///
  /// The Floor gave up its nav pill on 30 September 2026 and this group is
  /// where that shows. The allocator counts `navActiveTab` as slot 1 **whenever
  /// the pill renders**, so while it was there Night's budget of two was one
  /// chrome object plus one content object — and this screen now wants two
  /// content objects at once: the plate's strip light, plus (by phase) either
  /// Send or the answer's focus object.
  ///
  /// With no pill both grants go to content and every phase fits. The table
  /// below is the whole claim, and each row of it is a test:
  ///
  /// | phase | Night | Day | which |
  /// |---|---|---|---|
  /// | at rest | 1 | 0 | the strip light; Send is disabled and a disabled Send is never amber |
  /// | at rest, no photograph | 0 | 0 | nothing to light — a budget is a ceiling |
  /// | typing, keyboard up | 2 | 1 | the strip light + Send |
  /// | typing, keyboard down | 2 | 1 | the same two — the nav is gone, so the keyboard no longer changes the count |
  /// | answered, with a focus object | 2 | 0 | the strip light + one ranked bar |
  /// | offline | 1 | 0 | the strip light; Send is held |
  ///
  /// The two `typing` rows are the pair that mattered: under the old
  /// arrangement they differed (the keyboard hid the nav and handed its grant
  /// back), and the keyboard-down case was a three-object over-claim the
  /// moment a plate was on the screen. They are now the same number, which is
  /// the arrangement doing its job.
  group('the amber census', () {
    /// The screen with a photograph on the plate and something in the list.
    ///
    /// **Through the router harness**, because the census now has to type.
    /// `EditableText` builds a `TextSelectionOverlay` the moment the trough
    /// takes focus and that needs an `Overlay` ancestor, which `pumpFloor`
    /// deliberately does not provide — it stands the screen up with no
    /// Navigator so a sheet has nowhere to open. Typing is behaviour, and
    /// `pumpFloorRoute` is the harness for behaviour.
    Future<void> floor(
      WidgetTester tester, {
      TiqSkin? skin,
      double keyboard = 0,
      bool photograph = true,
      bool online = true,
      AssistantRepository? assistant,
      Size size = const Size(360, 640),
    }) async {
      await pumpFloorRoute(
        tester,
        skin: skin,
        size: size,
        keyboard: keyboard,
        online: online,
        assistant: assistant,
        plateImage: photograph ? await SyncImage.solid(tester) : null,
        current: kpis(execution: 72, executionSample: 18),
        previous: kpis(execution: 91, executionSample: 18),
        alerts: <AlertItem>[alert(outletId: 'o1', photoId: 'p1')],
        outlets: twoOutlets,
      );
    }

    /// Put a question in the trough, which is the only thing that arms Send.
    Future<void> type(WidgetTester tester) async {
      await tester.enterText(
        find.byKey(const ValueKey<String>('ask-composer-field')),
        'Why is 72 down?',
      );
      await tester.pump();
    }

    testWidgets(
      'Night at rest paints one lit object: the plate\'s strip light',
      (tester) async {
        await floor(tester);

        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          TiqSkin.night(),
          route: 'the-floor',
          phase: 'loaded',
        );
        expect(
          census.objectCount,
          1,
          reason:
              'At rest the only armed thing on this screen is nothing: the '
              'trough is empty, so Send is disabled, and a disabled Send is '
              'never amber in any skin. The nav tab that used to be object 1 '
              'went with the pill.\n${census.describe()}',
        );
      },
    );

    testWidgets(
      'Night with NO photograph paints nothing — a budget is a ceiling',
      (tester) async {
        await floor(tester, photograph: false);

        final census = await amberCensus(tester);
        expect(
          census.objectCount,
          0,
          reason:
              'With no photograph there is nothing for a strip light to be a '
              'strip of light ON, so the plate spends nothing — and there is '
              'no longer a nav tab underneath it to make the count one '
              'anyway.\n${census.describe()}',
        );
      },
    );

    for (final (name, keyboard) in const <(String, double)>[
      ('keyboard up', 320),
      ('keyboard down', 0),
    ]) {
      testWidgets('Night typing, $name: the strip light and Send', (
        tester,
      ) async {
        await floor(tester, keyboard: keyboard);
        await type(tester);

        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          TiqSkin.night(),
          route: 'the-floor',
          phase: 'typing',
        );
        expect(
          census.objectCount,
          2,
          reason:
              'Send is rung 1 and the strip light rung 2, and with no nav tab '
              'ahead of them both are granted. THIS IS THE PAIR THE '
              'ARRANGEMENT WAS CHOSEN FOR: with the pill still on the screen '
              'the keyboard-down case would be three claims against a budget '
              'of two.\n${census.describe()}',
        );
      });

      testWidgets('Day typing, $name: Send alone takes the one grant', (
        tester,
      ) async {
        await floor(tester, skin: TiqSkin.day(), keyboard: keyboard);
        await type(tester);

        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          TiqSkin.day(),
          route: 'the-floor',
          phase: 'typing',
        );
        expect(
          census.objectCount,
          1,
          reason:
              'On a light ground the ladder has one rung and it is the '
              'primary commit block. The strip light falls back to its unlit '
              'ink rule, which the plate already did on every Day screen '
              'before this change.\n${census.describe()}',
        );
      });
    }

    testWidgets(
      'Night answered: the strip light stays, and the answer lights one bar',
      (tester) async {
        // ON THE TALL PHONE, because this census has to see BOTH objects in
        // one frame and the census measures painted pixels rather than
        // granted claims. At 360×640 the plate is lit and the answer's bar is
        // below the fold, which is legal — a budget is a ceiling — but it
        // proves only half of what this test is for.
        await floor(
          tester,
          assistant: ScriptedRepository(rankedTurn()),
          size: const Size(390, 844),
        );
        await type(tester);
        // The keyboard's own Send key, which is the composer's `onSubmitted`
        // and the same closure the button's `onPressed` runs. Tapping the
        // button would need `ensureSemantics`, and a semantics handle open
        // across an amber census is a second tree to keep in step.
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pumpAndSettle();

        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          TiqSkin.night(),
          route: 'the-floor',
          phase: 'landed-focus',
        );
        expect(
          census.objectCount,
          2,
          reason:
              'THE ANSWERED STATE IS WHY THE PILL WENT. The plate keeps its '
              'light — the manager is still in the territory they asked '
              'about — and the answer lights the one bar the server named. '
              'Those are rungs 2 and 3; a nav tab at rung 0 would have '
              'outranked one of them and the census would read '
              'one.\n${census.describe()}',
        );
      },
    );

    testWidgets('Night offline: the composer is held and lights nothing', (
      tester,
    ) async {
      await floor(tester, online: false);

      final census = await amberCensus(tester);
      expect(
        census.objectCount,
        1,
        reason:
            'Offline disables Send, and a disabled Send is never amber. The '
            'plate is unaffected: the figures on it were measured before the '
            'connection went and are still true.\n${census.describe()}',
      );
    });

    testWidgets('a falling hero delta is crimson, and is not a third light', (
      tester,
    ) async {
      await floor(tester);
      await type(tester);

      final census = await amberCensus(tester);
      // Two, not three: if severity had drifted into the amber band the
      // hero's `▼ 19` would be counted here.
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

      // THE HERO IS ASSERTED BEFORE THE SCROLL AND THE ROW AFTER IT, because
      // the two are no longer on screen together. The briefing and the
      // composer went between them on 30 September 2026 and the decision list
      // moved below the fold on a 360×640 phone; scrolling to the row lets the
      // plate leave, and a `ListView` that has scrolled its first child away
      // has disposed it. Both figures are still drawn by the same formatter in
      // the same locale — which is what this test is about.
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

      await revealDecisions(tester);
      // 56,9 in Afrikaans — a comma, from the locale, never a format string.
      expect(find.textContaining('56,9'), findsWidgets);
      expect(find.textContaining('56.9'), findsNothing);

      // The hyphen sweep runs over BOTH halves of the screen: everything the
      // plate drew before the scroll and everything the list drew after it.
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

    testWidgets('a hero on target is green on Day', (tester) async {
      // THIS USED TO SAY "in both grounds" AND LOOP BOTH SKINS. It asserted
      // the 28 September decision — that a figure's ground does not change
      // whether it carries a verdict — and the owner reversed that for Night
      // the next day. Day is what is left of it, unchanged.
      final skin = TiqSkin.day();
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
        reason: 'A score over its standard is good news on paper.',
      );
    });

    // ── NIGHT, 29 September 2026 ──────────────────────────────────────
    testWidgets('the Night hero is luminous below its standard', (
      tester,
    ) async {
      final skin = TiqSkin.night();
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        skin: skin,
        // The same 73-against-75 and 61%-against-95 the Day test above uses,
        // where both render crimson.
        current: kpis(osa: 61, execution: 73),
        previous: kpis(osa: 64, execution: 92),
        outlets: twoOutlets,
      );
      expect(
        inkOf(tester, '73'),
        skin.palette.ink1,
        reason:
            'The hero is ink-1 at every band on Night. Section 16.2 has said '
            'so since the visit outcome shipped — a severity-coded figure at '
            '72px is a hue doing a number\'s job, and it is the one object '
            'large enough that its colour reads as the whole message. The '
            "artifact's own hero `72` is bone beside a crimson delta.",
      );
      expect(
        inkOf(tester, '61'),
        skin.palette.ink1,
        reason:
            'The availability tile is a row figure. Its verdict is on the '
            "sparkline's crimson last dot, exactly as the artifact's lead row "
            'draws it.',
      );
    });

    testWidgets('the Night hero is luminous on target too', (tester) async {
      final skin = TiqSkin.night();
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        skin: skin,
        current: kpis(osa: 97, execution: 88),
        previous: kpis(osa: 96, execution: 87),
        outlets: twoOutlets,
      );
      expect(
        inkOf(tester, '88'),
        skin.palette.ink1,
        reason:
            'Green left the Night figures with crimson. The owner asked for '
            'luminous, not for a different hue.',
      );
    });

    testWidgets('and the standing is on the plate in words instead', (
      tester,
    ) async {
      // THE CUE THAT REPLACED THE COLOUR. Taking the hue off the hero would
      // have left the plate carrying only the DELTA, and a delta says whether
      // the score moved, not whether it is where it should be — the screen's
      // own comment makes exactly that distinction. So the standing is printed
      // on the health line now, out of the semantics label where only a screen
      // reader could reach it.
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        skin: TiqSkin.night(),
        current: kpis(osa: 61, execution: 73),
        previous: kpis(osa: 64, execution: 92),
        outlets: twoOutlets,
      );
      expect(
        find.text('Territory health \u00b7 Close to the standard'),
        findsOneWidget,
        reason:
            'A luminous hero with no word beside it is a number with no '
            'verdict. 73 against a published 75 is inside the watch band.',
      );
    });

    testWidgets('a Night row figure is luminous, and its dot is not', (
      tester,
    ) async {
      // THE OWNER'S ACTUAL COMPLAINT, AS A TEST: "make the numbers lumunuous
      // white and not red". The decision rows were the crimson they were
      // looking at. The dot beside the name still carries the verdict, which
      // is the only reason the colour may leave the figure at all.
      final skin = TiqSkin.night();
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        skin: skin,
        current: kpis(osa: 61, execution: 73),
        previous: kpis(osa: 64, execution: 92),
        now: DateTime.utc(2026, 9, 18, 18),
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
      await revealDecisions(tester);
      // The figures themselves: bone, both of them, on a critical row and a
      // watch row alike.
      for (final hours in <String>['12', '6']) {
        expect(inkOf(tester, hours), skin.palette.ink1);
      }
      final rows = tester.widgetList<DecisionRow>(find.byType(DecisionRow));
      expect(rows, isNotEmpty);
      for (final row in rows) {
        expect(
          row.severity,
          isNot(SoftRowSeverity.none),
          reason:
              'If a row has no severity bar then its figure WAS the only '
              'signal and the colour may not leave it. THIS is the assertion '
              'that makes the reversal safe rather than merely requested.',
        );
        expect(
          row.severityLabel,
          isNotNull,
          reason:
              'And the word is announced first in the row label, so a reader '
              'who sees neither hue nor bar still gets the verdict.',
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

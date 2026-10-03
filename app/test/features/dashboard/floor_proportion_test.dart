import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/torch_press.dart';
import 'package:tradeiq_app/core/widgets/torchlight/card.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input/filter_chip.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/plate/plate.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/assistant/answer/composer.dart';
import 'package:tradeiq_app/features/dashboard/presentation/floor_ask.dart';
import 'package:tradeiq_app/features/dashboard/presentation/the_floor_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../agent_harness.dart';
import 'floor_harness.dart';

/// THE HIERARCHY, AS MEASURED PIXELS.
///
/// The Floor shipped with its hierarchy inverted: on a 360×640 phone the
/// territory-health hero rendered **18.7dp** tall and the on-shelf-availability
/// figure that supports it rendered **34dp**. The supporting metric was 1.8×
/// the thing it supports, and the hero was crammed into the plate's bottom-left
/// corner with a caption floating in a hole above it.
///
/// The cause was one line of layout: the plate's text zone laid its caption and
/// its hero cluster out with `spaceBetween` and a `Flexible` on each, which is
/// not "caption at the top, hero at the foot" — it is **half the zone each**.
/// A 17dp caption took 44dp and a 129dp cluster took the other 44, and the
/// `FittedBox` below crushed the figure to a third of its face.
///
/// Nothing failed, because every test here asked whether a widget was present.
/// These ask how big it is.
void main() {
  // THE FOLD IS A FACT ABOUT THE TYPEFACE. `flutter_test`'s own font is wider
  // than Schibsted Grotesk, so every label wraps sooner and every screen
  // measures TALLER in it — which is the right default for a test about a role
  // or a count and the wrong one for a file whose every assertion is a height.
  // The row counts below are the counts on the device because of this line.
  setUpAll(loadAgentFonts);

  final outlets = <Outlet>[
    outlet('o1', 'Corner Express Parkhurst'),
    outlet('o2', 'Shoprite Klipspruit Mall'),
    outlet('o3', 'Kasi Corner Spaza'),
    outlet('o4', 'Pick n Pay Rosebank'),
  ];

  final decisions = <AlertItem>[
    alert(
      id: 'a1',
      outletId: 'o1',
      photoId: 'p1',
      createdAt: DateTime.utc(2026, 9, 9, 12),
    ),
    alert(
      id: 'a2',
      severity: 'warning',
      outletId: 'o2',
      message: 'Price above the published band for the third week running',
      createdAt: DateTime.utc(2026, 9, 12),
    ),
    alert(
      id: 'a3',
      outletId: 'o3',
      message: 'Planogram compliance under 50 percent on the main aisle',
      createdAt: DateTime.utc(2026, 9, 14),
    ),
    alert(
      id: 'a4',
      severity: 'warning',
      outletId: 'o4',
      message: 'Competitor facings doubled since the last visit',
      createdAt: DateTime.utc(2026, 9, 15),
    ),
  ];

  Future<void> pump(WidgetTester tester, Size size) async => pumpFloor(
    tester,
    const TheFloorScreen(),
    size: size,
    // A real photograph, so the plate is in its photographic state and the
    // hero sits on it — the state the whole screen is proportioned around.
    plateImage: await SyncImage.seededShelf(tester),
    // The figures from the owner's screenshot: availability 94, health 73.
    current: kpis(osa: 94, execution: 73),
    previous: kpis(osa: 90, execution: 92),
    alerts: decisions,
    outlets: outlets,
  );

  /// The tallest figure inside [of]. `FigureSlot` paints a `TextSpan`, so a
  /// figure is a `Text` with no `data` — and its painted height is the only
  /// honest measure of a face that a `FittedBox` may have scaled.
  double figureHeight(WidgetTester tester, {required Finder of}) {
    var tallest = 0.0;
    for (final element in find
        .descendant(of: of, matching: find.byType(Text))
        .evaluate()) {
      final text = element.widget as Text;
      if (text.data != null) continue;
      final height = tester.getRect(find.byWidget(text)).height;
      if (height > tallest) tallest = height;
    }
    return tallest;
  }

  group('the hero is the biggest figure on the screen', () {
    for (final (name, size) in <(String, Size)>[
      ('a 412×915 phone', Size(412, 915)),
      ('a browser window', Size(1280, 800)),
    ]) {
      testWidgets('on $name', (tester) async {
        await pump(tester, size);

        final hero = figureHeight(tester, of: find.byType(PlateHeroCluster));
        // THE SUPPORTING FIGURE IS A BRIEFING LINE NOW. It was the
        // availability `StatTile`, which went when the briefing took that
        // figure — see the note in `the_floor_test.dart`. What this measures
        // is unchanged: the hero against the largest figure under it.
        final supporting = figureHeight(
          tester,
          of: find.byType(FloorBriefingBlock),
        );

        expect(
          hero,
          greaterThan(supporting * 1.5),
          reason:
              'territory health renders ${hero}dp and the briefing\'s '
              'largest figure ${supporting}dp. The hero is the screen; the '
              'briefing is three lines under it.',
        );

        // AND IT IS AT A DECLARED FACE, NOT A SCALED-DOWN ONE — and the floor
        // is the COMPACT face now, not the full one.
        //
        // This asserted 60dp, which is `hero.figure` at 72/0.92. The plate is
        // 30% of the viewport since 30 September 2026 rather than up to 312dp,
        // so on anything under an ~867dp viewport it resolves below the 260dp
        // mark where `PlateSpec` steps to `heroFigureCompact` — 56/0.92, about
        // 51dp painted. That is the mockup's hero, which is visibly smaller
        // than the one this pin was written against.
        //
        // The rule the pin protects is the one that matters and it is
        // untouched: the hero is at one of its two declared faces and has NOT
        // fallen through to the `FittedBox` rung of the fitting ladder.
        expect(
          hero,
          greaterThan(48),
          reason:
              'the hero came out ${hero}dp, below the compact face. That is '
              'the FittedBox rung, which is the last resort and not a layout.',
        );
      });
    }

    testWidgets('and at the 200dp plate floor it is at least its equal', (
      tester,
    ) async {
      // 360×640 is the hostile case the spec names: `vh − 440` pins the plate
      // at its 200dp floor, the text zone is 116dp, and the cluster's fixed
      // overhead — eyebrow, the 44dp health target, two gaps — is most of it.
      // The FittedBox is the documented last rung of the fitting ladder and it
      // does run here. What may not happen again is the hero coming out a
      // third of the size of the metric that supports it.
      await pump(tester, const Size(360, 640));

      final hero = figureHeight(tester, of: find.byType(PlateHeroCluster));
      final supporting = figureHeight(
        tester,
        of: find.byType(FloorBriefingBlock),
      );

      expect(
        hero / supporting,
        greaterThan(0.9),
        reason: 'hero ${hero}dp against the briefing\'s ${supporting}dp',
      );
    });
  });

  group('the plate is a card', () {
    testWidgets('it is inset from the top edge and from both gutters', (
      tester,
    ) async {
      await pump(tester, const Size(360, 640));
      final plate = tester.getRect(find.byType(TiqPlate));
      final skin = TiqSkin.night();

      // PIN MOVED, 25 September 2026: this was `top == 0`, and it was right
      // while the plate ran full-bleed and was the screen's top edge. The
      // owner's reference makes it an inset rounded card, so the shell's own
      // console inset is the air above it — 24dp, measured — and a card hard
      // against the status bar would be a card with one edge missing.
      expect(
        plate.top,
        24,
        reason:
            'the console shell inset. A card starts below it; a band started '
            'at 0.',
      );
      expect(plate.left, skin.space.gutter);
      expect(plate.right, 360 - skin.space.gutter);
    });

    testWidgets('it carries no printed caption; the provenance is spoken', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const Size(412, 915));

      // PIN MOVED, 25 September 2026: this used to measure the gap between
      // the printed provenance caption and the hero cluster. The owner's
      // reference has no caption line, so what is asserted now is that it is
      // gone from the paint and still present for anything that reads the
      // screen — an unattributed photograph is an assertion either way.
      expect(
        find.descendant(
          of: find.byType(TiqPlate),
          matching: find.text('Corner Express Parkhurst'),
        ),
        findsNothing,
      );
      expect(
        find.bySemanticsLabel(RegExp('Corner Express Parkhurst')),
        findsWidgets,
      );
      handle.dispose();
    });
  });

  group('the vertical rhythm is the spacing scale', () {
    testWidgets('every gap is a token, measured between the things a reader '
        'can see', (tester) async {
      await pump(tester, const Size(360, 640));

      // THE GAPS ARE SEMANTIC TOKENS, not `sN` literals. The screen's blocks
      // hang off `blockGap` and `intraBlock`, so a screen re-tuned by changing
      // `blockGap` moves together and this test follows it instead of pinning
      // it.
      //
      // THE KICK IS GONE, 1 October 2026. This measured the plate to the
      // briefing's `LAST 30 DAYS` eyebrow and the eyebrow to its first card.
      // There is no eyebrow — the approved arrangement has no heading over
      // this block and the window is on the scope chip — so the first gap is
      // now measured to the thing that is actually there.
      final skin = TiqSkin.night();
      final plate = tester.getRect(find.byType(TiqPlate));
      expect(
        find.byType(Eyebrow),
        findsNothing,
        reason: 'a heading over the briefing is the density the owner rejected',
      );
      final cards = find.descendant(
        of: find.byType(FloorBriefingBlock),
        matching: find.byType(TorchCard),
      );
      final firstCard = tester.getRect(cards.first);
      final secondCard = tester.getRect(cards.at(1));

      expect(
        firstCard.top - plate.bottom,
        skin.space.blockGap,
        reason: 'the plate to the briefing is one block gap',
      );
      // THE CARD GAP IS THE BRIEFING'S OWN, NOT `intraBlock` — 1 Oct 2026.
      //
      // PIN MOVED, AND IT IS A TIGHTENING RATHER THAN A RELAXATION. This read
      // `skin.space.intraBlock`, which is 12dp. The mockup's is
      // `margin-bottom:5px` — 6.5dp at 1.3 dp/px — and the owner read the
      // block as "much taller cards with a much larger gap". Measured, the
      // cards are within a dp of the drawing's height; the gap was doing all
      // of it.
      //
      // It is still a named constant and not an `sN` literal, so the pin
      // follows the decision instead of restating it: `FloorBriefingBlock`
      // owns the number, with the conversion written at it.
      expect(
        secondCard.top - firstCard.bottom,
        FloorBriefingBlock.cardGap,
        reason:
            'two briefing lines are one READING broken into three, not three '
            'things near each other — the drawing gives them half the gap of '
            'everything else on the screen, and `intraBlock` was twice it',
      );
      expect(
        FloorBriefingBlock.cardGap,
        lessThan(skin.space.intraBlock),
        reason:
            'the whole point is that this gap is tighter than the screen\'s '
            'ordinary one. If somebody has raised it back to `intraBlock` the '
            'assertion above would still pass and the owner would be looking '
            'at the render they rejected.',
      );
    });

    testWidgets('every card hangs off the same gutter', (tester) async {
      await pump(tester, const Size(360, 640));

      // THE DECISION LIST WAS THE THIRD EDGE THIS MEASURED, and it was the
      // one that could go wrong: it was bled out to the screen's edges and put
      // its own margin back. It is not on this screen since 1 October 2026, so
      // what is left is the plate, the briefing's three cards and the scope
      // chip ON the plate — which is the edge the new arrangement introduced
      // and therefore the one worth measuring.
      final gutter = TiqSkin.night().space.gutter;
      expect(tester.getRect(find.byType(TiqPlate)).left, gutter);
      for (final card in find
          .descendant(
            of: find.byType(FloorBriefingBlock),
            matching: find.byType(TorchCard),
          )
          .evaluate()) {
        expect(
          tester.getRect(find.byWidget(card.widget)).left,
          gutter,
          reason: 'a card that starts 4dp off every other left edge is a card '
              'somebody will notice and nobody can explain',
        );
      }
      // The chip rides the PICTURE, so its line is the plate's own inner
      // gutter rather than the screen's — one gutter inside a card that is
      // itself one gutter in. That is what makes it read as part of the plate
      // instead of a header standing on it, and it is the same inset the hero
      // cluster below it hangs off.
      final plate = tester.getRect(find.byType(TiqPlate));
      expect(
        tester
            .getRect(find.byKey(const ValueKey<String>('floor-scope-chip')))
            .left,
        plate.left + gutter,
      );
    });
  });

  /// ── THE CONTROLS RIDE THE PICTURE, AND THEY CLEAR THE LIGHT ───────────
  ///
  /// The approved arrangement puts the scope chip and `Menu` on the plate,
  /// top-left and top-right. The shipped screen put them on the GROUND under
  /// the plate once a question had been asked, which read as a second header —
  /// and the reason it was done is a real defect that this group is what
  /// replaces.
  ///
  /// `TiqPlate`'s top slot is drawn over the photograph at a fixed inset from
  /// the top edge, while the strip light rides at a FRACTION of the plate's
  /// height. Shrink the plate far enough and the control lands on the middle
  /// of the light, leaves its two ends showing, and the amber census counts
  /// one lit object as two — which on the answered state made three against a
  /// budget of two.
  ///
  /// So the clearance is a number (`PlateSpec.topSlotRoom`) and this is where
  /// it is measured against the control the screen actually draws, on both
  /// supported phones.
  ///
  /// ## IT IS ONE CONTROL NOW, NOT TWO — 2 October 2026
  ///
  /// This measured `max(chip.bottom, menu.bottom)`, because arrangement B put
  /// `FloorDestinationsButton` on the plate's top band beside the chip. Model
  /// 1 moves the destinations into the ask bar at the bottom of every console
  /// screen, so the plate's band is the scope chip alone and the chip has the
  /// full width to wrap in.
  ///
  /// The clearance therefore got **easier**, which is worth stating plainly
  /// rather than quietly passing: the 360dp phone used to clear only because
  /// the Menu control had already dropped its printed word, and that argument
  /// is retired along with the control.
  group('the plate\'s controls clear its strip light', () {
    for (final (name, size) in <(String, Size)>[
      ('390x844 phone', Size(390, 844)),
      ('360x640 phone', Size(360, 640)),
    ]) {
      testWidgets('on a $name, at rest', (tester) async {
        await pump(tester, size);

        final plate = tester.getRect(find.byType(TiqPlate));
        final spec = PlateSpec.resolve(
          skin: TiqSkin.night(),
          viewportHeight: size.height,
          ground: TheFloorScreen.plateGroundFor(size.height, shrunk: false),
          shortest: TheFloorScreen.plateShortest,
        );
        expect(spec.form, PlateForm.photographic);
        expect(
          plate.height,
          moreOrLessEquals(spec.height, epsilon: 0.5),
          reason: 'the spec and the drawn plate have to be the same plate',
        );

        // The whole top band, which is the scope chip and nothing else.
        final chip = tester.getRect(
          find.byKey(const ValueKey<String>('floor-scope-chip')),
        );
        // AND THE DESTINATIONS CONTROL IS NOT ON THE PLATE. It is in the ask
        // bar, below the fold of this measurement entirely — proved here so
        // the clearance cannot quietly start measuring it again.
        expect(
          tester
              .getRect(find.byKey(const ValueKey<String>('floor-destinations')))
              .top,
          greaterThan(plate.bottom),
        );
        final taken = chip.bottom - plate.top - PlateSpec.topSlotInset;

        expect(
          taken,
          lessThanOrEqualTo(spec.topSlotRoom),
          reason:
              'the controls take ${taken}dp of a ${spec.topSlotRoom}dp band '
              'above the strip light at y=${spec.stripLightY}. Past it they '
              'paint across the middle of the line and one lit object is '
              'counted as two.',
        );

        // Belt and braces, in the units the defect was reported in: the
        // control's own bottom edge, against the light's own y.
        expect(
          chip.bottom - plate.top,
          lessThan(spec.stripLightY),
          reason: 'the control reaches the strip light itself',
        );
      });
    }

    test('and the shrunken plate has no band to put one in', () {
      // WHY THE ANSWERING STATE DRAWS NO CONTROL AT ALL, as arithmetic rather
      // than as taste. The approved mockup draws the shrunken plate bare, and
      // the numbers say it had to:
      //
      //   phone      answering plate   light at   band above it
      //   390×844    160dp             61dp       45dp
      //   360×640    122dp             46dp       30dp
      //
      // A tap target is 44dp. It fits on the tall phone by less than a
      // millimetre and does not fit on the narrow one at all — so an
      // arrangement chosen by measurement would draw a chip at 390 and not at
      // 360, which is one screen rendering as two 30dp apart. That is exactly
      // the defect `PlateSpec.floorShortest` was made a parameter to stop.
      //
      // So the rule is the phase, not the viewport, and it is the same on
      // every phone. Nothing is lost: `Back to the briefing` is one tap above
      // the transcript and goes to the state that has both controls — pressed
      // in `floor_taps_test.dart`.
      final skin = TiqSkin.night();
      final rooms = <double, double>{
        for (final vh in <double>[844, 640])
          vh: PlateSpec.resolve(
            skin: skin,
            viewportHeight: vh,
            ground: TheFloorScreen.plateGroundFor(vh, shrunk: true),
            shortest: TheFloorScreen.plateShortest,
          ).topSlotRoom,
      };
      expect(
        rooms[640],
        lessThan(skin.space.tapTarget),
        reason:
            'a 44dp control does not fit over the answering plate on the '
            'narrowest supported phone: ${rooms[640]}dp of band. If this ever '
            'passes on BOTH sizes the mockup can be revisited.',
      );
      expect(rooms[844], lessThan(skin.space.tapTarget + 2));
    });
  });

  group('the briefing is the whole of what the screen says', () {
    /// ── WHAT CLEARS THE FOLD NOW, AND WHAT THE OWNER TRADED FOR IT ──────
    ///
    /// **This group used to count decision cards above the nav pill**: three
    /// on a 390×844 phone, two on a 360×640. That was the measurement The
    /// Floor's whole fold budget was cut to, and it is the one thing this
    /// change deliberately spends.
    ///
    /// The approved arrangement puts the briefing and the composer between the
    /// plate and the list, so on a 640dp phone **no decision card clears the
    /// fold at all** — the list is a scroll away. That is not a capability
    /// going missing and it is not an accident:
    ///
    /// * the briefing's first line is the same question answered shorter
    ///   ("Overdue work · 12 · across 4 outlets"), it is above the fold on
    ///   every supported phone, and it opens `/tasks`;
    /// * the list itself is unchanged below it — same rank, same five, same
    ///   more-row — and `revealDecisions` in the harness is how the tests that
    ///   care about it reach it;
    /// * Work is also one tap away in the destinations sheet, with its count
    ///   printed on the row.
    ///
    /// So the pin moves to what the fold is actually for now: **the briefing
    /// is complete above the composer**. A briefing whose third line is under
    /// the chip row is the same defect the old three-card pin existed to
    /// catch, one block higher up the screen.
    for (final (name, size) in <(String, Size)>[
      ('390x844 phone', Size(390, 844)),
      ('412x915 phone', Size(412, 915)),
      ('360x640 phone', Size(360, 640)),
    ]) {
      testWidgets('the whole briefing clears the composer on a $name', (
        tester,
      ) async {
        await pump(tester, size);

        // The fold is the top of the pinned band — the suggestion chips when
        // there are any, the composer otherwise. It is a sibling of the
        // scroll view rather than an overlay, so its top IS the fold.
        final chips = find.byType(FloorSuggestionChips);
        final fold = tester
            .getRect(
              chips.evaluate().isEmpty
                  ? find.byType(QuestionComposer)
                  : chips,
            )
            .top;

        final cards = find.descendant(
          of: find.byType(FloorBriefingBlock),
          matching: find.byType(TorchCard),
        );
        expect(
          cards,
          findsNWidgets(3),
          reason: 'the briefing is three lines on a populated screen',
        );
        for (var i = 0; i < 3; i++) {
          expect(
            tester.getRect(cards.at(i)).bottom,
            lessThanOrEqualTo(fold),
            reason:
                'briefing line ${i + 1} is under the composer on a $name. '
                'The briefing is the whole of what this screen says before it '
                'is asked anything, and a line below the fold is a line that '
                'is not said.',
          );
        }
      });
    }

    testWidgets('and there is nothing under it — the gap is the design', (
      tester,
    ) async {
      await pump(tester, const Size(390, 844));

      // THE TRADE, STATED IN THE SUITE RATHER THAN ONLY IN A RENDER. The list
      // is not below the fold, it is on the Work queue, and the empty ground
      // between the last briefing line and the chip row is the thing the
      // owner asked for rather than room going to waste.
      await scrollFloorToTail(tester);
      expect(find.byType(DecisionRow), findsNothing);

      await revealPlate(tester);
      final cards = find.descendant(
        of: find.byType(FloorBriefingBlock),
        matching: find.byType(TorchCard),
      );
      final lastCard = tester.getRect(cards.at(2));
      final fold = tester.getRect(find.byType(FloorSuggestionChips)).top;
      expect(
        fold - lastCard.bottom,
        greaterThan(120),
        reason:
            'the calm gap between the briefing and the chips came out '
            '${fold - lastCard.bottom}dp. A screen the owner calls simplistic '
            'earns it by what it leaves out, and anything that fills this is '
            'the change that has to be argued for.',
      );
    });
  });

  /// ── THE WEIGHT TABLE: THE DRAWING'S NUMBERS AGAINST OURS ────────────
  ///
  /// The owner has been handed a mismatch three times and the brief asked for
  /// the side-by-side that settles it. A picture settles whether two screens
  /// *look* alike; this settles whether they *measure* alike, which is the
  /// claim actually in dispute — *"every piece of chrome is heavier, larger
  /// and louder than the drawing."*
  ///
  /// Every left-hand number is read off the artifact's own CSS and converted
  /// at **1.3 dp/px** (it renders a 390dp screen into a 300px device). Every
  /// right-hand number is measured off the running widget tree at 390×844,
  /// not asserted and not copied from a comment.
  ///
  /// THE TARGET COLUMN IS THE POINT OF THE WHOLE PASS. The drawing's chrome
  /// is 29–35dp throughout and WCAG 2.5.5 and this product's own
  /// `space.tapTarget` both floor an interactive box at 44. Every row below
  /// therefore has two numbers on our side: what is painted, which matches the
  /// drawing, and what a finger hits, which does not and must not.
  testWidgets('THE WEIGHT TABLE — mockup dp against drawn dp, printed', (
    tester,
  ) async {
    await pump(tester, const Size(390, 844));
    final skin = TiqSkin.night();

    double paintedHeight(Finder of) => tester
        .getRect(find.descendant(of: of, matching: find.byType(Container)).first)
        .height;

    final chip = find.byKey(const ValueKey<String>('floor-scope-chip'));
    final menu = find.byKey(const ValueKey<String>('floor-destinations'));
    final cards = find.descendant(
      of: find.byType(FloorBriefingBlock),
      matching: find.byType(TorchCard),
    );
    final card0 = tester.getRect(cards.first);
    final card1 = tester.getRect(cards.at(1));
    final suggestion = find
        .descendant(
          of: find.byType(FloorSuggestionChips),
          matching: find.byType(TorchFilterChip),
        )
        .first;
    // The ask bar's trailing key. Depth-first order puts the grid's pressable
    // first and Send's last; measured rather than quoted, like every other
    // right-hand number in this table.
    final send = find
        .descendant(
          of: find.byType(QuestionComposer),
          matching: find.byType(TorchPressable),
        )
        .last;

    final rows = <(String, String, String, String)>[
      (
        'scope chip',
        'pad 5/10, 999r, 8.5px',
        '${paintedHeight(chip).toStringAsFixed(0)}dp pill, no border',
        '${tester.getRect(chip).height.toStringAsFixed(0)}dp',
      ),
      (
        // IT MOVED, AND IT GREW TWICE. The 22x22 in the drawing is a control
        // sitting ON a photograph, where a quiet 29dp box is right because
        // the picture is doing the work; in the ask bar it stands on the
        // ground and at 29dp it read as a smudge rather than a control, so on
        // 2 October it went to 44, the tap-target floor.
        //
        // That left the row at 44 drawn, 54 for the trough and 36 for Send —
        // three heights — and on 3 October 2026 the owner said the bottom of
        // the screen does not look proportioned. All three are
        // `QuestionComposer.barExtent` now. This is still the row where drawn
        // and targeted are the same number; it is now the whole row.
        'grid control (was Menu)',
        'n/a — moved off the plate',
        '${paintedHeight(menu).toStringAsFixed(0)}'
            'x${tester.getRect(find.descendant(of: menu, matching: find.byType(Container))).width.toStringAsFixed(0)}dp,'
            ' no word',
        '${tester.getRect(menu).height.toStringAsFixed(0)}dp',
      ),
      (
        'briefing card',
        'pad 10/11, r18',
        '${card0.height.toStringAsFixed(0)}dp, r${skin.radii.card.toStringAsFixed(0)}',
        'n/a (not a control)',
      ),
      (
        'briefing gap',
        'margin-bottom 5px',
        '${(card1.top - card0.bottom).toStringAsFixed(0)}dp',
        'n/a',
      ),
      (
        'suggestion chip',
        'pad 5/9, 8.5px',
        '${paintedHeight(suggestion).toStringAsFixed(0)}dp pill',
        '${tester.getRect(suggestion).height.toStringAsFixed(0)}dp',
      ),
      (
        // OVERRIDDEN BY THE OWNER, 3 OCTOBER 2026, and the one row in this
        // table where our number is deliberately not the drawing's. The
        // mockup's 27px is 35dp and 36 was that on the 4dp scale; beside a
        // 48dp grid key and a 48dp trough it was the smallest of three
        // objects that have to read as one row. See `composer.dart`'s
        // `_sendDisc`, which records the override rather than leaving a
        // derivation for a number no longer in the code.
        'send button',
        '27x27, r50%, filled',
        '${paintedHeight(send).toStringAsFixed(0)}dp amber disc',
        '${tester.getRect(send).height.toStringAsFixed(0)}dp',
      ),
    ];

    // ignore: avoid_print
    print(
      '\n  THE FLOOR — the drawing\'s chrome against ours, 390x844\n'
      '  the mockup renders 390dp into 300px, so its px x 1.3 = dp\n'
      '  ${'element'.padRight(18)}${'mockup CSS'.padRight(24)}'
      '${'we DRAW'.padRight(26)}we TARGET',
    );
    for (final (what, css, drawn, target) in rows) {
      // ignore: avoid_print
      print(
        '  ${what.padRight(18)}${css.padRight(24)}'
        '${drawn.padRight(26)}$target',
      );
    }
    // ignore: avoid_print
    print(
      '  every drawn number is the drawing\'s; every target is 44 or 48,\n'
      '  which is where the drawing and WCAG 2.5.5 disagree and the rule wins.',
    );

    // The pins. Printed numbers nobody checks are decoration, so each drawn
    // figure is held to the mockup's within a dp of rounding, and each target
    // to the floor the rule sets.
    expect(paintedHeight(chip), closeTo(plateQuietExtent, 0.5));
    // The grid control is `TorchAskDestinations.extent`, not the plate's quiet
    // extent: it is no longer a control on a picture. See the row above.
    expect(paintedHeight(menu), closeTo(TorchAskDestinations.extent, 0.5));
    // AND THE ROW IS ONE HEIGHT. Three objects, one number, which is the
    // claim the 3 October proportion pass exists to make true.
    expect(paintedHeight(send), closeTo(QuestionComposer.barExtent, 0.5));
    expect(
      paintedHeight(menu),
      closeTo(paintedHeight(send), 0.5),
      reason: 'the two ends of the bar',
    );
    expect(paintedHeight(suggestion), closeTo(TorchFilterChip.quietExtent, 0.5));
    expect(card1.top - card0.bottom, FloorBriefingBlock.cardGap);
    for (final control in <Finder>[chip, menu, suggestion]) {
      expect(
        tester.getRect(control).height,
        greaterThanOrEqualTo(skin.space.tapTarget),
        reason:
            'the painted box came down to the drawing; the TARGET may not. '
            'A control under ${skin.space.tapTarget}dp fails WCAG 2.5.5 and '
            'this product\'s own token, and the drawing has no opinion about '
            'tap targets because a drawing cannot be tapped.',
      );
    }
  });
}

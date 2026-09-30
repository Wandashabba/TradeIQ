import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/card.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/plate/plate.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
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
  // THE FOLD IS A FACT ABOUT THE TYPEFACE. `flutter_test`'s own font is
  // wider than Onest, so every label wraps sooner and every screen measures
  // TALLER in it — which is the right default for a test about a role or a
  // count and the wrong one for a file whose every assertion is a height.
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

      // Box-to-box is not the measurement: a box with a 16dp inset of its own
      // reads as `s6 + 16` however tidy its rect looks. So this measures the
      // eyebrow, the last line of supports, the rule and the first row — the
      // marks on the screen.
      // THE GAPS ARE SEMANTIC TOKENS NOW, not `sN` literals.
      //
      // The screen's new blocks hang off `blockGap` and `intraBlock` rather
      // than off `s4`/`s3`, which is what unify asks for and what #492 spent
      // a PR undoing on the agent side. The numbers are currently the same —
      // `blockGap` is s6 and the plate-to-briefing gap is one block — so this
      // is a rename with teeth: a screen re-tuned by changing `blockGap` moves
      // together, and this test follows it instead of pinning it.
      final skin = TiqSkin.night();
      final plate = tester.getRect(find.byType(TiqPlate));
      final kick = tester.getRect(find.byType(Eyebrow).first);
      final cards = find.descendant(
        of: find.byType(FloorBriefingBlock),
        matching: find.byType(TorchCard),
      );
      final firstCard = tester.getRect(cards.first);
      final secondCard = tester.getRect(cards.at(1));

      expect(
        kick.top - plate.bottom,
        skin.space.blockGap,
        reason: 'the plate to the briefing\'s kick is one block gap',
      );
      expect(
        firstCard.top - kick.bottom,
        skin.space.intraBlock,
        reason: 'the kick to its first line is inside one block',
      );
      expect(
        secondCard.top - firstCard.bottom,
        skin.space.intraBlock,
        reason:
            'two briefing lines are one block, not two — a reader scans them '
            'as a list, and a block gap between them would make three',
      );
    });

    testWidgets('every card hangs off the same gutter', (tester) async {
      await pump(tester, const Size(360, 640));

      await revealDecisions(tester);
      final gutter = tester.getRect(find.text('NEEDS A DECISION')).left;
      await revealPlate(tester);
      expect(tester.getRect(find.byType(TiqPlate)).left, gutter);
      expect(tester.getRect(find.byType(TorchCard).first).left, gutter);
      await revealDecisions(tester);
      // The decision list is bled out to the screen's edges and each card
      // puts its own edge back on the gutter line, which is the whole reason
      // the row's margin is the gutter and not a number of its own.
      expect(
        tester
            .getRect(
              find
                  .descendant(
                    of: find.byType(DecisionRow).first,
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .left,
        gutter,
        reason: 'a card that starts 4dp off every other left edge is a card '
            'somebody will notice and nobody can explain',
      );
    });
  });

  group('the decision cards are compact', () {
    testWidgets('the reason takes one line, not two', (tester) async {
      await pump(tester, const Size(360, 640));
      await revealDecisions(tester);

      final row = tester.widget<SoftRow>(
        find
            .descendant(
              of: find.byType(DecisionRow).first,
              matching: find.byType(SoftRow),
            )
            .first,
      );
      expect(
        row.subtitleMaxLines,
        1,
        reason:
            'a wrapped reason costs a whole row of fold on the one screen '
            'that is meant to show several decisions',
      );
    });

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

    testWidgets('the decision list is still there, below the briefing', (
      tester,
    ) async {
      await pump(tester, const Size(360, 640));

      // Nothing above the fold — stated, so the trade is visible in the suite
      // rather than only in a render.
      expect(find.byType(DecisionRow), findsNothing);

      await revealDecisions(tester);
      expect(
        find.byType(DecisionRow),
        findsWidgets,
        reason:
            'the list moved below the fold; it did not leave. If this fails, '
            'the manager has lost the worklist rather than scrolled to it.',
      );
    });
  });
}

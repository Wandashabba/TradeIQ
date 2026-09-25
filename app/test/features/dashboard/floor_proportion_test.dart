import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/card.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/core/widgets/torchlight/figure/stat_tile.dart';
import 'package:tradeiq_app/core/widgets/torchlight/plate/plate.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/dashboard/presentation/the_floor_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

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
        final supporting = figureHeight(tester, of: find.byType(StatTile));

        expect(
          hero,
          greaterThan(supporting * 1.5),
          reason:
              'territory health renders ${hero}dp and on-shelf availability '
              '${supporting}dp. The hero is the screen; availability is a '
              'lead tile under it.',
        );
        // And it is at its declared face, not a scaled-down one: hero.figure
        // is 72/0.92, so about 66dp of painted line.
        expect(hero, greaterThan(60));
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
      final supporting = figureHeight(tester, of: find.byType(StatTile));

      expect(
        hero / supporting,
        greaterThan(0.9),
        reason: 'hero ${hero}dp against availability ${supporting}dp',
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
      final plate = tester.getRect(find.byType(TiqPlate));
      final card = tester.getRect(find.byType(TorchCard));
      final marker = tester.getRect(find.text('NEEDS A DECISION'));
      final row = tester.getRect(find.byType(DecisionRow).first);

      // Card to card, now that the blocks have edges a reader can see: the
      // gaps used to be measured between marks because the blocks were
      // invisible, and a card's own edge is the mark.
      expect(
        card.top - plate.bottom,
        TiqSpace.s5,
        reason: 'the plate card to the lead card',
      );
      expect(
        marker.top - card.bottom,
        TiqSpace.s5,
        reason: 'the lead card to the section marker',
      );
      expect(
        row.top - marker.bottom,
        TiqSpace.s3,
        reason: 'the marker to the first decision card',
      );
    });

    testWidgets('every card hangs off the same gutter', (tester) async {
      await pump(tester, const Size(360, 640));

      final gutter = tester.getRect(find.text('NEEDS A DECISION')).left;
      expect(tester.getRect(find.byType(TiqPlate)).left, gutter);
      expect(tester.getRect(find.byType(TorchCard)).left, gutter);
      // The decision list is bled out to the screen's edges and each card
      // puts its own edge back on the gutter line, which is the whole reason
      // the row's margin is the gutter and not a number of its own.
      expect(
        tester.getRect(find.byType(DecisionRow).first).left,
        gutter,
        reason: 'a card that starts 4dp off every other left edge is a card '
            'somebody will notice and nobody can explain',
      );
    });
  });

  group('the decision cards are compact', () {
    testWidgets('the reason takes one line, not two', (tester) async {
      await pump(tester, const Size(360, 640));

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

    /// THE COUNT THE OWNER'S REFERENCE SHOWS, AT THE SIZE THEY LOOKED AT IT.
    ///
    /// Three rows on a 390x844 phone is the measurement the plate's fold
    /// budget was cut to (0.44/360 down to 0.40/320) and the reason the
    /// decision row dropped from the 80dp tall density to compact. It is the
    /// first thing a layout change eats, so it fails CI rather than a review.
    ///
    /// These run in the test font, which is wider than Onest and therefore
    /// measures TALLER — so a count that holds here holds on the device. The
    /// pictures rendered in the real typeface are in
    /// `floor_look_test.dart`.
    for (final (name, size, atLeast) in <(String, Size, int)>[
      ('390x844 phone', Size(390, 844), 3),
      ('412x915 phone', Size(412, 915), 3),
      ('360x640 phone', Size(360, 640), 2),
    ]) {
      testWidgets('$atLeast of them clear the nav on a $name', (tester) async {
        await pump(tester, size);

        final fold = tester.getRect(find.byType(TorchNavPill)).top;
        final visible = <int>[];
        for (
          var i = 0;
          i < tester.widgetList(find.byType(DecisionRow)).length;
          i++
        ) {
          if (tester.getRect(find.byType(DecisionRow).at(i)).bottom <= fold) {
            visible.add(i);
          }
        }
        expect(
          visible.length,
          greaterThanOrEqualTo(atLeast),
          reason:
              'only ${visible.length} decision card(s) clear the nav on a '
              '$name. The screen answers what is broken and who is fixing '
              'it — one row is a headline, not a list.',
        );
      });
    }
  });
}

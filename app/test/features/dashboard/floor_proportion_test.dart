import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
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

  group('the plate is the header', () {
    testWidgets('it starts at the top edge, with no band of ground above it', (
      tester,
    ) async {
      await pump(tester, const Size(360, 640));
      expect(
        tester.getRect(find.byType(TiqPlate)).top,
        0,
        reason:
            'The Floor has no app header because the plate is one. 24dp of '
            'ground above it is a plate that is visibly not the header it '
            'claims to be, and 24dp of a 640dp fold.',
      );
    });

    testWidgets('the caption sits on the hero, not in a hole above it', (
      tester,
    ) async {
      await pump(tester, const Size(412, 915));

      // The provenance caption: the plate's own naming of the specimen, not
      // the decision row that happens to carry the same outlet.
      final caption = tester.getRect(
        find.descendant(
          of: find.byType(TiqPlate),
          matching: find.text('Corner Express Parkhurst'),
        ),
      );
      final cluster = tester.getRect(find.byType(PlateHeroCluster));
      final skin = TiqSkin.night();
      final gap = cluster.top - caption.bottom;

      expect(gap, closeTo(TiqSpace.s2, 1), reason: 'caption gap is $gap');
      expect(
        caption.height,
        lessThan(skin.text.meta.size * 2),
        reason: 'the provenance caption is one line, never two',
      );
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
      final eyebrow = tester.getRect(find.text('ON-SHELF AVAILABILITY'));
      final supports = tester.getRect(
        find.textContaining('Coverage 33 of 42 outlets'),
      );
      final rule = tester.getRect(find.byType(SectionRule));
      final row = tester.getRect(find.byType(DecisionRow).first);

      expect(
        eyebrow.top - plate.bottom,
        TiqSpace.s6,
        reason: 'the plate to the lead tile',
      );
      expect(
        rule.top - supports.bottom,
        TiqSpace.s6,
        reason: 'the lead tile to the rule — this was s6 plus a 16dp inset',
      );
      expect(
        row.top - rule.bottom,
        TiqSpace.s5,
        reason: 'the rule to the first decision',
      );
    });

    testWidgets('the lead tile hangs off the same gutter as everything else', (
      tester,
    ) async {
      await pump(tester, const Size(360, 640));

      final gutter = tester.getRect(find.byType(SectionRule)).left;
      expect(
        tester.getRect(find.text('ON-SHELF AVAILABILITY')).left,
        gutter,
        reason:
            'the tile carried a 16dp inset of its own inside a shell that had '
            'already spent the gutter, so its eyebrow sat 16dp right of every '
            'other left edge on the screen',
      );
      expect(tester.getRect(find.byType(PlateHeroCluster)).left, gutter);
    });
  });

  group('the decision rows are compact', () {
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

    testWidgets('more than one of them is above the nav on a tall phone', (
      tester,
    ) async {
      await pump(tester, const Size(412, 915));

      final fold = tester.getRect(find.byType(TorchNavPill)).top;
      final visible = <int>[];
      for (var i = 0; i < tester.widgetList(find.byType(DecisionRow)).length; i++) {
        if (tester.getRect(find.byType(DecisionRow).at(i)).bottom <= fold) {
          visible.add(i);
        }
      }
      expect(
        visible.length,
        greaterThanOrEqualTo(2),
        reason:
            'only ${visible.length} decision row(s) clear the nav. The screen '
            'answers "what is broken and who is fixing it" — one row is a '
            'headline, not a list.',
      );
    });
  });
}

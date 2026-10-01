import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/assistant/answer/composer.dart';
import 'package:tradeiq_app/features/dashboard/presentation/the_floor_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../../core/widgets/torchlight/torch_harness.dart' show torchPixels;
import '../agent_harness.dart';
import 'floor_harness.dart';

/// THE BAND HAS NO EDGES — MEASURED, BECAUSE "SEAMLESS" IS A MEASUREMENT.
///
/// The owner: *"The background colour is messed up here please fix this to be
/// seamless and not have this box blue there."* The box was a
/// `ColoredBox(color: skin.palette.ground)` around this screen's band, over a
/// shell whose console ground is a vertical falloff. Three edges, measured on
/// a 390x844 Night render before the fill came out. The band's box is
/// `(20, 706, 370, 844)` and the row at y=708 is 2dp inside it:
///
/// | edge | outside | inside | step (R,G,B) |
/// |---|---|---|---|
/// | x=20, the left gutter   | `#0F1620` | `#0B1017` | 4, 6, 9 |
/// | x=370, the right gutter | `#0F1620` | `#0B1017` | 4, 6, 9 |
/// | y=706, the band's top   | `#0F1620` | `#0B1017` | 4, 6, 9 |
///
/// On **Day** the same fill is a *lighter* box and the step is larger —
/// `#EEE9DF` inside against `#E6E0D4` outside, 8, 9, 11 — which is why nobody
/// had named it on paper: a light box on light paper reads as a highlight.
/// After the fix the row is one colour from x=0 to x=389 in both skins.
///
/// What is asserted is not "the band is `ground`". It is that **the band is
/// not an edge**: a row drawn through it is one colour from x=0 to the far
/// side of the screen, and the rows either side of its top edge are that same
/// colour. The ground's own gradient travels less than a level per dp and
/// dithers by one, so the tolerance is 2 — and every seam in the table above is
/// wider than that at its worst channel.
///
/// `torch_shell_band_test.dart` holds the other half: why the band is allowed
/// to paint nothing at all.
void main() {
  setUpAll(loadAgentFonts);

  const tolerance = 2;

  bool same(Color a, Color b) =>
      ((a.r - b.r).abs() * 255).round() <= tolerance &&
      ((a.g - b.g).abs() * 255).round() <= tolerance &&
      ((a.b - b.b).abs() * 255).round() <= tolerance;

  String show(Color c) =>
      '#'
              '${(c.r * 255).round().toRadixString(16).padLeft(2, '0')}'
              '${(c.g * 255).round().toRadixString(16).padLeft(2, '0')}'
              '${(c.b * 255).round().toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();

  final outlets = <Outlet>[
    outlet('o1', 'SaveMor Glenwood'),
    outlet('o2', 'Shoprite Klipspruit Mall'),
    outlet('o3', 'Kasi Corner Spaza'),
  ];
  final decisions = <AlertItem>[
    alert(
      id: 'a1',
      outletId: 'o1',
      message: 'Kalahari Cola 2L out of stock at SaveMor Glenwood (6 days)',
      createdAt: DateTime.utc(2026, 9, 16, 9, 6),
    ),
    alert(
      id: 'a2',
      severity: 'warning',
      outletId: 'o2',
      message: 'Price above the published band for the third week running',
      createdAt: DateTime.utc(2026, 9, 16, 12),
    ),
  ];

  for (final (name, size, skin) in <(String, Size, TiqSkin?)>[
    ('390x844 night', Size(390, 844), null),
    ('390x844 day', Size(390, 844), TiqSkin.day(density: TiqDensity.console)),
    ('360x640 night', Size(360, 640), null),
    ('360x640 day', Size(360, 640), TiqSkin.day(density: TiqDensity.console)),
  ]) {
    testWidgets('$name: the band is not an edge', (tester) async {
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        size: size,
        skin: skin,
        current: kpis(osa: 61, execution: 73, priceCompliance: 74),
        previous: kpis(osa: 64, execution: 92),
        alerts: decisions,
        outlets: outlets,
      );

      final band = tester.getRect(
        find.byKey(const ValueKey<String>('floor-band')),
      );
      final pixels = await torchPixels(tester);

      // ── The band's top edge ──────────────────────────────────────────
      //
      // Two rows, 4dp apart, straddling it. Before the fix the lower one was
      // `ground` from the gutter in and the upper one was the falloff's own
      // colour, so the pair differed by 9 levels of blue across 350dp of
      // screen — a drawn line. Nothing paints on either row in any phase:
      // the band's first child is a chip row whose 29dp pill is centred in a
      // 44dp target, and above the band is the space the briefing leaves.
      final above = band.top - 2;
      final below = band.top + 2;
      final reference = pixels.at(2, above);
      for (var x = 0; x < pixels.width; x++) {
        final up = pixels.at(x.toDouble(), above);
        final down = pixels.at(x.toDouble(), below);
        expect(
          same(up, reference) && same(down, reference),
          isTrue,
          reason:
              'The band has a top edge at x=$x: y=${above.round()} reads '
              '${show(up)} and y=${below.round()} reads ${show(down)}, '
              'against a ground of ${show(reference)}.',
        );
      }

      // ── The two gutter edges ─────────────────────────────────────────
      //
      // The shell pads the band `fromLTRB(gutter, 0, gutter, keyboard)`, so
      // anything the band fills is inset by the gutter and the ground shows
      // either side of it. The row is sampled right across the screen rather
      // than only at the two x's, because a fill is a rectangle and a
      // rectangle has to be absent everywhere, not just at its corners.
      for (final y in <double>[
        band.top + 2,
        // The gap the band leaves between the chip row and the composer:
        // `space.intraBlock`, and the one row inside the band that is ground
        // across its whole width in every phase.
        tester.getRect(find.byType(QuestionComposer)).top - 2,
      ]) {
        final ground = pixels.at(2, y);
        for (var x = 0; x < pixels.width; x++) {
          final here = pixels.at(x.toDouble(), y);
          expect(
            same(here, ground),
            isTrue,
            reason:
                'The band has a vertical edge: at y=${y.round()}, x=$x reads '
                '${show(here)} against a ground of ${show(ground)}. A row '
                'drawn through the band is one colour across the screen.',
          );
        }
      }
    });
  }
}

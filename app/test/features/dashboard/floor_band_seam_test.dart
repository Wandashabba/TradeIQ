import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/assistant/answer/composer.dart';
import 'package:tradeiq_app/features/dashboard/presentation/the_floor_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../../core/widgets/torchlight/torch_harness.dart'
    show TorchPixels, torchPixels;
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
/// After the fix the row is one colour from x=0 to x=389 on Day, and free of
/// any step on Night — see the note below for why those are two sentences now.
///
/// What is asserted is not "the band is `ground`". It is that **the band is
/// not an edge**, and every seam in the table above is many times wider than
/// the backdrop's own travel at its worst channel.
///
/// ## The invariant was "one colour" and is now "no step" — 1 October 2026
///
/// It read: *a row drawn through the band is one colour from x=0 to x=389, and
/// the rows either side of its top edge are that same colour*. That was an
/// exact statement about a ground that varied **only vertically**, and it
/// stopped being true the day The Floor got an ambient wash: Dawn
/// (`floor_dawn.dart`) is two RADIAL gradients rising from the bottom edge, so
/// the ground is now brightest at the horizontal centre of the band's own
/// rows. Measured on a 390x844 Night render with the wash on, the row at
/// y=708 reads `#181B23` at x=0 and `#27262C` at x=195 — **15 levels across
/// 195dp**, which the old form counted as five separate failures.
///
/// **The defect the owner named was a STEP, not a variation.** The box was
/// three hard edges of 4, 6 and 9 levels each, every one of them between two
/// ADJACENT pixels, at a boundary 20dp in from the gutter. A gradient that
/// drifts 15 levels over 195dp is 0.08 of a level per dp — there is no edge
/// there to see.
///
/// **And "no step between two adjacent pixels" is the wrong instrument, which
/// is worth writing down because it was the obvious first try.** Flutter
/// dithers a gradient, and the wash is TWO of them: measured along the row at
/// y=760, the blue channel reads `36 39 37 39 36 39 37 39 …` — a regular
/// ±2-level ordered pattern at a 1dp pitch, so **adjacent pixels differ by up
/// to 4 levels everywhere**. That is the dither doing its job (two stops band
/// on a 6-bit panel, which is why the shell's own falloff takes four), and a
/// test that forbade it would be a test against anti-banding.
///
/// So the instrument is a **4-pixel box mean on each side of every boundary**.
/// A 4-wide window cancels a period-2 dither exactly, a real edge survives it
/// at its full height, and a gradient's own travel across 8 pixels is under
/// two levels. Measured with the wash on: worst smoothed step **1.00** and
/// **1.50** along the two bare rows, **2.00** across the band's top edge, and
/// **0.00–0.25** on Day.
///
/// **And it was shown to fail on the code it is aimed at**, which is the test
/// the band-seam PR set for its own guards. Re-introducing the
/// `ColoredBox(color: skin.palette.ground)` around the band reads **11.00**
/// at the left gutter and **15.25** at the right on 390x844 Night, and
/// **11.00–11.50** on 360x640 in both skins — all four cases fail. So the
/// tolerance of 3 sits one level above the honest signal and at least eight
/// below the defect.
///
/// The old form compared every pixel to one reference at x=2 and so could
/// never say *where* a seam was; this one names the x. And the ONE-COLOUR form
/// is kept where it is still exact: on **Day**, where there is no wash at all,
/// the row is asserted to be a single colour across the whole screen exactly
/// as before — which is also a second, independent proof that Dawn does not
/// paint on a light ground.
///
/// `torch_shell_band_test.dart` holds the other half: why the band is allowed
/// to paint nothing at all. `floor_dawn_test.dart` holds the wash's own
/// measurements.
void main() {
  setUpAll(loadAgentFonts);

  const tolerance = 2;

  bool same(Color a, Color b) =>
      ((a.r - b.r).abs() * 255).round() <= tolerance &&
      ((a.g - b.g).abs() * 255).round() <= tolerance &&
      ((a.b - b.b).abs() * 255).round() <= tolerance;

  /// ── THE INSTRUMENT: A 4-PIXEL BOX MEAN EITHER SIDE OF A BOUNDARY ─────
  ///
  /// [window] is 4 because the dither's period is 2 and a 4-wide mean cancels
  /// it exactly. An edge survives at its full height; a gradient's own travel
  /// across the 8 pixels the pair spans is under two levels. See the note at
  /// the top of this file for the measurements.
  const window = 4;
  const smoothTolerance = 3;

  List<double> mean(
    TorchPixels px,
    int from,
    bool horizontal, {
    required double fixed,
  }) {
    var r = 0.0, g = 0.0, b = 0.0;
    for (var i = 0; i < window; i++) {
      final at = (from + i).toDouble();
      final c = horizontal ? px.at(at, fixed) : px.at(fixed, at + 0.5);
      r += c.r * 255;
      g += c.g * 255;
      b += c.b * 255;
    }
    return <double>[r / window, g / window, b / window];
  }

  /// The largest per-channel difference between two means, in levels.
  double gap(List<double> a, List<double> b) {
    var m = 0.0;
    for (var i = 0; i < 3; i++) {
      final d = (a[i] - b[i]).abs();
      if (d > m) m = d;
    }
    return m;
  }

  String showMean(List<double> m) =>
      '#'
              '${m[0].round().toRadixString(16).padLeft(2, '0')}'
              '${m[1].round().toRadixString(16).padLeft(2, '0')}'
              '${m[2].round().toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();

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

  // `flat` is whether this skin's ground is a single colour along a row —
  // true on Day, where Dawn paints nothing, and false on Night, where the
  // wash is two radial gradients. See the note at the top of this file.
  for (final (name, size, skin, flat) in <(String, Size, TiqSkin?, bool)>[
    ('390x844 night', Size(390, 844), null, false),
    (
      '390x844 day',
      Size(390, 844),
      TiqSkin.day(density: TiqDensity.console),
      true,
    ),
    ('360x640 night', Size(360, 640), null, false),
    (
      '360x640 day',
      Size(360, 640),
      TiqSkin.day(density: TiqDensity.console),
      true,
    ),
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

      // The two rows nothing paints on in any phase: 2dp inside the band's
      // top edge, and the `space.intraBlock` gap the band leaves between the
      // chip row and the composer. The band's first child is a chip row whose
      // 29dp pill is centred in a 44dp target, and above the band is the space
      // the briefing leaves — so both rows read the backdrop and nothing else.
      final rows = <double>[
        band.top + 2,
        tester.getRect(find.byType(QuestionComposer)).top - 2,
      ];

      // ── NO VERTICAL EDGE: no step along the row ──────────────────────
      //
      // The shell pads the band `fromLTRB(gutter, 0, gutter, keyboard)`, so
      // anything the band fills is inset by the gutter and the ground shows
      // either side of it. The whole row is walked rather than the two x's,
      // because a fill is a rectangle and a rectangle has to be absent
      // everywhere, not just at its corners.
      for (final y in rows) {
        var worst = 0.0;
        var worstAt = 0;
        for (var x = window; x + window <= pixels.width; x++) {
          final here = gap(
            mean(pixels, x - window, true, fixed: y),
            mean(pixels, x, true, fixed: y),
          );
          if (here > worst) {
            worst = here;
            worstAt = x;
          }
        }
        expect(
          worst,
          lessThanOrEqualTo(smoothTolerance),
          reason:
              'The band has a vertical edge: at y=${y.round()}, the '
              '$window-pixel means either side of x=$worstAt differ by '
              '${worst.toStringAsFixed(2)} levels — '
              '${showMean(mean(pixels, worstAt - window, true, fixed: y))} '
              'against '
              '${showMean(mean(pixels, worstAt, true, fixed: y))}. A row '
              'drawn through the band has no step in it: the gutter is not a '
              'boundary between two materials.',
        );

        // AND ON DAY IT IS STILL ONE COLOUR, which is the stronger statement
        // and is still exact there: Dawn is Night-only, so a light-ground row
        // has nothing on it but the vertical falloff. A failure here is
        // either the box coming back or the wash painting on paper.
        if (flat) {
          final ground = pixels.at(2, y);
          for (var x = 0; x < pixels.width; x++) {
            final here = pixels.at(x.toDouble(), y);
            expect(
              same(here, ground),
              isTrue,
              reason:
                  'At y=${y.round()}, x=$x reads ${show(here)} against a '
                  'ground of ${show(ground)}. On a light ground this row is '
                  'one colour across the screen: the band fills nothing and '
                  'the Dawn wash does not render on Day.',
            );
          }
        }
      }

      // ── NO HORIZONTAL EDGE: no step across the band's top ────────────
      //
      // Before the fix the row below the edge was `ground` from the gutter in
      // and the row above was the falloff's own colour, so the pair differed
      // by 9 levels of blue across 350dp of screen — a drawn line. Adjacent
      // rows rather than a 4dp straddle, so the measurement is of a step and
      // not of the ground's own travel.
      var worstTop = 0.0;
      var worstTopAt = 0;
      for (var x = 0; x < pixels.width; x++) {
        final here = gap(
          mean(pixels, band.top.toInt() - window, false, fixed: x + 0.5),
          mean(pixels, band.top.toInt(), false, fixed: x + 0.5),
        );
        if (here > worstTop) {
          worstTop = here;
          worstTopAt = x;
        }
      }
      expect(
        worstTop,
        lessThanOrEqualTo(smoothTolerance),
        reason:
            'The band has a top edge: at x=$worstTopAt the $window-row means '
            'either side of y=${band.top.round()} differ by '
            '${worstTop.toStringAsFixed(2)} levels — '
            '${showMean(mean(pixels, band.top.toInt() - window, false, fixed: worstTopAt + 0.5))} '
            'above against '
            '${showMean(mean(pixels, band.top.toInt(), false, fixed: worstTopAt + 0.5))} '
            'below.',
      );
    });
  }
}

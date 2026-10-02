import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';

import 'torch_harness.dart';

/// THE SCRIM OVER THE BODY'S LAST 24dp — MEASURED, AND ITS LIMIT MEASURED TOO.
///
/// The owner's screenshot of Tasks showed a task sentence cut mid-word at the
/// bottom of the list. The brief that commissioned Model 1 read that as the
/// nav pill overlapping the content. **It is not, and that matters, because it
/// changes what the fix has to be.**
///
/// The bottom region and the band are both **siblings** of the scroll view in
/// the shell's `Column` — `torch_shell_band_test.dart` counts zero body pixels
/// inside the band's box and that is still true here. What cuts the sentence
/// is the scroll view's own **hard clip at its viewport's bottom edge**, which
/// is a pixel row, and 24dp above the chrome is where every console list puts
/// it. So the fade has to go **over the body**, not into the band: a wash
/// painted in the band would be ground over ground, which is the box
/// `fix/band-seam` took out of this exact y.
///
/// ## What is asserted
///
/// 1. The scrim's opaque end is the ground **at that y**, not
///    `palette.ground`. On the console the ground is a vertical falloff, so
///    the token is the ground only at the screen's first and last pixel row;
///    a scrim that ended in it would be a 24dp box with a hard top edge.
/// 2. It actually fades: the row at the scrim's top is the body's own
///    material, and by its bottom the body is gone.
/// 3. It is **absent on a route with a `backdrop`**, which is the named gap.
void main() {
  /// A body tall enough to be mid-clip at the scrim, in one flat colour so a
  /// probe can say whether any of it survives.
  const bodyInk = Color(0xFFFF00FF);

  Future<void> pumpShell(
    WidgetTester tester, {
    required TiqSkin skin,
    required Size size,
    List<Decoration> backdrop = const <Decoration>[],
    bool band = true,
  }) async {
    await pumpTorch(
      tester,
      skin: skin,
      size: size,
      child: TorchShell(
        profile: TorchShellProfile.console,
        backdrop: backdrop,
        band: band
            ? const SizedBox(height: 56, key: ValueKey<String>('a-band'))
            : null,
        children: <Widget>[
          // Twice the viewport, so the last row is always mid-clip.
          SizedBox(height: size.height * 2, child: const ColoredBox(color: bodyInk)),
        ],
      ),
    );
    await tester.pump();
  }

  for (final (name, skin) in <(String, TiqSkin)>[
    ('night', TiqSkin.night(density: TiqDensity.console)),
    ('day', TiqSkin.day(density: TiqDensity.console)),
  ]) {
    testWidgets('$name: the scrim ends in the ground at its own y', (
      tester,
    ) async {
      const size = Size(390, 844);
      await pumpShell(tester, skin: skin, size: size);

      final scrim = tester.getRect(
        find.byKey(const ValueKey<String>('torch-band-scrim')),
      );
      expect(
        scrim.height,
        TorchShell.bandScrimExtent,
        reason: 'the scrim is the body\'s own bottom padding, no more',
      );

      final pixels = await torchPixels(tester);

      // THE OPAQUE END. One pixel row inside the scrim's bottom edge, where
      // the gradient has arrived and the body has not: whatever is drawn here
      // must be indistinguishable from the ground the shell would have drawn
      // at this y with nothing over it.
      final drawn = pixels.at(size.width / 2, scrim.bottom - 0.5);
      final expected = torchGroundAt(
        skin,
        falloff: true,
        height: size.height,
        y: scrim.bottom,
      );

      // Flutter dithers a gradient — `floor_band_seam_test.dart` measures a
      // regular ±2-level ordered pattern at a 1dp pitch on this very
      // backdrop — so the instrument is a tolerance, not equality. Three
      // levels is above the dither and far below the 4, 6, 9 step the owner
      // saw and named.
      // `Color.r` is a 0..1 double. `~/ 1` was the first spelling of this and
      // it read 0 for every channel in both skins, which made the tolerance
      // trivially true — an instrument that cannot fail.
      for (final (channel, got, want) in <(String, int, int)>[
        ('red', (drawn.r * 255).round(), (expected.r * 255).round()),
        ('green', (drawn.g * 255).round(), (expected.g * 255).round()),
        ('blue', (drawn.b * 255).round(), (expected.b * 255).round()),
      ]) {
        expect(
          (got - want).abs(),
          lessThanOrEqualTo(3),
          reason:
              '$channel: the scrim bottom read $drawn and the ground at '
              'y=${scrim.bottom} is $expected. A scrim that does not end in '
              'the ground at its own y is the box the band used to be.',
        );
      }

      // AND IT FADES, WHICH IS A RAMP AND NOT A STEP. The row immediately
      // ABOVE the scrim is the body untouched; the row immediately below the
      // scrim's top is the body minus a hair; the last row is the ground.
      // Asserting exact magenta at `top + 0.5` was the first instrument and
      // it is the wrong one — the gradient has already travelled half a dp by
      // then, which is the ramp working.
      expect(
        pixels.at(size.width / 2, scrim.top - 0.5),
        bodyInk,
        reason: 'nothing above the scrim is touched at all',
      );
      final entering = pixels.at(size.width / 2, scrim.top + 0.5);
      expect(
        (entering.g * 255).round(),
        lessThan(16),
        reason:
            'the scrim starts at (near) zero alpha: the body is still '
            'essentially itself one pixel in, which is what makes this a fade '
            'rather than the hard edge it is hiding. Read $entering.',
      );
      expect(
        pixels.at(size.width / 2, scrim.bottom - 0.5),
        isNot(bodyInk),
        reason: 'and it is opaque by its last row',
      );
    });

    testWidgets('$name: no band, no scrim — the tree is what it was', (
      tester,
    ) async {
      await pumpShell(
        tester,
        skin: skin,
        size: const Size(390, 844),
        band: false,
      );
      expect(
        find.byKey(const ValueKey<String>('torch-band-scrim')),
        findsNothing,
      );
    });

    // ── THE NAMED GAP ───────────────────────────────────────────────────
    //
    // The Floor's Dawn wash is two RADIAL gradients centred 4% below the
    // bottom edge, so at the scrim's own y the ground varies horizontally as
    // well as vertically — `floor_band_seam_test.dart` measures 15 levels
    // across 195dp on the row at y=708. `torchGroundAt` answers a question
    // about a vertical falloff and there is no answer to give about a radial
    // one. Masking the composite is a `ShaderMask`, which the paint budget
    // does not have.
    //
    // So the scrim is declined there rather than shipped slightly wrong, and
    // this is the test that says so out loud instead of leaving it to be
    // rediscovered.
    testWidgets('$name: a route with a backdrop declines the scrim', (
      tester,
    ) async {
      await pumpShell(
        tester,
        skin: skin,
        size: const Size(390, 844),
        backdrop: <Decoration>[
          BoxDecoration(
            gradient: RadialGradient(
              colors: <Color>[
                skin.palette.comparison.withValues(alpha: 0.3),
                skin.palette.comparison.withValues(alpha: 0),
              ],
            ),
          ),
        ],
      );
      expect(
        find.byKey(const ValueKey<String>('torch-band-scrim')),
        findsNothing,
        reason:
            'an exact scrim over a radial wash needs a mask, and the paint '
            'budget has no ShaderMask',
      );
    });
  }

  testWidgets('the agent profile has no falloff, so the ground is the token', (
    tester,
  ) async {
    final skin = TiqSkin.night(density: TiqDensity.field);
    expect(
      torchGroundAt(skin, falloff: false, height: 640, y: 500),
      skin.palette.ground,
    );
  });

  testWidgets('torchGroundAt agrees with the falloff at both ends', (
    tester,
  ) async {
    final skin = TiqSkin.night(density: TiqDensity.console);
    // The first and last pixel row are the two places `palette.ground` has
    // ever been the ground, which is the sentence the whole helper exists for.
    //
    // CHANNELS, NOT `==`. `Color.lerp` returns a float-component Color even at
    // t=0, so it is never `==` an int-constructed token however identical the
    // two print. The question being asked is about the pixel, so the
    // instrument is the pixel.
    void sameInk(Color got, Color want, String where) {
      for (final (c, a, b) in <(String, double, double)>[
        ('red', got.r, want.r),
        ('green', got.g, want.g),
        ('blue', got.b, want.b),
      ]) {
        expect(
          (a * 255 - b * 255).abs(),
          lessThan(0.5),
          reason: '$where, $c: $got against $want',
        );
      }
    }

    sameInk(
      torchGroundAt(skin, falloff: true, height: 844, y: 0),
      skin.palette.ground,
      'the top edge',
    );
    sameInk(
      torchGroundAt(skin, falloff: true, height: 844, y: 844),
      skin.palette.ground,
      'the bottom edge',
    );
    // And the middle is the vignette, flat, between the two 96dp ramps.
    sameInk(
      torchGroundAt(skin, falloff: true, height: 844, y: 422),
      skin.palette.vignette,
      'the middle',
    );
    // 24dp above the bottom edge is NEITHER — which is the number that makes
    // a constant the wrong tool.
    final atScrim = torchGroundAt(skin, falloff: true, height: 844, y: 820);
    expect(
      (atScrim.b * 255 - skin.palette.ground.b * 255).abs(),
      greaterThan(1),
      reason: 'a constant is the wrong tool at the scrim\'s y: $atScrim',
    );
    expect(
      (atScrim.b * 255 - skin.palette.vignette.b * 255).abs(),
      greaterThan(1),
    );
  });
}

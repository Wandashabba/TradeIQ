import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/torch_shell.dart';

import 'torch_harness.dart';

/// THE BAND'S BACKDROP IS THE SHELL'S GROUND — AND THE INVARIANT THAT ALLOWS IT.
///
/// [TorchShell.band] paints nothing. The shell's own ground is behind it, and
/// on the console that ground is a vertical falloff, so **any** fill a band
/// gives itself disagrees with the ground at the band's own y — a flat fill
/// over a gradient is a seam everywhere the two differ. The Floor shipped such
/// a fill on 30 September 2026 and the owner named it the next day: *"The
/// background colour is messed up here please fix this to be seamless and not
/// have this box blue there."*
///
/// The fill was there for a reason that does not hold: "the decision list read
/// through the chip row". It cannot. A band is a **sibling** of the scroll view
/// in the shell's Column, never an overlay, and a `ListView` clips to its own
/// viewport — which ends where the band begins. That is the invariant the fill
/// was standing in for, and a comment is not an invariant, so it is measured
/// here instead: a magenta body dragged under a band with no material at all,
/// and a count of body pixels inside the band's box.
///
/// Two failures this is aimed at, and they are different:
///
/// * Somebody makes the band an overlay (a `Stack`, a sliver, a negative
///   margin). The bleed count stops being zero and the first test fails.
/// * Somebody gives a band a backdrop again. The seam measurements fail.
void main() {
  /// Pure magenta: nothing in either palette is within reach of it, so a
  /// magenta pixel inside the band's box is a body pixel and nothing else.
  const body = Color(0xFFFF00FF);

  /// The dither the ground's own gradient paints with. Adjacent pixels on a
  /// four-stop vertical gradient alternate by a level, and the gradient's own
  /// step over the 96dp ramp is under one level per dp on both skins — Night
  /// travels 4,6,9 and Day 8,9,10 across the whole ramp. So two neighbouring
  /// samples of the same ground never differ by more than this, and the three
  /// seams this file exists for were 7, 9 and 10 at their widest channel.
  const tolerance = 2;

  bool matches(Color a, Color b) =>
      ((a.r - b.r).abs() * 255).round() <= tolerance &&
      ((a.g - b.g).abs() * 255).round() <= tolerance &&
      ((a.b - b.b).abs() * 255).round() <= tolerance;

  String show(Color c) =>
      '#${((c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round()).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  Widget shell({
    required TorchShellProfile profile,
    required Widget band,
    required ScrollController controller,
  }) => TorchShell(
    profile: profile,
    scrollController: controller,
    band: band,
    children: <Widget>[
      for (var i = 0; i < 40; i++)
        Container(
          height: 48,
          margin: const EdgeInsets.only(bottom: 8),
          color: body,
        ),
    ],
  );

  const bandKey = ValueKey<String>('shell-band-probe');

  /// The band under test: 120dp tall, full width, and **no material of its
  /// own** — which is the whole point.
  ///
  /// Full width because a bare `SizedBox` with no width measures **zero** wide
  /// in the shell's Column, and the first version of this guard passed against
  /// a flat fill for exactly that reason: it was sampling a band 0dp across.
  const probeBand = SizedBox(key: bandKey, height: 120, width: double.infinity);

  for (final profile in TorchShellProfile.values) {
    for (final (label, skin) in <(String, TiqSkin)>[
      ('night', TiqSkin.night(density: TiqDensity.console)),
      ('day', TiqSkin.day(density: TiqDensity.console)),
    ]) {
      final name = '${profile.name}, $label';

      testWidgets('$name: no body pixel reaches the band box', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await pumpTorch(
          tester,
          skin: skin,
          size: const Size(390, 844),
          child: shell(
            profile: profile,
            controller: controller,
            band: probeBand,
          ),
        );
        // Half the extent plus 13dp, so a 48dp row is caught mid-way across
        // the band's top edge rather than aligned to it.
        controller.jumpTo(controller.position.maxScrollExtent / 2 + 13);
        await tester.pump();

        final box = tester.getRect(find.byKey(bandKey));
        final pixels = await torchPixels(tester);
        var bled = 0;
        for (var y = box.top.round(); y < box.bottom.round(); y++) {
          for (var x = 0; x < pixels.width; x++) {
            if (matches(pixels.at(x.toDouble(), y.toDouble()), body)) bled++;
          }
        }
        expect(
          bled,
          0,
          reason:
              'The body read through the band. The band is a sibling of the '
              'scroll view and the scroll view clips to its viewport, so this '
              'is zero by construction — if it is not, the band has become an '
              'overlay and it now needs a backdrop, which on the console has '
              'to be the slice of the falloff it covers and never a flat '
              'palette.ground.',
        );
      });

      testWidgets('$name: the band box is the ground, at every y', (
        tester,
      ) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await pumpTorch(
          tester,
          skin: skin,
          size: const Size(390, 844),
          child: shell(
            profile: profile,
            controller: controller,
            band: probeBand,
          ),
        );
        await tester.pump();

        final box = tester.getRect(find.byKey(bandKey));
        final pixels = await torchPixels(tester);
        // x=2 is outside the gutter the shell pads the band by, so it is the
        // ground and nothing else — the reading the band's own box has to
        // agree with. The old flat fill disagreed with it by 7 levels of blue
        // at the gutter and 9 at the band's top edge.
        for (var y = box.top.round(); y < box.bottom.round(); y++) {
          final ground = pixels.at(2, y.toDouble());
          for (final x in <double>[
            box.left - 1,
            box.left + 1,
            box.center.dx,
            box.right - 1,
            box.right + 1,
          ]) {
            final inside = pixels.at(x, y.toDouble());
            expect(
              matches(inside, ground),
              isTrue,
              reason:
                  'At y=$y, x=$x the band reads ${show(inside)} against a '
                  'ground of ${show(ground)}. A band paints no backdrop; the '
                  'shell ground is continuous through its box.',
            );
          }
        }
      });
    }
  }

  testWidgets('a band with the keyboard up still takes no body pixel', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final skin = TiqSkin.night(density: TiqDensity.console);
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          devicePixelRatio: 1.0,
          // The band clears the keyboard itself, which moves it up the screen
          // and up the falloff — the y at which a flat fill is most wrong.
          viewInsets: EdgeInsets.only(bottom: 320),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Theme(
            data: ThemeData(extensions: <ThemeExtension<dynamic>>[skin]),
            child: RepaintBoundary(
              key: torchBoundaryKey,
              child: SizedBox.fromSize(
                size: const Size(390, 844),
                child: shell(
                  profile: TorchShellProfile.console,
                  controller: controller,
                  band: probeBand,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    controller.jumpTo(controller.position.maxScrollExtent / 2 + 13);
    await tester.pump();

    final box = tester.getRect(find.byKey(bandKey));
    final pixels = await torchPixels(tester);
    var bled = 0;
    for (var y = box.top.round(); y < box.bottom.round(); y++) {
      for (var x = 0; x < pixels.width; x++) {
        if (matches(pixels.at(x.toDouble(), y.toDouble()), body)) bled++;
      }
    }
    expect(bled, 0);
    for (var y = box.top.round(); y < box.bottom.round(); y++) {
      final ground = pixels.at(2, y.toDouble());
      expect(
        matches(pixels.at(box.center.dx, y.toDouble()), ground),
        isTrue,
        reason: 'The band disagrees with the ground at y=$y, keyboard up.',
      );
    }
  });

  test('a pinned band is refused on a profile that has a falloff', () {
    // The flat fill a pinned band carries is exact on the agent profile and a
    // box on the console. The assert is the note the next caller will read.
    expect(
      () => TorchShell(
        profile: TorchShellProfile.console,
        pinned: const SizedBox(height: 40),
        children: const <Widget>[],
      ),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => TorchShell(
        profile: TorchShellProfile.agent,
        pinned: const SizedBox(height: 40),
        children: const <Widget>[],
      ),
      returnsNormally,
    );
  });
}

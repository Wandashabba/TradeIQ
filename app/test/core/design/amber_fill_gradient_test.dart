import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_contrast.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/primary_button.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/nav_circle.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/nav_pill.dart';
import 'package:tradeiq_app/features/assistant/answer/ask_light.dart';

import '../widgets/torchlight/torch_harness.dart';
import 'amber_golden.dart';

/// THE AMBER FILL GRADIENT'S TWO PROMISES, CHECKED AT EVERY STOP.
///
/// A filled amber object stopped being one colour on 1 October 2026 — the
/// owner's note was *"the send button on the app and everywhere else for orange
/// is very dull, it need to be lumunous and bright and inviting"*, `flame600`
/// was already at value 1.00, and a flat swatch of one colour cannot glow. Each
/// of the four filled amber objects now ramps from a hot stop to `flame600`.
///
/// That change is only safe because of two claims, and both of them are the
/// kind of claim it is easy to make and easy to be wrong about:
///
/// 1. **The ink's worst case does not move.** Dark ink on amber is a declared
///    pairing in `tiq_contrast.dart`, and over a gradient the ink sits on a
///    *range* of colours rather than one. The honest number is therefore the
///    worst point under the text, **never the average** — and averaging is
///    exactly how this check gets fudged. The promise is that the worst point
///    is `flame600` itself, because `flame600` is the ramp's last stop and the
///    ramp goes no further, so the gradient cannot be worse than the flat fill
///    it replaced.
///
/// 2. **The amber census does not move.** `amber_golden.dart` counts connected
///    regions inside a flame-hue box — hue 20–48°, value ≥ 0.90, saturation
///    ≥ 0.12. If any interpolated colour between the hot stop and `flame600`
///    fell out of that box, a filled object would break into two regions or
///    shrink, and a screen that lights two objects would start counting one or
///    three. The promise is that every stop across the ramp is inside the box.
///
/// Both are checked here at **a hundred and one points** across each skin's
/// ramp, not at its two ends: the interesting failure is a colour in the middle
/// that leaves the box or dips under the floor while both endpoints look fine.
/// Interpolation is per-channel on 8-bit values, which is what Flutter's
/// gradient shader and `Color.lerp` both do.
void main() {
  /// The stop a gradient actually paints at `t`, quantised the way the shader
  /// quantises it.
  Color at(List<Color> ramp, double t) => Color.lerp(ramp.first, ramp.last, t)!;

  for (final (name, skin) in <(String, TiqSkin)>[
    ('night', TiqSkin.night()),
    ('day', TiqSkin.day()),
  ]) {
    group('$name — the amber fill ramp', () {
      final ramp = skin.amberFillRamp;
      final p = skin.palette;

      test('runs from the skin\'s hot stop to flame-600 and no further', () {
        expect(
          ramp.length,
          2,
          reason: 'Two stops. A third would be a third thing to measure.',
        );
        expect(
          ramp.last,
          p.flame600,
          reason:
              'THE COLD END MUST BE flame-600. It is the whole reason the ink '
              'ratios survive this change: the worst pixel under any label on '
              'an amber fill is the ramp\'s coldest stop, and if that stop is '
              'flame-500 instead then every declared onAmber pairing has '
              'silently moved and nothing in the contrast table knows.',
        );
        expect(
          ramp.first,
          // Night has the headroom for a white-hot core; on paper flame-900 is
          // 1.04:1 against Palladian and an amber block with one in it reads
          // as a hole rather than a hot centre.
          skin.amberIsInk ? p.flame700 : p.flame900,
          reason: 'the hot stop is per skin — see TiqSkin.amberFillRamp',
        );
      });

      test('every stop is inside the census\'s flame box', () {
        for (var i = 0; i <= 100; i++) {
          final c = at(ramp, i / 100);
          expect(
            isFlameHued(
              (c.r * 255).round(),
              (c.g * 255).round(),
              (c.b * 255).round(),
            ),
            isTrue,
            reason:
                'the stop at t=${(i / 100).toStringAsFixed(2)} is '
                '${c.toARGB32().toRadixString(16)}, which is OUTSIDE the '
                'flame box. A filled amber object would break into more than '
                'one connected region there, and every per-screen census '
                'count in the suite would move.',
          );
        }
      });

      test('the worst point under the text is flame-600 exactly', () {
        // Dark ink on amber, swept across the ramp. The minimum is the number
        // that has to clear the floor — not the mean, and not the midpoint.
        var worst = double.infinity;
        var worstT = -1.0;
        for (var i = 0; i <= 100; i++) {
          final t = i / 100;
          final r = contrastRatio(p.onAmber, at(ramp, t));
          if (r < worst) {
            worst = r;
            worstT = t;
          }
        }
        expect(
          worstT,
          1.0,
          reason:
              'The worst point is at t=$worstT, not at the cold end. The ramp '
              'is supposed to be monotonic in luminance so that the coldest '
              'stop is also the darkest — if it is not, the figure the '
              'contrast table declares is no longer the binding one.',
        );
        expect(
          worst,
          closeTo(contrastRatio(p.onAmber, p.flame600), 0.0001),
          reason:
              'The worst pixel under the label must be the same pixel the flat '
              'fill painted. It measures ${worst.toStringAsFixed(2)}:1 against '
              'flame-600\'s '
              '${contrastRatio(p.onAmber, p.flame600).toStringAsFixed(2)}:1.',
        );
        expect(
          worst,
          greaterThanOrEqualTo(ContrastRole.text.floor),
          reason:
              'ink on a gradient-filled amber block measures '
              '${worst.toStringAsFixed(2)}:1 at its worst point, under the '
              '${ContrastRole.text.floor} a text pairing needs',
        );
      });

      test('the pressed fill is NOT a gradient, and stays declared', () {
        // The press floods to a single flame-500 and the ink stays dark. A
        // gradient on the pressed state would put the one frame a manager
        // looks at hardest on a range nothing measures.
        expect(
          contrastRatio(p.onAmberPressed, p.amberPressed),
          greaterThanOrEqualTo(ContrastRole.text.floor),
        );
      });
    });
  }

  test('the two skins ramp to the same cold end', () {
    // One brand colour, two depths of glow. If these ever diverge there are
    // two Burning Flames and the amber law has a seam in it.
    expect(
      TiqSkin.night().amberFillRamp.last,
      TiqSkin.day().amberFillRamp.last,
    );
  });

  // ── AND IT IS ACTUALLY WIRED ──────────────────────────────────────────
  //
  // The arithmetic above is about the ramp. This is about the four objects
  // that paint it, because a gradient computed and never handed to a
  // `BoxDecoration` is a change that passes every number and ships nothing.
  // Each object chose its own geometry and the reason is on each one; what is
  // asserted here is the part they must share — that the decoration carries a
  // gradient at all, and that its last stop is `flame600`.
  group('the objects that paint it', () {
    /// The gradient on the one decoration that has one, under [of].
    Gradient? rampOf(WidgetTester tester, Finder of) {
      final found = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: of, matching: find.byType(DecoratedBox)),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.gradient)
          .whereType<Gradient>()
          .toList();
      return found.isEmpty ? null : found.first;
    }

    for (final (name, skin) in <(String, TiqSkin)>[
      ('night', TiqSkin.night()),
      ('day', TiqSkin.day()),
    ]) {
      testWidgets('$name — the filled primary commit', (tester) async {
        const claim = 'commit';
        await pumpTorch(
          tester,
          skin: skin,
          claims: <TorchClaim>[TorchPrimaryButton.claim(claim)],
          child: Center(
            child: TorchPrimaryButton(
              claimId: claim,
              label: 'Check in here',
              filled: true,
              onPressed: () {},
            ),
          ),
        );
        final ramp = rampOf(tester, find.byType(TorchPrimaryButton));
        expect(
          ramp,
          isNotNull,
          reason:
              'the granted filled face paints flat. The gradient was computed '
              'and never reached the BoxDecoration.',
        );
        expect(ramp, isA<LinearGradient>());
        expect(
          ramp!.colors.last,
          skin.palette.flame600,
          reason: 'the cold end carries the declared onAmber ratio',
        );
      });

      // THE NAV CIRCLE IS NOT IN THE SKIN LOOP FOR THE PRIMARY'S REASON
      // INVERTED. It claims rung 4, and on a light ground the allocator
      // refuses every rung but the primary commit outright
      // (`TorchDenial.notAmberOnLightGround`) — so the Day circle has no amber
      // form to put a gradient on, and asserting one would be asserting
      // against the amber law. Both halves of that are checked.
      testWidgets('$name — the nav circle', (tester) async {
        const claim = 'unplanned-visit';
        await pumpTorch(
          tester,
          skin: skin,
          navRenders: true,
          claims: <TorchClaim>[TorchClaim.navCircle(claim)],
          child: Center(
            child: TorchNavCircle(
              claimId: claim,
              expected: true,
              icon: Icons.add,
              expectedIcon: Icons.arrow_forward,
              semanticLabel: 'Start a visit somewhere else',
              expectedSemanticLabel: 'Start a visit here',
              onPressed: () {},
            ),
          ),
        );
        final ramp = rampOf(tester, find.byType(TorchNavCircle));
        if (skin.amberIsInk) {
          expect(
            ramp,
            isNull,
            reason:
                'a light ground granted rung 4. On paper the only amber is the '
                'primary commit block, so this disc must have no amber form '
                'at all — let alone a glowing one.',
          );
          return;
        }
        expect(ramp, isNotNull, reason: 'the granted disc paints flat');
        expect(
          ramp,
          isA<RadialGradient>(),
          reason: 'a disc is lit from a point, not washed from an edge',
        );
        expect(ramp!.colors.last, skin.palette.flame600);
      });
    }

    // ── THE NAV TAB HAS NO RAMP ANY MORE — 4 October 2026, shape A ───────
    //
    // This test used to assert the opposite: that the lit active tab carried a
    // `LinearGradient` whose last stop was `flame600`, washed from its top
    // edge because it was "a wide short block". **The block is gone.**
    // [TorchNavPill]'s shape A names the active tab with a 24×2dp amber edge
    // under its label instead of filling the slot, and a 2dp rule has no room
    // for a falloff — a three-stop ramp across two pixel rows is a dither, not
    // a light with a core.
    //
    // It is INVERTED rather than deleted, because "no gradient" is the claim
    // that now needs holding. The file's thesis is that every filled amber
    // object in the product carries the 1 October ramp; the nav tab stopped
    // being a filled amber object, and a reader coming here to ask why it is
    // missing should find the answer rather than a gap.
    //
    // What the owner's *"it need to be lumunous and bright"* bought is still
    // on screen beside this bar: the forward key's hot-core radial is
    // untouched and is asserted in the loop above.
    testWidgets('night — the nav tab is an edge, and edges have no ramp', (
      tester,
    ) async {
      final skin = TiqSkin.night();
      await pumpTorch(
        tester,
        skin: skin,
        navRenders: true,
        tabbedRoute: true,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: TorchNavPill(
            slots: const <TorchNavSlot>[
              TorchNavSlot(label: 'Today', icon: Icons.today, activeIcon: Icons.today),
              TorchNavSlot(label: 'Map', icon: Icons.map, activeIcon: Icons.map),
            ],
            activeIndex: 0,
            onSelect: (_) {},
          ),
        ),
      );
      expect(
        rampOf(tester, find.byType(TorchNavPill)),
        isNull,
        reason:
            'shape A took the filled tab away, and the two-identical-stop '
            'companion gradient went with it: that existed only so a '
            'lit-to-unlit cross-fade never lerped a gradient against null. '
            'With no gradient in either state there is no such transition.',
      );
      // AND THE AMBER IS STILL THERE, flat, which is the half that stops this
      // from passing on a bar that lost its light altogether.
      final fills = tester
          .widgetList<AnimatedContainer>(
            find.descendant(
              of: find.byType(TorchNavPill),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.color)
          .toList();
      expect(
        fills,
        contains(skin.palette.flame600),
        reason: 'the active tab edge, at full alpha, read off the skin',
      );
    });

    // The send disc is resolved in `ask_light.dart` rather than by the widget,
    // so its ramp is checked at the source — which is also the only place a
    // screen is allowed to decide it.
    for (final (name, skin) in <(String, TiqSkin)>[
      ('night', TiqSkin.night()),
      ('day', TiqSkin.day()),
    ]) {
      test('$name — the send disc', () {
        final lit = AskLight.send(
          skin,
          lit: true,
          pressed: false,
          disabled: false,
        );
        expect(lit.bloom, isNotNull);
        expect(
          lit.bloom,
          isA<RadialGradient>(),
          reason: 'the same geometry as the nav circle — one light direction',
        );
        expect(lit.bloom!.colors.last, skin.palette.flame600);
        expect(
          lit.fill,
          skin.palette.flame600,
          reason:
              'the flat fallback stays, for a skin with no gradient budget',
        );

        // EVERY OTHER STATE IS FLAT. A disc that is not carrying the route's
        // light has nothing to glow with, and a gradient on the pressed frame
        // would put the moment of commitment on a range nothing measures.
        for (final (state, look) in <(String, AskSendLook)>[
          (
            'denied',
            AskLight.send(skin, lit: false, pressed: false, disabled: false),
          ),
          (
            'pressed',
            AskLight.send(skin, lit: true, pressed: true, disabled: false),
          ),
          (
            'disabled',
            AskLight.send(skin, lit: false, pressed: false, disabled: true),
          ),
        ]) {
          expect(look.bloom, isNull, reason: '$state must paint flat');
        }
      });
    }
  });
}

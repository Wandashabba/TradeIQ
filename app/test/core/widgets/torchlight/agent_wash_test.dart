import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderDecoratedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_contrast.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/agent_wash.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';

import '../../design/amber_golden.dart';
import 'torch_harness.dart';

/// ── THE BACK SHADE AND THE FADE, AND THE ONE FACT THAT LETS THEM COEXIST ──
///
/// `TorchShell.backdrop`'s own note declines the 24dp scrim on any route with
/// a wash, because *"a wash makes the colour at that y unknowable"*: no linear
/// gradient in a `BoxDecoration` reproduces a radial one, and masking the
/// composite is what a `ShaderMask` is for and the paint budget does not have
/// one. The Floor loses the scrim by that rule and still does.
///
/// The agent's tab roots get **both**, and the whole argument is one
/// measurement: a **top-anchored** Dawn is zero across the body's last 24dp,
/// so there is nothing there for the scrim to disagree with. The arithmetic is
/// in `agent_wash.dart` — the clay ellipse's outermost stop lands at
/// `0.76 × 0.48 − 0.04 = 0.3248` of the screen's height — and this file is the
/// part that reads it off real pixels instead of trusting it.
///
/// `TorchShell.backdropClearsScrim` is a route's **claim** that this holds.
/// A claim a test does not check is a comment, so:
///
/// 1. the wash is **exactly** the bare ground across the scrim band, at both
///    approved sizes, in both skins — equality, not a tolerance, because the
///    gradient's last stop is alpha zero and zero composites to nothing;
/// 2. the scrim ends in `palette.ground`, which on this profile really is the
///    ground at every y (`torchGroundAt` returns the token unchanged with no
///    falloff), so the agent half of the seam argument is exact rather than
///    computed;
/// 3. it covers a real clip: a body dragged under the bar is gone by the
///    scrim's bottom edge;
/// 4. **a bottom-rising wash gets no scrim**, which is the half that proves
///    the rule still bites. That is the comparison direction the owner was
///    offered, and the two renders differ in the fade for this reason.
void main() {
  /// The two approved sizes. 390×844 is what the manager screens are
  /// photographed at; 360×640 is the cheap Android the fold is judged on and
  /// the tighter case for the clearance arithmetic, because a shorter screen
  /// puts the scrim band closer to the wash.
  const sizes = <(String, Size)>[
    ('390x844', Size(390, 844)),
    ('360x640', Size(360, 640)),
  ];

  /// Night first, then Day — the order the design says to build them in. Day
  /// is the agent's default and the harder case, so it is also the one the
  /// reasons are written against.
  List<(String, TiqSkin)> skins() => <(String, TiqSkin)>[
    ('night', TiqSkin.night(density: TiqDensity.field)),
    ('day', TiqSkin.day(density: TiqDensity.field)),
  ];

  /// A body in one flat colour, so a probe can say whether any of it survived
  /// the fade. Magenta is in neither palette and in neither wash.
  const bodyInk = Color(0xFFFF00FF);

  const slots = <TorchNavSlot>[
    TorchNavSlot(
      icon: Icons.today_outlined,
      activeIcon: Icons.today,
      label: 'Today',
    ),
    TorchNavSlot(
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
      label: 'Work',
    ),
    TorchNavSlot(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Map'),
    TorchNavSlot(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Me',
    ),
  ];

  /// An agent tab root: the wash, the flag, the bar, and a body twice the
  /// viewport so the last row is always mid-clip.
  Future<void> pumpTabRoot(
    WidgetTester tester, {
    required TiqSkin skin,
    required Size size,
    AgentWashDirection direction = AgentWashDirection.falling,
    bool flatBody = true,
  }) async {
    await pumpTorch(
      tester,
      skin: skin,
      size: size,
      navRenders: true,
      tabbedRoute: true,
      child: TorchShell(
        profile: TorchShellProfile.agent,
        backdrop: agentWashFor(skin, direction),
        backdropClearsScrim: agentWashClearsScrim(direction),
        navPill: TorchNavPill(
          slots: slots,
          activeIndex: 0,
          onSelect: (_) {},
        ),
        children: <Widget>[
          if (flatBody)
            SizedBox(
              height: size.height * 2,
              child: const ColoredBox(color: bodyInk),
            ),
        ],
      ),
    );
    await tester.pump();
  }

  /// The shell with no wash at all, for the bare-ground reading every
  /// measurement below is against. Same tree otherwise.
  Future<void> pumpBare(
    WidgetTester tester, {
    required TiqSkin skin,
    required Size size,
  }) async {
    await pumpTorch(
      tester,
      skin: skin,
      size: size,
      navRenders: true,
      tabbedRoute: true,
      child: TorchShell(
        profile: TorchShellProfile.agent,
        navPill: TorchNavPill(
          slots: slots,
          activeIndex: 0,
          onSelect: (_) {},
        ),
        children: const <Widget>[],
      ),
    );
    await tester.pump();
  }

  // ───────────────────────── 1. THE CLEARANCE, MEASURED ─────────────────────

  group('the wash is absent where the scrim has to match', () {
    for (final (sizeName, size) in sizes) {
      for (final (skinName, skin) in skins()) {
        testWidgets('$skinName, $sizeName: every pixel of the scrim band is '
            'the bare ground', (tester) async {
          // No body at all, so what is under the scrim band is the shell's
          // ground and the wash and nothing else. A flat body would be the
          // thing being measured instead of the backdrop.
          await pumpTabRoot(tester, skin: skin, size: size, flatBody: false);
          final scrim = tester.getRect(
            find.byKey(const ValueKey<String>('torch-band-scrim')),
          );
          expect(
            scrim.height,
            TorchShell.bandScrimExtent,
            reason: "the scrim is the body's own bottom padding, no more",
          );
          final washed = await torchPixels(tester);

          // WHERE THE BAND IS, as a share of the screen — the number the
          // clearance argument is about. Printed rather than asserted at a
          // literal: the body's height is the shell's arithmetic and pinning
          // it here would be a second copy of it.
          final t = scrim.top / size.height;
          expect(
            t,
            greaterThan(0.3248),
            reason:
                'the scrim band must begin BELOW the wash\'s outermost stop. '
                'Band top t=${t.toStringAsFixed(3)}, wash reaches zero at '
                't=0.3248 (0.76 x 0.48 - 0.04 — see agent_wash.dart).',
          );

          // EQUALITY, NOT A TOLERANCE. The clay layer's last stop is alpha
          // zero and the Night hot breath's is too, so across this band the
          // composite is the ground unchanged — not the ground plus a dither.
          // A tolerance here would pass on a wash that was merely faint, and
          // "faint" is exactly what the bottom-rising version is.
          for (var y = scrim.top.toInt(); y < scrim.bottom.toInt(); y++) {
            for (final x in <double>[
              0.5,
              size.width / 4,
              size.width / 2,
              size.width * 3 / 4,
              size.width - 0.5,
            ]) {
              expect(
                washed.at(x, y + 0.5),
                skin.palette.ground,
                reason:
                    '$skinName $sizeName: ($x, $y) inside the scrim band is '
                    'not the bare ground. A top-anchored Dawn is zero here by '
                    'construction; if this fails the centre or the radii moved '
                    'and the fade has to go with them.',
              );
            }
          }
        });
      }
    }

    // AND THE INSTRUMENT BITES. The same probe against the direction the
    // owner was offered as a comparison: a bottom-rising Dawn is the wash
    // this test would have to pass with a tolerance, and it does not pass
    // with equality. The numbers it prints are the cost of choosing it.
    for (final (skinName, skin) in skins()) {
      testWidgets('$skinName: a bottom-rising wash is NOT absent there, and '
          'this is what it spreads', (tester) async {
        const size = Size(360, 640);
        await pumpTabRoot(
          tester,
          skin: skin,
          size: size,
          direction: AgentWashDirection.rising,
          flatBody: false,
        );
        // No scrim at all on this direction — see group 4 — so the band is
        // computed from the bare shell's own scrim instead.
        await pumpBare(tester, skin: skin, size: size);
        final band = tester.getRect(
          find.byKey(const ValueKey<String>('torch-band-scrim')),
        );
        final bare = await torchPixels(tester);
        final bareGround = bare.at(size.width / 2, band.top + 1);

        await pumpTabRoot(
          tester,
          skin: skin,
          size: size,
          direction: AgentWashDirection.rising,
          flatBody: false,
        );
        final rising = await torchPixels(tester);

        var worstR = 0;
        var worstG = 0;
        var worstB = 0;
        for (var y = band.top.toInt(); y < band.bottom.toInt(); y++) {
          final c = rising.at(size.width / 2, y + 0.5);
          worstR = <int>[
            worstR,
            ((c.r - bareGround.r) * 255).round().abs(),
          ].reduce((a, b) => a > b ? a : b);
          worstG = <int>[
            worstG,
            ((c.g - bareGround.g) * 255).round().abs(),
          ].reduce((a, b) => a > b ? a : b);
          worstB = <int>[
            worstB,
            ((c.b - bareGround.b) * 255).round().abs(),
          ].reduce((a, b) => a > b ? a : b);
        }
        // ignore: avoid_print
        print(
          'bottom-rising wash, $skinName, across the 24dp scrim band: '
          'red $worstR levels, green $worstG, blue $worstB off the bare '
          'ground. That is the step a flat-ground scrim would have had to '
          'end in, and it is the seam class fix/band-seam removed.',
        );
        expect(
          worstR + worstG + worstB,
          greaterThan(0),
          reason:
              'if a bottom-rising Dawn were also absent across the band then '
              'the direction would not matter and this whole argument would '
              'be decoration. It is not: the wash is live down there.',
        );
      });
    }
  });

  // ─────────────────── 2 & 3. THE FADE ITSELF, ON THE AGENT PROFILE ─────────

  group('the fade over the nav row', () {
    for (final (sizeName, size) in sizes) {
      for (final (skinName, skin) in skins()) {
        testWidgets('$skinName, $sizeName: it ends in the ground and the clip '
            'is covered', (tester) async {
          await pumpTabRoot(tester, skin: skin, size: size);
          final scrim = tester.getRect(
            find.byKey(const ValueKey<String>('torch-band-scrim')),
          );
          final pixels = await torchPixels(tester);

          // THE OPAQUE END. `torchGroundAt` returns `palette.ground`
          // unchanged on a profile with no falloff, so unlike the console
          // this is an exact token and not a computed slice of a gradient.
          expect(
            torchGroundAt(
              skin,
              falloff: false,
              height: size.height,
              y: scrim.bottom,
            ),
            skin.palette.ground,
            reason:
                'the agent profile has no letterbox falloff, which is what '
                'makes the scrim target exact here',
          );
          expect(
            pixels.at(size.width / 2, scrim.bottom - 0.5),
            skin.palette.ground,
            reason:
                '$skinName $sizeName: the scrim\'s last row must BE the '
                'ground. The fade finishes at 85% and the last 3.6dp is '
                'opaque ground, so the clip row is covered rather than nearly '
                'covered.',
          );

          // AND THE BODY IS GONE BY THEN. The flat magenta body runs twice
          // the viewport, so it is mid-clip at the scrim in every case.
          expect(
            pixels.at(size.width / 2, scrim.top + 0.5),
            isNot(skin.palette.ground),
            reason:
                'at the scrim\'s TOP the fade has not started, so the body is '
                'still visible — otherwise this is not a fade, it is a band',
          );
          for (var y = (scrim.bottom - 3).toInt();
              y < scrim.bottom.toInt();
              y++) {
            expect(
              pixels.at(size.width / 2, y + 0.5),
              skin.palette.ground,
              reason:
                  'the last 3dp carries no body pixel at all: that is the '
                  'cut the owner photographed, and covering it is the point',
            );
          }
        });
      }
    }

    testWidgets('a thumb-zone screen still clips hard, and that is named', (
      tester,
    ) async {
      // The gap this change does NOT close. A thumb zone draws a hairline
      // across its own top edge, so the clip stops against a declared
      // boundary rather than in mid-air; the fault shape A created does not
      // exist there. Pinned so the absence is a decision with a test on it
      // rather than something nobody looked at.
      final skin = TiqSkin.day(density: TiqDensity.field);
      await pumpTorch(
        tester,
        skin: skin,
        size: const Size(360, 640),
        child: TorchShell(
          profile: TorchShellProfile.agent,
          skinCycle: const SizedBox(width: 56, height: 56),
          children: <Widget>[
            const SizedBox(height: 1280, child: ColoredBox(color: bodyInk)),
          ],
        ),
      );
      expect(find.byType(TorchThumbZone), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('torch-band-scrim')),
        findsNothing,
        reason:
            'no fade over a thumb zone. The hairline is the boundary there, '
            'and whether these screens would read better with one too is a '
            'separate question from shape A.',
      );
    });
  });

  // ──────────────────── 4. THE RULE STILL BITES, MEASURED ───────────────────

  group('a wash that is live at the bottom gets no fade', () {
    for (final (skinName, skin) in skins()) {
      testWidgets('$skinName: rising → no scrim', (tester) async {
        await pumpTabRoot(
          tester,
          skin: skin,
          size: const Size(360, 640),
          direction: AgentWashDirection.rising,
        );
        expect(
          find.byKey(const ValueKey<String>('torch-band-scrim')),
          findsNothing,
          reason:
              'the direction and the flag come from one place '
              '(`agentWashClearsScrim`), so a wash that is live across the '
              'band cannot be shipped with a scrim that would have to end in '
              'a colour nobody can compute. This is the trade the comparison '
              'render shows.',
        );
      });

      testWidgets('$skinName: falling → a scrim', (tester) async {
        await pumpTabRoot(tester, skin: skin, size: const Size(360, 640));
        expect(
          find.byKey(const ValueKey<String>('torch-band-scrim')),
          findsOneWidget,
        );
      });
    }
  });

  // ───────────────────────── THE BUDGETS, BOTH OF THEM ─────────────────────

  group('what it costs', () {
    for (final (skinName, skin) in skins()) {
      testWidgets('$skinName: no blur, no mask, no shadow, and the right '
          'number of decorations', (tester) async {
        await pumpTabRoot(tester, skin: skin, size: const Size(390, 844));
        expectNoBlurOrShadow(tester);
        // Two on Night — Dawn's `flame900` hot breath and its clay — and one
        // on Day, which drops the hot breath because it is worth +0.8 of a
        // red level on Palladian and is what would put the wash inside the
        // census box. `floor_dawn.dart` has the interval arithmetic.
        expect(
          agentDawnWash(skin).length,
          skin.amberIsInk ? 1 : 2,
          reason: 'Day has no hot breath; Night does',
        );
      });

      testWidgets('$skinName: a skin with no gradient budget gets no wash', (
        tester,
      ) async {
        // Both shipping skins allow gradients, so this changes no pixel
        // today — it is pinned so the guard cannot go quiet, which is
        // `floor_dawn.dart`'s own reason for pinning it.
        // The same literal `floor_dawn_test.dart` uses, for the same reason:
        // `TiqDepth` has no `copyWith`, and spelling the whole value out is
        // what makes "allowsGradients is the only thing that differs" visible.
        const flat = TiqDepth(
          shadows: <BoxShadow>[],
          litRim: Color(0x00000000),
          allowsGradients: false,
          borderWidth: 1,
        );
        final flatSkin = skin.copyWith(depth: flat);
        expect(agentDawnWash(flatSkin), isEmpty);
        expect(
          agentWashClearsScrim(AgentWashDirection.falling),
          isTrue,
          reason:
              'and the flag is still true with no wash at all, which is '
              'vacuously correct: nothing is painted across the band',
        );
      });
    }

    for (final (skinName, skin) in skins()) {
      testWidgets('$skinName: the wash lights nothing', (tester) async {
        await pumpTabRoot(
          tester,
          skin: skin,
          size: const Size(390, 844),
          flatBody: false,
        );
        final withWash = await amberCensus(tester);
        await pumpBare(tester, skin: skin, size: const Size(390, 844));
        final without = await amberCensus(tester);
        expect(
          withWash.objectCount,
          without.objectCount,
          reason:
              'the back shade declares no claim and emits nothing. '
              'with: ${withWash.describe()} without: ${without.describe()}',
        );
      });
    }
  });

  // ── THE PEAK, AND WHICH PAIRINGS IT WOULD AND WOULD NOT CARRY ─────────
  //
  // THIS IS NOT THE CONTRAST PROOF. The proof is
  // `test/features/agent_wash_contrast_test.dart`, which walks every text run
  // and every outline on the four real tab roots and measures each one
  // against the ground actually under it. This group is the *bound*: what the
  // wash's strongest on-screen pixel would do to a pairing placed there.
  //
  // It is here because the first version of the contrast proof WAS this
  // measurement, and it failed — on Night `edgeStructure` reads 1.93:1 at the
  // peak against a floor of 3.0 — and the failure was the instrument's, not
  // the wash's: `navInkInactive` is the nav bar's inactive ink and the nav bar
  // is at the bottom, where this wash is provably zero, and no agent tab root
  // paints an `edgeStructure` outline in its top third at rest.
  //
  // So the finding is **pinned rather than deleted**, in both directions:
  // three pairings clear the peak and three do not, and the three that do not
  // are a live constraint on anybody adding an object to the top of an agent
  // tab root. The crossing alphas below were computed by sweep against the
  // on-screen peak (declared peak x 0.8106, which is where the clay gradient
  // stands at the top edge: centre 0.04 above it, first stop at 0.44 of the
  // 0.48H radius).
  group('the wash at its peak', () {
    for (final (skinName, skin) in skins()) {
      testWidgets('$skinName: three pairings clear it and three do not', (
        tester,
      ) async {
        const size = Size(390, 844);
        await pumpTabRoot(tester, skin: skin, size: size, flatBody: false);
        final pixels = await torchPixels(tester);

        // THE PEAK IS FOUND, NOT ASSUMED: furthest from the bare ground in
        // LUMINANCE, because contrast is a function of luminance alone.
        final bareLum = relativeLuminance(skin.palette.ground);
        var peak = skin.palette.ground;
        var distance = 0.0;
        for (var y = 0; y < (size.height * 0.33).toInt(); y++) {
          for (var x = 0; x < size.width.toInt(); x += 3) {
            final c = pixels.at(x + 0.5, y + 0.5);
            final d = (relativeLuminance(c) - bareLum).abs();
            if (d > distance) {
              distance = d;
              peak = c;
            }
          }
        }

        final clears = <(String, Color, double)>[
          ('ink1', skin.palette.ink1, 4.5),
          ('ink2', skin.palette.ink2, 4.5),
          ('edgeControl', skin.palette.edgeControl, 3.0),
        ];
        // The three that do not, with the declared clay peak each one crosses
        // its floor at. Day's binding term is `navInkInactive` at 0.039 and
        // Night's is `edgeStructure` at 0.124 — which is why "just lower the
        // alpha until the peak is safe for everything" is not an option: on
        // Day it lands at three eight-bit levels, which is a wash nobody can
        // see, and the owner asked for the shade on Day by name.
        final doNot = <(String, Color, double)>[
          ('ink3', skin.palette.ink3, 4.5),
          ('navInkInactive', skin.palette.navInkInactive, 4.5),
          ('edgeStructure', skin.palette.edgeStructure, 3.0),
        ];

        final table = StringBuffer()
          ..writeln(
            'the wash at its peak — $skinName, 390x844. peak pixel '
            '${peak.toARGB32().toRadixString(16).substring(2).toUpperCase()} '
            'against bare '
            '${skin.palette.ground.toARGB32().toRadixString(16).substring(2).toUpperCase()}:',
          );
        for (final (name, ink, floor) in <(String, Color, double)>[
          ...clears,
          ...doNot,
        ]) {
          table.writeln(
            '  ${name.padRight(15)} bare '
            '${contrastRatio(ink, skin.palette.ground).toStringAsFixed(2)}:1  '
            'at the peak ${contrastRatio(ink, peak).toStringAsFixed(2)}:1  '
            'floor $floor',
          );
        }
        // ignore: avoid_print
        print(table);

        for (final (name, ink, floor) in clears) {
          expect(
            contrastRatio(ink, peak),
            greaterThanOrEqualTo(floor),
            reason: '$skinName: $name must survive the peak. $table',
          );
        }
        for (final (name, ink, floor) in doNot) {
          expect(
            contrastRatio(ink, peak),
            lessThan(floor),
            reason:
                '$skinName: $name is recorded as NOT surviving the wash\'s '
                'peak, and it just did. That is good news and it means this '
                'pin is stale — either the wash got weaker or the palette '
                'moved. Re-measure and move the name into `clears`, and say '
                'in the PR that the constraint on the top of an agent tab '
                'root has loosened. $table',
          );
        }
      });
    }
  });
}

/// Every widget and decoration type this system has a zero budget for.
///
/// A copy of `chrome_golden_test.dart`'s pair rather than an import of it: a
/// test file carries a `main()`, and importing one into another runs its suite
/// twice. The list is the paint budget's own and is short enough that two
/// copies is cheaper than a third shared file nobody can find.
void expectNoBlurOrShadow(WidgetTester tester) {
  for (final widget in tester.allWidgets) {
    expect(
      widget,
      isNot(isA<BackdropFilter>()),
      reason: 'zero BackdropFilter in this application',
    );
    expect(widget, isNot(isA<ImageFiltered>()));
    expect(widget, isNot(isA<ShaderMask>()));
    expect(widget, isNot(isA<ColorFiltered>()));
  }
  for (final object in tester.allRenderObjects) {
    if (object is RenderDecoratedBox) {
      final decoration = object.decoration;
      if (decoration is BoxDecoration) {
        expect(
          decoration.boxShadow ?? const <BoxShadow>[],
          isEmpty,
          reason: 'a BoxShadow under a wash is a shadow nobody budgeted',
        );
      }
    }
  }
}

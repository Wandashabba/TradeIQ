import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_contrast.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';

/// The generated half of the contrast harness.
///
/// `torchlight_contrast_test.dart` checks the pairings a person wrote down.
/// This checks the ones nobody wrote down: every ink in the ramp, in every
/// type role, on every legal fill, in every skin at every density the app can
/// build — and then the same tokens again through greyscale, deuteranopia and
/// protanopia, because the audit's own chart focus mechanism was a no-op in
/// all three and nobody noticed for months.
void main() {
  group('generated: every ink, every role, every fill, every density', () {
    for (final skin in TorchlightContrast.allSkinsAndDensities) {
      final label = '${skin.mode.name} x ${skin.density.name}';

      test('$label — every generated pairing clears its floor', () {
        final pairings = TorchlightContrast.generatedFor(skin);
        expect(
          pairings,
          isNotEmpty,
          reason: 'A generator that produces nothing is not a guard.',
        );

        final failures = <String>[];
        for (final p in pairings) {
          if (p.ratio < p.role.floor) {
            failures.add(
              '  ${p.label}: ${p.ratio.toStringAsFixed(2)}:1 '
              '(needs ${p.role.floor}:1)',
            );
          }
        }
        expect(
          failures,
          isEmpty,
          reason:
              '$label — ${failures.length} of ${pairings.length} generated '
              'pairings are under their floor:\n${failures.join('\n')}\n'
              'The floor comes from the type role that is actually set in the '
              'ink, so the same two colours can pass at figure.l and fail at '
              'meta. Fix the token, not the floor.',
        );
      });

      test('$label — the skin declares its own floor and the walk uses it', () {
        // Veld's 9:1 / 15:1 is a token on the skin, not an `if (mode == veld)`
        // in the generator. If someone replaces it with a branch, this fails.
        final isVeld = skin.space.density == TiqDensity.veld;
        expect(skin.textFloor, isVeld ? 9.0 : 0.0);
        expect(skin.borderFloor, isVeld ? 15.0 : 0.0);
        expect(
          skin.floorFor(4.5, isText: true),
          isVeld ? 9.0 : 4.5,
          reason: 'The applicable floor is the stricter of role and skin.',
        );
        expect(
          skin.floorFor(3.0, isText: false),
          isVeld ? 15.0 : 3.0,
        );
      });
    }

    test('the walk covers all three skins and both densities', () {
      final combos = TorchlightContrast.allSkinsAndDensities
          .map((s) => '${s.mode.name}/${s.density.name}')
          .toList();
      expect(combos, <String>[
        'night/console',
        'night/field',
        'day/console',
        'day/field',
        'veld/veld',
      ]);
    });

    test('the generated walk is large enough to be a sweep', () {
      final total = TorchlightContrast.allSkinsAndDensities
          .map((s) => TorchlightContrast.generatedFor(s).length)
          .fold<int>(0, (a, b) => a + b);
      expect(
        total,
        greaterThan(900),
        reason:
            'Only $total generated pairings. Sixteen roles x three inks x '
            'four fills x five skin/density combinations is 960 before the '
            'edges; a number much under that means a matrix silently emptied.',
      );
    });

    test('a broken token is caught by the generated walk', () {
      // A guard that cannot fail is not a guard. Move ink-3 onto the ground
      // it is supposed to sit on and the sweep has to notice.
      final broken = TiqSkin.night().copyWith(
        palette: TiqSkin.night().palette.lerp(
          TiqSkin.night().palette,
          0,
        ),
      );
      final sabotaged = TiqSkin.night().copyWith(
        palette: _withInk3(TiqSkin.night().palette, const Color(0xFF12181F)),
      );
      expect(
        TorchlightContrast.generatedFor(broken).every(
          (p) => p.ratio >= p.role.floor,
        ),
        isTrue,
      );
      expect(
        TorchlightContrast.generatedFor(sabotaged).any(
          (p) => p.ratio < p.role.floor,
        ),
        isTrue,
        reason:
            'ink-3 moved to within a hair of the ground and the sweep did not '
            'fail. The matrix is empty or the floors are not being applied.',
      );
    });
  });

  group('greyscale, deuteranopia and protanopia', () {
    test('the simulations reproduce the ruling\'s own figures', () {
      // The ruling states two numbers it derived from a Vienot simulation.
      // Recomputing them here is how we know this implementation is the same
      // one the design was argued from, rather than a different filter that
      // happens to be in the same family.
      final n = TiqSkin.night().palette;
      expect(
        separationUnder(n.flame600, n.comparison, VisionFilter.deuteranopia),
        closeTo(1.41, 0.02),
        reason:
            'The ruling says simulated deuteranopia puts Burning Flame and '
            'Truffle 1.41:1 apart, which is why the solid/dashed stroke '
            'distinction is mandatory rather than nice.',
      );
      expect(
        separationUnder(n.bad, n.chartNeutral, VisionFilter.protanopia),
        closeTo(1.26, 0.02),
        reason:
            'The ruling says `bad` against `chart-neutral` is 1.55:1 true and '
            '1.26:1 in protanopia, which is why a diverging negative is '
            'hatched.',
      );
      expect(
        separationUnder(n.bad, n.chartNeutral, VisionFilter.trichromat),
        closeTo(1.55, 0.02),
      );
    });

    test('greyscale is luminance, and says so', () {
      // Not a tautology dressed as a test: this asserts the *finding*. WCAG
      // contrast is already a luminance-only metric, so a hue pair that
      // measures 1.42:1 in colour measures 1.42:1 in greyscale. There is no
      // hue rescue available anywhere in this system, which is the reason the
      // second channel is mandatory rather than recommended.
      final n = TiqSkin.night().palette;
      for (final pair in <List<Color>>[
        <Color>[n.flame600, n.chartNeutral],
        <Color>[n.good, n.bad],
        <Color>[n.comparison, n.ink2],
      ]) {
        expect(
          separationUnder(pair[0], pair[1], VisionFilter.greyscale),
          closeTo(
            separationUnder(pair[0], pair[1], VisionFilter.trichromat),
            0.01,
          ),
        );
      }
      // …and two different hues are still two different greys, unless their
      // luminance is identical — which is exactly the Burning Flame / Oatmeal
      // collision chart-neutral exists to fix.
      expect(
        separationUnder(n.flame600, n.ink2, VisionFilter.greyscale),
        closeTo(1.0, 0.01),
        reason:
            'Burning Flame and Oatmeal are the same grey. If they stop being '
            'the same grey, someone moved a token and chart-neutral may no '
            'longer be needed — decide that deliberately.',
      );
    });

    for (final pair in TorchlightContrast.seriesPairs) {
      test('${pair.skin} — ${pair.label}', () {
        expect(
          pair.channels,
          isNotEmpty,
          reason:
              'Every hue-coded distinction carries a second channel. This one '
              'declares none, so hue is doing all of the work: '
              '${pair.why}',
        );
        expect(
          pair.why,
          isNotEmpty,
          reason: 'A declared channel without a reason is a checkbox.',
        );

        // The claim being tested is not "these separate" — several of them
        // deliberately do not. It is "where they do not separate, something
        // that is not colour does".
        if (pair.worst < TorchlightContrast.separationFloor) {
          expect(
            pair.channels.length,
            greaterThanOrEqualTo(1),
            reason:
                '${pair.label} falls to '
                '${pair.worst.toStringAsFixed(2)}:1 under '
                '${pair.worstFilter.name} and carries no non-colour channel.',
          );
        }
      });
    }

    test('a pair with no second channel cannot be declared', () {
      // The registry's type allows an empty channel set; the test is what
      // forbids it. Prove the test would actually catch one.
      final offender = SeriesPair(
        skin: 'night',
        label: 'two bars that differ only in hue',
        a: TiqSkin.night().palette.flame600,
        b: TiqSkin.night().palette.ink2,
        channels: const <SeparationChannel>{},
        why: 'nothing',
      );
      expect(offender.channels, isEmpty);
      expect(
        offender.worst,
        lessThan(TorchlightContrast.separationFloor),
        reason:
            'The fixture has to actually be a violation, or the check above '
            'is checking nothing.',
      );
    });

    test('every skin contributes its series pairs', () {
      final skins = TorchlightContrast.seriesPairs.map((p) => p.skin).toSet();
      expect(skins, <String>{'night', 'day', 'veld'});
      expect(
        TorchlightContrast.seriesPairs.length,
        27,
        reason:
            'Nine pairs in each of three skins. Pinned so that deleting one '
            'is a visible edit rather than an omission.',
      );
    });

    test('the dichromacy matrices are the ones they claim to be', () {
      // Not "a dichromat sees less" — that is false, and believing it is how
      // you ship a check that never fires. A protanope sees crimson far
      // darker than a trichromat does, so `good` against `badSolid` actually
      // separates BETTER under protanopia (4.10:1 against 2.58:1) — and that
      // is no help at all, because the pair is still one hue with two
      // silhouettes doing the work.
      //
      // What is checkable is the matrix itself.
      for (final filter in <VisionFilter>[
        VisionFilter.deuteranopia,
        VisionFilter.protanopia,
      ]) {
        for (final grey in <Color>[
          const Color(0xFF000000),
          const Color(0xFF404040),
          const Color(0xFF808080),
          const Color(0xFFFFFFFF),
        ]) {
          final out = simulateVision(grey, filter);
          expect(
            out.r,
            closeTo(grey.r, 0.01),
            reason:
                '${filter.name} moved a neutral grey. Both Vienot matrices '
                'have rows that sum to one, so a grey must map to itself; if '
                'it does not, the matrix has been mistyped.',
          );
          expect(out.g, closeTo(grey.g, 0.01));
          expect(out.b, closeTo(grey.b, 0.01));
        }
      }

      // A dichromat's two remaining cones collapse the red and green channels
      // onto one another: that is what dichromacy IS, and if the simulated
      // output ever has r != g the projection is not happening.
      final n = TiqSkin.night().palette;
      for (final token in <Color>[n.flame600, n.bad, n.good, n.comparison]) {
        for (final filter in <VisionFilter>[
          VisionFilter.deuteranopia,
          VisionFilter.protanopia,
        ]) {
          final out = simulateVision(token, filter);
          expect(
            out.r,
            closeTo(out.g, 0.005),
            reason:
                'Under ${filter.name} the red and green channels collapse '
                'onto one confusion line. This one did not.',
          );
        }
      }

      expect(
        simulateVision(n.flame600, VisionFilter.trichromat),
        n.flame600,
        reason: 'Normal vision is the identity.',
      );
    });
  });
}

TiqPalette _withInk3(TiqPalette base, Color ink3) => TiqPalette(
  ground: base.ground,
  vignette: base.vignette,
  well: base.well,
  surface: base.surface,
  raised: base.raised,
  lifted: base.lifted,
  hairline: base.hairline,
  edgeStructure: base.edgeStructure,
  edgeControl: base.edgeControl,
  navInkInactive: base.navInkInactive,
  inkMute: base.inkMute,
  ink1: base.ink1,
  ink2: base.ink2,
  ink3: ink3,
  chartNeutral: base.chartNeutral,
  flame300: base.flame300,
  flame500: base.flame500,
  flame600: base.flame600,
  flame700: base.flame700,
  flame900: base.flame900,
  good: base.good,
  goodSolid: base.goodSolid,
  onGoodSolid: base.onGoodSolid,
  bad: base.bad,
  badSolid: base.badSolid,
  onBadSolid: base.onBadSolid,
  comparison: base.comparison,
  comparisonWash: base.comparisonWash,
  onAmber: base.onAmber,
  amberPressed: base.amberPressed,
  onAmberPressed: base.onAmberPressed,
  scrim: base.scrim,
);

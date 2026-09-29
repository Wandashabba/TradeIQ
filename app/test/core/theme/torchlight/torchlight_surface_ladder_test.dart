import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_contrast.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';

/// THE NIGHT SURFACE LADDER IS ONE WASH, AND THIS IS THE PROOF.
///
/// The owner looked at The Floor in the dark theme on 29 September 2026 and
/// said the cards were *"this blue everywhere"* against the approved
/// artifact's grey. They were: the ladder was four separately chosen navies
/// whose blue cast climbed as they got lighter, so a card was not a lit
/// version of the ground but a bluer one.
///
/// It is derived now — `ink1` over `ground` at four declared alphas, two of
/// them the artifact's own — and that is a claim a test can hold. Without this
/// file the four hexes are once again four hexes, and the next person to nudge
/// one has nothing telling them what family it belongs to.
void main() {
  final night = TiqSkin.night().palette;

  group('the Night ladder is ink-1 washed over the ground', () {
    final tiers = <String, Color>{
      'well': night.well,
      'surface': night.surface,
      'raised': night.raised,
      'lifted': night.lifted,
    };

    for (final MapEntry(key: name, value: tier) in tiers.entries) {
      test('$name is bone at ${TiqPalette.nightSurfaceAlpha[name]}', () {
        final alpha = TiqPalette.nightSurfaceAlpha[name];
        expect(
          alpha,
          isNotNull,
          reason: 'Every tier declares the alpha it was washed at.',
        );
        expect(
          tier,
          TiqPalette.nightWash(alpha!),
          reason:
              '$name is ${_hex(tier)} but bone #EEE9DF over #0B1017 at $alpha '
              'is ${_hex(TiqPalette.nightWash(alpha))}. Either the hex was '
              'hand-edited or the alpha was — the ladder is one wash at four '
              'strengths and a tier that is not on the line does not belong '
              'to it.',
        );
      });
    }

    test('the two tiers a card is painted in are the artifact\'s own', () {
      // Not a round number somebody liked: the approved artifact's soft row is
      // `rgba(238,233,223,0.055)` and its lead row `0.085`. If these move, the
      // app has stopped matching the design rather than been retuned.
      expect(TiqPalette.nightSurfaceAlpha['surface'], 0.055);
      expect(TiqPalette.nightSurfaceAlpha['raised'], 0.085);
    });

    test('the alphas rise with the ladder', () {
      final order = <String>['well', 'surface', 'raised', 'lifted'];
      final alphas = order
          .map((n) => TiqPalette.nightSurfaceAlpha[n]!)
          .toList();
      for (var i = 0; i < alphas.length - 1; i++) {
        expect(
          alphas[i + 1],
          greaterThan(alphas[i]),
          reason:
              '${order[i + 1]} must carry more light than ${order[i]}. The '
              'ordering is the ladder; the alphas are only how it is built.',
        );
      }
    });

    test('every tier stays warm-neutral, like the artifact it came from', () {
      // The defect this replaced, as a number. Blue cast is B−R: the artifact
      // holds 9–11 across every surface it draws and the old ladder ran 19 /
      // 23 / 28 / 33, climbing as the surface got lighter. A tier that drifts
      // back over 12 has started being a colour again instead of the ground
      // with more light on it.
      for (final MapEntry(key: name, value: tier) in tiers.entries) {
        final cast = (tier.b * 255).round() - (tier.r * 255).round();
        expect(
          cast,
          lessThanOrEqualTo(12),
          reason:
              '$name ${_hex(tier)} has a blue cast of $cast. This is the '
              '"blue everywhere" the recast removed.',
        );
      }
    });

    test('the ground and the vignette did not move', () {
      // They are the letterbox falloff's own stops and they already matched
      // the artifact's `--abyss-deep` / `--abyss`. The recast was of the
      // cards, not of the room.
      expect(night.ground, const Color(0xFF0B1017));
      expect(night.vignette, const Color(0xFF0F1620));
    });

    test('Day is untouched by any of it', () {
      // The owner said "this is on the dark theme". Paper's ladder is a
      // different problem with a different answer and it was not asked about.
      final day = TiqSkin.day().palette;
      expect(day.well, const Color(0xFFE2DBCC));
      expect(day.surface, const Color(0xFFFAF7F2));
      expect(day.raised, const Color(0xFFF4F0E8));
      expect(day.lifted, const Color(0xFF2C3B4D));
    });
  });

  group('what the recast cost, measured rather than assumed', () {
    test('every tier got darker, so nothing set on one got harder', () {
      // The direction of the whole change in one assertion: the new ladder is
      // below the old one at every tier, which is why all 25 declared Night
      // pairings that moved moved UP. If a tier ever gets lighter than the
      // navy it replaced, some ink somewhere lost margin and the table in
      // `torchlight_contrast_test.dart` has to be re-read rather than
      // regenerated.
      const before = <String, Color>{
        'well': Color(0xFF141D27),
        'surface': Color(0xFF1B2632),
        'raised': Color(0xFF22303E),
        'lifted': Color(0xFF2C3B4D),
      };
      final after = <String, Color>{
        'well': night.well,
        'surface': night.surface,
        'raised': night.raised,
        'lifted': night.lifted,
      };
      for (final MapEntry(key: name, value: old) in before.entries) {
        expect(
          relativeLuminance(after[name]!),
          lessThan(relativeLuminance(old)),
          reason: '$name is no longer darker than the navy it replaced.',
        );
      }
    });

    test('the fill steps shrank, and the rule that survives says so', () {
      // WHAT THE OWNER IS BUYING, STATED AS ARITHMETIC. Anchoring `surface` on
      // the artifact's 0.055 means the whole span from ground to surface is
      // 1.11:1, so the tiers below `raised` are necessarily closer together
      // than they were: 1.12 / 1.11 / 1.14 / 1.18 became 1.06 / 1.05 / 1.07 /
      // 1.11.
      //
      // §2 already refuses to treat a step in this range as a cue — "a
      // 1.12–1.24:1 fill step is one or two quantisation levels on a budget
      // LCD in sunlight" — and the rule it states instead is unchanged:
      // nothing is identified by a fill step alone and every perceivable
      // boundary carries a real edge. This test pins the fact rather than the
      // comfort: the steps ARE small, they are meant to be, and a future agent
      // who "fixes" them by lightening a tier is undoing the owner's note.
      final ladder = <Color>[
        night.ground,
        night.well,
        night.surface,
        night.raised,
        night.lifted,
      ];
      for (var i = 0; i < ladder.length - 1; i++) {
        final step = contrastRatio(ladder[i], ladder[i + 1]);
        expect(
          step,
          greaterThan(1.0),
          reason: 'Tier $i and ${i + 1} are the same fill.',
        );
        expect(
          step,
          lessThan(1.2),
          reason:
              'A fill step of ${step.toStringAsFixed(3)} is big enough that '
              'somebody will start relying on it. The ladder is a wash, not a '
              'set of distinguishable surfaces — the edge is what separates '
              'two regions.',
        );
      }
    });

    test('the exempt pairings are still quiet', () {
      // The recast pushed every light ink UP against these fills, and an
      // "exempt" token that drifts over 3:1 is a token doing the wrong job.
      // `torchlight_contrast_test` asserts the floor; this asserts the
      // direction the recast could have broken it from.
      expect(contrastRatio(night.inkMute, night.surface), lessThan(3.0));
      expect(contrastRatio(night.hairline, night.surface), lessThan(3.0));
      expect(contrastRatio(night.hairline, night.raised), lessThan(3.0));
      expect(contrastRatio(night.hairline, night.lifted), lessThan(3.0));
    });
  });
}

String _hex(Color c) {
  String b(double v) =>
      (v * 255).round().toRadixString(16).toUpperCase().padLeft(2, '0');
  return '#${b(c.r)}${b(c.g)}${b(c.b)}';
}

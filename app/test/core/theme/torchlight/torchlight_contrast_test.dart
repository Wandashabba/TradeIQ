import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_contrast.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';

/// The contrast contract, over the real tokens, in all three skins.
///
/// Every ratio here is RECOMPUTED from the palette. Nothing is asserted
/// against a number copied out of the design document — that is how a
/// contrast table ends up describing a palette that changed six months ago.
/// Where the spec stated a ratio, the computed value is checked against it to
/// the second decimal, so a wrong claim in the spec fails here too.
void main() {
  group('declared pairings meet their floor', () {
    for (final pairing in TorchlightContrast.declared) {
      test('${pairing.skin} — ${pairing.label}', () {
        final ratio = pairing.ratio;
        if (pairing.role == ContrastRole.exempt) {
          // An exempt pairing still has to be declared exempt WITH a reason,
          // and it has to actually be the quiet thing it claims to be — an
          // "exempt" pairing at 9:1 is a token being used for the wrong job.
          expect(
            pairing.note,
            isNotNull,
            reason: 'An exemption without a written reason is an excuse.',
          );
          expect(
            ratio,
            lessThan(3.0),
            reason:
                '${pairing.label} is ${ratio.toStringAsFixed(2)}:1 — that is '
                'not decorative, it is a real edge. Give it a real role.',
          );
          return;
        }
        expect(
          ratio,
          greaterThanOrEqualTo(pairing.role.floor),
          reason:
              '${pairing.skin} ${pairing.label} is ${ratio.toStringAsFixed(2)}'
              ':1, below the ${pairing.role.floor}:1 floor for a '
              '${pairing.role.name} pairing. Fix the token, not the floor.',
        );
      });
    }

    test('the table covers both skins and the plate', () {
      final skins = TorchlightContrast.declared.map((p) => p.skin).toSet();
      expect(skins, containsAll(<String>['night', 'day', 'plate']));
      expect(TorchlightContrast.declared.length, greaterThan(40));
    });

    test('every ground a coloured figure can land on is declared', () {
      // THE RULE THE SEMANTIC-FIGURE COLOUR NEEDS, AS A TEST RATHER THAN AS A
      // HABIT. `good` and `bad` are real ink now — a score against its
      // target, an availability against the published standard, the figure on
      // a decision row — so every fill a figure is ever set on has to appear
      // against both of them in this table, by hand, with a label somebody
      // wrote. The generated sweep in `torchlight_generated_contrast_test`
      // walks the same matrix; this is the half that carries the reasons.
      final labels = TorchlightContrast.declared
          .map((p) => '${p.skin} ${p.label}')
          .toSet();
      for (final skin in <String>['night', 'day']) {
        for (final token in <String>['good', 'bad']) {
          final grounds = labels.where(
            (l) => l.startsWith('$skin $token on '),
          );
          expect(
            grounds,
            isNotEmpty,
            reason: '$skin $token is set on no declared ground at all.',
          );
        }
      }
    });
  });

  group('banned pairings are banned, and stay banned', () {
    for (final ban in TorchlightContrast.banned) {
      test('${ban.skin} — ${ban.label}', () {
        // The ban has to be justified by the arithmetic. If a token moves and
        // this pairing quietly becomes legal, the ban is folklore and this
        // test says so rather than letting it rot in a document.
        expect(
          ban.ratio,
          lessThan(ban.wouldNeed.floor),
          reason:
              '${ban.label} now measures ${ban.ratio.toStringAsFixed(2)}:1, '
              'which clears the ${ban.wouldNeed.floor}:1 it would need. '
              'Either a token moved and the ban should be lifted deliberately, '
              'or the ban is on the wrong pairing.',
        );
        expect(
          ban.instead,
          isNotEmpty,
          reason: 'A ban without a replacement is a dead end.',
        );
      });
    }

    test('every banned pairing is listed, and there are four of them', () {
      // Pinned so that deleting a ban is a visible edit, not an omission.
      expect(
        TorchlightContrast.banned.map((b) => b.label).toList(),
        <String>[
          'flame-600 and ink-2 (Oatmeal) as adjacent bar fills',
          'flame-900 ink on a pressed flame-500 block',
          'flame-600 as text on the Palladian ground',
          'edge-structure on the Day well',
        ],
      );
    });

    test('no skin puts a banned pairing in its own defaults', () {
      // The bans are only worth having if the token source itself obeys them.
      for (final skin in <TiqSkin>[
        TiqSkin.night(),
        TiqSkin.day(),
      ]) {
        final p = skin.palette;
        expect(
          p.onAmberPressed,
          isNot(p.flame900),
          reason:
              '${skin.mode.name}: the pressed amber block must keep dark ink. '
              'flame-900 on flame-500 is 2.00:1 — the label vanishes at the '
              'moment of commitment.',
        );
        expect(
          skin.onFill(p.flame600),
          p.onAmber,
          reason: '${skin.mode.name}: ink on amber comes from one token.',
        );
        if (skin.amberIsInk) {
          // On light grounds amber is an ink-CARRIER. It may not be ink.
          expect(
            <Color>[p.ink1, p.ink2, p.ink3, p.onAmber],
            isNot(contains(p.flame600)),
            reason:
                '${skin.mode.name}: Burning Flame as text on a light ground is '
                '${contrastRatio(p.flame600, p.ground).toStringAsFixed(2)}:1. '
                'flame-300 is the only legal amber text there.',
          );
        }
      }
    });
  });

  group('the amber law holds in the token values', () {
    test('there is no amber severity token in any skin', () {
      for (final skin in <TiqSkin>[
        TiqSkin.night(),
        TiqSkin.day(),
      ]) {
        final p = skin.palette;
        final ambers = <Color>{
          p.flame300,
          p.flame500,
          p.flame600,
          p.flame700,
          p.flame900,
        };
        for (final MapEntry(key: name, value: severity) in <String, Color>{
          'good': p.good,
          'goodSolid': p.goodSolid,
          'bad': p.bad,
          'badSolid': p.badSolid,
        }.entries) {
          expect(
            ambers,
            isNot(contains(severity)),
            reason:
                '${skin.mode.name}.$name is an amber. Severity abandons '
                "amber's hue band entirely — there is no amber warning in "
                'TradeIQ.',
          );
        }
      }
    });

    test('the comparison series is never a severity', () {
      for (final skin in <TiqSkin>[TiqSkin.night(), TiqSkin.day()]) {
        final p = skin.palette;
        expect(p.comparison, isNot(p.bad));
        expect(p.comparison, isNot(p.badSolid));
        expect(
          p.comparison,
          isNot(p.good),
          reason:
              'Truffle is the competitor, the prior period, the benchmark — '
              'never a verdict.',
        );
      }
    });

    test('the focus channel on a light ground is ink, not amber', () {
      for (final skin in <TiqSkin>[TiqSkin.day()]) {
        final p = skin.palette;
        // The ranked-bar focus fill on a light ground is ink-1 on the track.
        final focus = contrastRatio(p.ink1, p.well);
        expect(
          focus,
          greaterThanOrEqualTo(3.0),
          reason:
              '${skin.mode.name}: the ink focus bar is only '
              '${focus.toStringAsFixed(2)}:1 on its track.',
        );
      }
    });
  });

  group('skin-wide floors', () {
    test('Night casts no shadow; Day casts exactly three', () {
      expect(
        TiqSkin.night().depth.shadows,
        isEmpty,
        reason:
            'Black on black is invisible. Night builds depth from an edge and '
            'a rim, never a drop shadow.',
      );
      expect(TiqSkin.day().depth.shadows, hasLength(3));
    });

    test('the ink ramp steps down in every skin', () {
      for (final skin in <TiqSkin>[TiqSkin.night(), TiqSkin.day()]) {
        final p = skin.palette;
        final i1 = contrastRatio(p.ink1, p.ground);
        final i2 = contrastRatio(p.ink2, p.ground);
        final i3 = contrastRatio(p.ink3, p.ground);
        final mute = contrastRatio(p.inkMute, p.ground);
        expect(i1, greaterThan(i2), reason: '${skin.mode.name} ink1 vs ink2');
        expect(i2, greaterThan(i3), reason: '${skin.mode.name} ink2 vs ink3');
        expect(
          i3,
          greaterThan(mute),
          reason:
              '${skin.mode.name}: disabled ink has to be quieter than meta, '
              'or a disabled control does not look disabled.',
        );
      }
    });

    test('a control edge outranks a container edge', () {
      for (final skin in <TiqSkin>[TiqSkin.night(), TiqSkin.day()]) {
        final p = skin.palette;
        expect(
          contrastRatio(p.edgeControl, p.ground),
          greaterThan(contrastRatio(p.edgeStructure, p.ground)),
          reason:
              '${skin.mode.name}: controls outrank containers, on purpose.',
        );
      }
    });
  });

  group('the spec\'s stated ratios, recomputed', () {
    // Every ratio the design document claims, checked against the tokens that
    // shipped. All 63 recomputed exactly; this is the assertion that keeps
    // them that way.
    const claims = <String, double>{
      'night ink-1 on ground': 15.77,
      'night ink-1 on surface': 14.16,
      'night ink-1 on raised': 13.20,
      'night ink-2 on ground': 10.67,
      'night ink-2 on surface': 9.58,
      'night ink-3 (11px meta) on ground': 7.19,
      'night ink-3 (11px meta) on raised — the binding case': 6.02,
      'night hero figure flame-600 on ground': 10.65,
      'night amber text flame-700 on ground': 12.92,
      'night focus ring flame-700 on surface': 11.60,
      'night focus ring flame-700 on raised': 10.82,
      'night amber rim flame-600 on raised': 8.91,
      'night active-tab underbar flame-600 on nav body (well)': 10.05,
      'night focus bar flame-600 on chart track (lifted)': 8.06,
      'night neutral bar chart-neutral on chart track (lifted)': 5.09,
      'night good on ground': 11.76,
      'night good on raised': 9.85,
      'night bad on ground': 7.78,
      'night bad on raised': 6.51,
      'night bad on well': 7.34,
      'night comparison on ground': 7.52,
      'night comparison on raised': 6.30,
      'night edge-control on ground': 6.02,
      'night edge-control on surface': 5.41,
      'night edge-control on raised': 5.04,
      'night edge-structure on surface — the Panel outline': 3.41,
      'night edge-structure on ground': 3.79,
      'night nav ink inactive on nav body (well)': 6.69,
      'night ink on amber block': 10.65,
      'night ink on pressed amber block (flame-500)': 8.59,
      'night decorative hairline on ground': 2.14,
      'night disabled ink-mute on surface': 2.66,
      // THE CEILING IS PER SKIN SINCE 29 SEPTEMBER 2026, and it moved. Night
      // was 7.68:1 against #474747; the owner asked for the pictures to be
      // luminous, the ceiling went to #666666, and this is what that costs —
      // 4.75:1, which still clears the 4.5 a text pairing needs and has very
      // little left over. Any further lift of the Night ceiling has to be
      // argued against this line, not against a screenshot.
      'plate night ink-1 on an unscrimmed plate pixel at the ceiling': 4.75,
      'plate day ink-1 on an unscrimmed plate pixel at the ceiling': 12.28,
      'plate ink-1 on the mandatory scrim over a full-value strip light': 10.56,
      'plate ink-2 eyebrow on that same worst-case scrimmed amber': 7.15,
      'day ink-1 on ground': 12.67,
      'day ink-1 on card (surface)': 14.34,
      'day ink-2 on ground': 7.99,
      'day ink-3 (11px meta) on ground': 5.15,
      'day ink-3 on well — the darkest Day surface': 4.52,
      'day flame-300, the one legal amber text on a light ground': 5.66,
      'day ink on the one amber block': 8.55,
      'day good on ground': 5.73,
      'day bad on ground': 7.52,
      'day comparison on ground': 4.58,
      'day edge-control on ground': 4.69,
      'day edge-structure on ground — the Panel outline': 3.41,
      'day neutral bar on chart track (well)': 5.29,
      'day focus bar ink-1 on chart track (well)': 11.12,
      'day nav-active: ground ink on the lifted block': 9.43,
      'day decorative hairline on ground': 1.18,
      // ── The semantic-figure colour, 28 September 2026 ──────────────
      //
      // "On this theme we need to add the colours of green red and some
      // colours on the numbers and graphs that make sense." Every pairing
      // that change created, recomputed here so the owner's note has an
      // arithmetic record rather than a screenshot.
      'night good on surface — a coloured figure on a card': 10.57,
      'night bad on surface — a coloured figure on a card': 6.99,
      'night critical mark badSolid on surface — the row dot': 4.09,
      'night subject run ink-1 on the card it is plotted in (surface)': 14.16,
      'night good run on the card it is plotted in (surface)': 10.57,
      'night bad run on the card it is plotted in (surface)': 6.99,
      'day good on card (surface) — a coloured figure on a card': 6.49,
      'day good on well — the darkest Day fill a figure sits on': 5.03,
      'day bad on card (surface) — a coloured figure on a card': 8.51,
      'day bad on well': 6.60,
      'day critical mark badSolid on ground — the row dot, as red': 5.74,
      'day critical mark badSolid on card (surface)': 6.50,
      'day subject run ink-1 on the card it is plotted in (surface)': 14.34,
      'day good run on the card it is plotted in (surface)': 6.49,
      'day bad run on the card it is plotted in (surface)': 8.51,
      'day target rule ink-2 on the card it is plotted in (surface)': 9.04,
      'day ink on solid critical block': 6.95,
      'plate night hero good on the darkest scrimmed plate pixel': 12.02,
      'plate night hero bad on the darkest scrimmed plate pixel': 7.95,
      'plate day hero good on the darkest scrimmed plate pixel': 3.60,
      'plate day hero bad on the darkest scrimmed plate pixel': 4.72,
      'plate day hero delta bad at 13px on the darkest scrimmed plate pixel':
          4.72,
    };

    final measured = <String, double>{
      for (final p in TorchlightContrast.declared)
        '${p.skin} ${p.label}': p.ratio,
    };

    for (final MapEntry(key: label, value: claimed) in claims.entries) {
      test('$label is $claimed:1', () {
        final actual = measured[label];
        expect(
          actual,
          isNotNull,
          reason: 'No declared pairing named "$label".',
        );
        expect(
          actual!,
          closeTo(claimed, 0.005),
          reason:
              '$label measures ${actual.toStringAsFixed(4)}:1, not $claimed:1. '
              'Either a token moved or the claim was wrong — fix whichever it '
              'is and say which in the PR.',
        );
      });
    }

    test('the banned pairings measure what the ban claims', () {
      final banRatios = {
        for (final b in TorchlightContrast.banned)
          '${b.skin} ${b.label}': b.ratio,
      };
      expect(
        banRatios['night flame-600 and ink-2 (Oatmeal) as adjacent bar fills'],
        closeTo(1.00, 0.005),
        reason: 'This 1.00:1 is the entire reason chart-neutral exists.',
      );
      expect(
        banRatios['night flame-900 ink on a pressed flame-500 block'],
        closeTo(2.00, 0.005),
      );
      expect(
        banRatios['day flame-600 as text on the Palladian ground'],
        closeTo(1.48, 0.005),
      );
      expect(
        banRatios['day edge-structure on the Day well'],
        closeTo(2.99, 0.005),
      );
    });
  });

  group('data separation survives the channels hue does not', () {
    // Greyscale, deuteranopia and protanopia, because the audit's own focus
    // mechanism was a no-op in all three and nobody noticed for months.
    double luminanceSeparation(Color a, Color b) => contrastRatio(
      _greyscale(a),
      _greyscale(b),
    );

    test('the focus bar separates from the neutral bar in greyscale', () {
      final p = TiqSkin.night().palette;
      final grey = luminanceSeparation(p.flame600, p.chartNeutral);
      expect(
        grey,
        greaterThan(1.4),
        reason:
            'Focus/neutral separation in greyscale is '
            '${grey.toStringAsFixed(2)}:1. It carries shape, weight and a '
            'leading marker as well — but if this drops to 1.0 the amber bar '
            'is literally its neighbour again.',
      );
      // THE TRADE, RECORDED. Phase 1 moved chart-neutral from #8B8271 to
      // #A39887 (unify §1.4) because the old value measured 3.01:1 against its
      // own track — the product's most-drawn graphic sitting on the AA floor
      // with 0.01 of margin. It now measures 5.09:1 there (4.02:1 until the
      // Night ladder was recast warm-neutral and the track went darker
      // with it), and the price was
      // this number: the neutral moved *up* the luminance range, towards the
      // focus amber, and the greyscale separation between the two fell from
      // 2.42:1 to 1.58:1.
      //
      // That is affordable here and nowhere else. The focus bar carries four
      // channels — an amber fill, a gradient bloom, a leading triangle marker
      // and a heavier label — and the hue is the third of them. The track
      // carries one channel, which is the fill against the track, and a
      // graphic on the floor with no margin is a graphic that disappears on a
      // 6-bit panel at 40% backlight. One of the two had to give and it was
      // the one with three spares.
      expect(
        grey,
        lessThan(2.42),
        reason:
            'This is the old value. If the separation is back above it, '
            'chart-neutral has been reverted to #8B8271 and every neutral bar '
            'in the product is back on the AA floor.',
      );
    });

    test('the old Burning Flame / Oatmeal pair is the same bar', () {
      final p = TiqSkin.night().palette;
      expect(
        luminanceSeparation(p.flame600, p.ink2),
        closeTo(1.0, 0.02),
        reason:
            'This is the collision chart-neutral was introduced to fix. If it '
            'ever stops being ~1.0 someone moved Oatmeal.',
      );
    });
  });

  /// WCAG 1.4.3'S LARGE-TEXT BOUNDARY, AS A GUARD RATHER THAN A HOPE.
  ///
  /// `TorchlightContrast._roleContrast` derives each role's floor from the
  /// role's own size and weight: 3:1 for large text — 24px, or 18.66px at w600
  /// and above — and 4.5:1 for everything else. **A type-size change can
  /// therefore move a contrast floor without a single colour moving**, and the
  /// generated sweep would only notice if the ratio happened to fall between
  /// the two floors. That is the quietest way this palette can break.
  ///
  /// It nearly did on 1 October 2026. The prose reduction multiplied every
  /// prose role by 13/14, which puts `title.l` at 18.57 — **0.09px under the
  /// boundary.** Rounding it down to 18 would have moved every `title.l`
  /// pairing in the sweep from 3:1 to 4.5:1 silently; it is 19 instead, and
  /// this is where that decision is enforced rather than remembered.
  /// `display.s` lands on 24.14 → 24 and holds its class with nothing to
  /// spare, which is why it may not be rounded down either.
  group('the large-text boundary', () {
    /// Role name → the class it must resolve to. Every role in the scale, so
    /// adding one without deciding its contrast class fails here.
    const classes = <String, String>{
      'hero.figure': 'large',
      'hero.figure.compact': 'large',
      'display': 'large',
      'display.m': 'large',
      'display.s': 'large',
      'figure.l': 'large',
      'figure.m': 'large',
      'figure.s': 'text',
      'title.l': 'large',
      'title.m': 'text',
      'headline.answer': 'large',
      'body': 'text',
      'body.strong': 'text',
      'label': 'text',
      'eyebrow': 'text',
      'meta': 'text',
      'axis.label': 'text',
      'mono.ident': 'text',
    };

    /// The rule, restated here rather than reached for, so this test fails if
    /// the production derivation drifts from WCAG rather than agreeing with
    /// its own bug.
    bool isLarge(TiqTypeToken t) =>
        t.size >= 24 ||
        (t.size >= 18.66 && t.weight.value >= FontWeight.w600.value);

    test('every role resolves to the contrast class it is listed under', () {
      final skin = TiqSkin.night();
      expect(
        skin.text.all.map((t) => t.name).toSet(),
        classes.keys.toSet(),
        reason:
            'A role was added or renamed without deciding whether it is large '
            'text. That decision is a contrast floor, not a detail.',
      );
      final wrong = <String>[];
      for (final t in skin.text.all) {
        final actual = isLarge(t) ? 'large' : 'text';
        if (actual != classes[t.name]) {
          wrong.add(
            '  ${t.name}: ${t.size}/w${t.weight.value} is $actual, listed as '
            '${classes[t.name]}',
          );
        }
      }
      expect(
        wrong,
        isEmpty,
        reason:
            'A type size moved across WCAG 1.4.3\'s large-text boundary, which '
            'moves a contrast FLOOR with no colour changing:\n'
            '${wrong.join('\n')}\n'
            'If the move is intended, change the list above AND re-run the '
            'generated sweep, because every pairing in that role just took a '
            'different floor.',
      );
    });

    test('the production derivation agrees with the rule', () {
      // `_roleContrast` is private, so it is checked through the thing it
      // decides: the floor on a generated pairing.
      final skin = TiqSkin.night();
      final byRole = <String, double>{};
      for (final p in TorchlightContrast.generatedFor(skin)) {
        final m = RegExp(r' at (.+) on ').firstMatch(p.label);
        if (m != null) byRole[m.group(1)!] = p.role.floor;
      }
      for (final t in skin.text.all) {
        expect(
          byRole[t.name],
          isLarge(t) ? 3.0 : 4.5,
          reason:
              '${t.name} at ${t.size}/w${t.weight.value} is swept at a '
              '${byRole[t.name]}:1 floor, which is not what WCAG 1.4.3 says '
              'for that size and weight.',
        );
      }
    });

    test('the two roles that sit on the boundary are named, with margins', () {
      final skin = TiqSkin.night();
      // title.l: 19 against 18.66 at w600 — 0.34px of margin, and it is the
      // only prose role whose rounding was overridden to keep it.
      expect(skin.text.titleL.size, 19);
      expect(skin.text.titleL.weight.value, greaterThanOrEqualTo(600));
      expect(
        skin.text.titleL.size,
        greaterThanOrEqualTo(18.66),
        reason:
            'title.l dropped under the w600 large-text boundary. 20 x 13/14 '
            'is 18.57 and it was deliberately rounded UP to 19 rather than '
            'down to 18 for exactly this reason.',
      );
      // display.s: 24 against 24 — on the boundary, which the >= in the rule
      // means is inside it. One dp down and eight pairings change floor.
      expect(skin.text.displayS.size, 24);
      expect(
        skin.text.displayS.size,
        greaterThanOrEqualTo(24),
        reason:
            'display.s dropped under 24. It is the floor of the display '
            'fitting ladder, so this moves the contrast floor of every '
            'four-line headline in the app.',
      );
    });

    test('no generated pairing is under its floor, in any skin or density', () {
      // The sweep already asserts this; it is repeated here as the closing
      // line of the boundary argument, because the whole point of the group
      // above is that a floor can move. Printed so a reviewer reading a type
      // change can see the margin rather than take it.
      for (final skin in TorchlightContrast.allSkinsAndDensities) {
        final pairings = TorchlightContrast.generatedFor(skin);
        final tightest = pairings.reduce(
          (a, b) =>
              a.ratio - a.role.floor <= b.ratio - b.role.floor ? a : b,
        );
        // ignore: avoid_print
        print(
          '${skin.mode.name}/${skin.density.name}: ${pairings.length} '
          'generated pairings, 0 under floor, tightest '
          '${tightest.ratio.toStringAsFixed(2)}:1 against a '
          '${tightest.role.floor}:1 floor (${tightest.label})',
        );
        expect(pairings.where((p) => p.ratio < p.role.floor), isEmpty);
      }
    });
  });
}

/// Relative-luminance greyscale: what a sun-washed panel, a photocopier and a
/// monochromat all see.
Color _greyscale(Color c) {
  final l = relativeLuminance(c);
  // Invert the sRGB transfer so the grey has the same *luminance*, not the
  // same average byte value.
  final channel = l <= 0.0031308
      ? l * 12.92
      : 1.055 * _pow(l, 1 / 2.4) - 0.055;
  return Color.from(alpha: 1, red: channel, green: channel, blue: channel);
}

double _pow(double x, double e) => math.pow(x, e).toDouble();

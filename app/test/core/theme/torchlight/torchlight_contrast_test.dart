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

    test('the table covers all three skins and the plate', () {
      final skins = TorchlightContrast.declared.map((p) => p.skin).toSet();
      expect(skins, containsAll(<String>['night', 'day', 'veld', 'plate']));
      expect(TorchlightContrast.declared.length, greaterThan(50));
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

    test('every banned pairing is listed, and there are five of them', () {
      // Pinned so that deleting a ban is a visible edit, not an omission.
      expect(
        TorchlightContrast.banned.map((b) => b.label).toList(),
        <String>[
          'flame-600 and ink-2 (Oatmeal) as adjacent bar fills',
          'flame-900 ink on a pressed flame-500 block',
          'flame-600 as text on the Palladian ground',
          'edge-structure on the Day well',
          'flame-600 as a line, icon, border or word on white',
        ],
      );
    });

    test('no skin puts a banned pairing in its own defaults', () {
      // The bans are only worth having if the token source itself obeys them.
      for (final skin in <TiqSkin>[
        TiqSkin.night(),
        TiqSkin.day(),
        TiqSkin.veld(),
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
        TiqSkin.veld(),
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
      for (final skin in <TiqSkin>[TiqSkin.day(), TiqSkin.veld()]) {
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
    test('Veld has no text token under 9:1 and no border under 15:1', () {
      final v = TiqSkin.veld().palette;
      for (final MapEntry(key: name, value: ink) in <String, Color>{
        'ink1': v.ink1,
        'ink2': v.ink2,
        'ink3': v.ink3,
        'navInkInactive': v.navInkInactive,
        'inkMute': v.inkMute,
        'chartNeutral': v.chartNeutral,
        'good': v.good,
        'bad': v.bad,
      }.entries) {
        final ratio = contrastRatio(ink, v.ground);
        expect(
          ratio,
          greaterThanOrEqualTo(9.0),
          reason:
              'Veld $name is ${ratio.toStringAsFixed(2)}:1 on white. In '
              'highveld sun an entry LCD at 40% backlight loses the bottom two '
              'stops; Veld has no token under 9:1 for text — including the '
              'disabled one, because outdoors there is no such thing as a '
              'decoration.',
        );
      }
      for (final MapEntry(key: name, value: edge) in <String, Color>{
        'edgeStructure': v.edgeStructure,
        'edgeControl': v.edgeControl,
        'hairline': v.hairline,
      }.entries) {
        final ratio = contrastRatio(edge, v.ground);
        expect(
          ratio,
          greaterThanOrEqualTo(15.0),
          reason: 'Veld $name is ${ratio.toStringAsFixed(2)}:1 on white.',
        );
      }
    });

    test('Veld casts no shadow, gradient or rim', () {
      final veld = TiqSkin.veld();
      expect(veld.depth.shadows, isEmpty);
      expect(veld.depth.allowsGradients, isFalse);
      expect(veld.depth.litRim.a, 0);
      expect(veld.depth.borderWidth, 2);
      expect(
        veld.motion.enabled,
        isFalse,
        reason: 'Veld kills every ambient loop.',
      );
      expect(veld.motion.resolve(TiqMotion.reveal), Duration.zero);
    });

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
      'night ink-1 on surface': 12.67,
      'night ink-1 on raised': 11.12,
      'night ink-2 on ground': 10.67,
      'night ink-2 on surface': 8.57,
      'night ink-3 (12px meta) on ground': 7.19,
      'night ink-3 (12px meta) on raised — the binding case': 5.07,
      'night hero figure flame-600 on ground': 10.65,
      'night amber text flame-700 on ground': 12.92,
      'night focus ring flame-700 on surface': 10.38,
      'night focus ring flame-700 on raised': 9.11,
      'night amber rim flame-600 on raised': 7.51,
      'night active-tab underbar flame-600 on nav body (well)': 9.49,
      'night focus bar flame-600 on chart track (lifted)': 6.37,
      'night neutral bar chart-neutral on chart track (lifted)': 3.01,
      'night good on ground': 11.76,
      'night good on raised': 8.30,
      'night bad on ground': 7.78,
      'night bad on raised': 5.49,
      'night bad on well': 6.94,
      'night comparison on ground': 7.52,
      'night comparison on raised': 5.30,
      'night edge-control on ground': 6.02,
      'night edge-control on surface': 4.84,
      'night edge-control on raised': 4.25,
      'night edge-structure on surface — the Panel outline': 3.05,
      'night edge-structure on ground': 3.79,
      'night nav ink inactive on nav body (well)': 6.32,
      'night ink on amber block': 10.65,
      'night ink on pressed amber block (flame-500)': 8.59,
      'night decorative hairline on ground': 2.14,
      'night disabled ink-mute on surface': 2.38,
      'plate ink-1 on an unscrimmed plate pixel at the luminance ceiling': 7.68,
      'plate ink-1 on the mandatory scrim over a full-value strip light': 10.56,
      'plate ink-2 eyebrow on that same worst-case scrimmed amber': 7.15,
      'day ink-1 on ground': 12.67,
      'day ink-1 on card (surface)': 14.34,
      'day ink-2 on ground': 7.99,
      'day ink-3 (12px meta) on ground': 5.15,
      'day ink-3 on well — the darkest Day surface': 4.52,
      'day flame-300, the one legal amber text on a light ground': 5.66,
      'day ink on the one amber block': 8.55,
      'day good on ground': 5.73,
      'day bad on ground': 7.52,
      'day comparison on ground': 4.58,
      'day edge-control on ground': 4.69,
      'day edge-structure on ground — the Panel outline': 3.41,
      'day neutral bar on chart track (well)': 4.52,
      'day focus bar ink-1 on chart track (well)': 11.12,
      'day nav-active: ground ink on the lifted block': 9.43,
      'day decorative hairline on ground': 1.18,
      'veld body ink on white': 18.52,
      'veld secondary ink on white': 9.66,
      'veld 2px structural border on white': 15.33,
      'veld ink on the one amber block': 10.34,
      'veld ink on the pressed amber block': 15.33,
      'veld ink on solid success block': 9.43,
      'veld ink on solid critical block': 10.94,
      'veld white ink on the lifted (Abyssal) block': 15.33,
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
      expect(
        banRatios['veld flame-600 as a line, icon, border or word on white'],
        closeTo(1.79, 0.005),
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
        greaterThan(2.0),
        reason:
            'Focus/neutral separation in greyscale is '
            '${grey.toStringAsFixed(2)}:1. It carries shape, weight and a '
            'leading marker as well — but if this drops to 1.0 the amber bar '
            'is literally its neighbour again.',
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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';

// WCAG 2.x relative luminance + contrast ratio, written out in full so a
// palette regression fails with the actual ratio in the message.
// Color.r/.g/.b are already 0..1 doubles on current Flutter.
double _linearize(double channel) => channel <= 0.04045
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

double _relativeLuminance(Color c) =>
    0.2126 * _linearize(c.r) + 0.7152 * _linearize(c.g) + 0.0722 * _linearize(c.b);

double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('TiqColors.dark parity', () {
    // Dark's values only ever change deliberately (spec, Testing section) —
    // ink3 moved #6A7280 → #838D9E for M6 (issue #144: 3.16:1 on surface3 as
    // 10–13px text), everything else is frozen. Literal hex — not AppColors
    // refs — so a slipped value in EITHER table fails loudly.
    test('every slot carries today\'s exact dark value', () {
      const d = TiqColors.dark;
      expect(d.plane, const Color(0xFF0B0C10));
      expect(d.surface1, const Color(0xFF14161C));
      expect(d.surface2, const Color(0xFF1A1D25));
      expect(d.surface3, const Color(0xFF21252E));
      expect(d.line, const Color(0xFF23262F));
      expect(d.lineStrong, const Color(0xFF2F333E));
      expect(d.ink1, const Color(0xFFE9EBEE));
      expect(d.ink2, const Color(0xFF99A1AD));
      expect(d.ink3, const Color(0xFF838D9E));
      expect(d.ink4, const Color(0xFF6A7280)); // the old ink3, marks only
      expect(d.brand, const Color(0xFF0A6CF0));
      expect(d.brandHover, const Color(0xFF1F7CF5));
      expect(d.series1, const Color(0xFF3987E5));
      expect(d.series2, const Color(0xFF199E70));
      expect(d.series3, const Color(0xFFC98500));
      expect(d.good, const Color(0xFF0CA30C));
      expect(d.warn, const Color(0xFFFAB219));
      expect(d.crit, const Color(0xFFD03B3B));
      expect(d.critText, const Color(0xFFE87370));
      expect(d.grid, const Color(0xFF22252D));
      expect(d.axis, const Color(0xFF2F333E));
      // New slots: dark keeps shadow transparent (borders do the job) and the
      // scrim equal to Flutter's default black54, so Plan B's application of
      // these slots changes nothing visually in dark.
      expect(d.shadow, const Color(0x00000000));
      expect(d.scrim, const Color(0x8A000000));
    });

    test('light carries the dark ink forward as its primary text color', () {
      // "the two modes read as one product" — spec §Paper & Ink.
      expect(TiqColors.light.ink1, const Color(0xFF14161C));
      expect(TiqColors.light.plane, const Color(0xFFF7F8FA));
      expect(TiqColors.light.surface1, const Color(0xFFFFFFFF));
      expect(TiqColors.light.line, const Color(0xFFE3E5EA));
    });

    test('lerp interpolates and copyWith replaces a single slot', () {
      final mid = TiqColors.dark.lerp(TiqColors.light, 0.5);
      expect(mid.plane, Color.lerp(TiqColors.dark.plane, TiqColors.light.plane, 0.5));
      final copied = TiqColors.dark.copyWith(brand: const Color(0xFF123456));
      expect(copied.brand, const Color(0xFF123456));
      expect(copied.plane, TiqColors.dark.plane);
    });
  });

  group('TiqColors.light chart palette contrast', () {
    const white = Color(0xFFFFFFFF);
    const l = TiqColors.light;

    // Charts draw on surface1 (#FFFFFF in light). Series and status colors
    // must clear 3:1 there (spec §2). If any value here fails: darken it until
    // it passes, then update BOTH the spec value and TiqColors.light.
    final palette = <String, Color>{
      'series1': l.series1, // #2069C9 ≈ 5.0:1
      'series2': l.series2, // #177A57 ≈ 5.3:1
      'series3': l.series3, // #9A6700 ≈ 4.9:1
      'good': l.good, //       #0B7A0B ≈ 5.5:1
      'warn': l.warn, //       #935F00 ≈ 5.4:1
      'crit': l.crit, //       #B32E2E ≈ 6.3:1
    };

    for (final entry in palette.entries) {
      test('${entry.key} clears 3:1 against white', () {
        final ratio = contrastRatio(entry.value, white);
        expect(
          ratio,
          greaterThanOrEqualTo(3.0),
          reason: '${entry.key} is $ratio:1 on white — darken it and update '
              'the spec (docs/superpowers/specs/2026-07-17-premium-ui-theme-'
              'motion-design.md §2) to the passing value.',
        );
      });
    }
  });

  group('ink contrast (M6, issue #144)', () {
    // ink3 is body text at 10–13px in ~66 places (hints, captions, BarNote),
    // so WCAG AA demands 4.5:1 — not the 3:1 graphical bar — on every surface
    // it can sit on, in both themes. ink4 (the old ink3) survives only for
    // graphical marks, where 3:1 is the requirement.
    final themes = <String, TiqColors>{
      'dark': TiqColors.dark,
      'light': TiqColors.light,
    };

    for (final MapEntry(key: name, value: t) in themes.entries) {
      final surfaces = <String, Color>{
        'plane': t.plane,
        'surface1': t.surface1,
        'surface2': t.surface2,
        'surface3': t.surface3,
      };

      for (final MapEntry(key: sName, value: surface) in surfaces.entries) {
        test('$name ink3 clears 4.5:1 (AA text) on $sName', () {
          final ratio = contrastRatio(t.ink3, surface);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '$name ink3 is $ratio:1 on $sName — ink3 is body text, '
                'not chrome. Fix the value; never demote text to ink4.',
          );
        });

        test('$name ink4 clears 3:1 (graphical) on $sName', () {
          final ratio = contrastRatio(t.ink4, surface);
          expect(
            ratio,
            greaterThanOrEqualTo(3.0),
            reason: '$name ink4 is $ratio:1 on $sName — even a quiet target '
                'rule has to be findable.',
          );
        });

        test('$name critText clears 4.5:1 over the crit wash on $sName', () {
          // The StatusBanner sets its title over crit at 12% alpha
          // (BannerLevelStyle.wash) — reproduce that exact composite here so
          // the assertion tests what agents actually read.
          final wash = Color.alphaBlend(t.crit.withValues(alpha: 0.12), surface);
          final ratio = contrastRatio(t.critText, wash);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '$name critText is $ratio:1 over the crit wash on $sName — '
                'this is the "items will not send" banner title. It must be '
                'the most readable thing on the screen, not the least.',
          );
        });
      }

      test('$name ink hierarchy still steps down: ink2 > ink3 > ink4', () {
        // The fix must not flatten the type ramp — muted has to stay visibly
        // quieter than secondary, and marks quieter than muted.
        final ink2 = contrastRatio(t.ink2, t.plane);
        final ink3 = contrastRatio(t.ink3, t.plane);
        final ink4 = contrastRatio(t.ink4, t.plane);
        expect(ink2, greaterThan(ink3),
            reason: '$name ink2 ($ink2:1) must outrank ink3 ($ink3:1)');
        expect(ink3, greaterThan(ink4),
            reason: '$name ink3 ($ink3:1) must outrank ink4 ($ink4:1)');
      });
    }
  });
}

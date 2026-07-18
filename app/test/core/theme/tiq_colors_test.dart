import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';

void main() {
  group('TiqColors.dark parity', () {
    // The dark theme's values must not change AT ALL (spec, Testing section).
    // Literal hex — not AppColors refs — so a slipped value in EITHER table
    // fails loudly.
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
      expect(d.ink3, const Color(0xFF6A7280));
      expect(d.brand, const Color(0xFF0A6CF0));
      expect(d.brandHover, const Color(0xFF1F7CF5));
      expect(d.series1, const Color(0xFF3987E5));
      expect(d.series2, const Color(0xFF199E70));
      expect(d.series3, const Color(0xFFC98500));
      expect(d.good, const Color(0xFF0CA30C));
      expect(d.warn, const Color(0xFFFAB219));
      expect(d.crit, const Color(0xFFD03B3B));
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
    // WCAG 2.x relative luminance + contrast ratio, written out in full so a
    // palette regression fails with the actual ratio in the message.
    // Color.r/.g/.b are already 0..1 doubles on current Flutter.
    double linearize(double channel) => channel <= 0.04045
        ? channel / 12.92
        : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

    double relativeLuminance(Color c) =>
        0.2126 * linearize(c.r) + 0.7152 * linearize(c.g) + 0.0722 * linearize(c.b);

    double contrastRatio(Color a, Color b) {
      final la = relativeLuminance(a);
      final lb = relativeLuminance(b);
      final hi = math.max(la, lb);
      final lo = math.min(la, lb);
      return (hi + 0.05) / (lo + 0.05);
    }

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
}

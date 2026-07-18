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
}

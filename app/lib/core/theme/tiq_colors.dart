import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The theme-aware TradeIQ palette — every semantic slot the console uses,
/// carried as a [ThemeExtension] so widgets can respond to the light/dark
/// toggle at runtime.
///
/// [TiqColors.dark] is seeded from the [AppColors] consts, so it is identical
/// to today's static palette by construction. [TiqColors.light] is the
/// "Paper & Ink" scheme from the 2026-07-17 premium-UI spec: `#F7F8FA` page
/// ground, white panels, `#E3E5EA` hairlines — and the dark theme's ink
/// `#14161C` carried forward as primary text, so the two modes read as one
/// product. Its chart series/status colors are darkened variants validated
/// ≥3:1 against white (see tiq_colors_test.dart).
///
/// Slot discipline is unchanged: status colors are never series colors, and
/// meaning never rides on color alone.
///
/// Mirrors `design/tokens.css` (dark `:root` + `[data-theme="light"]`).
class TiqColors extends ThemeExtension<TiqColors> {
  const TiqColors({
    required this.plane,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.line,
    required this.lineStrong,
    required this.ink1,
    required this.ink2,
    required this.ink3,
    required this.ink4,
    required this.brand,
    required this.brandHover,
    required this.series1,
    required this.series2,
    required this.series3,
    required this.good,
    required this.warn,
    required this.crit,
    required this.critText,
    required this.grid,
    required this.axis,
    required this.shadow,
    required this.scrim,
  });

  // ── Planes & surfaces ────────────────────────────────────────────────
  final Color plane;
  final Color surface1;
  final Color surface2;
  final Color surface3;

  // ── Hairlines ────────────────────────────────────────────────────────
  final Color line;
  final Color lineStrong;

  // ── Ink ──────────────────────────────────────────────────────────────
  final Color ink1;
  final Color ink2;
  final Color ink3;

  /// Graphical marks only (dashed target rules) — 3:1, never text.
  final Color ink4;

  // ── Brand ────────────────────────────────────────────────────────────
  final Color brand;
  final Color brandHover;

  // ── Data series — fixed slot order. Never cycled, never generated. ───
  final Color series1;
  final Color series2;
  final Color series3;

  // ── Status — reserved. Never a series color. ─────────────────────────
  final Color good;
  final Color warn;
  final Color crit;

  /// [crit] when it has to carry words — clears 4.5:1 over the crit wash,
  /// which crit itself (a mark color) does not.
  final Color critText;

  // ── Chart chrome ─────────────────────────────────────────────────────
  final Color grid;
  final Color axis;

  // ── Elevation & overlay (new slots — used by Plan B) ─────────────────
  /// Panel drop-shadow color. Transparent in dark: its borders already carry
  /// elevation, so dark's appearance cannot change.
  final Color shadow;

  /// Drawer overlay wash. Dark equals Flutter's default black54 so applying
  /// the slot (Plan B) is a no-op in dark.
  final Color scrim;

  /// Today's exact dark palette. Seeded from [AppColors] so the static table
  /// and the extension can never disagree.
  static const dark = TiqColors(
    plane: AppColors.plane,
    surface1: AppColors.surface1,
    surface2: AppColors.surface2,
    surface3: AppColors.surface3,
    line: AppColors.line,
    lineStrong: AppColors.lineStrong,
    ink1: AppColors.ink1,
    ink2: AppColors.ink2,
    ink3: AppColors.ink3,
    ink4: AppColors.ink4,
    brand: AppColors.brand,
    brandHover: AppColors.brandHover,
    series1: AppColors.series1,
    series2: AppColors.series2,
    series3: AppColors.series3,
    good: AppColors.good,
    warn: AppColors.warn,
    crit: AppColors.crit,
    critText: AppColors.critText,
    grid: AppColors.grid,
    axis: AppColors.axis,
    shadow: Color(0x00000000),
    scrim: Color(0x8A000000), // == Colors.black54
  );

  /// Paper & Ink. brand is shared with dark deliberately (4.98:1 on white);
  /// ink3 no longer is — dark's #838D9E is unreadable on paper (2.80:1 on
  /// surface3), and even the old shared #6A7280 quietly failed light's
  /// tinted surfaces (4.06:1 on surface3). Each mode now carries the muted
  /// ink its own grounds demand; tiq_colors_test.dart holds both above 4.5:1.
  static const light = TiqColors(
    plane: Color(0xFFF7F8FA),
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFF1F3F6),
    surface3: Color(0xFFE8EBF0),
    line: Color(0xFFE3E5EA),
    lineStrong: Color(0xFFD2D6DE),
    ink1: Color(0xFF14161C), // the dark theme's ink, carried forward
    ink2: Color(0xFF4C5560),
    ink3: Color(0xFF5F6875), // 4.72:1 on surface3, the palest ground it meets
    ink4: Color(0xFF6A7280), // marks only — 4.06:1 on surface3 clears the 3:1 bar
    brand: Color(0xFF0A6CF0),
    brandHover: Color(0xFF0857C4), // hover darkens on a light ground
    series1: Color(0xFF2069C9),
    series2: Color(0xFF177A57),
    series3: Color(0xFF9A6700),
    good: Color(0xFF0B7A0B),
    warn: Color(0xFF935F00),
    crit: Color(0xFFB32E2E),
    critText: Color(0xFFA52A2A), // crit deepened: 4.94:1 over its wash on surface3
    grid: Color(0xFFECEEF2),
    axis: Color(0xFFD2D6DE),
    shadow: Color(0x14101828), // 8% slate — Plan B layers opacities on top
    scrim: Color(0x99101828), // 60% slate — deeper than black54's wash reads on light
  );

  @override
  TiqColors copyWith({
    Color? plane,
    Color? surface1,
    Color? surface2,
    Color? surface3,
    Color? line,
    Color? lineStrong,
    Color? ink1,
    Color? ink2,
    Color? ink3,
    Color? ink4,
    Color? brand,
    Color? brandHover,
    Color? series1,
    Color? series2,
    Color? series3,
    Color? good,
    Color? warn,
    Color? crit,
    Color? critText,
    Color? grid,
    Color? axis,
    Color? shadow,
    Color? scrim,
  }) {
    return TiqColors(
      plane: plane ?? this.plane,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      ink1: ink1 ?? this.ink1,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      ink4: ink4 ?? this.ink4,
      brand: brand ?? this.brand,
      brandHover: brandHover ?? this.brandHover,
      series1: series1 ?? this.series1,
      series2: series2 ?? this.series2,
      series3: series3 ?? this.series3,
      good: good ?? this.good,
      warn: warn ?? this.warn,
      crit: crit ?? this.crit,
      critText: critText ?? this.critText,
      grid: grid ?? this.grid,
      axis: axis ?? this.axis,
      shadow: shadow ?? this.shadow,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  TiqColors lerp(ThemeExtension<TiqColors>? other, double t) {
    if (other is! TiqColors) return this;
    return TiqColors(
      plane: Color.lerp(plane, other.plane, t)!,
      surface1: Color.lerp(surface1, other.surface1, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      ink1: Color.lerp(ink1, other.ink1, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      ink4: Color.lerp(ink4, other.ink4, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandHover: Color.lerp(brandHover, other.brandHover, t)!,
      series1: Color.lerp(series1, other.series1, t)!,
      series2: Color.lerp(series2, other.series2, t)!,
      series3: Color.lerp(series3, other.series3, t)!,
      good: Color.lerp(good, other.good, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      crit: Color.lerp(crit, other.crit, t)!,
      critText: Color.lerp(critText, other.critText, t)!,
      grid: Color.lerp(grid, other.grid, t)!,
      axis: Color.lerp(axis, other.axis, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

/// `context.colors` — how feature code reads the ambient palette.
///
/// Falls back to [TiqColors.dark] when no theme registers the extension. In
/// production both AppTheme.light() and AppTheme.dark() register it, so the
/// fallback only fires in tests that pump a bare MaterialApp — where dark (the
/// pre-theme-system status quo) is exactly what their assertions expect. This
/// keeps all pre-existing widget tests green with zero edits.
extension TiqColorsContext on BuildContext {
  TiqColors get colors => Theme.of(this).extension<TiqColors>() ?? TiqColors.dark;
}

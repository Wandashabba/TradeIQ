import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The theme-aware TradeIQ palette — every semantic slot the console uses,
/// carried as a [ThemeExtension] so widgets can respond to the light/dark
/// toggle at runtime.
///
/// [TiqColors.dark] is seeded from the [AppColors] consts, so it is identical
/// to the static instrument palette by construction. [TiqColors.light] is
/// **Lumen Glass** (design handoff, turn 4): a lit lavender ground, `#241F47`
/// ink, one blurple accent, and R/A/G for status. Its surface slots are the
/// *composited* colour of a glass pane over the ground — opaque, so contrast
/// math stays honest and a screen not yet built on `GlassPane` still reads as
/// part of the same material. The real translucency and blur live in
/// `core/widgets/glass.dart`, switched on by [glass].
///
/// Slot discipline is unchanged: status colors are never series colors, and
/// meaning never rides on color alone.
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
    required this.heroWash,
    required this.heroBorder,
    required this.navBarBg,
    required this.navBarLine,
    required this.navInactiveInk,
    required this.navActivePillBg,
    required this.navActiveInk,
    required this.glass,
    required this.action,
    required this.onAction,
    required this.radiusControl,
    required this.radiusCard,
    required this.radiusPanel,
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

  // ── Elevation & overlay ──────────────────────────────────────────────
  /// Panel drop-shadow color. Transparent in dark: its borders already carry
  /// elevation, so dark's appearance cannot change.
  final Color shadow;

  /// Drawer overlay wash. Dark equals Flutter's default black54.
  final Color scrim;

  // ── Hero wash ────────────────────────────────────────────────────────
  /// Top stop of a hero card's gradient wash; the bottom stop is [surface1].
  /// Each mode's [ink1] must clear 4.5:1 on it — tiq_colors_test.dart holds
  /// both.
  final Color heroWash;

  /// Hairline for the washed hero card.
  final Color heroBorder;

  // ── Floating bottom bar ──────────────────────────────────────────────
  /// The bar's fill over its blur. Glass: half-white. Dark: 92% instrument.
  final Color navBarBg;

  /// The bar's own rim.
  final Color navBarLine;

  /// Inactive slot icon + label. 10.5px text, so ≥4.5:1 on [navBarBg]
  /// composited over the palest ground it can meet — bottom_nav_bar_test.dart
  /// measures the rendered pair.
  final Color navInactiveInk;

  /// The sliding active pill's fill.
  final Color navActivePillBg;

  /// Icon + label on the active pill.
  final Color navActiveInk;

  // ── Material ─────────────────────────────────────────────────────────
  /// Whether this theme is Lumen Glass. Both app themes are ([light] and
  /// [night]); only the themeless fallback ([dark], the old flat instrument
  /// panel) is not, and glass widgets draw their flat recipe for it.
  final bool glass;

  /// The primary action's fill — the dark `#241F47` pill in glass, brand in
  /// dark — and the words set on it.
  final Color action;
  final Color onAction;

  // ── Geometry ─────────────────────────────────────────────────────────
  /// Buttons, inputs, stepper keys.
  final double radiusControl;

  /// Cards, tiles, list items.
  final double radiusCard;

  /// Panels and hero panes.
  final double radiusPanel;

  /// The flat instrument palette — no longer a theme, only the fallback for a
  /// widget pumped without one. Seeded from [AppColors] so the static table
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
    heroWash: Color(0xFF17233A), // ink1 13.9:1 — see tiq_colors_test.dart
    heroBorder: Color(0xFF22304A),
    navBarBg: Color(0xEB12151C), // rgba(18,21,28,.92)
    navBarLine: Color(0xFF262B33),
    navInactiveInk: Color(0xFF8A94A6), // 5.9:1 on the bar over surface3
    navActivePillBg: Color(0xFF12305C),
    navActiveInk: Color(0xFF6DB4FF), // 6.0:1 on the pill
    glass: false,
    action: AppColors.brand,
    onAction: Color(0xFFFFFFFF),
    radiusControl: AppColors.radiusControl,
    radiusCard: AppColors.radiusPanel,
    radiusPanel: AppColors.radiusPanel,
  );

  /// Lumen Glass. Surfaces are glass panes composited over the ground (see
  /// the class doc); ink and status follow the handoff's token table, with
  /// every text pair held ≥4.5:1 by tiq_colors_test.dart.
  static const light = TiqColors(
    plane: Color(0xFFECEAF6), // the ground, mid-gradient
    surface1: Color(0xFFF7F6FB), // a .50 glass pane over the ground
    surface2: Color(0xFFEFEDF7), // raised: inputs, table headers
    surface3: Color(0xFFE4E1F0), // pressed / selected wash
    line: Color(0xFFDCD8EA),
    lineStrong: Color(0xFFC9C4DD),
    ink1: Color(0xFF241F47),
    ink2: Color(0xFF3E3A5C),
    ink3: Color(0xFF5B5F75), // 4.8:1 on surface3, the palest ground it meets
    ink4: Color(0xFF74788E), // marks only — clears 3:1 on surface3
    brand: Color(0xFF5D5294),
    brandHover: Color(0xFF4A4180),
    series1: Color(0xFF2069C9),
    series2: Color(0xFF177A57),
    series3: Color(0xFF9A6700),
    // good and warn are used as WORDS as well as marks (band names, section
    // states), so they are deepened past the handoff's fills until they clear
    // 4.5:1 as text on every glass surface. The fills live in LumenStatus.
    good: Color(0xFF17704A),
    warn: Color(0xFF8A5A00),
    crit: Color(0xFFB3261E),
    critText: Color(0xFF8C1D17),
    grid: Color(0xFFE2DFEE),
    axis: Color(0xFFC9C4DD),
    shadow: Color(0x243C3078), // rgba(60,48,120,.14)
    scrim: Color(0x99241F47),
    heroWash: Color(0xFFF2F0FA),
    heroBorder: Color(0xFFFFFFFF),
    navBarBg: Color(0x80FFFFFF), // rgba(255,255,255,.50) over a 28px blur
    navBarLine: Color(0xCCFFFFFF),
    navInactiveInk: Color(0xFF5B5F75),
    navActivePillBg: Color(0xC7FFFFFF),
    navActiveInk: Color(0xFF241F47),
    glass: true,
    action: Color(0xFF241F47),
    onAction: Color(0xFFFFFFFF),
    radiusControl: 14,
    radiusCard: 16,
    radiusPanel: 20,
  );

  /// Lumen Glass at night — the indigo ground, faint white panes, pastel
  /// inks and a bright lavender action. Surfaces are panes composited over the
  /// ground, as in [light], so contrast math stays honest.
  static const night = TiqColors(
    plane: Color(0xFF111026), // the ground, mid-gradient
    surface1: Color(0xFF1D1B33), // a faint glass pane over the ground
    surface2: Color(0xFF24223C), // raised: inputs, table headers
    surface3: Color(0xFF2D2A48), // pressed / selected wash
    line: Color(0xFF2F2C4A),
    lineStrong: Color(0xFF3E3A5E),
    ink1: Color(0xFFEEECFB),
    ink2: Color(0xFFCFCCE6),
    ink3: Color(0xFFAEACC8), // 6.2:1 on surface3, the palest ground it meets
    ink4: Color(0xFF7E7B9C), // marks only
    brand: Color(0xFFB5ABFC),
    brandHover: Color(0xFFCFC7FF),
    series1: Color(0xFF6FA8FF),
    series2: Color(0xFF4FC79A),
    series3: Color(0xFFE6B450),
    good: Color(0xFF7FD8A8),
    warn: Color(0xFFF2C46D),
    crit: Color(0xFFFF8A80),
    critText: Color(0xFFFFB4AB),
    grid: Color(0xFF2A2745),
    axis: Color(0xFF3E3A5E),
    shadow: Color(0x66000000),
    scrim: Color(0xB3000000),
    heroWash: Color(0xFF221F3D),
    heroBorder: Color(0x33FFFFFF),
    navBarBg: Color(0x1FFFFFFF), // a faint pane over a 28px blur
    navBarLine: Color(0x33FFFFFF),
    navInactiveInk: Color(0xFFCFCCE6), // ink2: 5.9:1 on the bar over surface3
    navActivePillBg: Color(0x2EFFFFFF),
    navActiveInk: Color(0xFFFFFFFF),
    glass: true,
    action: Color(0xFFE9E6FF),
    onAction: Color(0xFF241F47),
    radiusControl: 14,
    radiusCard: 16,
    radiusPanel: 20,
  );

  /// Glass on a dark ground — light ink is the tell.
  bool get isNight => glass && ink1.computeLuminance() > 0.5;

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
    Color? heroWash,
    Color? heroBorder,
    Color? navBarBg,
    Color? navBarLine,
    Color? navInactiveInk,
    Color? navActivePillBg,
    Color? navActiveInk,
    bool? glass,
    Color? action,
    Color? onAction,
    double? radiusControl,
    double? radiusCard,
    double? radiusPanel,
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
      heroWash: heroWash ?? this.heroWash,
      heroBorder: heroBorder ?? this.heroBorder,
      navBarBg: navBarBg ?? this.navBarBg,
      navBarLine: navBarLine ?? this.navBarLine,
      navInactiveInk: navInactiveInk ?? this.navInactiveInk,
      navActivePillBg: navActivePillBg ?? this.navActivePillBg,
      navActiveInk: navActiveInk ?? this.navActiveInk,
      glass: glass ?? this.glass,
      action: action ?? this.action,
      onAction: onAction ?? this.onAction,
      radiusControl: radiusControl ?? this.radiusControl,
      radiusCard: radiusCard ?? this.radiusCard,
      radiusPanel: radiusPanel ?? this.radiusPanel,
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
      heroWash: Color.lerp(heroWash, other.heroWash, t)!,
      heroBorder: Color.lerp(heroBorder, other.heroBorder, t)!,
      navBarBg: Color.lerp(navBarBg, other.navBarBg, t)!,
      navBarLine: Color.lerp(navBarLine, other.navBarLine, t)!,
      navInactiveInk: Color.lerp(navInactiveInk, other.navInactiveInk, t)!,
      navActivePillBg: Color.lerp(navActivePillBg, other.navActivePillBg, t)!,
      navActiveInk: Color.lerp(navActiveInk, other.navActiveInk, t)!,
      // A material is not interpolable — the switch lands at the midpoint.
      glass: t < 0.5 ? glass : other.glass,
      action: Color.lerp(action, other.action, t)!,
      onAction: Color.lerp(onAction, other.onAction, t)!,
      radiusControl: lerpDouble(radiusControl, other.radiusControl, t)!,
      radiusCard: lerpDouble(radiusCard, other.radiusCard, t)!,
      radiusPanel: lerpDouble(radiusPanel, other.radiusPanel, t)!,
    );
  }
}

/// `context.colors` — how feature code reads the ambient palette.
///
/// Falls back to the flat [TiqColors.dark] when no theme registers the
/// extension. In production both AppTheme.light() and AppTheme.dark() register
/// a glass palette, so the fallback only fires in tests that pump a bare
/// MaterialApp.
extension TiqColorsContext on BuildContext {
  TiqColors get colors =>
      Theme.of(this).extension<TiqColors>() ?? TiqColors.dark;
}

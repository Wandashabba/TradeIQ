import 'package:flutter/material.dart';

/// The TradeIQ color scheme as a theme extension — one instance per mode, so
/// every slot flips with the toggle. Slot semantics (and the dark values) are
/// identical to the static [AppColors] table; light is the "Paper & Ink"
/// direction: white panels on a cool paper ground, with the dark theme's ink
/// carried over as the text color so both modes read as one product.
///
/// Slot discipline is unchanged from the dark palette: status colors are
/// reserved (never used as series colors), and meaning never rides on color
/// alone. The light series/status values are contrast-locked >=3:1 against
/// white by test/core/theme/tiq_colors_test.dart.
@immutable
class TiqColors extends ThemeExtension<TiqColors> {
  const TiqColors({
    required this.brightness,
    required this.plane,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.line,
    required this.lineStrong,
    required this.ink1,
    required this.ink2,
    required this.ink3,
    required this.brand,
    required this.brandHover,
    required this.series1,
    required this.series2,
    required this.series3,
    required this.good,
    required this.warn,
    required this.crit,
    required this.grid,
    required this.axis,
    required this.shadow,
    required this.scrim,
  });

  final Brightness brightness;

  // Planes & surfaces.
  final Color plane;
  final Color surface1;
  final Color surface2;
  final Color surface3;

  // Hairlines.
  final Color line;
  final Color lineStrong;

  // Ink.
  final Color ink1;
  final Color ink2;
  final Color ink3;

  // Brand.
  final Color brand;
  final Color brandHover;

  // Data series — fixed slots, never cycled.
  final Color series1;
  final Color series2;
  final Color series3;

  // Status — reserved.
  final Color good;
  final Color warn;
  final Color crit;

  // Chart chrome.
  final Color grid;
  final Color axis;

  /// Panel drop shadow. Transparent in dark mode — borders do that job there.
  final Color shadow;

  /// Drawer/backdrop scrim (alpha baked in).
  final Color scrim;

  /// Today's palette, exactly — mirrors the static AppColors table.
  static const dark = TiqColors(
    brightness: Brightness.dark,
    plane: Color(0xFF0B0C10),
    surface1: Color(0xFF14161C),
    surface2: Color(0xFF1A1D25),
    surface3: Color(0xFF21252E),
    line: Color(0xFF23262F),
    lineStrong: Color(0xFF2F333E),
    ink1: Color(0xFFE9EBEE),
    ink2: Color(0xFF99A1AD),
    ink3: Color(0xFF6A7280),
    brand: Color(0xFF0A6CF0),
    brandHover: Color(0xFF1F7CF5),
    series1: Color(0xFF3987E5),
    series2: Color(0xFF199E70),
    series3: Color(0xFFC98500),
    good: Color(0xFF0CA30C),
    warn: Color(0xFFFAB219),
    crit: Color(0xFFD03B3B),
    grid: Color(0xFF22252D),
    axis: Color(0xFF2F333E),
    shadow: Color(0x00000000),
    scrim: Color(0x99000000),
  );

  /// Paper & Ink. Same geometry, same brand blue, the dark theme's ink as text.
  static const light = TiqColors(
    brightness: Brightness.light,
    plane: Color(0xFFF7F8FA),
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFF1F2F5),
    surface3: Color(0xFFE8EAEF),
    line: Color(0xFFE3E5EA),
    lineStrong: Color(0xFFD2D6DE),
    ink1: Color(0xFF14161C),
    ink2: Color(0xFF4C5361),
    ink3: Color(0xFF8A909C),
    brand: Color(0xFF0A6CF0),
    brandHover: Color(0xFF0857C4), // darken on hover in light, not lighten
    series1: Color(0xFF2069C9),
    series2: Color(0xFF177A57),
    series3: Color(0xFF9A6700),
    good: Color(0xFF0B7A0B),
    warn: Color(0xFF935F00),
    crit: Color(0xFFB32E2E),
    grid: Color(0xFFE9EBF0),
    axis: Color(0xFFD2D6DE),
    shadow: Color(0xFF14161C), // applied at low opacity by the shadow tokens
    scrim: Color(0x8014161C),
  );

  @override
  TiqColors copyWith() => this; // slots only ever swap wholesale by mode

  @override
  TiqColors lerp(TiqColors? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

/// `context.colors.ink1` — the migration target for every `AppColors.x` read
/// in theme-following (manager/shared) code.
extension TiqColorsContext on BuildContext {
  TiqColors get colors => Theme.of(this).extension<TiqColors>()!;
}

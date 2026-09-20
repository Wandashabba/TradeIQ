import 'package:flutter/material.dart';

/// TradeIQ palette — a dark instrument panel for retail execution.
///
/// The three series hues and the status steps were validated against the
/// [surface1] chart surface (#14161C): they clear the lightness band, the
/// chroma floor, 3:1 contrast, and a worst adjacent colour-blind separation of
/// ΔE 41.3 (target ≥ 12). Status colours are *reserved* — never reuse one as a
/// series colour, and always pair one with an icon or a word so meaning never
/// rides on colour alone.
///
/// Mirrors `design/archive/tokens.css` — the pre-Torchlight mockups, kept
/// as a record. See `design/archive/README.md`.
@Deprecated(
  'Torchlight Aisle collapsed the five colour sources into one TiqSkin. '
  'Use context.skin.palette — see docs/design/torchlight-aisle.md. This table '
  'also carries radiusPill (999), which no longer exists: Torchlight has four '
  'radii tied to four materials and the stadium died with the active-tab pill.',
)
class AppColors {
  AppColors._();

  // ── Planes & surfaces ────────────────────────────────────────────────
  /// Page ground.
  static const plane = Color(0xFF0B0C10);

  /// Panel — the surface the data palette is validated against.
  static const surface1 = Color(0xFF14161C);

  /// Raised: inputs, table headers, hover.
  static const surface2 = Color(0xFF1A1D25);

  /// Pressed / selected wash.
  static const surface3 = Color(0xFF21252E);

  // ── Hairlines — solid, one shade off the surface. Never dashed. ──────
  static const line = Color(0xFF23262F);
  static const lineStrong = Color(0xFF2F333E);

  // ── Ink ──────────────────────────────────────────────────────────────
  static const ink1 = Color(0xFFE9EBEE); // primary
  static const ink2 = Color(0xFF99A1AD); // secondary

  /// Muted text: hints, captions, tick labels. ~66 call sites render this at
  /// 10–13px, which makes it *text* under WCAG — so it must clear 4.5:1, not
  /// the 3:1 graphical bar. The old #6A7280 bottomed out at 3.16:1 on
  /// [surface3]; this value clears 4.5:1 on all four surfaces (4.58:1 worst).
  static const ink3 = Color(0xFF838D9E);

  /// The old ink3, kept for graphical marks only — dashed target rules and
  /// other non-text strokes that need 3:1, where the dimmer weight is the
  /// point. Never put words in this color.
  static const ink4 = Color(0xFF6A7280);

  // ── Brand — identity and interactive affordances only. ───────────────
  static const brand = Color(0xFF0A6CF0);
  static const brandHover = Color(0xFF1F7CF5);

  // ── Data series — fixed slot order. Never cycled, never generated. ───
  static const series1 = Color(0xFF3987E5);
  static const series2 = Color(0xFF199E70);
  static const series3 = Color(0xFFC98500);

  // ── Status — reserved. Never a series colour. ────────────────────────
  static const good = Color(0xFF0CA30C);
  static const warn = Color(0xFFFAB219);
  static const crit = Color(0xFFD03B3B);

  /// [crit] as *text*. crit itself is a mark color — as the StatusBanner
  /// title over its own 12% wash it reads at 3.74:1, on the one banner that
  /// tells an agent their captures will not send. This tint keeps the hue and
  /// clears 4.5:1 over the crit wash on every surface (4.74:1 worst).
  static const critText = Color(0xFFE87370);

  // ── Chart chrome ─────────────────────────────────────────────────────
  static const grid = Color(0xFF22252D);
  static const axis = Color(0xFF2F333E);

  // ── Geometry ─────────────────────────────────────────────────────────
  /// Controls (buttons, inputs). Squared off — nothing is a pill.
  static const double radiusControl = 3;

  /// Panels and cards.
  static const double radiusPanel = 12;

  /// Pills — the premium restyle's chips and [DeltaPill]. Any radius beyond
  /// half the pill's height renders a stadium; 999 is the conventional cap.
  static const double radiusPill = 999;

  // ── Back-compat aliases ──────────────────────────────────────────────
  // Existing feature code references these names. They keep compiling; only
  // the values moved to the new palette. Prefer the names above in new code.
  static const canvas = plane;
  static const background = plane;
  static const surface = surface1;
  static const input = surface2;
  static const outline = lineStrong;

  static const blue = brand;
  static const blueLight = series1;
  static const blueDark = Color(0xFF07306E);

  static const textPrimary = ink1;
  static const textSecondary = ink2;
  static const textMuted = ink3;

  static const success = good;
  static const warning = warn;
  static const danger = crit;

  static const navyBackground = plane;
  static const navySurface = surface1;
  static const primaryBlue = brand;
  static const accentOrange = Color(0xFFEB6834);
  static const accentTeal = series2;
  static const accentGold = warn;
  static const accentPink = Color(0xFFD55181);
}

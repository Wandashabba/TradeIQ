import 'package:flutter/material.dart';

import 'tiq_colors.dart';

/// Lumen Glass — the light theme's material (design handoff, turn 4).
///
/// Translucent chrome over a lit lavender ground: every pane is a fill, a
/// rim, a backdrop blur, a specular highlight and a soft shadow. Two rules
/// carry over from the instrument-panel palette unchanged:
///
/// * **Glass is chrome only.** Panels, tiles, bars and buttons are glass;
///   every figure, label and status mark sits fully opaque on top of them.
/// * **Status is never colour alone.** Every [LumenStatus] carries a word,
///   and every status tile a glyph.
///
/// Only the LIGHT theme is glass ([TiqColors.glass]). Dark keeps the flat
/// instrument panel, so each widget built on these tokens checks
/// `context.colors.glass` and falls back to its flat recipe in dark.
class LumenGlass {
  LumenGlass._();

  // ── Ground: the lit lavender behind every pane ───────────────────────
  static const groundTop = Color(0xFFF2F0FA);
  static const groundBottom = Color(0xFFE6E4F2);
  static const bloomViolet = Color(0xFFD6CDF3);
  static const bloomBlue = Color(0xFFCFD8F1);
  static const bloomRose = Color(0xFFE4D9EE);

  // ── Ink ──────────────────────────────────────────────────────────────
  /// Headings, figures, body.
  static const ink = Color(0xFF241F47);

  /// Secondary text, meta and table cells — 5.6:1 on the ground. The floor:
  /// nothing that carries words goes lighter than this.
  static const inkMuted = Color(0xFF5B5F75);

  /// Uppercase mono micro-labels.
  static const kicker = Color(0xFF6A5F9B);

  /// Labels on the dark pane — ≈6:1 once composited over it.
  static const onDarkMuted = Color(0x9EFFFFFF);

  // ── Brand — identity and "where you are". Never a status. ────────────
  static const inkDark = Color(0xFF161826);
  static const buttonDark = Color(0xF0241F47);
  static const accent = Color(0xEB5D5294);
  static const accentSolid = Color(0xFF5D5294);
  static const accentInk = Color(0xFF3A2F78);
  static const accentLight = Color(0xFFB5ABFC);
  static const chartLine = Color(0xFFCFC7FF);

  /// An upward delta set on the dark pane.
  static const riseOnDark = Color(0xFF8FD0AB);

  /// Status words set ON the dark pane, where the handoff's inks would vanish.
  /// Each clears 6:1 on [darkPaneGround] (glass_test.dart holds it).
  static const onDarkGood = Color(0xFF8FD0AB);
  static const onDarkWarn = Color(0xFFF2C46D);
  static const onDarkCrit = Color(0xFFFFB4AB);

  /// The dark pane composited over the lightest point of the ground — the
  /// ground its words are measured against.
  static const darkPaneGround = Color(0xFF393B48);

  // ── Glass surfaces ───────────────────────────────────────────────────
  static const panelFill = Color(0x80FFFFFF);
  static const panelRim = Color(0xC7FFFFFF);
  static const tileFill = Color(0x7AFFFFFF);
  static const tileRim = Color(0xA8FFFFFF);

  /// A pane that skips the blur — list items on cheap handsets, where a
  /// [BackdropFilter] per row is too expensive. More opaque, so text stays
  /// legible without the blur doing half the work.
  static const solidFill = Color(0xD9FFFFFF);
  static const barFill = Color(0x80FFFFFF);
  static const barRim = Color(0xCCFFFFFF);
  static const pillFill = Color(0xC7FFFFFF);
  static const pillRim = Color(0x8CFFFFFF);
  static const darkFill = Color(0xD6161826);
  static const darkRim = Color(0x3DFFFFFF);
  static const actionRim = Color(0x4DFFFFFF);

  /// The disabled primary action. Deliberately not paler than this: white
  /// text over it still clears 4.7:1, so a blocked button stays readable.
  static const actionDisabled = Color(0x99241F47);

  /// Critical ink by day — the rose bloom deepened until it clears 4.5:1 as
  /// words on every pane. Night's value lives in `LumenPalette.dark`.
  static const critical = Color(0xFFA3294A);

  /// The neutral track under a bar.
  static const track = Color(0x245B5F75);

  static const shadowPanel = BoxShadow(
    color: Color(0x243C3078),
    blurRadius: 30,
    offset: Offset(0, 12),
  );
  static const shadowTile = BoxShadow(
    color: Color(0x1A3C3078),
    blurRadius: 16,
    offset: Offset(0, 6),
  );
  static const shadowBar = BoxShadow(
    color: Color(0x333C3078),
    blurRadius: 32,
    offset: Offset(0, 14),
  );
  static const shadowPill = BoxShadow(
    color: Color(0x2E3C3078),
    blurRadius: 16,
    offset: Offset(0, 6),
  );
  static const shadowDark = BoxShadow(
    color: Color(0x661E1646),
    blurRadius: 40,
    offset: Offset(0, 18),
  );
  static const shadowAction = BoxShadow(
    color: Color(0x573C3078),
    blurRadius: 26,
    offset: Offset(0, 12),
  );

  // ── Blur — CSS `blur(Npx)` ≈ sigma N ─────────────────────────────────
  static const double blurPanel = 22;
  static const double blurTile = 18;
  static const double blurBar = 28;
  static const double blurDark = 26;

  // ── Geometry ─────────────────────────────────────────────────────────
  static const double radiusHero = 20;
  static const double radiusScore = 22;
  static const double radiusCard = 16;
  static const double radiusControl = 14;
  static const double radiusButton = 15;
  static const double radiusIconTile = 11;
  static const double radiusChip = 8;

  // ── Motion ───────────────────────────────────────────────────────────
  // The pulse and bloom are written as HALF cycles: they run reversed, so a
  // 950ms half is the design's 1.9s breath.
  static const pulseHalf = Duration(milliseconds: 950);
  static const bloomHalf = Duration(milliseconds: 3250);
  static const sweep = Duration(milliseconds: 3600);
  static const sweepHero = Duration(milliseconds: 5000);
  static const spin = Duration(milliseconds: 4500);
  static const rise = Duration(milliseconds: 500);
  static const progress = Duration(milliseconds: 450);
  static const riseCurve = Cubic(0.22, 1, 0.36, 1);

  // ── Type ─────────────────────────────────────────────────────────────
  /// Every numeral in a data role, and every uppercase micro-label.
  static const mono = 'JetBrains Mono';

  static TextStyle kickerStyle({Color color = kicker, double size = 10}) =>
      TextStyle(
        fontFamily: mono,
        fontSize: size,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: size * 0.16,
        color: color,
      );

  static TextStyle figure({
    double size = 14,
    Color color = ink,
    FontWeight weight = FontWeight.w600,
  }) => TextStyle(
    fontFamily: mono,
    fontSize: size,
    height: 1.1,
    fontWeight: weight,
    letterSpacing: size * -0.02,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// The big standalone number — proportional Inter, tightly tracked.
  static TextStyle hero({double size = 56, Color color = ink}) => TextStyle(
    fontSize: size,
    height: 1,
    fontWeight: FontWeight.w600,
    letterSpacing: size * -0.045,
    color: color,
  );

  static TextStyle title({double size = 26, Color color = ink}) => TextStyle(
    fontSize: size,
    height: 1.1,
    fontWeight: FontWeight.w600,
    letterSpacing: size * -0.035,
    color: color,
  );
}

/// A status role's four colours: the mark, the wash, the outline and the
/// words set on the wash.
typedef StatusSwatch = ({Color fill, Color tint, Color rim, Color ink});

/// R/A/G — the retail-execution industry's own compliance language — plus
/// "not measured" and "you are here".
enum LumenStatus { good, warn, crit, none, current }

extension LumenStatusStyle on LumenStatus {
  /// The word every status carries, so meaning survives greyscale.
  String get word => switch (this) {
    LumenStatus.good => 'ON STANDARD',
    LumenStatus.warn => 'AT RISK',
    LumenStatus.crit => 'BREACH',
    LumenStatus.none => 'NOT MEASURED',
    LumenStatus.current => 'CURRENT',
  };

  /// The swatch for the ambient palette. Day glass gets the handoff's exact
  /// values, night glass pastel inks on deeper washes, and the flat fallback
  /// derives from its own reserved status slots.
  StatusSwatch swatchOf(TiqColors c) {
    if (c.isNight) {
      // Night glass: the same roles lifted to pastel inks, each clearing 4.5:1
      // on its own wash over the indigo panes.
      return switch (this) {
        LumenStatus.good => (
          fill: const Color(0xE64FB985),
          tint: const Color(0x2E4FB985),
          rim: const Color(0x664FB985),
          ink: LumenGlass.onDarkGood,
        ),
        LumenStatus.warn => (
          fill: const Color(0xE6E0A43A),
          tint: const Color(0x2EE0A43A),
          rim: const Color(0x66E0A43A),
          ink: LumenGlass.onDarkWarn,
        ),
        LumenStatus.crit => (
          fill: const Color(0xE6E5534B),
          tint: const Color(0x33E5534B),
          rim: const Color(0x73E5534B),
          ink: LumenGlass.onDarkCrit,
        ),
        LumenStatus.none => (
          fill: const Color(0x8CAEACC8),
          tint: const Color(0x24AEACC8),
          rim: const Color(0x4DAEACC8),
          ink: const Color(0xFFC9C7DD),
        ),
        LumenStatus.current => (
          fill: const Color(0xEBB5ABFC),
          tint: const Color(0x33B5ABFC),
          rim: const Color(0x80B5ABFC),
          ink: const Color(0xFFD4CDFF),
        ),
      };
    }
    if (c.glass) {
      return switch (this) {
        LumenStatus.good => (
          fill: const Color(0xE61F7A4D),
          tint: const Color(0x241F7A4D),
          rim: const Color(0x4D1F7A4D),
          ink: const Color(0xFF0F5C38),
        ),
        LumenStatus.warn => (
          fill: const Color(0xE6A86A00),
          tint: const Color(0x26A86A00),
          rim: const Color(0x52A86A00),
          ink: const Color(0xFF7A4D00),
        ),
        LumenStatus.crit => (
          fill: const Color(0xE6B3261E),
          tint: const Color(0x24B3261E),
          rim: const Color(0x4DB3261E),
          ink: const Color(0xFF8C1D17),
        ),
        LumenStatus.none => (
          fill: const Color(0x8C5B5F75),
          tint: const Color(0x24787C96),
          rim: const Color(0x4D787C96),
          // Deeper than inkMuted: #5B5F75 reads only 4.3:1 on this tint over
          // the darkest end of the ground.
          ink: const Color(0xFF4E5268),
        ),
        LumenStatus.current => (
          fill: LumenGlass.accent,
          tint: const Color(0x339184D9),
          rim: const Color(0x809184D9),
          ink: LumenGlass.accentInk,
        ),
      };
    }
    final base = switch (this) {
      LumenStatus.good => c.good,
      LumenStatus.warn => c.warn,
      LumenStatus.crit => c.crit,
      LumenStatus.none => c.ink3,
      LumenStatus.current => c.series1,
    };
    return (
      fill: base,
      tint: base.withValues(alpha: 0.14),
      rim: base.withValues(alpha: 0.35),
      ink: this == LumenStatus.crit ? c.critText : base,
    );
  }
}

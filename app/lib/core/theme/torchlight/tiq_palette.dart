import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The Torchlight Aisle colour tokens, one value set per skin.
///
/// Token names are the spec's names. Every hex here is load-bearing and every
/// text/edge pairing that uses one is measured in
/// `test/core/theme/torchlight/torchlight_contrast_test.dart` — the ratios are
/// recomputed there, never copied from prose.
///
/// The amber law lives in this file's shape as much as in its values: there is
/// no `warn` token, because severity never enters the 25–45° band. Amber is
/// [flame600] and its ramp, and it is emitted light — a rim, an underbar, a
/// focus ring, a gradient stop, or (on light grounds only) exactly one filled
/// commit block per screen.
@immutable
class TiqPalette {
  const TiqPalette({
    required this.ground,
    required this.vignette,
    required this.well,
    required this.surface,
    required this.raised,
    required this.lifted,
    required this.hairline,
    required this.edgeStructure,
    required this.edgeControl,
    required this.navInkInactive,
    required this.inkMute,
    required this.ink1,
    required this.ink2,
    required this.ink3,
    required this.chartNeutral,
    required this.flame300,
    required this.flame500,
    required this.flame600,
    required this.flame700,
    required this.flame900,
    required this.good,
    required this.goodSolid,
    required this.onGoodSolid,
    required this.bad,
    required this.badSolid,
    required this.onBadSolid,
    required this.comparison,
    required this.comparisonWash,
    required this.onAmber,
    required this.amberPressed,
    required this.onAmberPressed,
    required this.scrim,
  });

  // ── Grounds and surfaces ─────────────────────────────────────────────
  /// App ground, full bleed. Night `#0B1017`, Day Palladian, Veld pure white.
  final Color ground;

  /// Midpoint stop of the ground's letterbox falloff and the plate's baked
  /// edge-dissolve. Four perceptually even stops, because two band on a 6-bit
  /// panel.
  final Color vignette;

  /// Recessed surfaces: input troughs, nav-bar body, queue chip, mono blocks.
  final Color well;

  /// The one panel surface: the AI answer's instrument panel, forms, sheets.
  final Color surface;

  /// Stat-tile cells, scrub readouts, the question bubble.
  final Color raised;

  /// Pressed/hover, chart bar tracks, mono readout blocks. On Day it is the
  /// ink block behind an active nav slot.
  final Color lifted;

  // ── Edges ────────────────────────────────────────────────────────────
  /// DECORATIVE rules only: section rules, list separators, chart gridlines.
  /// Never the sole identifier of anything, and never the only cue that two
  /// regions differ — it is deliberately below 3:1.
  final Color hairline;

  /// The compliant edge for CONTAINERS: panel outlines, sheet edges, the
  /// plate's text-safe divider. ≥3:1 on the fill it bounds and the ground it
  /// sits on — except the Day well, where it is banned (2.99:1).
  final Color edgeStructure;

  /// The compliant edge for CONTROLS: outlined chips, input troughs, ghost
  /// buttons, the chip rail. Louder than a container edge on purpose.
  final Color edgeControl;

  /// Inactive tab-bar icon and label — real text at ≥4.5:1 on the nav body,
  /// not a ghost.
  final Color navInkInactive;

  /// Disabled ink and unfilled ladder glyphs ONLY. Deliberately sub-AA:
  /// disabled controls are exempt under 1.4.3 and must look disabled.
  final Color inkMute;

  // ── Ink ──────────────────────────────────────────────────────────────
  /// Body and headline text, hero figures, the focus bar fill on light
  /// grounds.
  final Color ink1;

  /// Secondary text: reasons, subtitles, chip labels, eyebrows.
  final Color ink2;

  /// Tertiary / meta: timestamps, units, axis labels, source lines.
  final Color ink3;

  // ── Data ─────────────────────────────────────────────────────────────
  /// The fill of every non-focus ranked bar and non-focus series. Exists
  /// because Burning Flame and Oatmeal share a relative luminance (1.00:1) and
  /// are therefore the same bar in greyscale, in deuteranopia and in sun.
  ///
  /// **Moved in Phase 1** (unify §1.4). Night `#8B8271` → `#A39887`; Day
  /// `#676052` → `#5C5648`. The old Night value measured 3.01:1 against the
  /// `lifted` track — the product's most-drawn graphic sitting on the AA floor
  /// with 0.01 of margin, which on a 6-bit panel at 40% backlight is a smudge.
  /// The old Day value was byte-identical to Day [ink3], so a bar and a meta
  /// line were the same token by accident. The floor did not move (a bar is a
  /// graphic at 3:1, not text at 4.5:1); the margin did.
  final Color chartNeutral;

  // ── Amber — emitted light, never a label ─────────────────────────────
  /// The ONLY amber allowed as text on a light ground.
  final Color flame300;

  /// Pressed state of an amber block; the second stop of the strip-light
  /// gradient.
  final Color flame500;

  /// The signature. Night: strip lights, underbars, focus rings, one focus
  /// bar. Day/Veld: one solid block per screen, carrying dark ink.
  final Color flame600;

  /// Amber as TEXT on dark, focus rings, the hot end of the bloom.
  final Color flame700;

  /// The white-hot core stop of an amber glow gradient. NEVER ink on an amber
  /// fill — see the banned pairings.
  final Color flame900;

  /// The ink that goes on a [flame600] block in this skin.
  final Color onAmber;

  /// The fill an amber block takes while it is held down, and the ink on it.
  ///
  /// On dark and paper grounds this is [flame500] — the amber gets hotter and
  /// the ink stays dark (8.59:1), which is the fix for a pressed state that
  /// used to put flame-900 on flame-500 at 2.00:1 and make the label vanish at
  /// the moment of commitment.
  ///
  /// Veld does NOT lighten. veld-ink on flame-500 is 8.34:1, under the 9:1
  /// floor Veld declares for every word it shows — the design document asserted
  /// both and they cannot both be true. Outdoors the press inverts to the ink
  /// block with white on it (15.33:1) instead, which is also the only press cue
  /// Veld can afford: it has no glow, no shadow and no gradient to spend.
  final Color amberPressed;
  final Color onAmberPressed;

  // ── Severity — one hue, two commitment levels, never amber ───────────
  final Color good;
  final Color goodSolid;
  final Color onGoodSolid;
  final Color bad;
  final Color badSolid;
  final Color onBadSolid;

  /// The comparison series: competitor share, prior period, benchmark. Also
  /// the held / queued / low-light warm neutral. NEVER a severity.
  final Color comparison;
  final Color comparisonWash;

  /// Sheet and dialog scrim.
  final Color scrim;

  /// The maximum luminance any pixel of a baked photographic plate may reach.
  /// A contrast floor, not a decoration: [ink1] on a plate pixel at this
  /// ceiling is 7.68:1. Enforced server-side; the token exists so the client
  /// test can assert the floor it implies.
  static const Color plateCeiling = Color(0xFF474747);

  /// The pixel a text scrim over a full-value amber strip light actually
  /// paints: `ground @ 80%` composited over `#FFB162`, quantised to 8 bits.
  /// Declared rather than computed so the worst case the hero number can meet
  /// is a value someone can look at.
  static const Color plateScrimOverStripLight = Color(0xFF3C3026);

  /// Alpha ramp stops for every amber bloom. Always a gradient, never a blur
  /// filter and never a [BoxShadow].
  static const List<Color> glowAmber = <Color>[
    Color(0x8CFFF1DE), // #FFF1DE @ 0.55
    Color(0x4DFFB162), // #FFB162 @ 0.30
    Color(0x00FFB162), // transparent
  ];

  /// NIGHT — the near-black console. Warm off-white ink on a cool navy-black
  /// ground is what makes it read as lit rather than switched off.
  static const TiqPalette night = TiqPalette(
    ground: Color(0xFF0B1017),
    vignette: Color(0xFF0F1620),
    well: Color(0xFF141D27),
    surface: Color(0xFF1B2632),
    raised: Color(0xFF22303E),
    lifted: Color(0xFF2C3B4D),
    hairline: Color(0xFF3A4B60),
    edgeStructure: Color(0xFF5B718A),
    edgeControl: Color(0xFF7C93AC),
    navInkInactive: Color(0xFF8AA0B8),
    inkMute: Color(0xFF4C6079),
    ink1: Color(0xFFEEE9DF),
    ink2: Color(0xFFC9C1B1),
    ink3: Color(0xFFA79E8C),
    chartNeutral: Color(0xFFA39887),
    flame300: Color(0xFF8A4A12),
    flame500: Color(0xFFF79742),
    flame600: Color(0xFFFFB162),
    flame700: Color(0xFFFFCB94),
    flame900: Color(0xFFFFF1DE),
    onAmber: Color(0xFF0B1017),
    amberPressed: Color(0xFFF79742),
    onAmberPressed: Color(0xFF0B1017),
    good: Color(0xFF6FE0AE),
    goodSolid: Color(0xFFC9F5E1),
    onGoodSolid: Color(0xFF0B1017),
    bad: Color(0xFFFF7D8C),
    badSolid: Color(0xFFE23C55),
    onBadSolid: Color(0xFF0B1017),
    comparison: Color(0xFFE08E71),
    comparisonWash: Color(0xFF7A3A28),
    scrim: Color(0xB80B1017), // abyss-000 @ 72%
  );

  /// DAY — Palladian paper. The field agent's default, and deliberately not
  /// cinematic.
  static const TiqPalette day = TiqPalette(
    ground: Color(0xFFEEE9DF),
    vignette: Color(0xFFE6E0D4),
    well: Color(0xFFE2DBCC),
    surface: Color(0xFFFAF7F2),
    raised: Color(0xFFF4F0E8),
    lifted: Color(0xFF2C3B4D),
    hairline: Color(0xFFDED7C9),
    edgeStructure: Color(0xFF857C6B),
    edgeControl: Color(0xFF6E6657),
    navInkInactive: Color(0xFF6E6657),
    inkMute: Color(0xFF9B917F),
    ink1: Color(0xFF1B2632),
    ink2: Color(0xFF4A4437),
    ink3: Color(0xFF676052),
    chartNeutral: Color(0xFF5C5648),
    flame300: Color(0xFF8A4A12),
    flame500: Color(0xFFF79742),
    flame600: Color(0xFFFFB162),
    flame700: Color(0xFFFFCB94),
    flame900: Color(0xFFFFF1DE),
    onAmber: Color(0xFF1B2632),
    amberPressed: Color(0xFFF79742),
    onAmberPressed: Color(0xFF1B2632),
    good: Color(0xFF14664A),
    goodSolid: Color(0xFF0F5039),
    onGoodSolid: Color(0xFFFFFFFF),
    bad: Color(0xFF8C1B2C),
    badSolid: Color(0xFF7A0F22),
    onBadSolid: Color(0xFFFFFFFF),
    comparison: Color(0xFFA35139),
    comparisonWash: Color(0xFFF7DCD2),
    scrim: Color(0xB81B2632),
  );

  /// VELD — outdoor high-contrast. Pure white ground, near-black ink, nothing
  /// under 9:1 for text and nothing under 15:1 for a border. Every shadow,
  /// gradient, rim, blur and glow is removed, not softened.
  ///
  /// Veld changes the physics, not the palette: its recessed/raised tokens all
  /// collapse onto white, because a fill step is not a cue an entry LCD at 40%
  /// backlight in highveld sun can resolve.
  static const TiqPalette veld = TiqPalette(
    ground: Color(0xFFFFFFFF),
    vignette: Color(0xFFFFFFFF),
    well: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFFFFFFF),
    lifted: Color(0xFF1B2632),
    hairline: Color(0xFF1B2632), // every hairline becomes a 2px solid border
    edgeStructure: Color(0xFF1B2632),
    edgeControl: Color(0xFF1B2632),
    navInkInactive: Color(0xFF4A4437),
    inkMute: Color(0xFF4A4437),
    ink1: Color(0xFF0E141A),
    ink2: Color(0xFF4A4437),
    ink3: Color(0xFF4A4437),
    chartNeutral: Color(0xFF4A4437),
    flame300: Color(0xFF8A4A12),
    flame500: Color(0xFFF79742),
    flame600: Color(0xFFFFB162),
    flame700: Color(0xFFFFCB94),
    flame900: Color(0xFFFFF1DE),
    onAmber: Color(0xFF0E141A),
    amberPressed: Color(0xFF1B2632),
    onAmberPressed: Color(0xFFFFFFFF),
    good: Color(0xFF0F5039),
    goodSolid: Color(0xFF0F5039),
    onGoodSolid: Color(0xFFFFFFFF),
    bad: Color(0xFF7A0F22),
    badSolid: Color(0xFF7A0F22),
    onBadSolid: Color(0xFFFFFFFF),
    comparison: Color(0xFFA35139),
    comparisonWash: Color(0xFFF7DCD2),
    scrim: Color(0xB80E141A),
  );

  TiqPalette lerp(TiqPalette other, double t) {
    if (t <= 0) return this;
    if (t >= 1) return other;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return TiqPalette(
      ground: c(ground, other.ground),
      vignette: c(vignette, other.vignette),
      well: c(well, other.well),
      surface: c(surface, other.surface),
      raised: c(raised, other.raised),
      lifted: c(lifted, other.lifted),
      hairline: c(hairline, other.hairline),
      edgeStructure: c(edgeStructure, other.edgeStructure),
      edgeControl: c(edgeControl, other.edgeControl),
      navInkInactive: c(navInkInactive, other.navInkInactive),
      inkMute: c(inkMute, other.inkMute),
      ink1: c(ink1, other.ink1),
      ink2: c(ink2, other.ink2),
      ink3: c(ink3, other.ink3),
      chartNeutral: c(chartNeutral, other.chartNeutral),
      flame300: c(flame300, other.flame300),
      flame500: c(flame500, other.flame500),
      flame600: c(flame600, other.flame600),
      flame700: c(flame700, other.flame700),
      flame900: c(flame900, other.flame900),
      onAmber: c(onAmber, other.onAmber),
      amberPressed: c(amberPressed, other.amberPressed),
      onAmberPressed: c(onAmberPressed, other.onAmberPressed),
      good: c(good, other.good),
      goodSolid: c(goodSolid, other.goodSolid),
      onGoodSolid: c(onGoodSolid, other.onGoodSolid),
      bad: c(bad, other.bad),
      badSolid: c(badSolid, other.badSolid),
      onBadSolid: c(onBadSolid, other.onBadSolid),
      comparison: c(comparison, other.comparison),
      comparisonWash: c(comparisonWash, other.comparisonWash),
      scrim: c(scrim, other.scrim),
    );
  }
}

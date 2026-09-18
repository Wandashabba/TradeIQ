import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'tiq_skin.dart';

/// WCAG 2.x relative luminance and contrast ratio.
///
/// Written out in full rather than pulled from a package so a palette
/// regression fails with the actual number in the message, and so the
/// production code and the test cannot compute it differently.
double _linearize(double channel) => channel <= 0.04045
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

double relativeLuminance(Color c) =>
    0.2126 * _linearize(c.r) +
    0.7152 * _linearize(c.g) +
    0.0722 * _linearize(c.b);

/// The ratio between two opaque colours, 1.0–21.0.
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// What a pairing has to clear.
enum ContrastRole {
  /// Body text and anything under 18.66px / 24px-bold. 4.5:1.
  text(4.5),

  /// Large text — ≥24px, or ≥18.66px at 600+. 3:1.
  largeText(3.0),

  /// A UI component boundary or a meaningful graphic. WCAG 1.4.11. 3:1.
  graphic(3.0),

  /// Decorative, or exempt under 1.4.3 (disabled controls). No floor — but it
  /// must be *declared* exempt, with the reason, so that "it's decorative" is
  /// a decision on the record rather than an excuse found later.
  exempt(1.0),

  /// Veld's own floor. Nothing that carries a word outdoors goes under 9:1.
  veldText(9.0),

  /// Veld's border floor.
  veldBorder(15.0);

  const ContrastRole(this.floor);

  final double floor;
}

/// One declared pairing. The ratio is NOT stored — it is recomputed from the
/// tokens every time the test runs, so the table can never drift from the
/// palette the way a hand-written contrast table always does.
@immutable
class ContrastPairing {
  const ContrastPairing({
    required this.skin,
    required this.label,
    required this.foreground,
    required this.background,
    required this.role,
    this.note,
  });

  final String skin;
  final String label;
  final Color foreground;
  final Color background;
  final ContrastRole role;
  final String? note;

  double get ratio => contrastRatio(foreground, background);

  bool get passes => ratio >= role.floor;
}

/// A pairing that is FORBIDDEN, with the number that forbids it.
///
/// A banned pairing is not simply an absent one: it is written down, its ratio
/// is recomputed, and the test asserts that it really does fail the floor it
/// would need. That keeps a ban from surviving as folklore after someone
/// changes a token and quietly makes it legal — and keeps anyone from
/// "fixing" the ban by reintroducing the pairing.
@immutable
class BannedPairing {
  const BannedPairing({
    required this.skin,
    required this.label,
    required this.foreground,
    required this.background,
    required this.wouldNeed,
    required this.instead,
  });

  final String skin;
  final String label;
  final Color foreground;
  final Color background;

  /// The floor this pairing would have to clear for its role.
  final ContrastRole wouldNeed;

  /// What to use instead. Every ban names a replacement; a ban without one is
  /// a dead end and someone will walk back into it.
  final String instead;

  double get ratio => contrastRatio(foreground, background);
}

/// The declared contrast contract for Torchlight Aisle.
class TorchlightContrast {
  TorchlightContrast._();

  static final TiqSkin _night = TiqSkin.night();
  static final TiqSkin _day = TiqSkin.day();
  static final TiqSkin _veld = TiqSkin.veld();

  /// The scrim that sits under any text block laid over a plate:
  /// `ground @ 80%`. The worst case a hero number can meet is this scrim over
  /// a full-value amber strip light.
  static Color plateScrim(TiqPalette p, Color over) =>
      Color.alphaBlend(p.ground.withValues(alpha: 0.80), over);

  static List<ContrastPairing> get declared {
    final n = _night.palette;
    final d = _day.palette;
    final v = _veld.palette;
    return <ContrastPairing>[
      // ── NIGHT ────────────────────────────────────────────────────────
      ContrastPairing(
        skin: 'night',
        label: 'ink-1 on ground',
        foreground: n.ink1,
        background: n.ground,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'ink-1 on surface',
        foreground: n.ink1,
        background: n.surface,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'ink-1 on raised',
        foreground: n.ink1,
        background: n.raised,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'ink-2 on ground',
        foreground: n.ink2,
        background: n.ground,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'ink-2 on surface',
        foreground: n.ink2,
        background: n.surface,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'ink-3 (12px meta) on ground',
        foreground: n.ink3,
        background: n.ground,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'ink-3 (12px meta) on raised — the binding case',
        foreground: n.ink3,
        background: n.raised,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'ink-3 on well',
        foreground: n.ink3,
        background: n.well,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'hero figure flame-600 on ground',
        foreground: n.flame600,
        background: n.ground,
        role: ContrastRole.largeText,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'amber text flame-700 on ground',
        foreground: n.flame700,
        background: n.ground,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'focus ring flame-700 on surface',
        foreground: n.flame700,
        background: n.surface,
        role: ContrastRole.graphic,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'focus ring flame-700 on raised',
        foreground: n.flame700,
        background: n.raised,
        role: ContrastRole.graphic,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'amber rim flame-600 on raised',
        foreground: n.flame600,
        background: n.raised,
        role: ContrastRole.graphic,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'active-tab underbar flame-600 on nav body (well)',
        foreground: n.flame600,
        background: n.well,
        role: ContrastRole.graphic,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'focus bar flame-600 on chart track (lifted)',
        foreground: n.flame600,
        background: n.lifted,
        role: ContrastRole.graphic,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'neutral bar chart-neutral on chart track (lifted)',
        foreground: n.chartNeutral,
        background: n.lifted,
        role: ContrastRole.graphic,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'good on ground',
        foreground: n.good,
        background: n.ground,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'good on raised',
        foreground: n.good,
        background: n.raised,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'bad on ground',
        foreground: n.bad,
        background: n.ground,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'bad on raised',
        foreground: n.bad,
        background: n.raised,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'bad on well',
        foreground: n.bad,
        background: n.well,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'comparison on ground',
        foreground: n.comparison,
        background: n.ground,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'comparison on raised',
        foreground: n.comparison,
        background: n.raised,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'edge-control on ground',
        foreground: n.edgeControl,
        background: n.ground,
        role: ContrastRole.graphic,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'edge-control on surface',
        foreground: n.edgeControl,
        background: n.surface,
        role: ContrastRole.graphic,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'edge-control on raised',
        foreground: n.edgeControl,
        background: n.raised,
        role: ContrastRole.graphic,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'edge-structure on surface — the Panel outline',
        foreground: n.edgeStructure,
        background: n.surface,
        role: ContrastRole.graphic,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'edge-structure on ground',
        foreground: n.edgeStructure,
        background: n.ground,
        role: ContrastRole.graphic,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'nav ink inactive on nav body (well)',
        foreground: n.navInkInactive,
        background: n.well,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'ink on amber block',
        foreground: n.onAmber,
        background: n.flame600,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'ink on pressed amber block (flame-500)',
        foreground: n.onAmberPressed,
        background: n.amberPressed,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'ink on solid critical block',
        foreground: n.onBadSolid,
        background: n.badSolid,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'ink on solid success block',
        foreground: n.onGoodSolid,
        background: n.goodSolid,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'night',
        label: 'decorative hairline on ground',
        foreground: n.hairline,
        background: n.ground,
        role: ContrastRole.exempt,
        note:
            'Decorative only — never the sole identifier of anything and never '
            'the only cue that two regions differ.',
      ),
      ContrastPairing(
        skin: 'night',
        label: 'disabled ink-mute on surface',
        foreground: n.inkMute,
        background: n.surface,
        role: ContrastRole.exempt,
        note:
            'WCAG 1.4.3 exempts disabled controls, and a disabled control has '
            'to look disabled.',
      ),
      // ── PLATE ────────────────────────────────────────────────────────
      ContrastPairing(
        skin: 'plate',
        label: 'ink-1 on an unscrimmed plate pixel at the luminance ceiling',
        foreground: n.ink1,
        background: TiqPalette.plateCeiling,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'plate',
        label: 'ink-1 on the mandatory scrim over a full-value strip light',
        foreground: n.ink1,
        background: TiqPalette.plateScrimOverStripLight,
        role: ContrastRole.text,
        note: 'The worst case the hero number can ever encounter.',
      ),
      ContrastPairing(
        skin: 'plate',
        label: 'ink-2 eyebrow on that same worst-case scrimmed amber',
        foreground: n.ink2,
        background: TiqPalette.plateScrimOverStripLight,
        role: ContrastRole.text,
      ),
      // ── DAY ──────────────────────────────────────────────────────────
      ContrastPairing(
        skin: 'day',
        label: 'ink-1 on ground',
        foreground: d.ink1,
        background: d.ground,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'day',
        label: 'ink-1 on card (surface)',
        foreground: d.ink1,
        background: d.surface,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'day',
        label: 'ink-2 on ground',
        foreground: d.ink2,
        background: d.ground,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'day',
        label: 'ink-3 (12px meta) on ground',
        foreground: d.ink3,
        background: d.ground,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'day',
        label: 'ink-3 on well — the darkest Day surface',
        foreground: d.ink3,
        background: d.well,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'day',
        label: 'flame-300, the one legal amber text on a light ground',
        foreground: d.flame300,
        background: d.ground,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'day',
        label: 'ink on the one amber block',
        foreground: d.onAmber,
        background: d.flame600,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'day',
        label: 'good on ground',
        foreground: d.good,
        background: d.ground,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'day',
        label: 'bad on ground',
        foreground: d.bad,
        background: d.ground,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'day',
        label: 'comparison on ground',
        foreground: d.comparison,
        background: d.ground,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'day',
        label: 'edge-control on ground',
        foreground: d.edgeControl,
        background: d.ground,
        role: ContrastRole.graphic,
      ),
      ContrastPairing(
        skin: 'day',
        label: 'edge-structure on ground — the Panel outline',
        foreground: d.edgeStructure,
        background: d.ground,
        role: ContrastRole.graphic,
      ),
      ContrastPairing(
        skin: 'day',
        label: 'neutral bar on chart track (well)',
        foreground: d.chartNeutral,
        background: d.well,
        role: ContrastRole.graphic,
      ),
      ContrastPairing(
        skin: 'day',
        label: 'focus bar ink-1 on chart track (well)',
        foreground: d.ink1,
        background: d.well,
        role: ContrastRole.graphic,
        note:
            'Amber is not the focus channel on light grounds — the one amber '
            'block is already spent on the primary action.',
      ),
      ContrastPairing(
        skin: 'day',
        label: 'nav-active: ground ink on the lifted block',
        foreground: d.ground,
        background: d.lifted,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'day',
        label: 'ink on solid critical block',
        foreground: d.onBadSolid,
        background: d.badSolid,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'day',
        label: 'ink on solid success block',
        foreground: d.onGoodSolid,
        background: d.goodSolid,
        role: ContrastRole.text,
      ),
      ContrastPairing(
        skin: 'day',
        label: 'decorative hairline on ground',
        foreground: d.hairline,
        background: d.ground,
        role: ContrastRole.exempt,
        note: 'Decorative only.',
      ),
      // ── VELD ─────────────────────────────────────────────────────────
      ContrastPairing(
        skin: 'veld',
        label: 'body ink on white',
        foreground: v.ink1,
        background: v.ground,
        role: ContrastRole.veldText,
      ),
      ContrastPairing(
        skin: 'veld',
        label: 'secondary ink on white',
        foreground: v.ink2,
        background: v.ground,
        role: ContrastRole.veldText,
      ),
      ContrastPairing(
        skin: 'veld',
        label: 'tertiary ink on white',
        foreground: v.ink3,
        background: v.ground,
        role: ContrastRole.veldText,
      ),
      ContrastPairing(
        skin: 'veld',
        label: 'neutral bar on white',
        foreground: v.chartNeutral,
        background: v.ground,
        role: ContrastRole.veldText,
      ),
      ContrastPairing(
        skin: 'veld',
        label: '2px structural border on white',
        foreground: v.edgeStructure,
        background: v.ground,
        role: ContrastRole.veldBorder,
      ),
      ContrastPairing(
        skin: 'veld',
        label: '2px control border on white',
        foreground: v.edgeControl,
        background: v.ground,
        role: ContrastRole.veldBorder,
      ),
      ContrastPairing(
        skin: 'veld',
        label: 'hairline (a 2px solid border here) on white',
        foreground: v.hairline,
        background: v.ground,
        role: ContrastRole.veldBorder,
      ),
      ContrastPairing(
        skin: 'veld',
        label: 'ink on the one amber block',
        foreground: v.onAmber,
        background: v.flame600,
        role: ContrastRole.veldText,
      ),
      ContrastPairing(
        skin: 'veld',
        label: 'ink on the pressed amber block',
        foreground: v.onAmberPressed,
        background: v.amberPressed,
        role: ContrastRole.veldText,
        note:
            'Veld does not lighten on press: veld-ink on flame-500 is 8.34:1, '
            'under the 9:1 floor Veld declares for every word. It inverts to '
            'the ink block instead.',
      ),
      ContrastPairing(
        skin: 'veld',
        label: 'ink on solid success block',
        foreground: v.onGoodSolid,
        background: v.goodSolid,
        role: ContrastRole.veldText,
      ),
      ContrastPairing(
        skin: 'veld',
        label: 'ink on solid critical block',
        foreground: v.onBadSolid,
        background: v.badSolid,
        role: ContrastRole.veldText,
      ),
      ContrastPairing(
        skin: 'veld',
        label: 'white ink on the lifted (Abyssal) block',
        foreground: v.ground,
        background: v.lifted,
        role: ContrastRole.veldText,
      ),
    ];
  }

  /// Every pairing that is forbidden, and why.
  static List<BannedPairing> get banned {
    final n = _night.palette;
    final d = _day.palette;
    final v = _veld.palette;
    return <BannedPairing>[
      BannedPairing(
        skin: 'night',
        label: 'flame-600 and ink-2 (Oatmeal) as adjacent bar fills',
        foreground: n.flame600,
        background: n.ink2,
        wouldNeed: ContrastRole.graphic,
        instead:
            'chart-neutral #8B8271 for every non-focus bar. Burning Flame and '
            'Oatmeal have the same relative luminance, so this pairing is one '
            'bar in greyscale, in deuteranopia and on a sun-washed panel.',
      ),
      BannedPairing(
        skin: 'night',
        label: 'flame-900 ink on a pressed flame-500 block',
        foreground: n.flame900,
        background: n.flame500,
        wouldNeed: ContrastRole.text,
        instead:
            'onAmber (the ground colour) stays dark through the press. The '
            'label must not vanish at the moment of commitment.',
      ),
      BannedPairing(
        skin: 'day',
        label: 'flame-600 as text on the Palladian ground',
        foreground: d.flame600,
        background: d.ground,
        wouldNeed: ContrastRole.text,
        instead:
            'flame-300 #8A4A12 — the only amber legal as text on a light '
            'ground.',
      ),
      BannedPairing(
        skin: 'day',
        label: 'edge-structure on the Day well',
        foreground: d.edgeStructure,
        background: d.well,
        wouldNeed: ContrastRole.graphic,
        instead:
            'edge-control #6E6657, or put the container on the ground or the '
            'surface instead of in the well.',
      ),
      BannedPairing(
        skin: 'veld',
        label: 'flame-600 as a line, icon, border or word on white',
        foreground: v.flame600,
        background: v.ground,
        wouldNeed: ContrastRole.graphic,
        instead:
            'A solid amber block carrying veld-ink, once per screen, on the '
            'primary commit action — or veld-ink itself for a line or a word.',
      ),
    ];
  }
}

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

/// The inverse of [_linearize] — a linear channel back to sRGB.
double _encode(double linear) {
  final l = linear.clamp(0.0, 1.0);
  return l <= 0.0031308
      ? l * 12.92
      : 1.055 * math.pow(l, 1 / 2.4).toDouble() - 0.055;
}

/// How a viewer sees a colour.
///
/// Every hue-coded distinction in this system has to survive all four. The
/// simulations are here, in the production file, rather than in the test, for
/// the same reason [contrastRatio] is: a palette regression has to fail with
/// the real number, and the code and the test must not be able to compute it
/// two different ways.
enum VisionFilter {
  /// Normal colour vision.
  trichromat,

  /// Relative-luminance greyscale: a sun-washed panel, a photocopier, a
  /// monochromat, a fax of a printed report.
  ///
  /// Note that [contrastRatio] is *already* a luminance-only metric, so the
  /// greyscale ratio of a pair equals its true ratio by construction. That is
  /// not a flaw in the test — it is the finding: a pair that measures 1.42:1
  /// in colour measures 1.42:1 in greyscale, which is why hue is never allowed
  /// to be the only channel. The greyscale pass earns its place by making that
  /// arithmetic explicit and by proving the two colours are not *identical*
  /// once hue is removed.
  greyscale,

  /// Deuteranopia (no M cone) — about 1 man in 16 across the agent workforce.
  deuteranopia,

  /// Protanopia (no L cone). The harsher of the two for anything in the
  /// crimson band, which is where this system puts severity.
  protanopia;

  bool get isDichromacy =>
      this == VisionFilter.deuteranopia || this == VisionFilter.protanopia;
}

/// Viénot, Brettel & Mollon (1999), applied to linear RGB.
///
/// Chosen over Brettel's full two-plane method because it is the one every
/// accessibility tool in common use implements, so a number here is a number
/// someone can reproduce. The ruling's own figures come out of it exactly:
/// Burning Flame against Truffle is 1.40:1 in deuteranopia, and `bad` against
/// `chartNeutral` is 1.06:1 in protanopia — both recomputed and pinned in
/// `torchlight_generated_contrast_test.dart`. (`bad`/`chartNeutral` was 1.26:1
/// before Phase 1 moved the neutral to #A39887; the two hues converged, which
/// makes the hatch on a diverging negative more load-bearing, not less.)
const List<List<double>> _protanopia = <List<double>>[
  <double>[0.11238, 0.88762, 0.0],
  <double>[0.11238, 0.88762, 0.0],
  <double>[0.00401, -0.00401, 1.0],
];

const List<List<double>> _deuteranopia = <List<double>>[
  <double>[0.29275, 0.70725, 0.0],
  <double>[0.29275, 0.70725, 0.0],
  <double>[-0.02234, 0.02234, 1.0],
];

/// [c] as [filter] sees it.
Color simulateVision(Color c, VisionFilter filter) {
  switch (filter) {
    case VisionFilter.trichromat:
      return c;
    case VisionFilter.greyscale:
      final channel = _encode(relativeLuminance(c));
      return Color.from(alpha: 1, red: channel, green: channel, blue: channel);
    case VisionFilter.deuteranopia:
    case VisionFilter.protanopia:
      final m = filter == VisionFilter.deuteranopia
          ? _deuteranopia
          : _protanopia;
      final v = <double>[_linearize(c.r), _linearize(c.g), _linearize(c.b)];
      return Color.from(
        alpha: 1,
        red: _encode(m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2]),
        green: _encode(m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2]),
        blue: _encode(m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2]),
      );
  }
}

/// The contrast between two colours as [filter] sees them.
double separationUnder(Color a, Color b, VisionFilter filter) =>
    contrastRatio(simulateVision(a, filter), simulateVision(b, filter));

/// The channel that is doing the work when hue is not.
///
/// "It also has a different shape" is a claim, and a claim in a review comment
/// does not survive the component being rewritten. Declaring the channel makes
/// it a value the test can insist on.
enum SeparationChannel {
  /// A different silhouette: a triangle against a square, a ring against a
  /// disc, a barred ring against a half-disc.
  shape,

  /// A heavier stroke or a heavier weight.
  weight,

  /// Solid against dashed. Mandatory on the amber/Truffle series pair.
  dash,

  /// One of the four [HatchPattern]s.
  hatch,

  /// Outlined against filled.
  outline,

  /// A word. The strongest channel there is, and the only one a screen reader
  /// can read.
  word,

  /// A position the other member cannot occupy — a tick breaking a track's top
  /// edge, a bar on a diverging axis's negative side.
  position,
}

/// Two things a reader has to tell apart, and what tells them apart when hue
/// cannot.
@immutable
class SeriesPair {
  const SeriesPair({
    required this.skin,
    required this.label,
    required this.a,
    required this.b,
    required this.channels,
    required this.why,
  });

  final String skin;
  final String label;
  final Color a;
  final Color b;

  /// The non-colour channels this pair carries. Never empty: every hue-coded
  /// distinction in this system carries a second channel, whether or not the
  /// luminance happens to be generous today.
  final Set<SeparationChannel> channels;

  /// One sentence. Why these two are on a screen together at all.
  final String why;

  double under(VisionFilter filter) => separationUnder(a, b, filter);

  /// The worst the pair ever gets, across every way of seeing it.
  double get worst =>
      VisionFilter.values.map(under).reduce((x, y) => x < y ? x : y);

  /// Which filter produces [worst].
  VisionFilter get worstFilter =>
      VisionFilter.values.reduce((x, y) => under(x) <= under(y) ? x : y);
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

  /// EVERY legal ink-on-fill and edge-on-fill pairing for one skin at one
  /// density, generated rather than listed.
  ///
  /// [declared] is the hand-written contract: the pairings a person thought
  /// about, with the notes that say why. This is the other half — the
  /// combinatorial sweep that catches the pairing nobody thought about, at
  /// every density, with the floor taken from the type role that is actually
  /// set in it. `meta` at 12px needs 4.5:1; `figure.l` at 32px needs 3.0:1;
  /// the same two colours are therefore two different verdicts depending on
  /// what is set in them, and only a generator gets that right every time.
  ///
  /// The legal matrices below are the design, not a convenience:
  ///
  /// * **Text grounds** are L0–L3. `lifted` is not one: it is a chart track
  ///   and, on Day, the nav-active ink block, and the only thing set on it is
  ///   the skin's own `ground` colour.
  /// * **`edgeStructure`** bounds an L2 container, which sits on the ground or
  ///   is the surface. It never bounds an L3 `raised` (2.67:1 in Night) —
  ///   an L3 lives inside an L2 that already has an edge and is divided by
  ///   hairlines — and it never bounds an L1 `well`, which is banned outright
  ///   on Day at 2.99:1 and is a surface whose job is to recede.
  /// * **`edgeControl`** bounds a control, and a control may sit anywhere,
  ///   including in a trough.
  static List<ContrastPairing> generatedFor(TiqSkin skin) {
    final p = skin.palette;
    final name = skin.mode.name;
    final density = skin.density.name;
    final out = <ContrastPairing>[];

    final textGrounds = <String, Color>{
      'ground': p.ground,
      'well': p.well,
      'surface': p.surface,
      'raised': p.raised,
    };
    // The ink ramp only. `good`, `bad` and `comparison` are *marks* that
    // sometimes carry a word, and where they do the pairing is written down by
    // hand in [declared] with the surface it is written for — Truffle as text
    // on the Day well is 4.02:1 and on Veld white is 5.54:1, and neither is a
    // pairing this system uses. Sweeping them everywhere would fail on
    // combinations nothing renders, which is how a generated test gets
    // switched off.
    final inks = <String, Color>{
      'ink-1': p.ink1,
      'ink-2': p.ink2,
      'ink-3': p.ink3,
    };

    for (final role in skin.text.all) {
      final roleFloor = _roleContrast(role);
      final floor = skin.floorFor(roleFloor.floor, isText: true);
      final effective = _roleFor(floor);
      for (final MapEntry(key: inkName, value: ink) in inks.entries) {
        for (final MapEntry(key: bgName, value: bg) in textGrounds.entries) {
          out.add(
            ContrastPairing(
              skin: '$name/$density',
              label: '$inkName at ${role.name} on $bgName',
              foreground: ink,
              background: bg,
              role: effective,
            ),
          );
        }
      }
    }

    final graphic = _roleFor(
      skin.floorFor(ContrastRole.graphic.floor, isText: false),
    );
    for (final MapEntry(key: bgName, value: bg) in <String, Color>{
      'ground': p.ground,
      'surface': p.surface,
    }.entries) {
      out.add(
        ContrastPairing(
          skin: '$name/$density',
          label: 'edge-structure bounding a container on $bgName',
          foreground: p.edgeStructure,
          background: bg,
          role: graphic,
        ),
      );
    }
    for (final MapEntry(key: bgName, value: bg) in textGrounds.entries) {
      out.add(
        ContrastPairing(
          skin: '$name/$density',
          label: 'edge-control bounding a control on $bgName',
          foreground: p.edgeControl,
          background: bg,
          role: graphic,
        ),
      );
    }
    return out;
  }

  /// Every skin × density the app can actually build. Veld appears once
  /// because `TiqSkin.veld()` takes no density argument — `Veld × Console`
  /// has no spelling, and a generator that invented one would be testing a
  /// configuration no user can reach.
  static List<TiqSkin> get allSkinsAndDensities => <TiqSkin>[
    TiqSkin.night(density: TiqDensity.console),
    TiqSkin.night(density: TiqDensity.field),
    TiqSkin.day(density: TiqDensity.console),
    TiqSkin.day(density: TiqDensity.field),
    TiqSkin.veld(),
  ];

  /// WCAG 1.4.3's large-text rule, applied to a declared role rather than
  /// guessed at a call site: 24px, or 18.66px at 600 and above.
  static ContrastRole _roleContrast(TiqTypeToken role) =>
      role.size >= 24 ||
          (role.size >= 18.66 && role.weight.value >= FontWeight.w600.value)
      ? ContrastRole.largeText
      : ContrastRole.text;

  static ContrastRole _roleFor(double floor) {
    if (floor >= ContrastRole.veldBorder.floor) return ContrastRole.veldBorder;
    if (floor >= ContrastRole.veldText.floor) return ContrastRole.veldText;
    if (floor >= ContrastRole.text.floor) return ContrastRole.text;
    return ContrastRole.graphic;
  }

  /// The separation floor a pair must clear on luminance alone before it is
  /// allowed to rely on colour at all. Below this, hue is decoration and the
  /// declared [SeparationChannel]s are what the reader is actually using.
  static const double separationFloor = 3.0;

  /// Every pair of things a reader has to tell apart, in every skin, with the
  /// channel that tells them apart when hue cannot.
  ///
  /// This list is the non-colour-encoding rule made checkable. It exists
  /// because the audit found a chart whose "focus" colour and whose "neutral"
  /// colour had identical relative luminance — the focus mechanism was a
  /// no-op in greyscale, in both dichromacies and in sunlight, and nobody
  /// noticed for months because in the office, on a good monitor, it looked
  /// fine.
  static List<SeriesPair> get seriesPairs {
    final out = <SeriesPair>[];
    for (final skin in <TiqSkin>[_night, _day, _veld]) {
      final name = skin.mode.name;
      final p = skin.palette;
      // On a light ground the focus channel is ink, not amber: the one amber
      // block is already spent on the primary action.
      final focus = skin.amberIsInk ? p.ink1 : p.flame600;
      out.addAll(<SeriesPair>[
        SeriesPair(
          skin: name,
          label: 'focus series vs neutral series',
          a: focus,
          b: p.chartNeutral,
          channels: const <SeparationChannel>{
            SeparationChannel.weight,
            SeparationChannel.position,
          },
          why:
              'Exactly one bar per chart is the one the answer sentence is '
              'about. It is heavier and it carries a leading marker; the '
              'colour is the third cue, not the first.',
        ),
        SeriesPair(
          skin: name,
          label: 'our series vs the comparison series',
          a: focus,
          b: p.comparison,
          channels: const <SeparationChannel>{
            SeparationChannel.dash,
            SeparationChannel.word,
          },
          why:
              'Amber is us, lit; Truffle is them, unlit earth. The solid/'
              'dashed stroke distinction is mandatory and the legend prints '
              'swatch AND pattern on every chart, every time.',
        ),
        SeriesPair(
          skin: name,
          label: 'neutral series vs the comparison series',
          a: p.chartNeutral,
          b: p.comparison,
          channels: const <SeparationChannel>{
            SeparationChannel.dash,
            SeparationChannel.word,
          },
          why: 'Same legend, same stroke rule.',
        ),
        SeriesPair(
          skin: name,
          label: 'negative bar vs positive bar on a diverging axis',
          a: p.bad,
          b: p.chartNeutral,
          channels: const <SeparationChannel>{
            SeparationChannel.hatch,
            SeparationChannel.position,
          },
          why:
              'The negative side is hatched with 45 degree rising stripes and '
              'sits on the other side of a 1dp ink-1 axis. The hue is the '
              'least of it.',
        ),
        SeriesPair(
          skin: name,
          label: 'on target vs critical',
          a: p.good,
          b: p.badSolid,
          channels: const <SeparationChannel>{
            SeparationChannel.shape,
            SeparationChannel.word,
          },
          why:
              'Outline plus a filled circle against a solid block plus a '
              'filled triangle plus a 3px left bar, each with its own word and '
              'its own semanticLabel.',
        ),
        SeriesPair(
          skin: name,
          label: 'watch vs critical — the two commitment levels of one hue',
          a: p.bad,
          b: p.badSolid,
          channels: const <SeparationChannel>{
            SeparationChannel.outline,
            SeparationChannel.word,
          },
          why:
              'Severity is one hue at two commitment levels: outline is '
              'Watch, solid is Critical. Intensity carries urgency, never hue '
              '— which is how instrumentation has always worked and is what '
              'frees the whole 25-45 degree band for the brand.',
        ),
        SeriesPair(
          skin: name,
          label: 'held (Oatmeal) vs on target',
          a: p.ink2,
          b: p.good,
          channels: const <SeparationChannel>{
            SeparationChannel.shape,
            SeparationChannel.word,
          },
          why:
              'Held is an Oatmeal square and the word Held. It is not a '
              'verdict and it must never be mistaken for one.',
        ),
        SeriesPair(
          skin: name,
          label: 'held (Oatmeal) vs the comparison series',
          a: p.ink2,
          b: p.comparison,
          channels: const <SeparationChannel>{
            SeparationChannel.shape,
            SeparationChannel.word,
          },
          why:
              'Two surfaces used Truffle for held work. Truffle is the '
              'comparison series and nothing else; giving it a second meaning '
              'is exactly the failure the severity system avoids.',
        ),
        SeriesPair(
          skin: name,
          label: 'focus series vs on target',
          a: focus,
          b: p.good,
          channels: const <SeparationChannel>{
            SeparationChannel.weight,
            SeparationChannel.position,
          },
          why:
              'A lit bar is where to look; a good bar is a verdict. In Night '
              'these two are within a tenth of a stop of each other, so the '
              'lit one is heavier and marked and the verdict one carries its '
              'glyph and its word.',
        ),
      ]);
    }
    return out;
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
            'chart-neutral #A39887 for every non-focus bar. Burning Flame and '
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

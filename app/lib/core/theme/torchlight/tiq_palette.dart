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
    required this.plateCeiling,
    required this.plateLift,
  });

  // ── Grounds and surfaces ─────────────────────────────────────────────
  /// App ground, full bleed. Night `#0B1017`, Day Palladian.
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
  /// `lifted` track *of the day* — the product's most-drawn graphic sitting on
  /// the AA floor with 0.01 of margin, which on a 6-bit panel at 40% backlight
  /// is a smudge. (Against the warm-neutral `lifted` of 29 September 2026 the
  /// old value would measure 3.80:1, so the recast would have relieved some of
  /// that pressure on its own. It does not reopen the decision: `#A39887`
  /// measures 5.09:1 on the new track, and the Day half of the move — a bar
  /// that was byte-identical to a meta line — had nothing to do with Night.)
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
  /// bar. Day: one solid block per screen, carrying dark ink.
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
  /// On both grounds this is [flame500] — the amber gets hotter and the ink
  /// stays dark (8.59:1), which is the fix for a pressed state that used to
  /// put flame-900 on flame-500 at 2.00:1 and make the label vanish at the
  /// moment of commitment.
  final Color amberPressed;
  final Color onAmberPressed;

  // ── Severity — one hue, two commitment levels, never amber ───────────
  /// The **word grade** of each severity: the ink a figure, a phrase or a
  /// delta is set in. It carries text, so it is measured at 4.5:1 on every
  /// fill the app sets text on, in every skin — the sweep in
  /// `TorchlightContrast.generatedFor` walks exactly these two.
  final Color good;

  /// The **mark grade**: a fill, a dot, a bar, a solid block. It is a graphic
  /// at 3:1 and it carries [onGoodSolid] / [onBadSolid] when it is a block, so
  /// it is free to be more chromatic than the word grade. It is **not** an ink
  /// for a word: Night [badSolid] is 4.09:1 on `surface`, which is what the
  /// grade split exists to keep out of a sentence.
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

  // ── The photographic plate's tone — PER SKIN ─────────────────────────
  //
  // THE PLATE HAS TWO ENDS, AND WHICH ONE IS BINDING DEPENDS ON THE GROUND.
  //
  // It used to have one: a single `static const plateCeiling` of `#474747`,
  // every channel multiplied by it, in both skins. On Night that is right —
  // the ink is light, the picture is dark, and the ceiling is what keeps the
  // hero legible. On **Day** it is the defect: the ink is dark and the
  // picture is dark too, so the two converge and "Territory health" measured
  // 2.63–2.99:1 against a 4.5 floor (§9g, and
  // `floor_plate_contrast_test.dart`, which asserted the failure on purpose).
  //
  // A light ground needs the opposite operation. A ceiling pushes pixels
  // DOWN; what dark ink on paper needs is the shadows pushed UP. So the tone
  // is now a *range* — `[plateLift, plateCeiling]` — and each skin says where
  // its own ends are. Night lifts nothing and raises its ceiling (the owner
  // asked for luminosity and Night had headroom); Day lifts hard and lets the
  // ceiling go nearly to white, because on paper the picture must be paler
  // than the ink, not darker.

  /// The brightest any pixel of the photographic plate may be, per skin.
  ///
  /// Night `#666666`, Day `#E6E6E6`. A neutral grey in both, so it composes
  /// with the saturation matrix as a per-channel scale — see `plateToneMatrix`
  /// in `core/widgets/torchlight/plate/plate.dart`.
  ///
  /// Night's was `#474747` until 29 September 2026. The owner said the
  /// territory photographs "are made dark"; Night had the headroom to answer
  /// that and still clear the floor, and it does — `ink1` on an unscrimmed
  /// Night plate pixel at this ceiling is measured in `tiq_contrast.dart`.
  final Color plateCeiling;

  /// The DIMMEST any pixel of the photographic plate may be, per skin, as a
  /// scalar share of full value: `0.0` means "no floor", `0.60` means no
  /// channel lands below `#999999`.
  ///
  /// Night `0.0` — a dark ground wants its picture dark, and lifting it would
  /// throw away the contrast the light ink depends on. Day `0.60` — on paper
  /// the ink is `#1B2632` and the only way a photograph under it stays a
  /// *ground* is if it stays paler than the ink.
  ///
  /// **Not to be confused with `TorchlightContrast.plateFloor`**, which is a
  /// different quantity entirely: the darkest pixel the *scrimmed* text-safe
  /// zone can produce. This is an input to the tone; that is an output of the
  /// scrim. Hence `lift` rather than `floor`.
  final double plateLift;

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

  /// The Night surface ladder's generating rule: [ink1] washed over [night]'s
  /// [ground] at `alpha`, quantised to 8 bits.
  ///
  /// It exists so the four tiers below are **provably one family** rather than
  /// four hand-picked hexes that happen to sit near each other.
  /// `tiq_palette_test.dart` recomputes each tier from its declared alpha and
  /// fails if a byte drifts — the same discipline `tiq_contrast.dart` applies
  /// to ratios, applied to the fills themselves.
  ///
  /// It cannot be called from the `const` constructor below, which is why the
  /// tiers are still written as literals. The literal is the shipped value;
  /// this is the proof it was derived.
  static Color nightWash(double alpha) {
    const Color bone = Color(0xFFEEE9DF);
    const Color ground = Color(0xFF0B1017);
    int channel(double bg, double fg) =>
        ((bg + alpha * (fg - bg)) * 255).round().clamp(0, 255);
    return Color.fromARGB(
      0xFF,
      channel(ground.r, bone.r),
      channel(ground.g, bone.g),
      channel(ground.b, bone.b),
    );
  }

  /// The alpha each Night surface tier is [nightWash]ed at, in ladder order.
  ///
  /// `surface` and `raised` are **the approved artifact's own numbers** — its
  /// soft row is `rgba(238,233,223,0.055)` and its lead row `0.085` — so the
  /// two tiers a card is actually painted in are not an interpretation of the
  /// design, they are the design. `well` and `lifted` extend the same line
  /// down and up; the artifact's recessed and pressed fills (`0.05` for the
  /// Ask panel, `0.10` for a progress track, `0.12` for a hover) bracket them.
  static const Map<String, double> nightSurfaceAlpha = <String, double>{
    'well': 0.030,
    'surface': 0.055,
    'raised': 0.085,
    'lifted': 0.120,
  };

  /// NIGHT — the near-black console. Warm off-white ink on a cool navy-black
  /// ground is what makes it read as lit rather than switched off.
  static const TiqPalette night = TiqPalette(
    ground: Color(0xFF0B1017),
    vignette: Color(0xFF0F1620),
    // ── THE SURFACE LADDER IS ONE WASH AT FOUR STRENGTHS ────────────────
    //
    // MOVED 29 September 2026. The owner looked at The Floor in Night beside
    // the approved artifact and said: *"Look at that grey, I need it on some
    // of these cards instead this blue everywhere, this is on the dark
    // theme."*
    //
    // The artifact's cards are not a colour. They are [ink1] — the bone
    // #EEE9DF — washed over the ground at a few per cent, so every surface in
    // it is the *same warm off-white* at a different strength and the ground's
    // own navy is what shows through. The app's ladder was four separately
    // chosen navies: measured as blue cast (B−R) they ran 19 / 23 / 28 / 33
    // against the artifact's flat 9–11, and that rising cast is the "blue
    // everywhere" the owner was pointing at. A card was not a lit version of
    // the ground; it was a bluer one.
    //
    // So the ladder is derived now, not picked — see [nightWash] and
    // [nightSurfaceAlpha]:
    //
    //   well    bone @ 0.030  #12171D   cast 11
    //   surface bone @ 0.055  #171C22   cast 11   (the artifact's .srow)
    //   raised  bone @ 0.085  #1E2228   cast 10   (the artifact's .srow.lead)
    //   lifted  bone @ 0.120  #262A2F   cast  9
    //
    // `ground` and `vignette` did not move: they are the letterbox falloff's
    // own stops and they already matched.
    //
    // WHAT IT COST, STATED PLAINLY. Every tier is darker than the one it
    // replaces, so every ink and every edge measured on it gained contrast —
    // the full table is in `torchlight_contrast_test.dart`, and nothing got
    // harder. What got *smaller* is the step between adjacent tiers: 1.12 /
    // 1.11 / 1.14 / 1.18 became 1.06 / 1.05 / 1.07 / 1.11. That is inside the
    // range §2 already refuses to treat as a cue ("a 1.12–1.24:1 fill step is
    // one or two quantisation levels on a budget LCD in sunlight"), and the
    // rule it states is unchanged and still enforced: nothing is identified by
    // a fill step alone and every perceivable boundary carries a real edge.
    // Anchoring `surface` on the artifact's 0.055 is what compresses the
    // bottom of the ladder — the whole span from ground to surface is only
    // 1.11:1 — and that is a consequence of the approved design, not of this
    // change's arithmetic.
    well: Color(0xFF12171D),
    surface: Color(0xFF171C22),
    raised: Color(0xFF1E2228),
    lifted: Color(0xFF262A2F),
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
    // The picture may reach 40% of full value, and has no floor: on a
    // near-black ground the shadows of a photograph ARE the ground.
    plateCeiling: Color(0xFF666666),
    plateLift: 0.0,
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
    // MOVED 28 September 2026, from #7A0F22. The critical mark on a light
    // ground is a filled 8dp dot, and at #7A0F22 — 9.04:1 on Palladian — it
    // read as brown rather than as red. The owner looked at The Floor in Day
    // and said so: "the severity dots ... are a dark crimson so muted they
    // read as brown".
    //
    // On paper, commitment is carried by **fill and chroma**, not by
    // darkness: past about 8:1 a red on cream stops gaining urgency and
    // starts losing hue. #B3121F is 5.74:1 on the ground and 5.04:1 on the
    // well — well clear of the 3:1 a mark needs and still clear of 4.5:1 —
    // and carries white at 6.95:1, so the solid critical block is unchanged
    // in its contract and changed in its colour.
    //
    // [bad] deliberately did NOT move with it. It is the word grade, and its
    // binding case is 13px text over the plate's scrimmed photograph, which
    // on a light ground composites to #BEBAB2 at worst: #8C1B2C is 4.70:1
    // there and anything brighter is under the floor. See the `day plate`
    // pairings in `tiq_contrast.dart`.
    badSolid: Color(0xFFB3121F),
    onBadSolid: Color(0xFFFFFFFF),
    comparison: Color(0xFFA35139),
    comparisonWash: Color(0xFFF7DCD2),
    scrim: Color(0xB81B2632),
    // Paper: the picture sits in the top 30% of the range, never below 60%.
    // Dark ink on a light ground needs the photograph to be the pale half of
    // the pairing, which is the exact inverse of what Night needs.
    plateCeiling: Color(0xFFE6E6E6),
    plateLift: 0.60,
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
      plateCeiling: c(plateCeiling, other.plateCeiling),
      plateLift: plateLift + (other.plateLift - plateLift) * t,
    );
  }
}

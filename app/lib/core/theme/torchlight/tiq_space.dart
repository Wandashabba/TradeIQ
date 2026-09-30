import 'dart:ui' show lerpDouble;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Which density a skin is laid out at.
///
/// **The two [TiqSpace] scales no longer differ in their rhythm** — see
/// [TiqSpace.field]. The enum stays because eight widgets outside this file
/// still branch on it for geometry that is not spacing (header height, chip
/// visual height, meter track, stat-tile inset and floor, trough height,
/// trend-chart plot height), and because it is how a caller says which
/// surface it is.
enum TiqDensity {
  /// The manager console: tight rows, 24px block gaps, a 44dp row floor.
  console,

  /// The field agent's phone. Its [TiqSpace] is the console's, in every
  /// field, since 29 September 2026 — see [TiqSpace.field] for what that
  /// traded and how to put it back.
  field,
}

/// The spacing scale. Base 4, eleven steps, and **no other value exists** —
/// this replaces the raw-numeric `EdgeInsets` the audit found in 96 files.
///
/// The steps are named `s1…s11` rather than by intent, because a name like
/// `cardPadding` invites a twelfth step the first time a card is not a card.
@immutable
class TiqSpace {
  const TiqSpace({
    required this.density,
    required this.gutter,
    required this.gutterWide,
    required this.rowMinHeight,
    required this.blockGap,
    required this.intraBlock,
    required this.tapTarget,
    required this.primaryActionHeight,
    required this.chipHeight,
  });

  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s7 = 32;
  static const double s8 = 40;
  static const double s9 = 56;
  static const double s10 = 72;
  static const double s11 = 96;

  /// THE MEASURE — how wide a single column of prose and fields is allowed to
  /// get, whatever the viewport does.
  ///
  /// > *"Thats not good please fix spacing"* — the owner, 30 September 2026,
  /// > looking at the redesigned sign-in screen in a desktop browser at about
  /// > 1200 logical pixels.
  ///
  /// Nothing in this scale capped a **width** before that day. Every token
  /// above is a gap between two things; [gutter] and [gutterWide] say how far
  /// content stops from the screen edge, which on a phone is the same
  /// question as how wide it gets and on a 1280dp browser is not. The agent
  /// shell does not even widen its gutter — `TorchShell` calls [gutterFor]
  /// only on the console profile — so the way in ran a 1240dp-wide email
  /// field, and there was no token to say it should not.
  ///
  /// **520, and here is the arithmetic.** `body` is 14/1.55 in Onest at both
  /// densities since #488. Onest measures **≈7.05dp per character** at 14
  /// (measured in `entry_width_test.dart`, not estimated), so 520dp is about
  /// **74 characters** — the top of the 45–75 band typography has used for a
  /// century, with 66 as the optimum. It is also 4 × 130: on the base-4 grid,
  /// like everything else here.
  ///
  /// It is deliberately **not** a container width. A card, a table or a
  /// dashboard is not prose and must not read this token; this is the measure
  /// for *one column of words and the controls that belong to them*, which is
  /// what every screen on the way in is.
  static const double readingWidth = 520;

  /// Every legal spacing value, in order. Anything not in this list is a
  /// magic number — `torchlight_lint_test.dart` treats it as one.
  static const List<double> scale = <double>[
    s1,
    s2,
    s3,
    s4,
    s5,
    s6,
    s7,
    s8,
    s9,
    s10,
    s11,
  ];

  final TiqDensity density;

  /// Side gutter on a phone. Everything on a screen hangs off this one line.
  final double gutter;

  /// Side gutter at ≥1080 logical pixels.
  ///
  /// It was Console-only — the field surface held its phone gutter at every
  /// width because it is phone-only and 1080dp was a case nobody had. Since
  /// 29 September 2026 both scales carry s8, so a field skin pointed at a
  /// tablet does the console's thing instead of nothing. See [field].
  final double gutterWide;

  /// Minimum height of a list row. **44 at both densities** since
  /// 29 September 2026; see [field].
  final double rowMinHeight;

  /// Between two sections. **s6 at both densities** since 29 September 2026;
  /// see [field].
  final double blockGap;

  /// Between two things inside one section. **s3 at both densities** since
  /// 29 September 2026; see [field].
  final double intraBlock;

  /// Minimum interactive box. **44 at both densities** since 29 September
  /// 2026 — the WCAG 2.5.5 floor; see [field] for what that cost.
  ///
  /// It is not the smallest target in the product: `torchTapTarget` holds a
  /// text or glyph action at 48 on both sides regardless of this value.
  final double tapTarget;

  /// Height of the one primary commit action. **44 at both densities** since
  /// 29 September 2026; see [field].
  final double primaryActionHeight;

  /// Chip height. **44 at both densities** since 29 September 2026; see
  /// [field].
  ///
  /// Nothing read this until that day — `TorchFilterChip.heightFor` restated
  /// 44/48 as its own switch on density, so the token was declared and dead.
  /// It is the single source now.
  final double chipHeight;

  static const TiqSpace console = TiqSpace(
    density: TiqDensity.console,
    gutter: s5,
    gutterWide: s8,
    rowMinHeight: 44,
    blockGap: s6,
    intraBlock: s3,
    tapTarget: 44,
    primaryActionHeight: 44,
    chipHeight: 44,
  );

  /// THE FIELD SCALE — **it is the console's, in every field, since
  /// 29 September 2026.**
  ///
  /// > *"Fix the spacing also please check if everything matches with the
  /// > manager side"* — the owner, 29 September 2026, after *"match the
  /// > manager side please"*, *"don't change the manager side, it looks
  /// > perfect"* and *"literally everything"* the same day.
  ///
  /// Seven tokens moved; `gutter` was already the same. **`gutterWide`
  /// s5 → s8**, **`rowMinHeight` 64 → 44**, **`blockGap` s7 → s6**,
  /// **`intraBlock` s4 → s3**, **`tapTarget` 48 → 44**, **`chipHeight`
  /// 48 → 44**, **`primaryActionHeight` s9 → 44**.
  ///
  /// THE TWO KINDS OF TOKEN IN HERE, AND WHY THEY MOVED IN SEPARATE COMMITS.
  /// `gutterWide`, `rowMinHeight`, `blockGap` and `intraBlock` are **visual
  /// rhythm**: they say how much air a screen puts between things and how tall
  /// a row stands. [tapTarget], [primaryActionHeight] and [chipHeight] are
  /// **thumb reach**: they say how big a thing has to be to be hit. They are
  /// separate questions with separate evidence, so reverting the touch change
  /// is one revert and does not take the rhythm change with it.
  ///
  /// WHAT THE RHYTHM SCALE WAS FOR — not withdrawn, **outranked**, and kept
  /// here in full so a reader knows what was traded. A 64dp row and a 32dp
  /// block gap are what a list looks like when it is scanned standing up, at
  /// arm's length, one-handed, on a cheap panel at 40% backlight, often in
  /// direct sunlight — the same premise that gave `TiqType.field` its larger
  /// prose. Looser vertical rhythm is the layout half of that answer: more
  /// air per row means fewer rows compete for one glance, and a 64dp row is
  /// tall enough that a two-line outlet name never crowds its status word.
  /// `gutterWide` held the phone gutter because the field surface is
  /// phone-only and a wide gutter on a 1080dp tablet was a case nobody had.
  ///
  /// WHAT THE OVERRIDE BUYS. One rhythm across the product. The owner has
  /// spent the day with the two surfaces side by side and has ruled, four
  /// times, that the manager side is the reference. After #488 unified type,
  /// spacing was the last axis on which the agent side differed **by
  /// construction** rather than by drift.
  ///
  /// WHAT IT COSTS. About a third of each row's height on the screens read
  /// outdoors, and a quarter of the air between blocks. The compensation is
  /// real and is the reason the owner asked: more of the screen is the screen.
  /// Today's rest-of-the-day list, the visit hub's section ladder and Me's
  /// visit rows all return rows below the fold on a 360dp phone.
  ///
  /// WHAT THE TOUCH SCALE WAS FOR — the same premise, stated about the thumb
  /// instead of the eye. 48dp exists because an agent works one-handed, in
  /// direct sunlight, often with a box under the other arm and a phone that
  /// is not theirs. It is the Material floor and one step of margin above the
  /// accessibility one.
  ///
  /// WHAT THE TOUCH OVERRIDE COSTS, said plainly: **every target on the agent
  /// side drops from 48dp to 44dp**, every chip from 48 to 44, and the commit
  /// action from 56dp to 44dp. 44 is the **WCAG 2.5.5 (AAA) minimum** — the
  /// floor rather than a margin above it — and it is what the manager side
  /// has run from the start with nobody filing it. It is not out of contract,
  /// and it is the number the owner is pointing at.
  ///
  /// ONE FLOOR DID NOT MOVE. `torchTapTarget` in
  /// `core/widgets/torchlight/button/torch_button.dart` reads
  /// `skin.space.tapTarget < 48 ? 48 : skin.space.tapTarget` — a hard 48 for
  /// text and glyph actions at **both** densities, written before this change
  /// and unaffected by it. So the smallest targets in the product stay 48dp
  /// on both sides; what drops to 44 is the row floor, the chip, the block
  /// button and the generic `space.tapTarget` constraint.
  ///
  /// TO RESTORE: put the seven values back below — they are listed in the
  /// comments beside them. **The rationale above comes back with them**: it is
  /// the whole of why they were different, and a future reader restoring 64dp
  /// rows or 48dp targets without it would be restoring a number rather than a
  /// decision.
  static const TiqSpace field = TiqSpace(
    density: TiqDensity.field,
    gutter: s5,
    // Rhythm — the console's, since 29 September 2026. Was, in order:
    // gutterWide s5, rowMinHeight 64, blockGap s7, intraBlock s4.
    gutterWide: s8,
    rowMinHeight: 44,
    blockGap: s6,
    intraBlock: s3,
    // Thumb reach — the console's too, since 29 September 2026, in its own
    // commit so it can come back alone. Was: tapTarget 48, primaryActionHeight
    // s9 (56), chipHeight 48.
    tapTarget: 44,
    primaryActionHeight: 44,
    chipHeight: 44,
  );

  /// The horizontal gutter for a viewport [width] logical pixels wide.
  EdgeInsets gutterFor(double width) =>
      EdgeInsets.symmetric(horizontal: width >= 1080 ? gutterWide : gutter);
}

/// Four materials, four radii. If a designer cannot name which of the four a
/// surface is, it does not get a radius.
///
/// The 999 pill radius is gone entirely: it existed only for the active-tab
/// pill, which no longer exists.
@immutable
class TiqRadii {
  const TiqRadii({
    required this.rule,
    required this.chip,
    required this.control,
    required this.panel,
    required this.card,
    required this.plate,
  });

  /// Rules and dividers.
  final double rule;

  /// Chips, outlined pills, ladder glyph tiles.
  final double chip;

  /// Buttons, inputs and thumbnails.
  ///
  /// Raised from 10 to 16 on 26 September 2026. At 10 a 56dp field and a 48dp
  /// button read as rectangles beside radius-22 cards — "the login as well",
  /// in the owner's words, looking at the running sign-in screen. 16 is a
  /// visible round-rect at both heights and still reads apart from a card,
  /// which is the distinction [card] exists to make.
  final double control;

  /// The instrument panel, forms, sheets.
  final double panel;

  /// THE CARD — a list row a person acts on, and the one block that carries a
  /// figure with it.
  ///
  /// Owner override, 25 September 2026: the flush list row of unify §1.3 is
  /// replaced by a soft rounded card. See `docs/design/torchlight-aisle.md`.
  /// It is a *bigger* radius than [panel] on purpose — a panel is a container
  /// and a card is an object, and the mockup the owner signed off reads the
  /// two apart by exactly this number.
  final double card;

  /// Photographic plates.
  final double plate;

  /// Night and Day share one radius set. It is the only one.
  static const TiqRadii lit = TiqRadii(
    rule: 0,
    chip: 6,
    control: 16,
    panel: 14,
    card: 22,
    plate: 28,
  );

  /// An input is a control, and it is round on all four corners.
  ///
  /// It was a **trough** — square at the top, rounded at the bottom — on the
  /// reading that an input "holds at the bottom". Two square corners at the
  /// top of a 56dp box is a rectangle, and it is the shape the owner was
  /// looking at when they said the sign-in screen is still rectangular. The
  /// trough said something true about an input and said it in the one channel
  /// this product uses to say "soft object"; the fill and the resting outline
  /// carry the holding, and the silhouette carries the softness.
  BorderRadius get input => BorderRadius.circular(control);

  TiqRadii lerp(TiqRadii other, double t) => TiqRadii(
    rule: lerpDouble(rule, other.rule, t)!,
    chip: lerpDouble(chip, other.chip, t)!,
    control: lerpDouble(control, other.control, t)!,
    panel: lerpDouble(panel, other.panel, t)!,
    card: lerpDouble(card, other.card, t)!,
    plate: lerpDouble(plate, other.plate, t)!,
  );
}

/// Five depth levels. The rule that governs them is the DEVICE FLOOR: no
/// surface may rely on a fill step alone to be perceived, because a
/// 1.12–1.24:1 fill step is one or two quantisation levels on a 6-bit budget
/// LCD at 40% backlight.
enum TiqDepthLevel {
  /// Ground. No edge.
  l0Ground,

  /// Well — inset, no edge. It is allowed to recede; that is its job.
  l1Well,

  /// Surface + a 1px `edgeStructure` outline (3.00:1), plus a decorative lit
  /// top rim over it.
  l2Surface,

  /// Raised. Used only INSIDE an L2 that already has an edge, divided by
  /// hairlines.
  l3Raised,

  /// Emitted: any fill plus an amber gradient bloom. Reserved for the plate's
  /// strip light, the active-tab underbar and the one focus bar in a chart —
  /// never more than two L4 objects on screen.
  l4Emitted,
}

/// What each skin is allowed to cast.
@immutable
class TiqDepth {
  const TiqDepth({
    required this.shadows,
    required this.litRim,
    required this.allowsGradients,
    required this.borderWidth,
  });

  /// `sh1`, `sh2`, `sh3` — Day only. Night has none (black on black is
  /// invisible, and the audit's 34 ad-hoc BoxShadows all go).
  final List<BoxShadow> shadows;

  /// The decorative 1px top rim over an L2 edge. Transparent where a skin has
  /// no rim.
  final Color litRim;

  /// Whether gradient decorations (the only legal bloom) are permitted.
  final bool allowsGradients;

  /// Structural border width.
  final double borderWidth;

  static const TiqDepth night = TiqDepth(
    shadows: <BoxShadow>[],
    litRim: Color(0x1AEEE9DF), // Palladian @ 10%
    allowsGradients: true,
    borderWidth: 1,
  );

  static const TiqDepth day = TiqDepth(
    shadows: <BoxShadow>[
      BoxShadow(
        color: Color(0x0F1B2632),
        offset: Offset(0, 1),
        blurRadius: 2,
      ), // sh1 .06
      BoxShadow(
        color: Color(0x141B2632),
        offset: Offset(0, 4),
        blurRadius: 12,
      ), // sh2 .08
      BoxShadow(
        color: Color(0x1F1B2632),
        offset: Offset(0, 12),
        blurRadius: 32,
      ), // sh3 .12
    ],
    litRim: Color(0x00000000),
    allowsGradients: true,
    borderWidth: 1,
  );

  /// sh1 — the only shadow a Day panel takes.
  BoxShadow? get sh1 => shadows.isEmpty ? null : shadows[0];
  BoxShadow? get sh2 => shadows.length < 2 ? null : shadows[1];
  BoxShadow? get sh3 => shadows.length < 3 ? null : shadows[2];
}

/// Durations and curves. One application-wide `Ticker` drives the three loops;
/// all three are disabled under `MediaQuery.disableAnimations` and
/// battery-saver.
@immutable
class TiqMotion {
  const TiqMotion({required this.enabled});

  /// Whether this skin animates at all. Both shipping skins do; a test pins
  /// [off] to render the resting frame.
  final bool enabled;

  /// Press, toggle, chip select.
  static const Duration press = Duration(milliseconds: 120);

  /// Element enter (40ms stagger).
  static const Duration enter = Duration(milliseconds: 200);

  /// Plate reveal, sheet, route.
  static const Duration reveal = Duration(milliseconds: 320);

  /// Figure count-up, and the button busy loop.
  static const Duration countUp = Duration(milliseconds: 600);

  /// The skeleton's travelling rule — Oatmeal, never amber: a skeleton is
  /// loading, not live.
  static const Duration skeleton = Duration(milliseconds: 1400);

  /// The ambient live pulse. Night-only, and the one semantic amber in the
  /// system: a *breathing* amber means "happening right now".
  static const Duration livePulse = Duration(milliseconds: 3200);

  static const Curve enterCurve = Cubic(0.05, 0.70, 0.10, 1.00);
  static const Curve exitCurve = Cubic(0.30, 0.00, 0.80, 0.15);
  static const Curve stateCurve = Cubic(0.20, 0.00, 0.00, 1.00);
  static const Curve countUpCurve = Curves.easeOutQuart;

  static const TiqMotion on = TiqMotion(enabled: true);
  static const TiqMotion off = TiqMotion(enabled: false);

  /// The duration to actually use — zero when motion is off, so a caller never
  /// has to branch.
  Duration resolve(Duration d) => enabled ? d : Duration.zero;
}

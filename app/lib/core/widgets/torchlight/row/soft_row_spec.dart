import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';

/// Which of the two forms a soft row takes.
///
/// One component, two forms — unify §1.3. Kit wanted an outlined radius-14 card
/// for every row and agent wanted a flush rule-separated band; the ruling gave
/// each of them the case it was right about.
///
/// **OWNER OVERRIDE, 25 September 2026.** unify §1.3 ruled the list form
/// flush, radius 0, separated by a 1px rule, and called the rounded
/// alternative the "uniform rounded cards" anti-slop failure. The owner has
/// looked at the running screens twice and overruled it: the mockup they
/// signed off — and the reference apps they chose — use **soft rounded rows**,
/// and "it's still very boxy and I don't need that" is the note that settles
/// it. The list form is now a card: radius [TiqRadii.card], a `surface` fill,
/// no outline, and a gap of ground instead of a rule.
///
/// The anti-slop concern is answered rather than ignored: the card grammar is
/// for **lists of things a person acts on** — decisions, alerts, tasks, stops,
/// outbox items. Nothing else on any screen gains a radius because of it, and
/// **Veld keeps the flush form** (radius 0, 2px borders): a soft translucent
/// row on white under glare stops reading as a row at all.
enum SoftRowForm {
  /// A card: radius [TiqRadii.card], `surface` fill, no outline, separated
  /// from the next row by a gap of ground. Every list in the app. In Veld it
  /// stays flush, radius 0, separated by a 2px rule inset to the text edge.
  list,

  /// Radius 14, `surface` fill, 1px `edgeStructure` outline. The Next-up card,
  /// the day block, the readiness block, the outbox summary — a row that is
  /// the only one of its kind on the screen and therefore has no neighbour to
  /// be separated from.
  standalone,
}

/// The three densities. Kit's three won; manager's 76 rounds up to 80.
enum SoftRowDensity {
  /// 56 — console lists.
  compact,

  /// 64 — field lists.
  standard,

  /// 80 — two meta lines: Next-up, outbox, person, decision rows.
  tall,
}

/// Severity, at two commitment levels and never amber.
///
/// The hue is the same crimson at both levels; what separates them is the
/// bar's **silhouette** — solid versus outlined — and the word the caller
/// passes as `severityLabel`, which is what a screen reader, a greyscale
/// screenshot and a deuteranope actually get.
enum SoftRowSeverity {
  /// No bar. Under unify §4's "unknown vs zero" rule a bar-less row means
  /// *fine* and nothing else; an unscored row says so in words.
  none,

  /// A 3px channel with a 1px `bad` stroke around it. Not the critical bar at
  /// 40% opacity — opacity is banned as a state channel.
  watch,

  /// A 3px solid `badSolid` bar.
  critical,
}

/// How a title that does not fit gives up.
enum SoftRowTruncation {
  /// Wrap to two lines, then ellipsise at the end. Everything except a name.
  end,

  /// Wrap to two lines, then drop the middle. Outlet names and person names,
  /// because "Shoprite Klipspruit Mall" and "Shoprite Klipfontein Mall"
  /// end-truncate to the same string and so do "Dlamini-Mkhize" and
  /// "Dlamini-Ndlovu".
  middle,
}

/// Whether a list row is separated from the one after it.
///
/// The rule's **colour** is never a caller's choice — that is the whole
/// content of unify §1.3's ruling — so this enum has no `structure` or
/// `hairline` member. A tappable row gets `edgeStructure` because 1.4.11 wants
/// a perceivable boundary around a UI component; a non-tappable one gets
/// `hairline`, which is deliberately below 3:1 because it is decoration.
enum SoftRowSeparator {
  /// A gap of ground after the card — and, in Veld only, a rule:
  /// `edgeStructure` between tappable rows, `hairline` between non-tappable
  /// ones. Resolved from the row, not declared.
  auto,

  /// The last row in a group, and every standalone row (which carries an
  /// outline instead).
  none,
}

/// Every number and colour a soft row paints, resolved once from the skin.
///
/// Split out from the widget for three reasons. It is what the golden test
/// snapshots — a text golden of declared values diffs readably and means the
/// same thing on macOS and on the Linux box CI runs on, which a PNG of
/// anti-aliased Onest does not. It is what a migrating screen reads when it
/// needs to align something *beside* a row to the row's own insets (a section
/// rule, a sticky header, a swipe background). And it is a pure function, so
/// the geometry can be argued about in a unit test rather than in a
/// screenshot.
@immutable
class SoftRowSpec {
  const SoftRowSpec({
    required this.form,
    required this.density,
    required this.severity,
    required this.tappable,
    required this.pressed,
    required this.minHeight,
    required this.margin,
    required this.gapAfter,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.gap,
    required this.stackedGap,
    required this.markIsDot,
    required this.barWidth,
    required this.barStrokeWidth,
    required this.barHeight,
    required this.severityLane,
    required this.leadingExtent,
    required this.radius,
    required this.fill,
    required this.outline,
    required this.outlineWidth,
    required this.separatorColour,
    required this.separatorWidth,
    required this.barFill,
    required this.barStroke,
    required this.titleInk,
    required this.subtitleInk,
    required this.metaInk,
    required this.titleStyle,
    required this.subtitleStyle,
    required this.metaStyle,
    required this.pressScale,
    required this.minTextWidth,
    required this.chevronExtent,
  });

  /// Resolve the spec. Pure and synchronous — no `BuildContext`, so it is
  /// callable from a test with a bare [TiqSkin].
  ///
  /// [textScale] is the live `TextScaler` applied to 1.0, already clamped by
  /// the caller to the app's 2.0 ceiling. [still] comes from `MotionBudget`
  /// and removes the press scale, leaving fill and edge — two channels, which
  /// is the minimum unify §4 allows.
  factory SoftRowSpec.resolve({
    required TiqSkin skin,
    SoftRowForm form = SoftRowForm.list,
    SoftRowDensity density = SoftRowDensity.standard,
    SoftRowSeverity severity = SoftRowSeverity.none,
    bool tappable = true,
    bool pressed = false,
    bool separated = true,
    double textScale = 1.0,
    bool still = false,
  }) {
    final palette = skin.palette;
    final veld = skin.density == TiqDensity.veld;

    // Veld collapses the three densities onto one 64dp row: outdoors, fewer
    // things further apart, and a 56dp row is under the 56dp target floor the
    // moment a border eats two pixels of it.
    final minHeight = veld
        ? 64.0
        : switch (density) {
            SoftRowDensity.compact => 56.0,
            SoftRowDensity.standard => 64.0,
            SoftRowDensity.tall => 80.0,
          };

    final verticalPadding = veld
        ? TiqSpace.s4
        : (density == SoftRowDensity.compact ? TiqSpace.s3 : TiqSpace.s4);
    final gap = density == SoftRowDensity.compact && !veld
        ? TiqSpace.s3
        : TiqSpace.s4;

    final isStandalone = form == SoftRowForm.standalone;
    // THE CARD. A list row is an inset object with air on both sides of it;
    // the standalone form is already inset by whatever holds it, and Veld is
    // flush by ruling.
    final isCard = !veld && !isStandalone;

    // 3px, and 6px in Veld where a 3px mark is a smudge in glare. The severity
    // LANE — the mark plus its gap — is reserved whether or not a mark is
    // drawn, which is manager's alignment rule and the reason a list of rows
    // reads as one column instead of two indented at random.
    //
    // OWNER OVERRIDE, 25 September 2026: on a card the mark is a **dot**, not
    // a bar. A 3px bar is the silhouette of a flush row's left edge; inside a
    // radius-22 card it reads as a scratch on the fill. Veld keeps the bar —
    // it keeps the flush row it belongs to.
    final markIsDot = !veld;
    // The mark carries meaning, so it grows with the text — at half rate, like
    // a track, because its job is to be findable down the left edge rather
    // than to be read. A dot grows but stays round, so its width grows with
    // it and the lane grows with the width: every row on a screen shares one
    // text scale, so the column is still a column.
    final barWidth = markIsDot
        ? TiqSpace.s2 * (1 + (textScale - 1) / 2)
        : (veld ? 6.0 : 3.0);
    final barStrokeWidth = skin.depth.borderWidth;
    final severityLane = barWidth + TiqSpace.s3;

    final barHeight = markIsDot
        ? barWidth
        : math.min(TiqSpace.s8 * (1 + (textScale - 1) / 2), minHeight);

    // A meaning-bearing glyph box grows with the text and stops at 48 — the
    // one pair unify §1.5 states for a tile is 28 → 48, and 48 is also the
    // tap-target floor, so nothing useful happens above it.
    final leadingBase = veld
        ? 48.0
        : (density == SoftRowDensity.compact ? 28.0 : TiqSpace.s8);
    final leadingExtent = math.min(leadingBase * textScale, 48.0);

    // A standalone row is never separated from anything: it carries an
    // outline, and a rule under an outlined card is a second boundary saying
    // the same thing. The resolver enforces it rather than trusting a caller.
    //
    // A CARD is separated by a gap of ground and never by a rule: a line
    // between two objects that already have edges is the table look the card
    // grammar exists to leave behind. Only Veld's flush row still draws one.
    final separates = separated && !isStandalone;
    final drawsRule = separates && !isCard;

    // `lifted` is a dark block in all three skins (#2C3B4D, #2C3B4D,
    // #1B2632). On Night that is a step up from the ground; on Day and Veld it
    // is an ink block on paper, so a pressed row inverts and the ink on it is
    // the skin's lightest neutral. Two facts about the token values, not two
    // code paths keyed on the mode.
    final pressedFill = palette.lifted;
    final pressedInk = skin.brightness == Brightness.dark
        ? palette.ink1
        : palette.ground;

    // A card carries a `surface` fill at rest — the same material as a
    // standalone row, which is the whole of the owner's note: one softness,
    // not two. The fill is the declared composited hex, never an opacity.
    final restingFill = (isStandalone || isCard) ? palette.surface : null;

    // THE PRESSED STATE, unify §1.3. The fill step alone is 1.49:1 on the
    // Night well — invisible on a 6-bit panel at 40% backlight — so the row's
    // rule or outline steps to `edgeControl` at the same time. Two channels,
    // plus the scale and the tick haptic the widget adds. A card has no
    // resting outline, so the press is where it gains one: the edge appears
    // rather than thickening, which is the same two channels.
    final outlineWidth = isStandalone
        ? (pressed ? skin.depth.borderWidth * 2 : skin.depth.borderWidth)
        : (isCard && pressed ? skin.depth.borderWidth : 0.0);
    final separatorWidth = !drawsRule
        ? 0.0
        : (pressed ? skin.depth.borderWidth * 2 : skin.depth.borderWidth);

    return SoftRowSpec(
      form: form,
      density: density,
      severity: severity,
      tappable: tappable,
      pressed: pressed,
      minHeight: minHeight,
      // The card's own air. On a list that has been bled out to the screen
      // edges this is the gutter line; a row inside something that has
      // already spent a gutter adds no second one, which is why the value is
      // s4 and not the gutter itself.
      margin: isCard ? TiqSpace.s4 : 0.0,
      gapAfter: isCard && separates ? TiqSpace.s3 : 0.0,
      horizontalPadding: isCard ? TiqSpace.s4 : skin.space.gutter,
      verticalPadding: verticalPadding,
      gap: gap,
      stackedGap: TiqSpace.s2,
      markIsDot: markIsDot,
      barWidth: barWidth,
      barStrokeWidth: barStrokeWidth,
      barHeight: barHeight,
      severityLane: severityLane,
      leadingExtent: leadingExtent,
      radius: isStandalone
          ? skin.radii.panel
          : (isCard ? skin.radii.card : skin.radii.rule),
      fill: pressed ? pressedFill : restingFill,
      outline: isStandalone
          ? (pressed ? palette.edgeControl : palette.edgeStructure)
          : (isCard && pressed ? palette.edgeControl : null),
      outlineWidth: outlineWidth,
      separatorColour: !drawsRule
          ? null
          : pressed
          ? palette.edgeControl
          : (tappable ? palette.edgeStructure : palette.hairline),
      separatorWidth: separatorWidth,
      barFill: severity == SoftRowSeverity.critical ? palette.badSolid : null,
      barStroke: severity == SoftRowSeverity.watch ? palette.bad : null,
      titleInk: pressed ? pressedInk : palette.ink1,
      subtitleInk: pressed ? pressedInk : palette.ink2,
      metaInk: pressed ? pressedInk : palette.ink3,
      titleStyle: skin.text.titleM,
      subtitleStyle: skin.text.body,
      metaStyle: skin.text.meta,
      // Veld runs `TiqMotion.off`, so its press is the inversion plus the
      // haptic and nothing moves.
      pressScale: (still || !skin.motion.enabled) ? 1.0 : 0.98,
      // Below this the trailing column stops sitting beside the text and drops
      // beneath it. Measured against the real laid-out trailing width, never
      // guessed from the text scale — see `_RenderSoftRowContent`.
      minTextWidth: 96.0,
      chevronExtent: math.min(20.0 * textScale, 32.0),
    );
  }

  final SoftRowForm form;
  final SoftRowDensity density;
  final SoftRowSeverity severity;
  final bool tappable;
  final bool pressed;

  /// A floor, never a fixed height: a row at 2.0× with a wrapped Afrikaans
  /// title grows past it and nothing is pinned.
  final double minHeight;

  /// The card's horizontal inset from whatever holds it. Zero for a flush row
  /// and for a standalone one.
  final double margin;

  /// The gap of ground under the card, before the next one. Zero where the
  /// rule does the separating (Veld) or where nothing follows.
  final double gapAfter;

  final double horizontalPadding;
  final double verticalPadding;

  /// Between the leading slot and the text column.
  final double gap;

  /// Between the text column and a trailing column that has dropped beneath
  /// it.
  final double stackedGap;

  /// Whether the severity mark is a dot (every card) or a bar (Veld's flush
  /// row). Two commitment levels either way, and the silhouette — filled
  /// versus outlined — is what separates them, never the hue alone.
  final bool markIsDot;

  final double barWidth;
  final double barStrokeWidth;
  final double barHeight;

  /// Bar width plus its gap. Reserved whether or not a bar is drawn, so
  /// content starts at the same inset down the whole list.
  final double severityLane;

  final double leadingExtent;
  final double radius;

  /// `surface` on a card and on a standalone row; null on Veld's flush row,
  /// where it is transparent over the ground and the 2px rule is what
  /// identifies it.
  final Color? fill;

  final Color? outline;
  final double outlineWidth;
  final Color? separatorColour;
  final double separatorWidth;

  /// Solid — critical only.
  final Color? barFill;

  /// Outlined — watch only.
  final Color? barStroke;

  final Color titleInk;
  final Color subtitleInk;
  final Color metaInk;

  final TiqTypeToken titleStyle;
  final TiqTypeToken subtitleStyle;
  final TiqTypeToken metaStyle;

  final double pressScale;
  final double minTextWidth;
  final double chevronExtent;

  /// Where the text column starts, measured from the row's leading edge.
  ///
  /// This is what the trailing rule is inset to — "inset to the text edge" is
  /// the ruling's wording — and what a migrating screen aligns a section rule
  /// or a sticky header to.
  double textInset({required bool hasLeading}) =>
      margin +
      horizontalPadding +
      severityLane +
      (hasLeading ? leadingExtent + gap : 0);

  /// The whole row is the target, and it is never under the floor: 48 on
  /// Night and Day, 56 in Veld. The densities are 56/64/80, so this is an
  /// assertion rather than a clamp.
  bool meetsTargetFloor(TiqSkin skin) => minHeight >= skin.space.tapTarget;

  /// The golden's line for this spec. Ordered and labelled so a diff names the
  /// value that moved rather than showing two blobs of hex.
  String describe() {
    String hex(Color? c) => c == null
        ? '—'
        : '#${(c.toARGB32() & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0').toUpperCase()}';
    return <String>[
      'form=${form.name}',
      'density=${density.name}',
      'severity=${severity.name}',
      'tappable=$tappable',
      'pressed=$pressed',
      'minHeight=${minHeight.toStringAsFixed(1)}',
      'margin=${margin.toStringAsFixed(1)}',
      'gapAfter=${gapAfter.toStringAsFixed(1)}',
      'pad=${horizontalPadding.toStringAsFixed(1)}/${verticalPadding.toStringAsFixed(1)}',
      'gap=${gap.toStringAsFixed(1)}',
      'lane=${severityLane.toStringAsFixed(1)}',
      'mark=${markIsDot ? 'dot' : 'bar'}',
      'bar=${barWidth.toStringAsFixed(1)}x${barHeight.toStringAsFixed(1)}',
      'barFill=${hex(barFill)}',
      'barStroke=${hex(barStroke)}',
      'leading=${leadingExtent.toStringAsFixed(1)}',
      'radius=${radius.toStringAsFixed(1)}',
      'fill=${hex(fill)}',
      'outline=${hex(outline)}@${outlineWidth.toStringAsFixed(1)}',
      'rule=${hex(separatorColour)}@${separatorWidth.toStringAsFixed(1)}',
      'ink=${hex(titleInk)}/${hex(subtitleInk)}/${hex(metaInk)}',
      'type=${titleStyle.name}/${subtitleStyle.name}/${metaStyle.name}',
      'scale=${pressScale.toStringAsFixed(2)}',
      'chevron=${chevronExtent.toStringAsFixed(1)}',
    ].join('  ');
  }
}

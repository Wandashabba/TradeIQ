import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'tiq_space.dart';

/// The two faces, and the law that divides them.
class TiqFonts {
  TiqFonts._();

  /// Schibsted Grotesk — the prose face. One bundled variable font
  /// (`SchibstedGrotesk-Variable.ttf`, wght **400–900**); Flutter maps
  /// [FontWeight] onto the wght axis, so no static instances are shipped.
  ///
  /// It replaced Onest on 1 October 2026, chosen by the owner from four
  /// open-licensed grotesques shown against the commercial face they were
  /// evaluating. SIL OFL 1.1, bundled rather than fetched — see `pubspec.yaml`.
  ///
  /// Its x-height is Onest's to within a thousandth of an em (0.5273 against
  /// 0.5270), which is why the swap did not change apparent size, and its
  /// lowercase is a few percent narrower, which is why prose wraps slightly
  /// later. The measurements are in `docs/design/torchlight-aisle.md`.
  ///
  /// The axis floor is 400 rather than Onest's 100. Every weight in this file
  /// is 400 or above; a token below it would be silently clamped to regular.
  static const String prose = 'Schibsted Grotesk';

  /// JetBrains Mono — the figure and identifier face.
  static const String mono = 'JetBrains Mono';

  static const List<String> proseFallback = <String>[
    'Roboto',
    'Helvetica',
    'Arial',
    'sans-serif',
  ];

  static const List<String> monoFallback = <String>[
    'Menlo',
    'Courier New',
    'monospace',
  ];
}

/// Whether a type role carries language or carries data.
///
/// This is the enforcement point for the rule that the prose face must never
/// render a figure or a code.
///
/// The rule was first written against Onest, which had no slashed zero,
/// proportional digits, and a capital I and lowercase l of the same shape.
/// **Schibsted Grotesk answers two of those three** — it has a slashed zero
/// under the `zero` feature, and its I and l are plainly different glyphs —
/// and the split stays anyway, because it is a design decision rather than a
/// glyph audit: a figure face and a prose face doing different jobs is what the
/// product reads as. The one ground that still holds on its own terms is the
/// third: digits are proportional by default in both faces, and a column of
/// stock counts is not a column without `tnum`.
///
/// `torchlight_type_test.dart` asserts the mapping in both directions.
enum TiqTypeKind {
  /// Language. Schibsted Grotesk.
  prose,

  /// A quantity, a timestamp, a unit, an axis label — anything a reader
  /// compares column-to-column. JetBrains Mono with `tnum` on.
  figure,

  /// A machine identifier: outlet code, GTIN, batch number, order ref,
  /// coordinate. JetBrains Mono with `tnum` on.
  identifier,
}

/// One role in the type scale.
@immutable
class TiqTypeToken {
  const TiqTypeToken({
    required this.name,
    required this.kind,
    required this.size,
    required this.weight,
    required this.height,
    this.trackingPercent = 0,
    this.uppercase = false,
    this.maxTextScale,
  });

  final String name;
  final TiqTypeKind kind;
  final double size;
  final FontWeight weight;

  /// Line height as a multiple of [size].
  final double height;

  /// Letter spacing as a percentage of [size] — the spec states tracking in
  /// percent, and a percentage is the only form that survives a size change.
  final double trackingPercent;

  final bool uppercase;

  /// The one documented exception to the app-wide 2.0 clamp. Set only on
  /// `hero.figure`: above 1.6 no fitting rule saves a 72px number on a 360dp
  /// screen. Documented in the token, not hidden in a wrapper.
  final double? maxTextScale;

  bool get isFigure =>
      kind == TiqTypeKind.figure || kind == TiqTypeKind.identifier;

  String get family => isFigure ? TiqFonts.mono : TiqFonts.prose;

  List<String> get fallback =>
      isFigure ? TiqFonts.monoFallback : TiqFonts.proseFallback;

  /// The resolved style. [color] is applied by [TiqType], which holds the
  /// skin's ink.
  TextStyle style({Color? color}) => TextStyle(
    color: color,
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: size * trackingPercent / 100,
    // Tabular figures on every data role, so a column of numbers is a column.
    fontFeatures: isFigure
        ? const <FontFeature>[FontFeature.tabularFigures()]
        : null,
  );

  TiqTypeToken copyWith({
    double? size,
    FontWeight? weight,
    double? height,
    double? trackingPercent,
  }) => TiqTypeToken(
    name: name,
    kind: kind,
    size: size ?? this.size,
    weight: weight ?? this.weight,
    height: height ?? this.height,
    trackingPercent: trackingPercent ?? this.trackingPercent,
    uppercase: uppercase,
    maxTextScale: maxTextScale,
  );
}

/// The type scale, resolved for one skin.
///
/// Sizes come from the spec; Console and Field differ only where the spec
/// says they do.
@immutable
class TiqType {
  const TiqType({
    required this.heroFigure,
    required this.heroFigureCompact,
    required this.display,
    required this.displayM,
    required this.displayS,
    required this.figureL,
    required this.figureM,
    required this.figureS,
    required this.titleL,
    required this.titleM,
    required this.headlineAnswer,
    required this.body,
    required this.bodyStrong,
    required this.label,
    required this.eyebrow,
    required this.meta,
    required this.axisLabel,
    required this.monoIdent,
  });

  /// ≤3 glyphs. The glyph-count fitting rule picks between this,
  /// [heroFigureCompact] and [display]; the formatter runs first.
  final TiqTypeToken heroFigure;

  /// 4–6 glyphs.
  final TiqTypeToken heroFigureCompact;

  /// 7+ glyphs, and the empty-state headline at one or two lines.
  final TiqTypeToken display;

  /// The display role's **three lines** step (unify §1.12).
  ///
  /// Display prose was the one type role with no fitting rule while
  /// `hero.figure` had one keyed to glyph count. It is now keyed to LINE
  /// COUNT after layout: 1–2 lines stay at [display] (40), 3 lines step to
  /// this (32), 4 or more to [displayS] (26), which is the floor.
  ///
  /// These are declared members of the scale rather than a `copyWith` at the
  /// call site, because a size that only exists inside one screen's helper is
  /// a size no contrast walk, no render sampler and no text-scale cap ever
  /// sees. `displayFor` in the empty-state grammar picks between the three.
  final TiqTypeToken displayM;

  /// The display role's **four-or-more lines** step, and its floor.
  final TiqTypeToken displayS;

  /// Stat tiles.
  final TiqTypeToken figureL;
  final TiqTypeToken figureM;
  final TiqTypeToken figureS;

  final TiqTypeToken titleL;
  final TiqTypeToken titleM;

  /// The answer's one sentence. Max width 32em.
  final TiqTypeToken headlineAnswer;

  final TiqTypeToken body;
  final TiqTypeToken bodyStrong;
  final TiqTypeToken label;

  /// 11/700/+4% uppercase, wrapping to two lines.
  ///
  /// Four places (unify §1.17, as overridden 25–26 September 2026): a stat
  /// tile's label, a hero/plate figure's label, a block label inside a panel
  /// ("WORST FIRST"), and — since the owner asked for The Floor's design
  /// everywhere — **the screen-level section marker**, which is now this role
  /// on the ground rather than `title.m` knocked out of a rule. `SectionRule`
  /// is the only component that may set a section marker in it.
  ///
  /// Tracking moved from +8% to **+4%** in Phase 1 (unify §1.4, "applies to
  /// the eyebrow role globally"). Uppercase plus tracking is the most
  /// space-hungry setting in the system and the eyebrow is a stat tile's only
  /// label channel; +8% on "BESKIKBAARHEID OP RAK" cost a line it did not
  /// need to.
  final TiqTypeToken eyebrow;

  /// Timestamps and source lines — prose.
  final TiqTypeToken meta;

  /// Chart axis labels and units — numerals, so mono.
  final TiqTypeToken axisLabel;

  /// Machine identifiers: outlet codes, GTINs, batch numbers, order refs,
  /// coordinates.
  final TiqTypeToken monoIdent;

  /// Every role, for the guard tests and for the docs generator.
  List<TiqTypeToken> get all => <TiqTypeToken>[
    heroFigure,
    heroFigureCompact,
    display,
    displayM,
    displayS,
    figureL,
    figureM,
    figureS,
    titleL,
    titleM,
    headlineAnswer,
    body,
    bodyStrong,
    label,
    eyebrow,
    meta,
    axisLabel,
    monoIdent,
  ];

  static const FontWeight _w4 = FontWeight.w400;
  static const FontWeight _w5 = FontWeight.w500;
  static const FontWeight _w6 = FontWeight.w600;
  static const FontWeight _w7 = FontWeight.w700;

  static const TiqTypeToken _heroFigure = TiqTypeToken(
    name: 'hero.figure',
    kind: TiqTypeKind.figure,
    size: 72,
    weight: _w6,
    height: 0.92,
    trackingPercent: -2.5,
    maxTextScale: 1.6,
  );

  static const TiqTypeToken _heroFigureCompact = TiqTypeToken(
    name: 'hero.figure.compact',
    kind: TiqTypeKind.figure,
    size: 56,
    weight: _w6,
    height: 0.95,
    trackingPercent: -2.0,
  );

  static const TiqTypeToken _display = TiqTypeToken(
    name: 'display',
    kind: TiqTypeKind.prose,
    size: 40,
    weight: _w6,
    height: 1.00,
    trackingPercent: -1.5,
  );

  static const TiqTypeToken _displayM = TiqTypeToken(
    name: 'display.m',
    kind: TiqTypeKind.prose,
    size: 32,
    weight: _w6,
    height: 1.05,
    trackingPercent: -1.0,
  );

  static const TiqTypeToken _displayS = TiqTypeToken(
    name: 'display.s',
    kind: TiqTypeKind.prose,
    size: 26,
    weight: _w6,
    height: 1.15,
    trackingPercent: -0.5,
  );

  static const TiqTypeToken _figureL = TiqTypeToken(
    name: 'figure.l',
    kind: TiqTypeKind.figure,
    size: 32,
    weight: _w6,
    height: 1.05,
    trackingPercent: -1.0,
  );

  static const TiqTypeToken _figureM = TiqTypeToken(
    name: 'figure.m',
    kind: TiqTypeKind.figure,
    size: 22,
    weight: _w6,
    height: 1.10,
    trackingPercent: -0.5,
  );

  static const TiqTypeToken _figureS = TiqTypeToken(
    name: 'figure.s',
    kind: TiqTypeKind.figure,
    size: 16,
    weight: _w6,
    height: 1.20,
  );

  static const TiqTypeToken _titleM = TiqTypeToken(
    name: 'title.m',
    kind: TiqTypeKind.prose,
    size: 16,
    weight: _w6,
    height: 1.30,
    trackingPercent: -0.25,
  );

  static const TiqTypeToken _headlineAnswer = TiqTypeToken(
    name: 'headline.answer',
    kind: TiqTypeKind.prose,
    size: 22,
    weight: _w6,
    height: 1.35,
    trackingPercent: -0.5,
  );

  static const TiqTypeToken _label = TiqTypeToken(
    name: 'label',
    kind: TiqTypeKind.prose,
    size: 13,
    weight: _w5,
    height: 1.35,
    trackingPercent: 0.5,
  );

  static const TiqTypeToken _eyebrow = TiqTypeToken(
    name: 'eyebrow',
    kind: TiqTypeKind.prose,
    size: 11,
    weight: _w7,
    height: 1.10,
    trackingPercent: 4,
    uppercase: true,
  );

  static const TiqTypeToken _meta = TiqTypeToken(
    name: 'meta',
    kind: TiqTypeKind.prose,
    size: 12,
    weight: _w4,
    height: 1.40,
  );

  static const TiqTypeToken _axisLabel = TiqTypeToken(
    name: 'axis.label',
    kind: TiqTypeKind.figure,
    size: 12,
    weight: _w4,
    height: 1.40,
  );

  static const TiqTypeToken _monoIdent = TiqTypeToken(
    name: 'mono.ident',
    kind: TiqTypeKind.identifier,
    size: 13,
    weight: _w5,
    height: 1.30,
    trackingPercent: 1,
  );

  /// The manager console.
  static const TiqType console = TiqType(
    heroFigure: _heroFigure,
    heroFigureCompact: _heroFigureCompact,
    display: _display,
    displayM: _displayM,
    displayS: _displayS,
    figureL: _figureL,
    figureM: _figureM,
    figureS: _figureS,
    titleL: TiqTypeToken(
      name: 'title.l',
      kind: TiqTypeKind.prose,
      size: 20,
      weight: _w6,
      height: 1.25,
      trackingPercent: -0.5,
    ),
    titleM: _titleM,
    headlineAnswer: _headlineAnswer,
    body: TiqTypeToken(
      name: 'body',
      kind: TiqTypeKind.prose,
      size: 14,
      weight: _w4,
      height: 1.55,
    ),
    bodyStrong: TiqTypeToken(
      name: 'body.strong',
      kind: TiqTypeKind.prose,
      size: 14,
      weight: _w6,
      height: 1.55,
    ),
    label: _label,
    eyebrow: _eyebrow,
    meta: _meta,
    axisLabel: _axisLabel,
    monoIdent: _monoIdent,
  );

  /// The field agent's phone: `title.l` is 24, body is 15/1.50.
  ///
  /// **SUPERSEDED — owner override, 29 September 2026. Nothing reads this any
  /// more; [forDensity] returns [console] at both densities.**
  ///
  /// > *"Make the font on the agentside the same as the manager side,
  /// > literally everything including colours"*
  ///
  /// The rationale below is **not withdrawn, it is outranked**, and it is kept
  /// here in full so that whoever reads this later knows exactly what was
  /// traded and can put it back by reverting one line in [forDensity].
  ///
  /// WHAT THIS SCALE WAS FOR. The agent reads standing up, at arm's length,
  /// one-handed, on a cheap panel at 40% backlight, often in direct sunlight —
  /// the same premise that gives field density its 48dp targets and its 64dp
  /// rows. Larger prose is the type half of that answer: `title.l` at 24 so an
  /// outlet name survives a glance, body at 15/1.50 so a blocking sentence
  /// survives a forecourt at 13:00. It was the one compensation left after
  /// Veld was struck on 28 September 2026 (unify §4), which is the paragraph
  /// that says out loud that outdoor legibility was given up and *nothing
  /// replaces it*. This scale was part of what was left.
  ///
  /// WHAT THE OVERRIDE BUYS. One type scale across the product. The owner has
  /// been looking at the two surfaces side by side all day and has ruled, three
  /// times, that the manager side is the reference; type was the last axis on
  /// which the agent side still diverged by construction rather than by drift.
  ///
  /// WHAT IT COSTS. Roughly a 7% linear reduction in prose on exactly the
  /// screens that are read outdoors. **Touch targets are untouched** — this is
  /// a type decision and not a density one; `TiqSpace.field` keeps its 48dp
  /// targets, its 64dp rows and its block gap, because thumb reach was not
  /// what the owner was looking at.
  ///
  /// TO RESTORE: make [forDensity] return this object for [TiqDensity.field]
  /// again. Nothing else has to move.
  static const TiqType field = TiqType(
    heroFigure: _heroFigure,
    heroFigureCompact: _heroFigureCompact,
    display: _display,
    displayM: _displayM,
    displayS: _displayS,
    figureL: _figureL,
    figureM: _figureM,
    figureS: _figureS,
    titleL: TiqTypeToken(
      name: 'title.l',
      kind: TiqTypeKind.prose,
      size: 24,
      weight: _w6,
      height: 1.25,
      trackingPercent: -0.5,
    ),
    titleM: _titleM,
    headlineAnswer: _headlineAnswer,
    body: TiqTypeToken(
      name: 'body',
      kind: TiqTypeKind.prose,
      size: 15,
      weight: _w4,
      height: 1.50,
    ),
    bodyStrong: TiqTypeToken(
      name: 'body.strong',
      kind: TiqTypeKind.prose,
      size: 15,
      weight: _w6,
      height: 1.50,
    ),
    label: _label,
    eyebrow: _eyebrow,
    meta: _meta,
    axisLabel: _axisLabel,
    monoIdent: _monoIdent,
  );

  /// The type scale for a density — **[console] at both, since 29 September
  /// 2026.**
  ///
  /// > *"Make the font on the agentside the same as the manager side,
  /// > literally everything including colours"* — the owner.
  ///
  /// There is one type scale in this product. [field] is kept beside it,
  /// unreferenced, as the record of what it used to be and why; see its doc
  /// comment. This line is the whole of the override, deliberately: a reader
  /// who wants the field scale back changes `console` to `field` here, and a
  /// reader who edits one token of [console] can no longer make the two
  /// surfaces drift apart by accident, because there is only one of them.
  static TiqType forDensity(TiqDensity density) => switch (density) {
    TiqDensity.console || TiqDensity.field => console,
  };
}

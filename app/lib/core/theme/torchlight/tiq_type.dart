import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'tiq_space.dart';

/// The two faces, and the law that divides them.
class TiqFonts {
  TiqFonts._();

  /// Onest — the prose face. One bundled variable font (`Onest[wght].ttf`,
  /// wght 100–900); Flutter maps [FontWeight] onto the wght axis, so no static
  /// instances are shipped.
  static const String prose = 'Onest';

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
/// This is the enforcement point for the rule that Onest must never render a
/// figure or a code. Onest has no slashed zero, its digits are proportional,
/// and its capital I and lowercase l are the same shape — all three are fine
/// for prose and disqualifying for an outlet code, a GTIN or an order ref.
/// `torchlight_type_test.dart` asserts the mapping in both directions.
enum TiqTypeKind {
  /// Language. Onest.
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
/// Sizes come from the spec; Console/Field differ only where the spec says
/// they do, and Veld steps up by explicit declared values rather than "one
/// stop" — a stop is how the first draft invented a 17px that collided with
/// two existing roles.
@immutable
class TiqType {
  const TiqType({
    required this.heroFigure,
    required this.heroFigureCompact,
    required this.display,
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

  /// 7+ glyphs, and the empty-state headline.
  final TiqTypeToken display;

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
  /// Legal in three places only (unify §1.17): a stat tile's label, a
  /// hero/plate figure's label, and a block label inside a panel ("WORST
  /// FIRST"). Every screen-level section marker is the knocked-out rule at
  /// `title.m` in sentence case, not an eyebrow.
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
  static const TiqType field = TiqType(
    heroFigure: _heroFigure,
    heroFigureCompact: _heroFigureCompact,
    display: _display,
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

  /// Veld. Declared scale members, not "one stop": body 15→17, label 13→16,
  /// meta 12→14, title.m 16→18, figure.m 22→24, a 600 weight floor,
  /// line-height +0.05 and tracking +0.5% because glare fills counters.
  static const TiqType veld = TiqType(
    heroFigure: TiqTypeToken(
      name: 'hero.figure',
      kind: TiqTypeKind.figure,
      size: 72,
      weight: _w7,
      height: 0.97,
      trackingPercent: -2.0,
      maxTextScale: 1.6,
    ),
    heroFigureCompact: TiqTypeToken(
      name: 'hero.figure.compact',
      kind: TiqTypeKind.figure,
      size: 56,
      weight: _w7,
      height: 1.00,
      trackingPercent: -1.5,
    ),
    display: TiqTypeToken(
      name: 'display',
      kind: TiqTypeKind.prose,
      size: 40,
      weight: _w7,
      height: 1.05,
      trackingPercent: -1.0,
    ),
    figureL: TiqTypeToken(
      name: 'figure.l',
      kind: TiqTypeKind.figure,
      size: 32,
      weight: _w7,
      height: 1.10,
      trackingPercent: -0.5,
    ),
    figureM: TiqTypeToken(
      name: 'figure.m',
      kind: TiqTypeKind.figure,
      size: 24,
      weight: _w7,
      height: 1.15,
    ),
    figureS: TiqTypeToken(
      name: 'figure.s',
      kind: TiqTypeKind.figure,
      size: 16,
      weight: _w7,
      height: 1.25,
      trackingPercent: 0.5,
    ),
    titleL: TiqTypeToken(
      name: 'title.l',
      kind: TiqTypeKind.prose,
      size: 24,
      weight: _w7,
      height: 1.30,
    ),
    titleM: TiqTypeToken(
      name: 'title.m',
      kind: TiqTypeKind.prose,
      size: 18,
      weight: _w7,
      height: 1.35,
      trackingPercent: 0.25,
    ),
    headlineAnswer: TiqTypeToken(
      name: 'headline.answer',
      kind: TiqTypeKind.prose,
      size: 22,
      weight: _w7,
      height: 1.40,
    ),
    body: TiqTypeToken(
      name: 'body',
      kind: TiqTypeKind.prose,
      size: 17,
      weight: _w6,
      height: 1.55,
      trackingPercent: 0.5,
    ),
    bodyStrong: TiqTypeToken(
      name: 'body.strong',
      kind: TiqTypeKind.prose,
      size: 17,
      weight: _w7,
      height: 1.55,
      trackingPercent: 0.5,
    ),
    label: TiqTypeToken(
      name: 'label',
      kind: TiqTypeKind.prose,
      size: 16,
      weight: _w6,
      height: 1.40,
      trackingPercent: 1.0,
    ),
    eyebrow: TiqTypeToken(
      name: 'eyebrow',
      kind: TiqTypeKind.prose,
      size: 13,
      weight: _w7,
      height: 1.15,
      trackingPercent: 4,
      uppercase: true,
    ),
    meta: TiqTypeToken(
      name: 'meta',
      kind: TiqTypeKind.prose,
      size: 14,
      weight: _w6,
      height: 1.45,
      trackingPercent: 0.5,
    ),
    axisLabel: TiqTypeToken(
      name: 'axis.label',
      kind: TiqTypeKind.figure,
      size: 14,
      weight: _w6,
      height: 1.45,
      trackingPercent: 0.5,
    ),
    monoIdent: TiqTypeToken(
      name: 'mono.ident',
      kind: TiqTypeKind.identifier,
      size: 16,
      weight: _w6,
      height: 1.35,
      trackingPercent: 1,
    ),
  );

  static TiqType forDensity(TiqDensity density) => switch (density) {
    TiqDensity.console => console,
    TiqDensity.field => field,
    TiqDensity.veld => veld,
  };
}

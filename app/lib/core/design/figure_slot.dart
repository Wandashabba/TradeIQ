import 'package:flutter/widgets.dart';

import '../theme/torchlight/tiq_skin.dart';
import 'tiq_number.dart';

/// THE ONE FIGURE PRIMITIVE.
///
/// Every number the app draws — a hero score, a stat tile, an axis label, a
/// table cell — is one of these. It owns four things that were being decided
/// separately, and wrongly, in every screen that showed a number:
///
/// 1. **The faces.** The digits are JetBrains Mono with tabular figures; the
///    affixes (`R`, `%`, `pts`) are Onest, because they are language. Onest
///    has no slashed zero and proportional digits, so a column of stock counts
///    set in it is not a column.
/// 2. **The unknown states.** A measured zero prints `0` and keeps its place.
///    A null prints an em dash in ink-3, at the figure's own role and face,
///    with the unit suppressed and no delta. A low sample keeps the figure at
///    ink-2 and removes the delta. A tile is never hidden.
/// 3. **The fitting.** Candidate roles are *measured* with a `TextPainter` at
///    the live `TextScaler`, affixes included, and the first that fits wins.
///    There is no `FittedBox`: optically shrinking one figure in a baseline
///    row breaks the row's baseline and puts two numbers at two sizes next to
///    each other, which is exactly what a tabular column exists to prevent.
/// 4. **The scale cap.** `hero.figure` caps at 1.6× — the one documented
///    exception to the app-wide 2.0 clamp — and the cap lives on the token, so
///    it is visible to anyone reading the scale.
///
/// ```dart
/// FigureSlot(
///   value: outlet.score,
///   role: skin.text.figureL,
///   fit: [skin.text.figureL, skin.text.figureM],
///   unit: TiqUnit.percent,
///   state: outlet.sampleSize < 30 ? FigureState.lowSample : FigureState.measured,
///   semanticsLabel: l10n.scoreOf(outlet.name),
/// )
/// ```
class FigureSlot extends StatelessWidget {
  const FigureSlot({
    super.key,
    required this.value,
    required this.role,
    this.fit,
    this.unit = TiqUnit.none,
    this.decimals,
    this.signed = false,
    this.state = FigureState.measured,
    this.color,
    this.textAlign = TextAlign.start,
    this.semanticsLabel,
  });

  /// Null is a state, not an absence: it renders an em dash, not nothing.
  final num? value;

  /// The role this figure is set in. Must be a `figure` or `identifier` role —
  /// asserted, because a figure in Onest is the bug this class exists to stop.
  final TiqTypeToken role;

  /// Candidate roles, largest first, measured in order. Defaults to [role]
  /// alone. The classic set is
  /// `[hero.figure, hero.figure.compact, display]`.
  final List<TiqTypeToken>? fit;

  final TiqUnit unit;

  /// The metric's declared precision, where the server sends one.
  final int? decimals;

  /// An explicit `+` on a rise. For a delta, never for a level.
  final bool signed;

  final FigureState state;

  /// The ink for a *measured* figure. The unknown states override it — an
  /// em dash is ink-3 whatever the caller wanted, because that is what makes
  /// it read as an absence rather than as a value.
  final Color? color;

  final TextAlign textAlign;

  /// What a screen reader says. Required for every state except a plain
  /// measurement: "em dash" is not a sentence, and the design asks for one
  /// in words ("No visits in this window").
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    assert(
      role.isFigure,
      'FigureSlot: ${role.name} is a prose role. Onest has no slashed zero, '
      'its digits are proportional and its I and l are the same shape — all '
      'three are fine in a sentence and disqualifying in a figure. Use a '
      'figure or identifier role.',
    );
    final skin = context.skin;
    final figure = TiqNumber.of(context).split(
      value,
      unit: unit,
      decimals: decimals,
      signed: signed,
      state: state,
    );
    // Asserted on the RESOLVED state, not the declared one: a caller that
    // passes a null value has not declared `missing`, it has produced one.
    assert(
      figure.state == FigureState.measured || semanticsLabel != null,
      'FigureSlot: a ${figure.state.name} figure needs a semanticsLabel. An '
      'em dash announced as "em dash" is not the sentence in words the design '
      'asks for.',
    );
    final candidates = fit ?? <TiqTypeToken>[role];
    assert(candidates.isNotEmpty, 'FigureSlot: fit cannot be empty.');

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = _scalerFor(context, candidates.first);
        final chosen = _choose(
          candidates,
          figure,
          scaler,
          constraints.maxWidth,
          skin,
        );
        final span = _span(chosen, figure, skin);
        return Semantics(
          label: semanticsLabel,
          excludeSemantics: semanticsLabel != null,
          child: Text.rich(
            span,
            textAlign: textAlign,
            textScaler: _scalerFor(context, chosen),
            maxLines: 1,
            softWrap: false,
            // A figure that overflows has already lost — the fitting above is
            // what prevents it. Clipping rather than ellipsising means a wrong
            // measurement shows as a cut digit, which is obvious, instead of a
            // "1,28…" that reads as a real number.
            overflow: TextOverflow.clip,
          ),
        );
      },
    );
  }

  /// The live scaler, clamped to the app ceiling and then to the role's own
  /// cap. Applied through `TextScaler`, never as a factor multiplied into a
  /// font size — a factor stops being right the moment the platform stops
  /// being linear.
  /// The width this figure takes at [role] and the live text scale, affixes
  /// included — for a column of figures that must share one width, so the
  /// thing beside them (a bar's track) starts and ends in the same place on
  /// every row. Measured exactly as the slot lays itself out.
  static double measure(
    BuildContext context, {
    required num? value,
    required TiqTypeToken role,
    TiqUnit unit = TiqUnit.none,
    int? decimals,
    bool signed = false,
  }) {
    final slot = FigureSlot(
      value: value,
      role: role,
      unit: unit,
      decimals: decimals,
      signed: signed,
      semanticsLabel: '',
    );
    final figure = TiqNumber.of(context).split(
      value,
      unit: unit,
      decimals: decimals,
      signed: signed,
      state: FigureState.measured,
    );
    final painter = TextPainter(
      text: slot._span(role, figure, context.skin),
      textDirection: TextDirection.ltr,
      textScaler: slot._scalerFor(context, role),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  TextScaler _scalerFor(BuildContext context, TiqTypeToken token) {
    final scaler = MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final cap = token.maxTextScale;
    return cap == null
        ? scaler
        : scaler.clamp(maxScaleFactor: cap);
  }

  /// Measure, do not guess. Every candidate is laid out with its real affixes
  /// at the real scale; the first that fits the incoming constraint wins, and
  /// the smallest is the floor.
  TiqTypeToken _choose(
    List<TiqTypeToken> candidates,
    FormattedFigure figure,
    TextScaler scaler,
    double maxWidth,
    TiqSkin skin,
  ) {
    if (candidates.length == 1 || !maxWidth.isFinite) return candidates.first;
    for (final candidate in candidates) {
      final painter = TextPainter(
        text: _span(candidate, figure, skin),
        textDirection: TextDirection.ltr,
        textScaler: _clampFor(scaler, candidate),
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      if (width <= maxWidth) return candidate;
    }
    return candidates.last;
  }

  TextScaler _clampFor(TextScaler scaler, TiqTypeToken token) {
    final cap = token.maxTextScale;
    return cap == null ? scaler : scaler.clamp(maxScaleFactor: cap);
  }

  /// Three runs, two faces. The affixes take the same size as the digits and
  /// zero tracking — a mono role's tracking is 0 by declaration, and an affix
  /// that inherited a negative one would kern into the digit beside it.
  InlineSpan _span(TiqTypeToken token, FormattedFigure figure, TiqSkin skin) {
    final ink = _ink(skin, figure.state);
    final run = token.style(color: ink).copyWith(
      decoration: figure.state == FigureState.provisional
          ? TextDecoration.underline
          : null,
      decorationStyle: TextDecorationStyle.dotted,
      decorationColor: ink,
    );
    final affix = run.copyWith(
      fontFamily: TiqFonts.prose,
      fontFamilyFallback: TiqFonts.proseFallback,
      letterSpacing: 0,
      fontFeatures: const <FontFeature>[],
    );
    return TextSpan(
      children: <InlineSpan>[
        if (figure.prefix.isNotEmpty)
          TextSpan(text: figure.prefix, style: affix),
        TextSpan(text: figure.run, style: run),
        if (figure.suffix.isNotEmpty)
          TextSpan(text: figure.suffix, style: affix),
      ],
    );
  }

  Color _ink(TiqSkin skin, FigureState state) => switch (state) {
    // An em dash is ink-3 whatever the caller asked for. Its job is to read as
    // an absence, and an absence in ink-1 reads as a value.
    FigureState.missing || FigureState.notMeasured => skin.palette.ink3,
    // A thin sample is a real number the reader should trust less. One ink
    // step down, plus the outlined fill and the removed delta the caller
    // applies from `figure.allowsDelta`.
    FigureState.lowSample => skin.palette.ink2,
    FigureState.provisional => color ?? skin.palette.ink1,
    FigureState.measured => color ?? skin.palette.ink1,
  };
}

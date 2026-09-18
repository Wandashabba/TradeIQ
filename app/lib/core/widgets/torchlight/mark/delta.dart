import 'package:flutter/widgets.dart';

import '../../../design/figure_slot.dart';
import '../../../design/tiq_number.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import '../figure/sample_threshold.dart';
import 'tiq_mark.dart';

/// Which way a figure moved. **From the server's `direction` field, never
/// inferred from the sign**: a delta may be sent as a magnitude.
enum DeltaDirection { up, down, flat }

/// Whether the movement is good news. **From the server's `sentiment` field,
/// never inferred from the direction**: a stock-out count going up is bad and
/// a spoilage count going down is good, so neither can be derived from the
/// other.
enum TiqSentiment {
  good,
  bad,

  /// Ink-3. The honest render when the server is slow, absent or sends
  /// something this client does not know.
  neutral;

  /// The wire's `sentiment` string.
  ///
  /// `warn` maps to [neutral], deliberately. The wire has a warn level; this
  /// design system does not have an amber warning, and a delta is never a
  /// severity carrier — a movement that genuinely needs a verdict gets one
  /// from the severity mark set, in crimson at a declared commitment level,
  /// beside the figure. Rendering `warn` as anything other than neutral would
  /// put a third colour on a mark whose whole job is direction.
  static TiqSentiment fromWire(Object? raw) => switch (raw) {
    'good' => TiqSentiment.good,
    'bad' => TiqSentiment.bad,
    _ => TiqSentiment.neutral,
  };

  Color inkOn(TiqSkin skin) => switch (this) {
    TiqSentiment.good => skin.palette.good,
    TiqSentiment.bad => skin.palette.bad,
    TiqSentiment.neutral => skin.palette.ink3,
  };
}

/// One movement, as the server stated it.
@immutable
class DeltaData {
  const DeltaData({
    required this.direction,
    required this.sentiment,
    this.magnitude,
    this.unit = TiqUnit.none,
    this.decimals,
    this.comparedTo,
  });

  final DeltaDirection direction;
  final TiqSentiment sentiment;

  /// The size of the movement, unsigned.
  ///
  /// Null means **there was no baseline to compare against** — the prior
  /// period was zero, or this is the first window. That renders as the words
  /// "up from none" with the triangle and no percentage. Never "n/a" beside a
  /// triangle, and never ∞.
  final num? magnitude;

  final TiqUnit unit;
  final int? decimals;

  /// "vs week 37". Meta, ink-3, wrapping.
  final String? comparedTo;

  bool get hasBaseline => magnitude != null;
}

/// Why a delta is not on screen.
///
/// Every one of these **removes** the delta. None of them greys it: a greyed
/// delta is still a delta, and the reader still reads the arrow.
enum DeltaSuppression {
  /// It is on screen.
  none,

  /// The figure beside it is an em dash. A delta never stands beside nothing
  /// (#392) — this is the rule, stated as an enum member so it has a name in
  /// a stack trace.
  nullFigure,

  /// The current window is too thin. The figure stays, one ink step down; the
  /// movement goes.
  lowSample,

  /// The **baseline** window is too thin. The figure is untouched — it is a
  /// good figure — and only the delta goes, with its own sentence.
  thinBaseline,

  /// There is no movement to show.
  noData,
}

/// The rule that decides whether a delta renders. Pure, so it can be tested
/// without a widget tree, which is how "a delta never appears beside a null"
/// stops being a thing somebody remembers.
class DeltaRule {
  DeltaRule._();

  static DeltaSuppression resolve({
    required FigureState figureState,
    required DeltaData? delta,
    FigureSampling sampling = FigureSampling.unknown,
  }) {
    // Order matters and is declared: the figure's own state outranks the
    // sample, because an em dash has nothing for a delta to be beside at all.
    if (figureState == FigureState.missing ||
        figureState == FigureState.notMeasured) {
      return DeltaSuppression.nullFigure;
    }
    if (delta == null) return DeltaSuppression.noData;
    if (figureState == FigureState.lowSample || sampling.isLowSample) {
      return DeltaSuppression.lowSample;
    }
    if (sampling.isThinBaseline) return DeltaSuppression.thinBaseline;
    return DeltaSuppression.none;
  }
}

/// The words that replace a suppressed delta.
///
/// English defaults; a screen passes its own. A suppressed delta is never
/// blank — the reader has to know the comparison was withheld rather than
/// that it was zero.
@immutable
class DeltaStrings {
  const DeltaStrings({
    this.tooFewToCompare = 'too few visits to compare',
    this.baselineTooThin = 'last week had too few visits — not compared',
    this.upFromNone = 'up from none',
    this.noChange = 'No change',
  });

  final String tooFewToCompare;
  final String baselineTooThin;
  final String upFromNone;
  final String noChange;

  static const DeltaStrings defaults = DeltaStrings();
}

/// The drawn triangle beside a figure.
///
/// Replaces `DeltaChip`, `DeltaPill` and `TileDelta.text`.
///
/// * **Drawn, not typed.** `TileDelta.text` built `▲`/`▼` as characters. Onest
///   does not carry U+25B2/U+25BC once `pyftsubset` has run, and the PDF
///   exporter rendered them as nothing at all (#401) — a number with no
///   direction beside it, which is worse than no delta.
/// * **No wash, no pill, no border, no radius.** `DeltaChip` put a 14%-alpha
///   severity wash behind an 11px figure: a second severity fill competing
///   with the severity system's own two commitment levels, and at 14% on a
///   6-bit LCD at 40% backlight it is one quantisation level — invisible where
///   it matters and noisy where it does not.
/// * **Direction and verdict are two fields.** The triangle is
///   [DeltaData.direction]; the colour is [DeltaData.sentiment]; neither is
///   derived from the other.
///
/// Use [DeltaSlot] rather than this widget directly unless you have already
/// run [DeltaRule].
class Delta extends StatelessWidget {
  const Delta({
    super.key,
    required this.data,
    this.strings = DeltaStrings.defaults,
    this.compact = false,
    this.semanticsLabel,
  });

  final DeltaData data;
  final DeltaStrings strings;

  /// True beside a `figure.l` or smaller: the magnitude sets at `label` rather
  /// than `figure.s`.
  final bool compact;

  /// "Down 19 points against last week, which is bad" — direction word,
  /// magnitude with unit, baseline, verdict word, in that order. The verdict
  /// word is always in the string, so colour is never the only carrier.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ink = data.sentiment.inkOn(skin);
    final triangle = MarkScale.glyph(context, 8);
    final shape = switch (data.direction) {
      DeltaDirection.up => MarkShape.deltaUp,
      DeltaDirection.down => MarkShape.deltaDown,
      DeltaDirection.flat => MarkShape.deltaFlat,
    };
    final metaStyle = skin.text.meta.style(color: skin.palette.ink3);

    final Widget magnitude;
    if (!data.hasBaseline) {
      // No baseline: the words, never a percentage and never ∞.
      magnitude = Text(strings.upFromNone, style: metaStyle);
    } else if (data.direction == DeltaDirection.flat &&
        data.magnitude == 0 &&
        !compact) {
      magnitude = Text(strings.noChange, style: metaStyle);
    } else {
      magnitude = FigureSlot(
        value: data.magnitude,
        role: compact ? skin.text.monoIdent : skin.text.figureS,
        unit: data.unit,
        decimals: data.decimals,
        // Signed, because the sign is the arithmetic and the triangle is the
        // reading. A rounds-to-zero magnitude prints unsigned — the formatter
        // already refuses to claim a movement that did not happen.
        signed: true,
        color: ink,
      );
    }

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      // A Wrap and not a Row: at 2.0× the triangle and magnitude take line
      // one and `comparedTo` takes line two, rather than the row clipping.
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TiqMark(shape: shape, color: ink, size: triangle),
              const SizedBox(width: 4),
              magnitude,
            ],
          ),
          if (data.comparedTo != null)
            Text(data.comparedTo!, style: metaStyle),
        ],
      ),
    );
  }
}

/// The delta's place in a layout — which is sometimes a delta and sometimes a
/// sentence saying why there is not one.
///
/// This is the widget a tile or a row should use. It runs [DeltaRule] and then
/// renders one of three things, and never a fourth:
///
/// 1. the [Delta];
/// 2. a meta line in words, when the comparison was withheld;
/// 3. nothing at all, when the figure beside it is an em dash.
///
/// Case 3 is the whole of #392. Case 2 is the case the low-sample rule missed.
class DeltaSlot extends StatelessWidget {
  const DeltaSlot({
    super.key,
    required this.data,
    required this.figureState,
    this.sampling = FigureSampling.unknown,
    this.strings = DeltaStrings.defaults,
    this.compact = false,
    this.semanticsLabel,
  });

  final DeltaData? data;
  final FigureState figureState;
  final FigureSampling sampling;
  final DeltaStrings strings;
  final bool compact;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final suppression = DeltaRule.resolve(
      figureState: figureState,
      delta: data,
      sampling: sampling,
    );
    final metaStyle = skin.text.meta.style(color: skin.palette.ink3);
    return switch (suppression) {
      DeltaSuppression.none => Delta(
        data: data!,
        strings: strings,
        compact: compact,
        semanticsLabel: semanticsLabel,
      ),
      // Nothing. Not a gap held open, not a skeleton: a slot that will have no
      // delta must not promise one.
      DeltaSuppression.nullFigure ||
      DeltaSuppression.noData => const SizedBox.shrink(),
      DeltaSuppression.lowSample => Text(
        strings.tooFewToCompare,
        style: metaStyle,
      ),
      DeltaSuppression.thinBaseline => Text(
        strings.baselineTooThin,
        style: metaStyle,
      ),
    };
  }
}

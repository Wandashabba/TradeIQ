import 'package:flutter/widgets.dart';

import '../../../design/figure_slot.dart';
import '../../../design/tiq_number.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import '../mark/tiq_mark.dart';

/// Whose number it is, and therefore which sentence the reconciliation uses.
///
/// One component, two string sets (unify §1.20). The manager never saw 84, so
/// "it was 84 when you saw it" is false on the console; the agent did see it,
/// so "the phone showed 84" is oddly distant on the agent app. The same
/// arithmetic, two voices, and neither string is shared.
enum ReconciliationVoice {
  /// Second person. "Now scored 71 — it was 84 when you saw it."
  agent,

  /// Third person. "Scored 71 — the phone showed 84."
  console,
}

/// The typographic distinction between an estimate and a recorded figure.
///
/// A dotted underline under the mono run (which [FigureSlot] draws when the
/// figure's state is `provisional`) plus **the word**, with a hollow-circle
/// mark. The figure stays ink-1 and full size: dimming a provisional number
/// would imply it is less legible rather than less final.
///
/// No count-up on a provisional figure. Count-up is the gesture of arrival.
///
/// ## Console only
///
/// The agent app never shows a provisional score (unify §1.20).
/// `visit_outcome_screen.dart`'s no-guess behaviour stands: where the final has
/// not arrived, the agent sees no number at all and a receipt. This widget is
/// for the manager console, where a provisional figure is a figure with a
/// caveat rather than a guess shown to the person who produced it.
class ProvisionalMarker extends StatelessWidget {
  const ProvisionalMarker({
    super.key,
    this.word = 'Provisional',
    this.confirmed = false,
    this.confirmedWord = 'Confirmed',
  });

  /// The localised word.
  final String word;

  /// The reassurance case: a final figure that agreed with its provisional
  /// within the metric's rounding. The same mark, filled — "confirmed" and
  /// "provisional" are one shape at two states, so the pair is legible at a
  /// glance and in greyscale.
  final bool confirmed;

  final String confirmedWord;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ink = skin.palette.ink3;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TiqMark(
          shape: confirmed ? MarkShape.filledCircle : MarkShape.hollowCircle,
          color: ink,
          size: MarkScale.glyph(context, 7),
          strokeWidth: 1.5,
        ),
        const SizedBox(width: 4),
        Text(
          confirmed ? confirmedWord : word,
          style: skin.text.meta.style(color: ink),
        ),
      ],
    );
  }
}

/// "Scored 71 — the phone showed 84."
///
/// One line, rendered when a final figure replaces a provisional one that
/// **differs by more than the metric's rounding**. When the two agree, nothing
/// renders except the confirmed marker: confirming the expected is noise.
///
/// ## What it refuses to do
///
/// * **It is never good or bad.** The hollow triangle between the two figures
///   shows direction and is ink-3 in every case. This delta is a
///   reconciliation, not a performance movement; colouring it tells an agent
///   they got worse when what happened is that the arithmetic changed.
/// * **Nothing is struck through.** A 1.5px strike at 40% backlight vanishes,
///   and a struck number reads as an error the agent made.
/// * **The figure above does not re-count.** A number that silently animates
///   from 84 to 71 is the exact event this line exists to narrate.
///
/// Both figures set in mono at `figure.s` inside the sentence, so there are
/// never two competing large numbers on the screen.
class ReconciliationLine extends StatelessWidget {
  const ReconciliationLine({
    super.key,
    required this.finalValue,
    required this.seenValue,
    required this.voice,
    this.unit = TiqUnit.none,
    this.decimals,
    this.reason,
    this.strings = ReconciliationStrings.defaults,
    this.semanticsLabel,
  });

  /// The recorded figure.
  final num finalValue;

  /// What was shown before it.
  final num seenValue;

  final ReconciliationVoice voice;
  final TiqUnit unit;
  final int? decimals;

  /// The server's explanation: "Two sections' photos arrived after scoring."
  final String? reason;

  final ReconciliationStrings strings;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ink2 = skin.palette.ink2;
    final ink3 = skin.palette.ink3;
    final number = TiqNumber.of(context);
    final finalText = number.format(finalValue, unit: unit, decimals: decimals);
    final seenText = number.format(seenValue, unit: unit, decimals: decimals);
    final lead = switch (voice) {
      ReconciliationVoice.agent => strings.agentLead,
      ReconciliationVoice.console => strings.consoleLead,
    };
    final tail = switch (voice) {
      ReconciliationVoice.agent => strings.agentTail,
      ReconciliationVoice.console => strings.consoleTail,
    };

    return Semantics(
      label: semanticsLabel ??
          '$lead $finalText. $tail $seenText.'
              '${reason == null ? '' : ' $reason'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: <Widget>[
              // The neutral square. Never good, never bad.
              TiqMark(
                shape: MarkShape.heldSquare,
                color: ink3,
                size: MarkScale.glyph(context, 7),
              ),
              Text(lead, style: skin.text.meta.style(color: ink2)),
              FigureSlot(
                value: finalValue,
                role: skin.text.figureS,
                unit: unit,
                decimals: decimals,
                color: skin.palette.ink1,
              ),
              TiqMark(
                shape: finalValue < seenValue
                    ? MarkShape.deltaHollowDown
                    : MarkShape.deltaHollowUp,
                color: ink3,
                size: MarkScale.glyph(context, 8),
                strokeWidth: 1.5,
              ),
              Text(tail, style: skin.text.meta.style(color: ink3)),
              FigureSlot(
                value: seenValue,
                role: skin.text.figureS,
                unit: unit,
                decimals: decimals,
                color: ink3,
              ),
            ],
          ),
          if (reason != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(reason!, style: skin.text.meta.style(color: ink2)),
          ],
        ],
      ),
    );
  }
}

/// The two string sets.
@immutable
class ReconciliationStrings {
  const ReconciliationStrings({
    this.agentLead = 'Now scored',
    this.agentTail = '— it was',
    this.consoleLead = 'Scored',
    this.consoleTail = '— the phone showed',
  });

  final String agentLead;
  final String agentTail;
  final String consoleLead;
  final String consoleTail;

  static const ReconciliationStrings defaults = ReconciliationStrings();
}

import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import '../mark/tiq_mark.dart';
import 'trough.dart';

/// THE FURNITURE AROUND A TROUGH — label above, help or error beneath.
///
/// Both fields and the count stepper hang off this, so a label is in the same
/// place, at the same weight, the same distance above every input in the app.
///
/// **The label is above and it stays there.** Never a floating placeholder: a
/// label that becomes the value's decoration the moment you type destroys the
/// field's own name at exactly the point a person looks up from a shelf and
/// asks "what was I typing into?".
///
/// **The error replaces the help line; it does not push it.** A layout that
/// grows by a line when a value is refused moves every control beneath it
/// under a thumb that is already travelling.
class TorchFieldShell extends StatelessWidget {
  const TorchFieldShell({
    super.key,
    required this.label,
    required this.spec,
    required this.child,
    this.help,
    this.error,
    this.counter,
    this.trailing,
    this.semanticsLabel,
  });

  /// The field's name, in sentence case. It is also the semantic label: a
  /// `hint` that doubles as a name is a name that disappears.
  final String label;

  final TroughSpec spec;

  /// The trough itself.
  final Widget child;

  /// One meta line beneath — a format, a range, a reason a field is disabled.
  final String? help;

  /// Replaces [help] when present, at 12/500 in `bad` behind a filled
  /// triangle. Three channels: a mark, a sentence and the rule above it.
  final String? error;

  /// The character counter, right-aligned under the trough. Rendered by the
  /// field, which is the only thing that knows the cap.
  final Widget? counter;

  /// Rendered beneath everything — the stepper's "Out of stock" status chip.
  final Widget? trailing;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final showError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: spec.labelStyle.style(color: spec.labelInk),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: spec.labelGap),
        child,
        if (showError || help != null || counter != null)
          SizedBox(height: spec.helpGap),
        if (showError)
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  // The triangle's optical centre against a 12/500 line.
                  padding: const EdgeInsets.only(top: 2),
                  child: TiqMark(
                    shape: MarkShape.criticalTriangle,
                    color: spec.errorInk,
                    size: MarkScale.glyph(context, 12),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    error!,
                    style: spec.helpStyle
                        .copyWith(weight: FontWeight.w500)
                        .style(color: spec.errorInk),
                    // A reason that is cut off is not a reason.
                  ),
                ),
                if (counter != null) ...<Widget>[
                  const SizedBox(width: TiqSpace.s2),
                  counter!,
                ],
              ],
            ),
          )
        else if (help != null || counter != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (help != null)
                Expanded(
                  child: Text(
                    help!,
                    style: spec.helpStyle.style(color: spec.helpInk),
                  ),
                )
              else
                const Spacer(),
              if (counter != null) ...<Widget>[
                const SizedBox(width: TiqSpace.s2),
                counter!,
              ],
            ],
          ),
        if (trailing != null) ...<Widget>[
          SizedBox(height: skin.space.intraBlock),
          Align(alignment: Alignment.centerLeft, child: trailing!),
        ],
      ],
    );
  }
}

/// The character counter. Appears at 80% of the cap and turns to `bad` ink at
/// 100% — a field is never silently truncated.
class TorchFieldCounter extends StatelessWidget {
  const TorchFieldCounter({
    super.key,
    required this.length,
    required this.maximum,
    required this.spec,
  });

  final int length;
  final int maximum;
  final TroughSpec spec;

  /// Whether a counter renders at all for this length.
  static bool visible(int length, int maximum) =>
      maximum > 0 && length >= maximum * TroughSpec.counterThreshold;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final over = length >= maximum;
    return ExcludeSemantics(
      child: Text(
        '$length/$maximum',
        // Mono, like every other figure in this product: a count of characters
        // that jitters as it counts is the thing tabular figures exist for.
        style: spec.counterStyle.style(
          color: over ? skin.palette.bad : skin.palette.ink3,
        ),
      ),
    );
  }
}

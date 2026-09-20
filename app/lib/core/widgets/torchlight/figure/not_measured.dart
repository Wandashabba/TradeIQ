import 'package:flutter/widgets.dart';

import '../../../design/figure_slot.dart';
import '../../../design/hatch_paint.dart';
import '../../../design/tiq_number.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import 'meter.dart';

/// The fourth state the product has been missing: **not zero, not missing, not
/// an error — we could not confirm this, and it is not counted against you.**
///
/// Three parts, and all three are mandatory:
///
/// 1. an **em dash** where the figure would be, at the figure's own role and
///    face, in ink-3, with the unit suppressed;
/// 2. a **full-width falling hatch** on the dimension's track;
/// 3. a **reason, in words**.
///
/// ## Why full width, always
///
/// This is the load-bearing rule. A partial hatched bar reads as a hatched
/// *value* — the reader sees a bar two-thirds across and takes the two-thirds
/// as the measurement. Full-width hatch plus an em dash above it says "there
/// is no measurement here", and nothing else can.
///
/// ## Why there is always a sentence
///
/// A hatch with no sentence is a puzzle. Where the server knows the cause it
/// says it ("No competitor on shelf"); where it does not, the generic line is
/// still a line ("Not measured in this visit") and never blank. The hatch
/// carries no semantics of its own: the visual encoding is for sighted users
/// and the sentence is for everyone, and neither is a fallback for the other.
///
/// ## Where the hatch may not go
///
/// Never inside a glyph and never on a mark under 4dp — `HatchPaint` asserts
/// both. "Can't confirm" on a *section* is a barred ring, not a hatched one;
/// "not measured" as a *row marker* is a barred square. The hatch lives on a
/// track, where it has the width to be a pattern rather than noise.
class NotMeasured extends StatelessWidget {
  const NotMeasured({
    super.key,
    required this.reason,
    this.role,
    this.showTrack = true,
    this.semanticsLabel,
  });

  /// The words. Required — there is no unlabelled hatch in this system.
  final String reason;

  /// The role the em dash is set in. Defaults to `figure.l`, so an unmeasured
  /// dimension keeps the same optical weight as a measured one and the column
  /// does not shift.
  final TiqTypeToken? role;

  /// False where the owning component draws its own track and only wants the
  /// dash and the sentence.
  final bool showTrack;

  /// "Not measured. No competitor on shelf." Defaults to "Not measured" plus
  /// the reason, which is the announcement order the design asks for.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FigureSlot(
          value: null,
          role: role ?? skin.text.figureL,
          state: FigureState.notMeasured,
          semanticsLabel: semanticsLabel ?? 'Not measured. $reason',
        ),
        if (showTrack) ...<Widget>[
          const SizedBox(height: 8),
          Meter(
            value: null,
            state: MeterState.notMeasured,
            reasonForHatch: reason,
          ),
        ],
        const SizedBox(height: 8),
        Text(reason, style: skin.text.meta.style(color: skin.palette.ink3)),
      ],
    );
  }

  /// The smallest track a hatch may be drawn on. Re-exported here so a caller
  /// sizing a custom track does not have to know which file the registry lives
  /// in.
  static const double minimumTrackExtent = HatchPaint.minimumMarkExtent;
}

import 'package:flutter/widgets.dart';

import '../../../../design/figure_slot.dart';
import '../../../../design/tiq_number.dart';
import '../../../../theme/torchlight/tiq_skin.dart';
import 'chart_series.dart';

/// One line in a [ScrubReadout].
@immutable
class ScrubEntry {
  const ScrubEntry({
    required this.name,
    required this.value,
    required this.role,
  });

  final String name;

  /// Null is a bucket nobody measured, and it renders as the em dash with the
  /// unit suppressed — the same rule the tiles obey. A scrub readout that
  /// printed `0%` over a strike week would be the chart lying at the one
  /// moment somebody is reading it closely.
  final double? value;

  final ChartSeriesRole role;
}

/// WHAT IS UNDER THE THUMB.
///
/// It **enhances**: every value it shows is also in the table twin, so
/// nothing is gated behind a pointer or a drag. That is why it can be a
/// transient block rather than a permanent one.
///
/// It sits *below* the plot rather than floating over it. A tooltip under a
/// thumb is a tooltip a thumb is covering, and the old chart set's inverted
/// dark readout was a second material with its own contrast argument on a
/// screen that already had three.
class ScrubReadout extends StatelessWidget {
  const ScrubReadout({
    super.key,
    required this.period,
    required this.entries,
    required this.unit,
    required this.notMeasuredWord,
    this.decimals,
  });

  /// The unabbreviated bucket — `2026-W26`, not `W26`. The axis abbreviates
  /// because it has 40dp; this has the width to be exact and the reader is
  /// here because they wanted exact.
  final String period;

  final List<ScrubEntry> entries;
  final TiqUnit unit;

  /// The words a null reading is announced and captioned with. "Not measured"
  /// — never "0", never "n/a", and never an em dash read out as "em dash".
  final String notMeasuredWord;

  final int? decimals;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TiqSpace.s3,
        vertical: TiqSpace.s3,
      ),
      decoration: BoxDecoration(
        color: skin.palette.well,
        borderRadius: BorderRadius.circular(skin.radii.control),
        border: Border.all(
          color: skin.palette.edgeStructure,
          width: skin.depth.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            period,
            style: skin.text.monoIdent.style(color: skin.palette.ink2),
          ),
          const SizedBox(height: TiqSpace.s2),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(top: TiqSpace.s1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      entry.name,
                      style: skin.text.meta.style(color: skin.palette.ink2),
                    ),
                  ),
                  const SizedBox(width: TiqSpace.s3),
                  FigureSlot(
                    value: entry.value,
                    role: skin.text.figureS,
                    unit: entry.value == null ? TiqUnit.none : unit,
                    decimals: decimals,
                    state: entry.value == null
                        ? FigureState.missing
                        : FigureState.measured,
                    textAlign: TextAlign.end,
                    semanticsLabel: entry.value == null
                        ? '${entry.name}, $notMeasuredWord'
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

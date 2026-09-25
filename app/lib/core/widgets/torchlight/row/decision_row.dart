import 'package:flutter/widgets.dart';

import '../../../design/figure_slot.dart';
import '../../../design/tiq_number.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import 'soft_row.dart';

/// The manager's "needs a decision" list item: one outlet that needs somebody
/// to do something, with the reason and the number that proves it.
///
/// A configuration of [SoftRow] at `tall` density. It contributes four
/// choices and no pixels of its own:
///
/// * the **severity bar**, at the two commitment levels the system has, with
///   the word beside it in the semantics label;
/// * the outlet name **middle-truncated**, because "Shoprite Klipspruit Mall"
///   and "Shoprite Klipfontein Mall" end-truncate to the same string;
/// * a trailing **figure** through [FigureSlot], so a column of them is a
///   column — mono, tabular, and an em dash where there is no number rather
///   than a blank;
/// * a **sparkline slot**, which is a hole. The sparkline belongs to the
///   figures workstream; this row reserves the space, drops it first at 2.0×
///   and omits it entirely rather than letting a fabricated shape appear.
///
/// The row emits no amber, and neither may anything put in [sparkline]: five
/// amber last-dots on five rows is the exact repeated fill the law bans.
///
/// ```dart
/// DecisionRow(
///   title: outlet.name,
///   reason: l10n.outOfStockSince(outlet.since),
///   severity: SoftRowSeverity.critical,
///   severityLabel: l10n.severityCritical,
///   value: outlet.score,
///   unit: TiqUnit.percent,
///   sparkline: Sparkline(points: outlet.trend),   // figures workstream
///   onTap: () => context.push(outlet.route),
/// )
/// ```
class DecisionRow extends StatelessWidget {
  const DecisionRow({
    super.key,
    required this.title,
    required this.reason,
    this.severity = SoftRowSeverity.none,
    this.severityLabel,
    this.value,
    this.unit = TiqUnit.none,
    this.decimals,
    this.figureState = FigureState.measured,
    this.valueSemanticsLabel,
    this.sparkline,
    this.meta,
    this.onTap,
    this.separator = SoftRowSeparator.auto,
  });

  /// The outlet name. Middle-truncated by construction.
  final String title;

  /// Why it needs a decision, on **one** line.
  ///
  /// The list's job is scanning: outlet, reason, figure, down the left edge.
  /// A reason that wraps costs a whole row of fold on the one screen that is
  /// meant to show several of them — on a 360×640 phone the second line was
  /// the difference between two visible decisions and one.
  final String reason;

  final SoftRowSeverity severity;

  /// Required whenever [severity] is not `none`, and announced first.
  final String? severityLabel;

  /// The number that proves it. Null renders an em dash in ink-3 — a figure
  /// that is absent is a state, not a blank.
  final num? value;

  final TiqUnit unit;
  final int? decimals;
  final FigureState figureState;

  /// What a screen reader says about an absent or thin figure. [FigureSlot]
  /// asserts on its absence for every state but a plain measurement.
  final String? valueSemanticsLabel;

  /// The sparkline, from the figures workstream. Omitted entirely when null —
  /// the figure simply shifts to the row's edge, and no shape is invented.
  final Widget? sparkline;

  /// An optional third line: flags, "Being reviewed by Thabo M.", a stale
  /// note.
  final Widget? meta;

  final VoidCallback? onTap;
  final SoftRowSeparator separator;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final scaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    // The sparkline drops first at 2.0×, then the figure moves onto its own
    // line — and the second half of that is the row's own layout, not a rule
    // written here. Veld drops it too: a 64×20 grey zigzag is under 9:1 by
    // construction, and Veld has no text token under 9:1.
    final showSparkline =
        sparkline != null &&
        skin.density != TiqDensity.veld &&
        scaler.scale(1.0) < 1.6;

    return SoftRow(
      // COMPACT, NOT TALL. unify §1.3 puts a decision row at the 80dp tall
      // density, and the reason it gives is "two meta lines". This row has
      // one: the reason went to a single line in #458, so the premise for the
      // tall density went with it, and the 80dp floor was holding open 11dp
      // of air per row that the card grammar now spends as a gap between
      // cards instead — where it is visible. Measured at 390×844 with Onest
      // loaded, the row is ~69dp of content either way; what the change buys
      // is the third decision above the nav pill.
      density: SoftRowDensity.compact,
      title: title,
      titleTruncation: SoftRowTruncation.middle,
      subtitle: reason,
      subtitleMaxLines: 1,
      meta: meta,
      severity: severity,
      severityLabel: severityLabel,
      trailing: _Trailing(
        sparkline: showSparkline ? sparkline : null,
        figure: FigureSlot(
          value: value,
          role: skin.text.figureM,
          fit: <TiqTypeToken>[skin.text.figureM, skin.text.figureS],
          unit: unit,
          decimals: decimals,
          state: figureState,
          textAlign: TextAlign.end,
          semanticsLabel: valueSemanticsLabel,
        ),
      ),
      onTap: onTap,
      separator: separator,
      semanticsLabel: <String?>[
        severityLabel,
        title,
        reason,
        valueSemanticsLabel,
      ].whereType<String>().join('. '),
    );
  }
}

class _Trailing extends StatelessWidget {
  const _Trailing({required this.sparkline, required this.figure});

  final Widget? sparkline;
  final Widget figure;

  @override
  Widget build(BuildContext context) {
    if (sparkline == null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 120),
        child: figure,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // A cached `Picture` inside a `RepaintBoundary` is the sparkline's own
        // contract; the slot's only job is to be a fixed box so the figure
        // beside it does not move from row to row.
        SizedBox(width: 64, height: 20, child: sparkline),
        SizedBox(width: TiqSpace.s3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: figure,
        ),
      ],
    );
  }
}

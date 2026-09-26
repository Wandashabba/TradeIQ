import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import '../button/buttons.dart';

/// "SHOWING THE 20 RISKIEST OF 74."
///
/// Stops a first page reading as the whole truth, which is what a cut list
/// always does.
///
/// ```dart
/// PaginationFooter(
///   summary: 'Showing the 20 riskiest of 74.',
///   narrowLine: 'Narrow by territory to see the rest.',
///   unscoredNote: '6 submitted visits have not been scored yet and are not '
///       'listed here.',
///   action: TorchTertiaryButton(label: 'Filter', onPressed: …),
/// )
/// ```
///
/// **There is no "Load more".** The API serves a first page, and a button that
/// cannot deliver is dishonest chrome. The action scrolls to the filter rail,
/// which can.
///
/// **The unscored note is not optional where it is true** (#236). An unscored
/// visit is not a clean one, and a short list of the riskiest twenty must
/// never read as "nothing suspicious" when six more were never scored at all.
class PaginationFooter extends StatelessWidget {
  const PaginationFooter({
    super.key,
    required this.summary,
    this.narrowLine,
    this.unscoredNote,
    this.action,
  });

  /// One `meta` line. "Showing the first 20. There are more." where the total
  /// is unknown — **never a fabricated total**.
  final String summary;

  /// What to do about it.
  final String? narrowLine;

  /// The honest case: records excluded because they are not scored yet.
  final String? unscoredNote;

  /// A ghost action at the trailing edge.
  final Widget? action;

  /// 44 on Night and Day, 64 in Veld.
  static double heightFor(TiqSkin skin) =>
      skin.density == TiqDensity.veld ? 64 : 44;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    // A blank string is not a line. The unscored note is honest on its own —
    // a queue that was NOT cut but still has visits nobody scored has
    // something to own up to and no summary to lead with — and an empty
    // `Text('')` there would render as a gap above the sentence that matters.
    final lines = <String>[
      summary,
      ?narrowLine,
      ?unscoredNote,
    ].where((line) => line.trim().isNotEmpty).toList();

    // The words are one utterance; the action is NOT inside it. An
    // `excludeSemantics` node drops every descendant node, so an action
    // rendered inside this one painted, hit-tested and was announced nowhere —
    // the same defect the button family was repaired for. The footer's own
    // `Semantics` therefore wraps the text column alone, and the action keeps
    // the node its button already built.
    final Widget words = Semantics(
      // Part of the list's own semantics, so a screen-reader user reaching the
      // bottom learns the list was cut.
      container: true,
      label: lines.join(' '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < lines.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: TiqSpace.s1),
            Text(lines[i], style: skin.text.meta.style(color: p.ink3)),
          ],
        ],
      ),
    );

    return Container(
      constraints: BoxConstraints(minHeight: heightFor(skin)),
      decoration: BoxDecoration(
        color: p.well,
        border: Border(
          top: BorderSide(
            color: skin.brightness == Brightness.dark
                ? p.hairline
                : p.edgeStructure,
            width: skin.depth.borderWidth,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: skin.space.gutter,
        vertical: TiqSpace.s2,
      ),
      // THE ACTION STACKS RATHER THAN OVERFLOWING — 26 September 2026.
      //
      // This was a `Row` of `Expanded(words)` and an unconstrained action, so
      // a verb longer than the room left ran off the right: "Showing 2. There
      // are older messages." beside "Show older messages" overflowed a 360dp
      // phone by 4.2px. A footer whose whole job is to admit a list was cut
      // must not itself be cut, and the fix cannot be a shorter English label
      // — Afrikaans is longer and 2.0× is longer again.
      //
      // Measured, not guessed at a text-scale threshold, which is the rule
      // `SectionRule` already follows for the same problem.
      child: action == null
          ? words
          : LayoutBuilder(
              builder: (context, constraints) {
                if (_stacks(context, skin, constraints.maxWidth)) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[words, action!],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(child: words),
                    const SizedBox(width: TiqSpace.s3),
                    action!,
                  ],
                );
              },
            ),
    );
  }

  /// Whether the longest line and the action stop fitting on one row.
  ///
  /// The action's own label is measured at the live scaler and in the caller's
  /// language: a constant cannot know how long a verb is in Afrikaans, which
  /// is the mistake `SectionRule` was repaired for.
  bool _stacks(BuildContext context, TiqSkin skin, double maxWidth) {
    if (!maxWidth.isFinite) return false;
    final scaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    double widthOf(String text, TiqTypeToken token) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: token.style(color: skin.palette.ink1),
        ),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final verb = _actionLabel;
    if (verb == null) return false;
    final longest = <String>[
      summary,
      ?narrowLine,
      ?unscoredNote,
    ].map((line) => widthOf(line, skin.text.meta)).fold(0.0, math.max);
    return longest + TiqSpace.s3 + widthOf(verb, skin.text.label) > maxWidth;
  }

  /// The action's words, when it is one of the kit's own buttons. Null for a
  /// caller's arbitrary widget, which then keeps the single-row layout — the
  /// measurement is the point, and a guess would be worse than none.
  String? get _actionLabel => switch (action) {
    TorchTertiaryButton(:final label) => label,
    TorchSecondaryButton(:final label) => label,
    _ => null,
  };
}

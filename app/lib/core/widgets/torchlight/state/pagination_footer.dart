import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(child: words),
          if (action != null) ...<Widget>[
            const SizedBox(width: TiqSpace.s3),
            action!,
          ],
        ],
      ),
    );
  }
}

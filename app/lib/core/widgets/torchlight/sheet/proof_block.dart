import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import '../mark/section_state_glyph.dart';
import '../state/skeleton.dart';

/// One countable fact about work that already exists.
@immutable
class ProofLine {
  const ProofLine({required this.text, this.state = SectionState.done});

  /// In concrete terms, with its figures in mono: "6 of 9 sections captured",
  /// "3 photos held on this phone", "Started 08:14, 41 minutes ago".
  final String text;

  /// The section-state glyph leading the line.
  final SectionState state;
}

/// THE PROOF BLOCK — the whole point of the decision sheet.
///
/// A `well`-filled radius-10 box with a 1px `edgeStructure` outline, listing
/// what exists in concrete terms, one fact per line, each behind a
/// section-state glyph.
///
/// **A decision about invisible work is a guess.** Before this existed, "you
/// have unsaved work — carry on or start over?" asked a person to weigh
/// something they could not see, in a shop, with one hand. Six sections and
/// three photos is a number; "unsaved work" is a feeling.
///
/// It is also the answer to the session-ended screen's old trick of rendering
/// the live screen behind itself at 0.35 opacity "so she can see it survived".
/// That measured 2.84:1 — below 3:1 even for large text — and it was a
/// full-screen `Opacity` over a live widget tree, which is a full-screen
/// `saveLayer`: the most expensive frame in the app, spent making its own
/// reassurance illegible. **The proof is countable, not ghostly.**
class ProofBlock extends StatelessWidget {
  const ProofBlock({
    super.key,
    required this.lines,
    this.counting = false,
    this.semanticsLabel,
  });

  final List<ProofLine> lines;

  /// The figures have not resolved yet. The block renders as a skeleton at its
  /// real geometry and **both actions stay busy-disabled** — no choice may be
  /// made until the cost is known.
  final bool counting;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: Container(
        decoration: BoxDecoration(
          color: p.well,
          borderRadius: BorderRadius.circular(skin.radii.control),
          border: Border.all(
            color: p.edgeStructure,
            width: skin.depth.borderWidth,
          ),
        ),
        padding: const EdgeInsets.all(TiqSpace.s4),
        child: counting
            ? Skeleton(
                label: 'what you have here',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (var i = 0; i < (lines.isEmpty ? 3 : lines.length); i++)
                      Padding(
                        padding: EdgeInsets.only(top: i == 0 ? 0 : TiqSpace.s3),
                        child: SkeletonLine(
                          role: skin.text.body,
                          widthFactor: i.isEven ? 0.72 : 0.54,
                        ),
                      ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (var i = 0; i < lines.length; i++)
                    Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : TiqSpace.s3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SectionStateGlyph(state: lines[i].state),
                          const SizedBox(width: TiqSpace.s3),
                          Expanded(
                            child: Text(
                              lines[i].text,
                              style: skin.text.body.style(color: p.ink1),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

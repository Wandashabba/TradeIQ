import 'package:flutter/widgets.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/figure/eyebrow.dart';
import '../../../l10n/l10n.dart';
import '../answer/answer_notes.dart';
import '../data/chat_controller.dart';
import 'rich_figures.dart';

/// One block inside the panel, with the label that names it.
@immutable
class PanelBlock {
  const PanelBlock({required this.child, this.eyebrow, this.key});

  final Widget child;

  /// "WORST FIRST", "OVER TIME". The uppercase eyebrow is legal here — unify
  /// §1.17 keeps it for a block label *inside* a panel, and retires it only
  /// as a screen-level section marker.
  ///
  /// Absent on the first block: a panel that opens with a label is a panel
  /// labelling itself.
  final String? eyebrow;

  final Key? key;
}

/// THE INSTRUMENT PANEL — the one surface that holds an answer's figures.
///
/// One sentence, one panel, one lit object. The eye's path is forced by the
/// panel existing at all: four tiles, a ranking and a chart loose on the
/// ground are three things; inside one outline they are one reading.
///
/// ## Separation is a gap *and* a rule
///
/// 24dp of clear space between blocks with a full-bleed 1px `edgeStructure`
/// rule centred in it. The previous build used a 1.72:1 hairline as the sole
/// divider with no gap at all; a decorative line is permitted only where a
/// compliant separation is already doing the work.
///
/// ## Amber
///
/// **At most one object inside the panel**, and only when the route's arbiter
/// has lit it here: the single focus bar in the ranked block *or* the primary
/// series in the trend block, never both. A panel holding only stat tiles
/// holds no amber at all, which is correct — four numbers together are the
/// reading, and lighting one would misdirect. The panel's own outline and its
/// block rules are never amber.
class InstrumentPanel extends StatelessWidget {
  const InstrumentPanel({super.key, required this.blocks});

  final List<PanelBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final veld = skin.mode == SkinMode.veld;
    // An empty panel reads as a bug and a dropped one reads as an answer that
    // did not need figures. Every container on this surface is dropped rather
    // than rendered empty.
    if (blocks.isEmpty) return const SizedBox.shrink();

    final padding = veld ? TiqSpace.s6 : TiqSpace.s4;
    final gap = veld ? TiqSpace.s8 : TiqSpace.s6;
    final ruleWidth = veld ? 2.0 : skin.depth.borderWidth;

    return Semantics(
      container: true,
      label: context.l10n.askFigures,
      child: Container(
        key: const ValueKey<String>('instrument-panel'),
        // Set with padding-inline/padding-block so a shorthand can never zero
        // the side gutters.
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(veld ? 0 : skin.radii.panel),
          border: Border.all(
            color: veld ? p.ink1 : p.edgeStructure,
            width: ruleWidth,
          ),
          // No shadow, no rim. The direction's 1px Palladian@10% top rim is
          // cut here: an 8–12% alpha step is below what a 6-bit LCD at 40%
          // backlight resolves, and it cost a second border paint to say
          // nothing.
          // sh1 on Day, and nothing at all in Night or Veld — the token is
          // empty there, so this is the palette's answer rather than a
          // condition restated in a widget.
          boxShadow: <BoxShadow>[?skin.depth.sh1],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < blocks.length; i++) ...<Widget>[
              if (i > 0) ...<Widget>[
                SizedBox(height: gap / 2),
                // Full-bleed: the rule runs to the panel's inside edges, so
                // it reads as the instrument's grid rather than as an
                // underline on the block above it.
                Container(
                  margin: EdgeInsets.symmetric(horizontal: -padding),
                  height: ruleWidth,
                  color: veld ? p.ink1 : p.edgeStructure,
                ),
                SizedBox(height: gap / 2),
              ],
              if (blocks[i].eyebrow != null && i > 0) ...<Widget>[
                Eyebrow(blocks[i].eyebrow!),
                SizedBox(height: skin.space.intraBlock),
              ],
              KeyedSubtree(key: blocks[i].key, child: blocks[i].child),
            ],
          ],
        ),
      ),
    );
  }
}

/// Which figures a turn may draw.
///
/// ## The Phase 0 rule, kept because it is still the honest one
///
/// #410 landed `origin` on every figure, so the client can now tell an
/// internal number from an outside one. It does **not** make the guard
/// unnecessary: a server older than this app, or a tool that forgets the
/// field, still produces a turn where a Shoprite-website shelf price and a
/// TradeIQ stock count are the same object. So the rule stands, unchanged in
/// substance and narrower in effect:
///
/// > If a turn invoked any web tool **and** any figure artifact in it carries
/// > no `origin`, the client renders **no** figure artifacts for that turn.
///
/// Post-schema that never fires, because every figure says where it came
/// from; internal figures render in the panel and outside ones are routed to
/// the band, never in the same container and never on the same scale.
///
/// ## The residual risk, stated rather than hidden
///
/// Prose figures are **not** suppressed. Suppressing an answer's sentences
/// would leave the manager with nothing, where suppressing its panel leaves
/// her the reading. On a web-touched turn a scraped price can therefore still
/// appear unmarked inside a sentence until the server tags inline runs too.
@immutable
class AnswerFigures {
  const AnswerFigures({
    required this.internal,
    required this.outside,
    required this.suppressed,
  });

  /// Artifacts that may be drawn inside the panel.
  final List<ChatArtifact> internal;

  /// Artifacts routed to the outside-data band. Never inside the panel, and
  /// never summed against an internal total.
  final List<ChatArtifact> outside;

  /// Every figure was dropped because the turn used the web and at least one
  /// figure did not say where it came from.
  final bool suppressed;

  /// The tool names that mean the model went outside TradeIQ.
  static const Set<String> webTools = <String>{
    'webSearch',
    'getCompetitorShelfPrices',
  };

  /// The spec types whose data carries provenance at all. Anything else is a
  /// view, not a figure run, and the rule does not apply to it.
  static const Set<String> figureTypes = <String>{'stat_tiles', 'ranked_bars'};

  static AnswerFigures of(ChatMessage message) {
    final usedWeb = message.tools.any((t) => webTools.contains(t.name));
    final internal = <ChatArtifact>[];
    final outside = <ChatArtifact>[];
    var untagged = false;

    for (final artifact in message.artifacts) {
      if (!figureTypes.contains(artifact.type)) {
        internal.add(artifact);
        continue;
      }
      final data = artifact.data;
      final tagged = data is Map && _carriesOrigin(data);
      if (!tagged) untagged = true;
      final provenance = FigureProvenance.from(data);
      (provenance.isOutside ? outside : internal).add(artifact);
    }

    if (usedWeb && untagged) {
      // A single untagged figure in a web-touched turn suppresses that turn's
      // figures. There is no "probably internal".
      return AnswerFigures(
        internal: <ChatArtifact>[
          for (final a in internal) if (!figureTypes.contains(a.type)) a,
        ],
        outside: const <ChatArtifact>[],
        suppressed: true,
      );
    }
    return AnswerFigures(
      internal: internal,
      outside: outside,
      suppressed: false,
    );
  }

  /// Whether a figure run says where it came from — at the run level, or on
  /// every tile of a `stat_tiles` run.
  static bool _carriesOrigin(Map<dynamic, dynamic> data) {
    if (data['origin'] is String) return true;
    if (data['outsideData'] is bool) return true;
    final tiles = data['tiles'];
    if (tiles is List && tiles.isNotEmpty) {
      return tiles.every((t) => t is Map && t['origin'] is String);
    }
    return false;
  }
}

/// The note that stands where a suppressed panel would have been.
Widget suppressedFiguresNote() => const UnprovenancedFiguresNote();

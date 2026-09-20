import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../l10n/l10n.dart';
import '../answer/answer_notes.dart';
import '../data/chat_controller.dart';
import 'agent_scorecard_card.dart';
import 'instrument_panel.dart';
import 'outlet_map_card.dart';
import 'pillar_metrics_card.dart';
import 'ranked_bars_card.dart';
import 'stat_tiles_card.dart';
import 'trend_chart_card.dart';

/// Spec type → widget.
///
/// **The model never emits UI.** It picks a tool; the tool declares a spec type
/// from a catalog the server closes and validates. This map is the client half
/// of that contract, and its most important property is what it does with a
/// type it has never heard of.
///
/// **An unknown type renders as a note, never as a blank card.** A blank card
/// reads as a bug in the app — the user retries, sees the same nothing, and
/// stops trusting the screen. A line saying the answer could not be drawn is
/// honest, and the narrative above it still carries the answer.
///
/// It also has to survive the *older* direction: a server that has added a spec
/// this build does not know about. That is not an error state, it is a normal
/// consequence of shipping the backend and the app separately.
typedef ViewSpecBuilder =
    Widget Function(BuildContext context, ChatArtifact artifact);

final Map<String, ViewSpecBuilder> viewSpecRegistry = {
  'agent_scorecard': (context, artifact) =>
      AgentScorecardCard(artifact: artifact),
  'trend_chart': (context, artifact) => TrendChartCard(artifact: artifact),
  'outlet_map': (context, artifact) => OutletMapCard(artifact: artifact),
  'pillar_metrics': (context, artifact) => PillarMetricsCard(artifact: artifact),
  'stat_tiles': (context, artifact) => StatTilesCard(artifact: artifact),
  'ranked_bars': (context, artifact) => RankedBarsCard(artifact: artifact),
};

/// Spec types the server never persists: they arrive with `params: {}` and a
/// turn-local id (`getRateOfSale-stat_tiles-1`), so there is no row for
/// Expand, Open or Refine to reach. Held as a rule of the type rather than
/// left to [ArtifactView.isPersisted], so a server that ever hands one a
/// UUID-shaped id still offers no control that leads nowhere.
const Set<String> answerOnlySpecTypes = {'stat_tiles', 'ranked_bars'};

/// The cards an answer shows, in the order the panel holds them.
///
/// **One clean set of numbers.** A pillar tool emits its `pillar_metrics` card
/// and then `stat_tiles` carrying the same figures; when tiles came from the
/// **same tool call** ([ChatArtifact.toolCall]), the tiles stand in and that
/// call's pillar card is dropped. A pillar card with no tiles from its own
/// call — including one whose neighbouring call produced tiles — stays exactly
/// as it was, and no other type is ever hidden.
///
/// **Ordered by type, not arrival: tiles, then bars, then everything else.**
/// The direction's own screen puts the ranking above the chart, and the old
/// ranks (`stat_tiles` 0, everything 1, `ranked_bars` 2) put the chart above
/// the ranking. The server emits a tool's own card before its tiles, so
/// arrival order would bury the headline figures under the chart they
/// summarise. A turn with neither new type keeps its order exactly.
List<ChatArtifact> arrangeAnswerArtifacts(List<ChatArtifact> artifacts) {
  final tiledCalls = {
    for (final a in artifacts)
      if (a.type == 'stat_tiles' && a.toolCall != null) a.toolCall,
  };
  final shown = [
    for (var i = 0; i < artifacts.length; i++)
      if (!(artifacts[i].type == 'pillar_metrics' &&
          artifacts[i].toolCall != null &&
          tiledCalls.contains(artifacts[i].toolCall)))
        (i, artifacts[i]),
  ];
  int rank(ChatArtifact a) => switch (a.type) {
    'stat_tiles' => 0,
    'ranked_bars' => 1,
    _ => 2,
  };
  shown.sort((a, b) {
    final byRank = rank(a.$2).compareTo(rank(b.$2));
    return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
  });
  return [for (final (_, artifact) in shown) artifact];
}

/// The block label a type takes inside the panel.
///
/// Null on `stat_tiles`, which is always first and therefore unlabelled: a
/// panel that opens with a label is a panel labelling itself.
String? panelEyebrowFor(AppLocalizations l10n, String type) => switch (type) {
  'ranked_bars' => l10n.askWorstFirst,
  'trend_chart' => l10n.askOverTime,
  _ => null,
};

/// Render an artifact, or explain why it could not be drawn.
class ArtifactView extends StatelessWidget {
  const ArtifactView({
    super.key,
    required this.artifact,
    this.expandable = false,
  });

  final ChatArtifact artifact;

  /// Whether to offer the expand affordance beneath the card. False inside
  /// the full view itself, which is where the link would lead.
  final bool expandable;

  /// Whether this artifact exists as a row the artifact routes can find.
  ///
  /// A turn that could not persist falls back to a **turn-local** id like
  /// `getStockLevels-0` — the card still renders, which is the point of that
  /// fallback, but `/artifact/getStockLevels-0` is a 404 waiting to happen, and
  /// a control that cannot work is worse than an absent one.
  static bool isPersisted(String id) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(id);

  /// Whether the expand row should be offered at all.
  static bool offersFullView(ChatArtifact artifact) =>
      !answerOnlySpecTypes.contains(artifact.type) && isPersisted(artifact.id);

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final builder = viewSpecRegistry[artifact.type];
    if (builder == null) return UnsupportedArtifactNote(type: artifact.type);

    // A card that throws while painting would take the whole transcript down
    // with it — including the narrative that already answered the question.
    // The data is server-validated against the spec's schema, so this should
    // not fire; "should not" is why it is caught rather than assumed.
    final Widget card;
    try {
      card = builder(context, artifact);
    } catch (_) {
      return UnsupportedArtifactNote(type: artifact.type);
    }

    if (!expandable || !offersFullView(artifact)) return card;

    final name = panelEyebrowFor(l10n, artifact.type) ?? l10n.askFigures;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        card,
        SizedBox(height: skin.space.intraBlock),
        // A row inside a panel, not a button: no fill, no radius, and it is
        // offered only where it can actually lead somewhere.
        SoftRow(
          density: SoftRowDensity.compact,
          title: l10n.askOpenFullView,
          trailing: const SoftRowChevron(),
          separator: SoftRowSeparator.none,
          semanticsLabel: l10n.askOpenFullViewOf(name),
          // `push`, not `go`: the chat is where the manager came from and
          // where Back must return her, transcript intact.
          onTap: () => context.push('/artifact/${artifact.id}'),
        ),
      ],
    );
  }
}

/// The panel an answer's internal figures live in, or nothing.
///
/// The arrangement, the block labels, the unprovenanced guard and the
/// suppression line are all resolved here, so a turn's figures are decided in
/// one place rather than in the screen that draws them.
class AnswerPanel extends StatelessWidget {
  const AnswerPanel({super.key, required this.figures, this.expandable = true});

  final AnswerFigures figures;
  final bool expandable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (figures.suppressed && figures.internal.isEmpty) {
      return const UnprovenancedFiguresNote();
    }
    final ordered = arrangeAnswerArtifacts(figures.internal);
    if (ordered.isEmpty) {
      return figures.suppressed
          ? const UnprovenancedFiguresNote()
          : const SizedBox.shrink();
    }
    return InstrumentPanel(
      blocks: <PanelBlock>[
        for (final artifact in ordered)
          PanelBlock(
            key: ValueKey<String>('artifact-${artifact.id}'),
            eyebrow: panelEyebrowFor(l10n, artifact.type),
            child: ArtifactView(artifact: artifact, expandable: expandable),
          ),
      ],
    );
  }
}

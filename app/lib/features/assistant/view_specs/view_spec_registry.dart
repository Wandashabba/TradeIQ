import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/glass.dart';
import '../data/chat_controller.dart';
import 'agent_scorecard_card.dart';
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
typedef ViewSpecBuilder = Widget Function(BuildContext context, ChatArtifact artifact);

final Map<String, ViewSpecBuilder> viewSpecRegistry = {
  'agent_scorecard': (context, artifact) => AgentScorecardCard(artifact: artifact),
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

/// The cards an answer shows, in the order it shows them.
///
/// **One clean set of numbers.** A pillar tool emits its `pillar_metrics` card
/// and then `stat_tiles` carrying the same figures; when tiles came from the
/// **same tool call** ([ChatArtifact.toolCall]), the tiles stand in and that
/// call's pillar card is dropped. A pillar card with no tiles from its own
/// call — including one whose neighbouring call produced tiles — stays exactly
/// as it was, and no other type is ever hidden.
///
/// **Ordered by type, not arrival.** Tiles first, then every other card as it
/// arrived, then `ranked_bars` — the answer design's order. The server emits a
/// tool's own card before its tiles, so arrival order would bury the headline
/// figures under the chart they summarise. A turn with neither new type keeps
/// its order exactly.
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
        'ranked_bars' => 2,
        _ => 1,
      };
  shown.sort((a, b) {
    final byRank = rank(a.$2).compareTo(rank(b.$2));
    return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
  });
  return [for (final (_, artifact) in shown) artifact];
}

/// Render an artifact, or explain why it could not be drawn.
class ArtifactView extends StatelessWidget {
  const ArtifactView({
    super.key,
    required this.artifact,
    this.expandable = false,
  });

  final ChatArtifact artifact;

  /// Whether to offer the Expand affordance beneath the card. False inside
  /// Expanded mode itself, which is where the link would lead.
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

  @override
  Widget build(BuildContext context) {
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

    if (!expandable ||
        answerOnlySpecTypes.contains(artifact.type) ||
        !isPersisted(artifact.id)) {
      return card;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        card,
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            // `push`, not `go`: the chat is where the user came from and where
            // they expect Back to return them, transcript intact.
            onPressed: () => context.push('/artifact/${artifact.id}'),
            icon: const Icon(Icons.open_in_full, size: 14),
            label: const Text('Expand', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }
}

class UnsupportedArtifactNote extends StatelessWidget {
  const UnsupportedArtifactNote({super.key, required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    if (context.colors.glass) {
      final muted = context.lumen.inkMuted;
      // An unblurred tile: it sits in the transcript like any other turn.
      return GlassPane(
        kind: GlassKind.tile,
        blur: false,
        shadow: false,
        radius: LumenGlass.radiusControl,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'This answer includes a “$type” view your app version cannot '
                'draw yet. The summary above still applies.',
                style: TextStyle(fontSize: 12, height: 1.4, color: muted),
              ),
            ),
          ],
        ),
      );
    }
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: theme.hintColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This answer includes a “$type” view your app version cannot '
              'draw yet. The summary above still applies.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ),
        ],
      ),
    );
  }
}

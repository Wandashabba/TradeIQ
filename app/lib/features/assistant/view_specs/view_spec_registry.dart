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
};

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

    if (!expandable || !isPersisted(artifact.id)) return card;

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

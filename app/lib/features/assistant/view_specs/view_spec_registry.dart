import 'package:flutter/material.dart';

import '../data/chat_controller.dart';
import 'agent_scorecard_card.dart';
import 'outlet_map_card.dart';
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
};

/// Render an artifact, or explain why it could not be drawn.
class ArtifactView extends StatelessWidget {
  const ArtifactView({super.key, required this.artifact});

  final ChatArtifact artifact;

  @override
  Widget build(BuildContext context) {
    final builder = viewSpecRegistry[artifact.type];
    if (builder == null) return UnsupportedArtifactNote(type: artifact.type);

    // A card that throws while painting would take the whole transcript down
    // with it — including the narrative that already answered the question.
    // The data is server-validated against the spec's schema, so this should
    // not fire; "should not" is why it is caught rather than assumed.
    try {
      return builder(context, artifact);
    } catch (_) {
      return UnsupportedArtifactNote(type: artifact.type);
    }
  }
}

class UnsupportedArtifactNote extends StatelessWidget {
  const UnsupportedArtifactNote({super.key, required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
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

import 'package:flutter/material.dart';

import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
// Imported directly: console.dart uses DeltaPill but does not re-export it.
import '../../../core/widgets/delta_pill.dart';
import '../../../core/widgets/lumen_kit.dart';
import '../data/chat_controller.dart';

/// The `agent_scorecard` spec, rendered inline in the chat stream.
///
/// **Deliberately minimal — this is the anti-crowding rule.** An inline card
/// carries the headline figure and the one comparison that makes it mean
/// something, and stops. A full panel with every dimension broken out turns a
/// three-turn conversation into a wall of near-identical charts, which is the
/// named failure mode for generative UI in a chat surface. Phase 2's Expanded
/// mode is where the detail belongs.
///
/// It reads its data defensively. The server validates params against the
/// spec's schema, but the *shape of the tool result* is not part of that
/// contract — a tool could add or rename a field and ship before this build
/// does. Every read therefore has a fallback, and a missing field renders as
/// an omission rather than as a zero: "0 visits" and "we did not capture
/// visits" call for opposite responses from a manager.
class AgentScorecardCard extends StatelessWidget {
  const AgentScorecardCard({super.key, required this.artifact});

  final ChatArtifact artifact;

  Map<String, dynamic> get _data {
    final data = artifact.data;
    return data is Map<String, dynamic> ? data : const {};
  }

  /// Type-tested rather than cast.
  ///
  /// `as num?` throws on a value that is present but the wrong type — a field
  /// the backend once sent as a number and now sends as a formatted string, say.
  /// That would take the whole transcript down, including the narrative that
  /// already answered the question. Testing gives an omission instead.
  num? _num(String key) {
    final value = _data[key];
    return value is num ? value : null;
  }

  String? _string(String key) {
    final value = _data[key];
    return value is String ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final name = _string('agentName');
    final average = _num('averageScore');
    final team = _num('teamAverageScore');
    final delta = _num('deltaVsTeam');
    final visits = _num('visits');
    final outlets = _num('outletsVisited');
    final scored = _num('scoredVisits');

    return PanelCard(
      title: name ?? 'Agent scorecard',
      subtitle: scored == null ? null : '$scored scored ${scored == 1 ? 'visit' : 'visits'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                average == null ? '—' : average.toStringAsFixed(1),
                // The headline is a standalone number, so glass sets it in the
                // proportional hero face; the small metrics below are mono.
                style: colors.glass
                    ? LumenGlass.hero(size: 34, color: context.lumen.ink)
                    : TextStyle(
                        fontSize: 30,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: colors.ink1,
                      ),
              ),
              const SizedBox(width: 10),
              // The comparison sits beside the figure, not below it. The
              // workflow being replaced is "export, export again, overlay in
              // Excel" — a score with nothing to read it against has
              // reproduced that problem rather than solved it.
              if (delta != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: DeltaPill(
                    delta: delta.toDouble(),
                    tone: delta < 0 ? DeltaTone.bad : DeltaTone.good,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            team == null
                // Honest about why there is no comparison. "vs team —" would
                // read as a missing number rather than as an absent team.
                ? 'No other agent has a scored visit in this period.'
                : 'Team average ${team.toStringAsFixed(1)}',
            style: TextStyle(fontSize: 11.5, color: colors.ink3),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Metric(label: 'VISITS', value: visits?.toString() ?? '—'),
              _Metric(label: 'OUTLETS', value: outlets?.toString() ?? '—'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (colors.glass) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Kicker(label, size: 9.5),
          const SizedBox(height: 4),
          Text(
            value,
            style: LumenGlass.figure(size: 15, color: context.lumen.ink),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: colors.ink3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colors.ink1,
          ),
        ),
      ],
    );
  }
}

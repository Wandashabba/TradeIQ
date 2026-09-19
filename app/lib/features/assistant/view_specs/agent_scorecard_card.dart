import 'package:flutter/widgets.dart';

import '../../../core/design/figure_slot.dart';
import '../../../core/design/tiq_number.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/figure/eyebrow.dart';
import '../../../core/widgets/torchlight/figure/stat_tile.dart';
import '../../../core/widgets/torchlight/mark/delta.dart';
import '../../../l10n/l10n.dart';
import '../data/chat_controller.dart';

/// The `agent_scorecard` spec, rendered inline in the answer's panel.
///
/// **Deliberately minimal — this is the anti-crowding rule.** An inline block
/// carries the headline figure and the one comparison that makes it mean
/// something, and stops. A full panel with every dimension broken out turns a
/// three-turn conversation into a wall of near-identical charts, which is the
/// named failure mode for generative UI in a chat surface. The full view is
/// where the detail belongs.
///
/// It reads its data defensively. The server validates params against the
/// spec's schema, but the *shape of the tool result* is not part of that
/// contract — a tool could add or rename a field and ship before this build
/// does. Every read therefore has a fallback, and a missing field renders as
/// an unknown rather than as a zero: "0 visits" and "we did not capture
/// visits" call for opposite responses from a manager.
///
/// No amber: a stat tile declares no claim, and the one lit object on this
/// route is a ranked bar or a trend series, never a score.
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
  /// the backend once sent as a number and now sends as a formatted string,
  /// say. That would take the whole transcript down, including the narrative
  /// that already answered the question. Testing gives an unknown instead.
  num? _num(String key) {
    final value = _data[key];
    return value is num && value.isFinite ? value : null;
  }

  String? _string(String key) {
    final value = _data[key];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final p = skin.palette;

    final name = _string('agentName');
    final average = _num('averageScore');
    final team = _num('teamAverageScore');
    final delta = _num('deltaVsTeam');
    final visits = _num('visits');
    final outlets = _num('outletsVisited');
    final scored = _num('scoredVisits');

    return Column(
      key: const ValueKey<String>('agent-scorecard'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // A person's name is never set in capitals: it is the one label here
        // a manager reads letter by letter.
        Text(
          name ?? l10n.askScorecardTitle,
          maxLines: 2,
          style: skin.text.titleM.style(color: p.ink1),
        ),
        if (scored != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s1),
          Text(
            l10n.askScorecardScored(scored.toInt()),
            style: skin.text.meta.style(color: p.ink3),
          ),
        ],
        SizedBox(height: skin.space.intraBlock),
        StatTile(
          eyebrow: l10n.askScorecardAverage,
          value: average,
          decimals: 1,
          noDataReason: average == null ? l10n.askTileNoData : null,
          // The comparison sits beside the figure, not below it. The workflow
          // being replaced is "export, export again, overlay in Excel" — a
          // score with nothing to read it against has reproduced that
          // problem rather than solved it.
          delta: delta == null || team == null
              ? null
              : DeltaData(
                  direction: delta > 0
                      ? DeltaDirection.up
                      : (delta < 0 ? DeltaDirection.down : DeltaDirection.flat),
                  // A score above the team's is better, by the metric's own
                  // definition — this is the one delta here whose sentiment
                  // the sign does carry.
                  sentiment: delta > 0
                      ? TiqSentiment.good
                      : (delta < 0 ? TiqSentiment.bad : TiqSentiment.neutral),
                  magnitude: delta.abs(),
                  decimals: 1,
                  comparedTo: l10n.askScorecardVsTeam,
                ),
        ),
        SizedBox(height: skin.space.intraBlock),
        if (team == null)
          // Honest about why there is no comparison. "vs team —" would read
          // as a missing number rather than as an absent team.
          Text(
            l10n.askScorecardNoTeam,
            style: skin.text.meta.style(color: p.ink3),
          )
        else
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  l10n.askScorecardTeam,
                  style: skin.text.meta.style(color: p.ink3),
                ),
              ),
              const SizedBox(width: TiqSpace.s2),
              FigureSlot(
                value: team,
                role: skin.text.monoIdent,
                decimals: 1,
                color: p.ink2,
              ),
            ],
          ),
        SizedBox(height: skin.space.intraBlock),
        Wrap(
          spacing: TiqSpace.s6,
          runSpacing: TiqSpace.s2,
          children: <Widget>[
            _Metric(label: l10n.askScorecardVisits, value: visits),
            _Metric(label: l10n.askScorecardOutlets, value: outlets),
          ],
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;

  /// Null renders an em dash in ink-3 — unknown, never zero.
  final num? value;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Eyebrow(label),
        const SizedBox(height: TiqSpace.s1),
        FigureSlot(
          value: value,
          role: skin.text.figureS,
          decimals: 0,
          unit: TiqUnit.none,
          color: skin.palette.ink1,
        ),
      ],
    );
  }
}

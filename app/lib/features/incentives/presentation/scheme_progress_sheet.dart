import 'package:flutter/widgets.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../data/incentives_view.dart';

/// EVERYBODY'S PROGRESS TOWARD ONE REWARD.
///
/// The list view shows the agent nearest the reward, because that is the
/// question a manager has at a glance. This is the rest of the answer: every
/// agent, nearest first, earners after them, and the ones nobody can measure
/// last — with their absence stated rather than drawn as a nought.
Future<void> showSchemeProgressSheet(
  BuildContext context, {
  required IncentiveSchemeRow row,
  required int agentsMeasured,
}) {
  return showTorchSheet<void>(
    context,
    builder: (sheetContext) =>
        _SchemeProgressSheet(row: row, agentsMeasured: agentsMeasured),
  );
}

class _SchemeProgressSheet extends StatelessWidget {
  const _SchemeProgressSheet({required this.row, required this.agentsMeasured});

  final IncentiveSchemeRow row;
  final int agentsMeasured;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final numbers = TiqNumber.of(context);
    final metric = row.metric;
    final threshold = numbers.format(row.scheme.threshold);
    final reward = '${numbers.format(row.scheme.rewardPoints)} pts';
    final unit = metric?.unitWord ?? '';
    final rewardLabel = metric == null ? reward : '$reward at $threshold $unit';

    return TorchSheet(
      title: row.scheme.name,
      subtitle: '${metric?.label ?? row.scheme.metric} · $rewardLabel',
      // A reading, not a decision: nothing here is armed and nothing is lit.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SectionRule(
            'Everyone',
            count: row.progress.isEmpty ? null : row.progress.length,
          ),
          const SizedBox(height: TiqSpace.s4),
          if (row.progress.isEmpty)
            const EmptyState(
              key: ValueKey<String>('scheme-progress-empty'),
              scope: EmptyScope.inPanel,
              headline: 'No agent figures loaded.',
              body:
                  'Progress toward this reward is read from the board, and '
                  'the board has not answered.',
            )
          else
            for (final p in row.progress) ...<Widget>[
              if (p.value == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: TiqSpace.s5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        p.name,
                        style: skin.text.bodyStrong.style(
                          color: skin.palette.ink1,
                        ),
                      ),
                      const SizedBox(height: TiqSpace.s1),
                      // An average nobody has scored is not a zero, and a bar
                      // drawn at nought would tell this agent they had made no
                      // progress when nobody has measured them at all.
                      Text(
                        'Not measured on this metric yet.',
                        key: ValueKey<String>('scheme-unmeasured-${p.agentId}'),
                        style: skin.text.meta.style(color: skin.palette.ink3),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: TiqSpace.s5),
                  child: TorchProgressBar(
                    key: ValueKey<String>('scheme-progress-${p.agentId}'),
                    label: p.name,
                    value: p.value,
                    total: row.scheme.threshold,
                    fractionText: metric == null
                        ? '${numbers.format(p.value!)} of $threshold'
                        : '${numbers.format(p.value!)} of $threshold $unit',
                    doneWord: 'Earned',
                    milestones: <ProgressMilestone>[
                      ProgressMilestone(
                        at: row.scheme.threshold,
                        label: rewardLabel,
                        reward: true,
                      ),
                    ],
                  ),
                ),
            ],
          const SizedBox(height: TiqSpace.s2),
          Text(
            '${numbers.format(row.earnedCount)} of '
            '${numbers.format(agentsMeasured)} '
            '${agentsMeasured == 1 ? 'agent has' : 'agents have'} earned it.',
            key: const ValueKey<String>('scheme-progress-earned'),
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
          const SizedBox(height: TiqSpace.s5),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchTertiaryButton(
              key: const ValueKey<String>('scheme-progress-close'),
              label: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/widgets.dart';

import '../../../core/design/tiq_number.dart';
import '../../../l10n/l10n.dart';
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
}) {
  return showTorchSheet<void>(
    context,
    builder: (sheetContext) => _SchemeProgressSheet(row: row),
  );
}

class _SchemeProgressSheet extends StatelessWidget {
  const _SchemeProgressSheet({required this.row});

  /// Everything this sheet counts comes off the row, so the board's size
  /// cannot become a denominator here by accident.
  final IncentiveSchemeRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final numbers = TiqNumber.of(context);
    final metric = row.metric;
    final threshold = numbers.format(row.scheme.threshold);
    final reward = l10n.incentivesRewardPoints(
      numbers.format(row.scheme.rewardPoints),
    );
    final unit = metric?.unitWord(l10n) ?? '';
    final rewardLabel = metric == null
        ? reward
        : l10n.incentivesRewardAt(reward, threshold, unit);

    return TorchSheet(
      title: row.scheme.name,
      subtitle: l10n.schemeProgressSubtitle(
        metric?.label(l10n) ?? row.scheme.metric,
        rewardLabel,
      ),
      // A reading, not a decision: nothing here is armed and nothing is lit.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SectionRule(
            l10n.schemeProgressEveryone,
            count: row.progress.isEmpty ? null : row.progress.length,
          ),
          const SizedBox(height: TiqSpace.s4),
          if (row.progress.isEmpty)
            EmptyState(
              key: const ValueKey<String>('scheme-progress-empty'),
              scope: EmptyScope.inPanel,
              headline: l10n.schemeProgressEmptyHeadline,
              body: l10n.schemeProgressEmptyBody,
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
                        l10n.schemeProgressUnmeasured,
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
                        ? l10n.incentivesFraction(
                            numbers.format(p.value!),
                            threshold,
                          )
                        : l10n.incentivesFractionUnit(
                            numbers.format(p.value!),
                            threshold,
                            unit,
                          ),
                    doneWord: l10n.schemeProgressEarned,
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
          // The denominator is who this metric can measure, not who is on the
          // board. A sheet that lists four agents each saying "not measured on
          // this metric yet" and then counts all four into "0 of 4 agents have
          // earned it" contradicts itself on one screen (#464).
          if (row.progress.isNotEmpty)
            Text(
              row.nobodyMeasured
                  ? l10n.schemeProgressNobodyMeasured
                  : l10n.incentivesEarnedOf(
                      row.measuredCount,
                      numbers.format(row.earnedCount),
                    ),
              key: const ValueKey<String>('scheme-progress-earned'),
              style: skin.text.meta.style(color: skin.palette.ink3),
            ),
          const SizedBox(height: TiqSpace.s5),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchTertiaryButton(
              key: const ValueKey<String>('scheme-progress-close'),
              label: l10n.schemeProgressClose,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

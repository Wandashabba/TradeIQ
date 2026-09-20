import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tiq_number.dart';
import '../../../l10n/l10n.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../data/incentives_repository.dart';
import '../data/incentives_view.dart';
import 'scheme_form_sheet.dart';
import 'scheme_progress_sheet.dart';

/// INCENTIVES — the rules that pay out, and who is about to trigger one.
///
/// ```text
///   Incentives                                    [ ⟳ ]
///   A scheme awards points when an agent reaches
///   its threshold. Paused schemes stop awarding.
///   ── Schemes ────────────────── 3 ── Add one ──
///   Twenty visits                       [ On   ]
///   Visits submitted · 20 visits · 250 pts
///   Closest: Thandi Mokoena
///   ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▌         14 of 20
///   250 pts at 20 visits
///   3 of 11 agents have earned it · See everyone
///   ──────────────────────────────────────────
///   [ nav pill ]
/// ```
///
/// ## The reward is named, on the bar
///
/// The progress-to-reward bar is the most motivating object an agent ever
/// sees and therefore the most tempting thing in the product to light. It is
/// never amber, in any skin, in any state: the fill goes `good` and the notch
/// fills when the reward is reached, and the near-reward amber exception was
/// written, argued and deleted. The milestone's label names **what** is being
/// worked toward — "250 pts at 20 visits" — because a bar with no reward on it
/// is a progress bar, not a reward bar.
///
/// ## Who is close, not who has already won
///
/// The board's own figures answer "who is about to earn this?" without a
/// second endpoint: a scheme pays on visits, closures or the scorecard mean,
/// and the leaderboard carries all three per agent. The row shows the agent
/// **nearest the reward without having reached it** — a list of people who
/// already earned it does not answer the question a manager has.
///
/// An average nobody has scored is **not** a zero: `scorecardsCounted` is what
/// separates them, and an agent the board cannot answer for gets no bar at all
/// rather than one drawn at nought, which would tell them they had made no
/// progress when nobody has measured them.
///
/// ## The one amber, counted
///
/// A tab root that nominates nothing: the toggles are Abyssal blocks with
/// their state word, the reward bars are `good` or `chartNeutral`, and there
/// is no commit action on the list. The two sheets are untabbed routes and
/// each spends one grant on its own commit while every amber beneath goes out.
class IncentivesScreen extends ConsumerWidget {
  const IncentivesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final view = ref.watch(incentivesViewProvider);

    void refresh() {
      ref.invalidate(incentivesViewProvider);
      ref.invalidate(incentivesListProvider);
    }

    Widget frame({
      required String phase,
      required List<Widget> children,
      String? facts,
    }) => ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.menu,
      header: TorchAppHeader(
        title: l10n.incentivesTitle,
        facts: <String>[l10n.incentivesFact, ?facts],
        trailing: TorchIconButton(
          key: const ValueKey<String>('incentives-refresh'),
          icon: Icons.refresh,
          semanticLabel: l10n.incentivesRefresh,
          onPressed: refresh,
        ),
      ),
      children: children,
    );

    return view.when(
      loading: () => frame(
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: l10n.incentivesSkeleton,
            child: const SkeletonRows(count: 3, rowHeight: 80),
          ),
        ],
      ),
      error: (error, stack) => frame(
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'incentive schemes',
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('incentives-retry'),
                label: l10n.incentivesRetry,
                onPressed: refresh,
              ),
            ),
          ),
        ],
      ),
      data: (data) {
        final gutter = context.skin.space.gutter;
        final numbers = TiqNumber.of(context);
        return frame(
          phase: data.rows.isEmpty ? 'empty' : 'loaded',
          facts: data.rows.isEmpty
              ? null
              : l10n.incentivesAwardingFact(
                  numbers.format(data.awarding),
                  numbers.format(data.rows.length),
                ),
          children: <Widget>[
            SectionRule(
              l10n.incentivesSchemes,
              count: data.rows.isEmpty ? null : data.rows.length,
              emptyLine: data.rows.isEmpty
                  ? l10n.incentivesNoneConfigured
                  : null,
              action: SectionRuleAction(
                l10n.incentivesAddScheme,
                onTap: () => showSchemeFormSheet(context, ref),
              ),
            ),
            const SizedBox(height: TiqSpace.s5),
            if (data.rows.isEmpty)
              EmptyState(
                key: const ValueKey<String>('incentives-empty'),
                scope: EmptyScope.inPanel,
                headline: l10n.incentivesEmptyHeadline,
                body: l10n.incentivesEmptyBody,
              )
            else
              TorchBleed(
                extra: gutter * 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (var i = 0; i < data.rows.length; i++)
                      _SchemeBlock(
                        key: ValueKey<String>(
                          'scheme-${data.rows[i].scheme.id}',
                        ),
                        row: data.rows[i],
                        agentsMeasured: data.agentsMeasured,
                        last: i == data.rows.length - 1,
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One scheme: the rule, whether it is paying, and who is closest to it.
class _SchemeBlock extends ConsumerStatefulWidget {
  const _SchemeBlock({
    super.key,
    required this.row,
    required this.agentsMeasured,
    required this.last,
  });

  final IncentiveSchemeRow row;
  final int agentsMeasured;
  final bool last;

  @override
  ConsumerState<_SchemeBlock> createState() => _SchemeBlockState();
}

class _SchemeBlockState extends ConsumerState<_SchemeBlock> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final row = widget.row;
    final scheme = row.scheme;
    final skin = context.skin;
    final numbers = TiqNumber.of(context);
    final threshold = numbers.format(scheme.threshold);
    final reward = l10n.incentivesRewardPoints(
      numbers.format(scheme.rewardPoints),
    );
    final metricLabel = row.metric?.label(l10n) ?? scheme.metric;
    final unit = row.metric?.unitWord(l10n);
    final stateWord = scheme.active
        ? l10n.incentivesAwarding
        : l10n.incentivesPaused;
    final rule = unit == null
        ? l10n.incentivesRuleNoUnit(stateWord, metricLabel, threshold, reward)
        : l10n.incentivesRuleWithUnit(
            stateWord,
            metricLabel,
            threshold,
            unit,
            reward,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SoftRow(
          density: SoftRowDensity.tall,
          title: scheme.name,
          subtitle: rule,
          // A control, so it keeps its own semantics node beneath the row's:
          // the row's label is excluded content, and a switch nobody can
          // reach is a scheme a TalkBack manager cannot pause.
          //
          // An icon button rather than a full-width TorchToggle: a toggle is a
          // form control that owns its row, and one squeezed into a row's
          // trailing lane runs off the edge at 2.0x. The state survives in
          // three channels anyway — the Abyssal block, the glyph, and the word
          // that leads the row's own reason line.
          trailingIsControl: true,
          trailing: TorchIconButton(
            key: ValueKey<String>('toggle-${scheme.id}'),
            icon: scheme.active
                ? Icons.payments_outlined
                : Icons.pause_circle_outline,
            toggledOn: scheme.active,
            stateWord: scheme.active ? l10n.incentivesAwarding : null,
            semanticLabel: scheme.active
                ? l10n.incentivesPauseScheme(scheme.name)
                : l10n.incentivesStartScheme(scheme.name),
            onPressed: _busy ? null : () => _setActive(!scheme.active),
          ),
          actions: Wrap(
            spacing: TiqSpace.s4,
            runSpacing: TiqSpace.s2,
            children: <Widget>[
              if (row.progress.isNotEmpty)
                TorchTertiaryButton(
                  key: ValueKey<String>('scheme-everyone-${scheme.id}'),
                  label: l10n.incentivesSeeEveryone,
                  onPressed: () => showSchemeProgressSheet(context, row: row),
                ),
              TorchTertiaryButton(
                key: ValueKey<String>('delete-${scheme.id}'),
                label: l10n.incentivesDeleteScheme,
                destructive: true,
                onPressed: _busy ? null : _confirmDelete,
              ),
            ],
          ),
          separator: SoftRowSeparator.none,
        ),
        Padding(
          padding: EdgeInsets.only(
            left: skin.space.gutter,
            right: skin.space.gutter,
            bottom: TiqSpace.s5,
          ),
          child: _Progress(
            row: row,
            agentsMeasured: widget.agentsMeasured,
          ),
        ),
        if (!widget.last)
          Padding(
            padding: const EdgeInsets.only(bottom: TiqSpace.s5),
            child: SizedBox(
              height: skin.depth.borderWidth,
              child: ColoredBox(color: skin.palette.edgeStructure),
            ),
          ),
      ],
    );
  }

  Future<void> _setActive(bool value) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(incentivesRepositoryProvider)
          .setActive(widget.row.scheme.id, value);
      if (!mounted) return;
      ref.invalidate(incentivesViewProvider);
      ref.invalidate(incentivesListProvider);
    } catch (error) {
      if (!mounted) return;
      showTorchToast(
        context,
        kind: ToastKind.failure,
        message: value
            ? context.l10n.incentivesCouldNotStart(widget.row.scheme.name)
            : context.l10n.incentivesCouldNotPause(widget.row.scheme.name),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    final scheme = widget.row.scheme;
    final confirmed = await showTorchSheet<bool>(
      context,
      dismissible: false,
      builder: (sheetContext) => ConfirmSheet(
        action: l10n.incentivesDeleteAction(scheme.name),
        record: scheme.metric,
        consequences: <String>[
          l10n.incentivesDeleteStops,
          l10n.incentivesDeleteKeeps,
          l10n.incentivesEarnedSoFar(widget.row.earnedCount),
        ],
        commitLabel: l10n.incentivesDeleteScheme,
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(incentivesRepositoryProvider).deleteScheme(scheme.id);
      if (!mounted) return;
      ref.invalidate(incentivesViewProvider);
      ref.invalidate(incentivesListProvider);
    } catch (error) {
      if (!mounted) return;
      showTorchToast(
        context,
        kind: ToastKind.failure,
        message: context.l10n.incentivesCouldNotDelete(scheme.name),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// The progress-to-reward bar, with the reward named on it.
class _Progress extends StatelessWidget {
  const _Progress({required this.row, required this.agentsMeasured});

  final IncentiveSchemeRow row;
  final int agentsMeasured;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final numbers = TiqNumber.of(context);
    final metric = row.metric;

    if (metric == null) {
      // A metric key this client has not been taught. Saying so is better
      // than a bar against a threshold nobody can interpret.
      return Text(
        l10n.incentivesUnknownMetric(row.scheme.metric),
        key: ValueKey<String>('scheme-unknown-metric-${row.scheme.id}'),
        style: skin.text.meta.style(color: skin.palette.ink3),
      );
    }
    if (agentsMeasured == 0) {
      // The board is the only source of these figures. Without it there is no
      // honest bar to draw — and a bar out of an invented total is worse than
      // none.
      return Text(
        l10n.incentivesNoBoard,
        key: ValueKey<String>('scheme-no-board-${row.scheme.id}'),
        style: skin.text.meta.style(color: skin.palette.ink3),
      );
    }

    if (row.nobodyMeasured) {
      // The board answered, and this metric cannot answer for a single agent
      // on it. "0 of 11 agents have earned it" would be eleven people who
      // failed; nobody was measured. Words, not a fraction.
      return Text(
        l10n.incentivesNobodyMeasured(metric.label(l10n).toLowerCase()),
        key: ValueKey<String>('scheme-none-measured-${row.scheme.id}'),
        style: skin.text.meta.style(color: skin.palette.ink3),
      );
    }

    final closest = row.closest;
    final earned = row.earnedCount;
    // The denominator is who this metric can measure, never the whole board.
    final measured = row.measuredCount;
    final reward = l10n.incentivesRewardPoints(
      numbers.format(row.scheme.rewardPoints),
    );
    final threshold = numbers.format(row.scheme.threshold);
    final unit = metric.unitWord(l10n);
    final rewardLabel = l10n.incentivesRewardAt(reward, threshold, unit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (closest == null)
          // At least one agent is measured here — the metric-measures-nobody
          // case returned above — so nobody being on the way can only mean
          // everybody measurable has already arrived.
          Text(
            l10n.incentivesEverybodyEarned,
            key: ValueKey<String>('scheme-nobody-close-${row.scheme.id}'),
            style: skin.text.meta.style(color: skin.palette.ink3),
          )
        else
          TorchProgressBar(
            key: ValueKey<String>('scheme-bar-${row.scheme.id}'),
            // The person, not the metric: "who is about to earn this?" is the
            // question a manager actually has.
            label: l10n.incentivesClosest(closest.name),
            value: closest.value,
            total: row.scheme.threshold,
            fractionText: l10n.incentivesFractionUnit(
              numbers.format(closest.value!),
              threshold,
              unit,
            ),
            milestones: <ProgressMilestone>[
              ProgressMilestone(
                at: row.scheme.threshold,
                label: rewardLabel,
                reward: true,
              ),
            ],
          ),
        const SizedBox(height: TiqSpace.s3),
        Text(
          l10n.incentivesEarnedOf(measured, numbers.format(earned)),
          key: ValueKey<String>('scheme-earned-${row.scheme.id}'),
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
      ],
    );
  }
}

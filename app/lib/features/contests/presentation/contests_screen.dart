import 'package:flutter/material.dart' show Icons, MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../data/contests_repository.dart';
import 'contest_form_screen.dart';
import 'contest_labels.dart';

/// CONTESTS (#124) — time-boxed competitions over the points ledger.
///
/// ```text
///   Contests                                      [ ⟳ ]
///   Agents are ranked by the points they earn…
///   ── Contests                             3 ────
///   Spring push                            Active
///   3 days left
///   2026-09-01 → 2026-09-30 · All territories · …
///   Edit   Cancel                              ›
///   …
///   [ New contest ]
///   [ nav pill ]
/// ```
///
/// ## The amber, counted
///
/// A tab root: the nav pill's active tab is slot 1 in Night whenever the nav
/// renders, and this route declines the one content grant it has left.
/// Nothing here is armed — creating a contest is a ghost at the foot of the
/// list, not a commit, and the status chips are a `live` dot and an Oatmeal
/// square. Day and Veld have one rung, the primary commit block, and this
/// route has no primary: they paint **zero**.
///
/// While a confirm sheet is up every amber beneath it goes out, which
/// [ConsoleFrame] wires through [TorchSheetAware].
///
/// ## Destroying one asks first, and names what it costs
///
/// Cancel and Delete both go through a [ConfirmSheet] — the console's instance
/// of the decision-sheet anatomy — rather than the dialog unify §1.7 deleted.
/// The contest's own id rides in the sheet's `record` slot, in mono, so a
/// manager can check they are cancelling the right one.
class ContestsScreen extends ConsumerWidget {
  const ContestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contests = ref.watch(contestsListProvider);

    return contests.when(
      loading: () => _frame(
        context,
        ref,
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: 'contests',
            child: const SkeletonRows(count: 4, rowHeight: 80),
          ),
        ],
      ),
      error: (error, stack) => _frame(
        context,
        ref,
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'contests',
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('contests-retry'),
                label: 'Try again',
                onPressed: () => ref.invalidate(contestsListProvider),
              ),
            ),
          ),
        ],
      ),
      data: (list) => _loaded(context, ref, list),
    );
  }

  Widget _frame(
    BuildContext context,
    WidgetRef ref, {
    required String phase,
    required List<Widget> children,
  }) {
    return ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.menu,
      header: TorchAppHeader(
        title: 'Contests',
        facts: const <String>[
          'Agents are ranked by the points they earn between a contest’s '
              'dates, counted in your timezone.',
        ],
        trailing: TorchIconButton(
          key: const ValueKey<String>('contests-refresh'),
          icon: Icons.refresh,
          semanticLabel: 'Refresh the contests list',
          onPressed: () => ref.invalidate(contestsListProvider),
        ),
      ),
      children: children,
    );
  }

  Widget _loaded(BuildContext context, WidgetRef ref, List<Contest> list) {
    final gutter = context.skin.space.gutter;

    return _frame(
      context,
      ref,
      phase: list.isEmpty ? 'empty' : 'loaded',
      children: <Widget>[
        // A section that vanishes when empty makes a manager think the
        // feature is gone, so the rule and its name render whatever the
        // count is.
        SectionRule('Contests', count: list.isEmpty ? null : list.length),
        const SizedBox(height: TiqSpace.s5),

        if (list.isEmpty)
          const EmptyState(
            key: ValueKey<String>('contests-empty'),
            scope: EmptyScope.inPanel,
            headline: 'No contests yet.',
            body:
                'Create one to rank agents by the points they earn between '
                'two dates, for a prize.',
          )
        else
          TorchBleed(
            extra: gutter * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < list.length; i++)
                  _ContestRow(
                    key: ValueKey<String>('contest-row-${list[i].id}'),
                    contest: list[i],
                    last: i == list.length - 1,
                  ),
              ],
            ),
          ),

        const SizedBox(height: TiqSpace.s7),
        // A ghost at the foot of the list, not a floating button: a FAB here
        // would collide with the nav circle's position vocabulary, and
        // creating a contest is not the commit this screen is about.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchSecondaryButton(
            key: const ValueKey<String>('contest-create'),
            label: 'New contest',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ContestFormScreen(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One contest, as a row, carrying only the verbs its status allows.
class _ContestRow extends ConsumerWidget {
  const _ContestRow({super.key, required this.contest, required this.last});

  final Contest contest;
  final bool last;

  Future<void> _confirmThen(
    BuildContext context,
    WidgetRef ref, {
    required String action,
    required List<String> consequences,
    required String commitLabel,
    required String failure,
    required Future<void> Function(ContestsRepository repo) run,
  }) async {
    final confirmed = await showTorchSheet<bool>(
      context,
      builder: (_) => ConfirmSheet(
        action: action,
        consequences: consequences,
        commitLabel: commitLabel,
        // The record a manager is about to act on, in mono, so they can check
        // it is the right one before a destructive press.
        record: contest.id,
        cancelLabel: 'Keep it',
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await run(ref.read(contestsRepositoryProvider));
      ref.invalidate(contestsListProvider);
    } catch (error) {
      if (!context.mounted) return;
      showTorchToast(
        context,
        message: '$failure ${TorchErrorMessage.sanitise(error).body}',
        kind: ToastKind.failure,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contest;
    final statusWord = contestStatusWord(c.status);
    final when = contestWhenSummary(c);
    final facts =
        '${c.startDate} → ${c.endDate} · ${contestScopeSummary(c)} · '
        '${contestCountsSummary(c)}';

    final verbs = <Widget>[
      if (!c.isCancelled)
        TorchTertiaryButton(
          key: ValueKey<String>('contest-edit-${c.id}'),
          label: 'Edit',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ContestFormScreen(contest: c),
            ),
          ),
        ),
      if (c.isActive || c.isUpcoming)
        TorchTertiaryButton(
          key: ValueKey<String>('contest-cancel-${c.id}'),
          label: 'Cancel',
          onPressed: () => _confirmThen(
            context,
            ref,
            action: 'Cancel “${c.name}”?',
            consequences: const <String>[
              'Agents stop seeing it straight away.',
              'You keep its standings.',
              'It cannot be edited or restarted.',
            ],
            commitLabel: 'Cancel contest',
            failure: 'The contest was not cancelled.',
            run: (repo) => repo.cancelContest(c.id),
          ),
        ),
      if (c.isUpcoming || c.isCancelled)
        TorchTertiaryButton(
          key: ValueKey<String>('contest-delete-${c.id}'),
          label: 'Delete',
          onPressed: () => _confirmThen(
            context,
            ref,
            action: 'Delete “${c.name}”?',
            consequences: const <String>['It is removed for good.'],
            commitLabel: 'Delete contest',
            failure: 'The contest was not deleted.',
            run: (repo) => repo.deleteContest(c.id),
          ),
        ),
    ];

    return SoftRow(
      key: ValueKey<String>('contest-${c.id}'),
      density: SoftRowDensity.tall,
      title: c.name,
      subtitle: when,
      meta: Text(facts),
      // A status is a label, so it is a word and a silhouette — never a hue
      // on its own, and never a severity: a cancelled contest is a decision
      // somebody made, not a fault.
      trailing: StatusChip(level: contestLevel(c.status), label: statusWord),
      // The verbs live in the row's action slot, not in `meta`: `meta` is
      // inside the row's excluded label, so a button there paints, hit-tests
      // and is announced nowhere.
      actions: verbs.isEmpty
          ? null
          : Wrap(spacing: TiqSpace.s4, children: verbs),
      onTap: () => context.push('/contests/${c.id}'),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[statusWord, c.name, when, facts].join('. '),
    );
  }
}

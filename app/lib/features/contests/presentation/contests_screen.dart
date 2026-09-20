import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/human_error.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/contests_repository.dart';
import 'contest_form_screen.dart';
import 'contest_labels.dart';

/// Contests (#124): time-boxed competitions over the points ledger. One row
/// per contest, newest start first; a row opens its standings, and carries
/// the actions its status allows — edit until cancelled, cancel while it has
/// not ended, delete only what never ran or was cancelled.
class ContestsScreen extends ConsumerWidget {
  const ContestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contests = ref.watch(contestsListProvider);
    return ManagerScaffold(
      title: 'Contests',
      floatingActionButton: FloatingActionButton(
        key: const ValueKey<String>('contest-create-fab'),
        tooltip: 'New contest',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => const ContestFormScreen(),
          ),
        ),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Agents are ranked by the points they earn between a contest’s '
            'dates, counted in your timezone. Tap a contest for its standings.',
            style: TextStyle(fontSize: 12, color: context.colors.ink3),
          ),
          const SizedBox(height: 12),
          AsyncSection<List<Contest>>(
            value: contests,
            label: 'contests',
            onRetry: () => ref.invalidate(contestsListProvider),
            builder: (list) => PanelCard(
              title:
                  '${list.length} ${list.length == 1 ? 'contest' : 'contests'}',
              subtitle: 'Newest first',
              padded: false,
              child: list.isEmpty
                  ? const EmptyState(
                      message: 'No contests yet',
                      hint: 'Create one to rank agents by the points they '
                          'earn between two dates, for a prize.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final contest in list)
                          _ContestRow(contest: contest),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContestRow extends ConsumerWidget {
  const _ContestRow({required this.contest});

  final Contest contest;

  Future<void> _confirmThen(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String body,
    required String confirmLabel,
    required String failure,
    required Future<void> Function(ContestsRepository repo) action,
  }) async {
    // Taken before the dialog's await: the row may be rebuilt meanwhile.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.colors.surface1,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            key: const ValueKey<String>('contest-confirm-keep'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            key: const ValueKey<String>('contest-confirm-go'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await action(ref.read(contestsRepositoryProvider));
      ref.invalidate(contestsListProvider);
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('$failure ${humanErrorMessage(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contest;
    return WorklistRow(
      key: ValueKey<String>('contest-${c.id}'),
      title: c.name,
      meta: Text(
        '${c.startDate} → ${c.endDate} · ${contestScopeSummary(c)} · '
        '${contestCountsSummary(c)}',
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
      level: contestLevel(c.status),
      statusLabel: contestStatusWord(c.status),
      when: contestWhenSummary(c),
      // Over, one way or the other: still listed, dimmed.
      resolved: c.isEnded || c.isCancelled,
      onTap: () => context.push('/contests/${c.id}'),
      actions: [
        if (!c.isCancelled)
          RowAction(
            key: ValueKey<String>('contest-edit-${c.id}'),
            label: 'Edit',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => ContestFormScreen(contest: c),
              ),
            ),
          ),
        if (c.isActive || c.isUpcoming)
          RowAction(
            key: ValueKey<String>('contest-cancel-${c.id}'),
            label: 'Cancel',
            tone: StatusLevel.critical,
            onPressed: () => _confirmThen(
              context,
              ref,
              title: 'Cancel “${c.name}”?',
              body: 'Agents stop seeing it straight away. You keep its '
                  'standings, but it cannot be edited or restarted.',
              confirmLabel: 'Cancel contest',
              failure: 'Failed to cancel contest.',
              action: (repo) => repo.cancelContest(c.id),
            ),
          ),
        if (c.isUpcoming || c.isCancelled)
          RowAction(
            key: ValueKey<String>('contest-delete-${c.id}'),
            label: 'Delete',
            tone: StatusLevel.critical,
            onPressed: () => _confirmThen(
              context,
              ref,
              title: 'Delete “${c.name}”?',
              body: 'It is removed for good.',
              confirmLabel: 'Delete contest',
              failure: 'Failed to delete contest.',
              action: (repo) => repo.deleteContest(c.id),
            ),
          ),
      ],
    );
  }
}

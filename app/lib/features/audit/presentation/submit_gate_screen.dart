import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/agent_kit.dart';
import '../../../core/widgets/agent_motion.dart';
import '../../../core/widgets/agent_scaffold.dart';
import '../data/visit_progress.dart';
import '../data/visit_review.dart';

/// The last screen before the visit leaves the agent's hands.
///
/// Submitting is irreversible and it raises tasks for a manager — it is the one
/// moment in the visit where the agent is *accusing the store of something*. So
/// it does not happen behind a button on a hub. It shows what the submission
/// will do, in plain words, and asks.
///
/// Everything on this screen is derived from what the agent captured. Nothing is
/// added afterwards, and the screen says so, because an agent who believes the
/// app is inventing findings will start under-reporting them.
class SubmitGateScreen extends ConsumerWidget {
  const SubmitGateScreen({
    super.key,
    required this.visitDraftId,
    required this.outletId,
    required this.outletName,
    required this.checkinTs,
    required this.onConfirm,
  });

  final String visitDraftId;
  final String outletId;
  final String outletName;
  final DateTime? checkinTs;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (visitDraftId: visitDraftId, outletId: outletId);
    final reviewAsync = ref.watch(visitReviewProvider(key));
    final progressAsync = ref.watch(visitProgressProvider(key));
    final offline = ref.watch(syncStatusProvider).maybeWhen(
          data: (s) => s.pending.isNotEmpty,
          orElse: () => false,
        );

    return AgentScaffold(
      title: 'Submit visit',
      subtitle: _inStore(),
      showSyncChip: false,
      onBack: () => Navigator.of(context).pop(),
      bottomAction: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (offline)
            const BarNote(
              'No signal? Submitting still works — it saves on the phone and '
              'sends itself.',
            ),
          AgentButton(
            key: const ValueKey('confirm-submit'),
            label: 'Submit visit',
            onPressed: onConfirm,
          ),
        ],
      ),
      body: reviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not read this visit: $err'),
          ),
        ),
        data: (review) {
          final progress = progressAsync.maybeWhen(
            data: (p) => p,
            orElse: () => null,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              const Text(
                'Check this over before it goes to your manager. After '
                'submitting you cannot change it.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: AppColors.ink2,
                ),
              ),
              const SizedBox(height: 16),
              Reveal(
                index: 0,
                child: _CapturedCard(
                  sectionsDone: progress?.doneCount ?? 0,
                  sectionsTotal: progress?.captureCount ?? 0,
                  line: review.capturedLine,
                ),
              ),
              if (review.willRaise.isNotEmpty) ...[
                const SizedBox(height: 18),
                const _Heading('This will raise'),
                Reveal(
                  index: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      border: Border.all(color: AppColors.line),
                      borderRadius:
                          BorderRadius.circular(AppColors.radiusPanel),
                    ),
                    child: Column(
                      children: [
                        for (final task in review.willRaise)
                          _TaskRow(task: task),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _accusation(review.willRaise.length),
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.ink3,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 18),
                Reveal(
                  index: 1,
                  child: _NothingWrong(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String? _inStore() {
    final start = checkinTs;
    if (start == null) return outletName;
    final minutes = DateTime.now().difference(start).inMinutes;
    if (minutes < 1) return outletName;
    return '$outletName · $minutes min in store';
  }

  /// The agent is about to tell a manager that a store is failing at something.
  /// Naming that plainly is the point: it is what makes the finding theirs, and
  /// it is why they trust the app not to have made it up.
  static String _accusation(int count) {
    final subject = count == 1
        ? 'You are telling the manager one thing is wrong in this store.'
        : 'You are telling the manager $count things are wrong in this store.';
    return '$subject They all come from what you captured — nothing is added '
        'afterwards. If the manager already has one of these open, it will not '
        'be raised twice.';
  }
}

class _CapturedCard extends StatelessWidget {
  const _CapturedCard({
    required this.sectionsDone,
    required this.sectionsTotal,
    required this.line,
  });

  final int sectionsDone;
  final int sectionsTotal;
  final String line;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppColors.radiusPanel),
      ),
      child: Row(
        children: [
          const TickMark(done: true, size: 22),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$sectionsDone of $sectionsTotal sections complete',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  line,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.ink3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final RaisedTask task;

  @override
  Widget build(BuildContext context) {
    final color = task.isUrgent ? AppColors.crit : AppColors.warn;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              task.isUrgent ? Icons.priority_high : Icons.adjust,
              size: 13,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.ink1,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // The priority is always paired with the word, never carried
                  // by the colour alone — a colour-blind agent in bad light
                  // still has to be able to tell urgent from routine.
                  'Task for the manager · ${task.priority}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.ink3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A clean store is a real result, and it should not read as an empty screen.
class _NothingWrong extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.good.withValues(alpha: 0.10),
        border: Border.all(color: AppColors.good.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(AppColors.radiusPanel),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, size: 20, color: AppColors.good),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Nothing to raise. You found no stockouts and flagged no risks — '
              'this store is in good shape.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.ink2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.08 * 11,
          color: AppColors.ink3,
        ),
      ),
    );
  }
}

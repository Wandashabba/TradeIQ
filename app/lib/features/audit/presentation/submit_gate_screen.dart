import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/agent_kit.dart';
import '../../../core/widgets/agent_motion.dart';
import '../../../core/widgets/agent_scaffold.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/lumen_kit.dart';
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
    final offline = ref
        .watch(syncStatusProvider)
        .maybeWhen(data: (s) => s.pending.isNotEmpty, orElse: () => false);

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
          // In glass the kit's primary button is the GlassPrimaryButton.
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
          final colors = context.colors;
          final progress = progressAsync.maybeWhen(
            data: (p) => p,
            orElse: () => null,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              Text(
                'Check this over before it goes to your manager. After '
                'submitting you cannot change it.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: colors.ink2,
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
                  child: colors.glass
                      // Glass: a checklist — each task its own tile, so the
                      // agent reads them one accusation at a time.
                      ? Column(
                          children: [
                            for (final (i, task) in review.willRaise.indexed)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: i == 0 ? 0 : 8,
                                ),
                                child: _TaskRow(task: task),
                              ),
                          ],
                        )
                      : PanelCard(
                          padded: false,
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
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: colors.ink3,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 18),
                Reveal(index: 1, child: _NothingWrong()),
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
    final colors = context.colors;
    if (colors.glass) return _glass(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(AppColors.radiusPanel),
      ),
      child: Row(
        children: [
          TickMark(done: true, size: 22, color: colors.good),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$sectionsDone of $sectionsTotal sections complete',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: colors.ink1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  line,
                  style: TextStyle(fontSize: 12.5, color: colors.ink3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Glass: the first checklist tile — a ✓ in its good status tile.
  Widget _glass(BuildContext context) {
    final lumen = context.lumen;
    return GlassPane(
      kind: GlassKind.tile,
      blur: false,
      radius: LumenGlass.radiusCard,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        children: [
          const ExcludeSemantics(
            child: StatusTile(status: LumenStatus.good, glyph: '✓', size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$sectionsDone of $sectionsTotal sections complete',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: lumen.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  line,
                  style: TextStyle(fontSize: 12.5, color: lumen.inkMuted),
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
    final colors = context.colors;
    if (colors.glass) return _glass(context);
    // The box wash follows the token; the glyph on it must clear AA. Urgent
    // needs critText — raw crit fails 4.5:1 in dark — while warn reads on its
    // own wash in both themes.
    final wash = task.isUrgent ? colors.crit : colors.warn;
    final glyph = task.isUrgent ? colors.critText : colors.warn;

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
              color: _wash(colors, wash),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              task.isUrgent ? Icons.priority_high : Icons.adjust,
              size: 13,
              color: glyph,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.ink1,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // The priority is always paired with the word, never carried
                  // by the colour alone — a colour-blind agent in bad light
                  // still has to be able to tell urgent from routine.
                  'Task for the manager · ${task.priority}',
                  style: TextStyle(fontSize: 11.5, color: colors.ink3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Glass: a checklist tile whose rim takes the task's status — crit when
  /// urgent, warn when routine — with the glyph in its status tile and the
  /// priority still spelled out beside it.
  Widget _glass(BuildContext context) {
    final colors = context.colors;
    final status = task.isUrgent ? LumenStatus.crit : LumenStatus.warn;
    final sw = status.swatchOf(colors);
    return GlassPane(
      kind: GlassKind.tile,
      blur: false,
      radius: LumenGlass.radiusCard,
      rimColor: sw.rim,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The word below says it; the glyph is for the eye.
          ExcludeSemantics(
            child: StatusTile(
              status: status,
              glyph: task.isUrgent ? '!' : '•',
              size: 28,
              radius: 9,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: context.lumen.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Task for the manager · ${task.priority}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: sw.ink,
                  ),
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
    final colors = context.colors;
    if (colors.glass) {
      // Glass: an OPAQUE good wash, so the words clear AA on their own.
      final good = LumenStatus.good.swatchOf(colors);
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: Color.alphaBlend(good.tint, colors.surface1),
          border: Border.all(color: good.rim),
          borderRadius: BorderRadius.circular(LumenGlass.radiusCard),
        ),
        child: Row(
          children: [
            const ExcludeSemantics(
              child: StatusTile(
                status: LumenStatus.good,
                glyph: '✓',
                size: 28,
                radius: 9,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nothing to raise. You found no stockouts and flagged no '
                'risks — this store is in good shape.',
                style: TextStyle(fontSize: 13, height: 1.45, color: good.ink),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: colors.good.withValues(alpha: 0.10),
        border: Border.all(color: colors.good.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(AppColors.radiusPanel),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 20, color: colors.good),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Nothing to raise. You found no stockouts and flagged no risks — '
              'this store is in good shape.',
              style: TextStyle(fontSize: 13, height: 1.45, color: colors.ink2),
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
    if (context.colors.glass) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Kicker(text, color: context.lumen.kicker),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.08 * 11,
          color: context.colors.ink3,
        ),
      ),
    );
  }
}

/// A status token composited to an OPAQUE 12% wash over surface1 — the ground a
/// coloured glyph reads against at ≥4.5:1. A local twin of the hub's `_wash`
/// (audit_shell_screen.dart); folding the two into one shared helper is tracked
/// in #214.
Color _wash(TiqColors colors, Color token) =>
    Color.alphaBlend(token.withValues(alpha: 0.12), colors.surface1);

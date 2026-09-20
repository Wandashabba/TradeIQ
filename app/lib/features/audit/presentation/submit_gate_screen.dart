import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_status.dart';
import '../../../core/theme/torchlight/agent_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../data/visit_progress.dart';
import '../data/visit_review.dart';
import 'audit_shell_screen.dart' show VisitFrame, cantConfirmText, sectionLabel;

/// THE SUBMIT GATE — the last screen before the visit leaves the agent's
/// hands.
///
/// Submitting is irreversible and it raises tasks against a real shop: it is
/// the one moment in the visit where the agent is *accusing a store of
/// something*. So it does not happen behind a button on a hub. It shows what
/// the submission will do, in plain words, and asks.
///
/// ```text
///   Submit visit                    Kasi Corner Spaza · 12 min in store
///   Check this before it goes to your manager — you cannot change it after.
///   ┌───────────────────────────────────────────┐
///   │ ◉  4 of 7 sections complete               │
///   │    12 SKUs counted · 2 competitors        │
///   │ ⊘  1 section could not be confirmed       │
///   └───────────────────────────────────────────┘
///   ── This will raise · 3 ──────────────────────
///   ▌▲ Fanta Orange 2L is out of stock
///   ▌  Task for the manager · high
///    ◺ Aisle blocked by delivery
///      Task for the manager · normal
///    ⊘ Stock & availability could not be confirmed
///      The manager is told · not confirmed
///   ■ No signal? Submitting still works…
///   [ ☾ ] [          Submit visit               ]
/// ```
///
/// Everything here is derived from what the agent captured. Nothing is added
/// afterwards, and the screen says so — an agent who believes the app is
/// inventing findings will start under-reporting them.
///
/// ## Amber
///
/// An untabbed route, so the content has two grants in Night and this screen
/// spends exactly one of them: the primary. The severity bars, the task
/// glyphs, the section rule and the offline note are all labels, and the law
/// bans amber from every one of them by name. While the review is loading or
/// unreadable the primary is still armed — **a failure to read the review is
/// not a failure to submit**, because submitting is a local write and the
/// captures are already on the phone.
///
/// ## Can't confirm is something to raise (#389)
///
/// The old gate listed nothing for a section the app could not establish, so a
/// store that refused four sections produced a gate printing "this store is in
/// good shape". Every can't-confirm section now gets its own row here, because
/// a store that refused the count *is* the finding.
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

  /// The primary's claim id.
  static const String submitClaimId = 'submit-gate';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (visitDraftId: visitDraftId, outletId: outletId);
    final reviewAsync = ref.watch(visitReviewProvider(key));
    final progressAsync = ref.watch(visitProgressProvider(key));
    final offline = ref
        .watch(syncStatusProvider)
        .maybeWhen(data: (s) => s.pending.isNotEmpty, orElse: () => false);

    final l10n = context.l10n;
    // Unknown is not zero. A progress that has not answered yet, or cannot be
    // read, is neither "0 of 0 sections" nor a visit with nothing
    // can't-confirm in it — and treating it as both printed a clean verdict
    // over a section nobody could confirm (#389's other half, again). The
    // last reading that did arrive is still a real reading, so a stream that
    // errors after a value keeps it.
    final progress = progressAsync.hasValue ? progressAsync.value : null;
    final progressUnread = progress == null && progressAsync.hasError;

    Widget frame({required String phase, required List<Widget> children}) =>
        VisitFrame(
          phase: phase,
          title: l10n.visitSubmitButton,
          facts: <String>[_inStore(l10n)],
          // The gate is not the hub: there is no sync chip here, because the
          // header already carries the outlet and the offline note carries the
          // one fact about signal that matters at this moment.
          showSyncChip: false,
          claimSubmit: true,
          claimId: SubmitGateScreen.submitClaimId,
          submit: TorchPrimaryButton(
            key: const ValueKey<String>('confirm-submit'),
            claimId: SubmitGateScreen.submitClaimId,
            label: l10n.visitSubmitButton,
            // The label a reader hears is the whole sentence, so nobody is ever
            // asked to confirm the word "Submit".
            semanticLabel: l10n.submitPrimarySemantics,
            onPressed: onConfirm,
          ),
          secondary: TorchSecondaryButton(
            key: const ValueKey<String>('gate-back'),
            label: l10n.submitGateBack,
            onPressed: () => Navigator.of(context).pop(),
          ),
          children: <Widget>[
            // Offline is not an error and it is not a blocker: submitting is a
            // local write. A square glyph and a sentence, never crimson.
            if (offline) ...<Widget>[
              Row(
                key: const ValueKey<String>('submit-offline-note'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const RowMarkTile(mark: RowMark.square),
                  const SizedBox(width: TiqSpace.s3),
                  Expanded(
                    child: Text(
                      l10n.submitOfflineNote,
                      style: context.skin.text.label.style(
                        color: context.skin.palette.ink2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TiqSpace.s5),
            ],
            ...children,
          ],
        );

    return TorchlightRoute(
      child: reviewAsync.when(
        loading: () =>
            frame(phase: 'loading', children: const <Widget>[_GateSkeleton()]),
        // The gate still submits and says so. Failing to *read* what the visit
        // will raise is not failing to submit — the captures are in the outbox
        // either way, and a gate that took the primary away here would strand
        // an agent with a finished visit they cannot send.
        error: (err, _) => frame(
          phase: 'review-failed',
          children: <Widget>[
            ErrorState(
              key: const ValueKey<String>('gate-review-error'),
              message: TorchErrorMessage(
                kind: TorchErrorKind.unknown,
                headline: l10n.visitReadFailedTitle,
                body: l10n.visitReadFailed('$err'),
                offersRetry: false,
              ),
              scope: ErrorScope.inline,
            ),
          ],
        ),
        data: (review) {
          // Still waiting on the sections: the same skeleton as the review,
          // never a count of nothing. The primary stays armed — the captures
          // are on the phone whether or not this screen has read them yet.
          if (progress == null && !progressUnread) {
            return frame(
              phase: 'loading',
              children: const <Widget>[_GateSkeleton()],
            );
          }
          final cantConfirm = _cantConfirmEntries(l10n, progress);
          final raised = review.willRaise.length + cantConfirm.length;
          // With the sections unread the gate cannot know what it would have
          // to raise for them, so it never says "nothing to raise": the list
          // carries a row that says, in words, what it could not read.
          final phase = progressUnread
              ? 'sections-unread'
              : raised == 0
              ? 'clean'
              : 'will-raise';
          return frame(
            phase: phase,
            children: <Widget>[
              Text(
                l10n.submitIntro,
                style: context.skin.text.body.style(
                  color: context.skin.palette.ink2,
                ),
              ),
              const SizedBox(height: TiqSpace.s4),
              _CapturedBlock(
                sectionsDone: progress?.doneCount,
                sectionsTotal: progress?.captureCount,
                line: review.capturedLineIn(l10n),
                unconfirmed: cantConfirm.length,
              ),
              const SizedBox(height: TiqSpace.s7),
              if (raised == 0 && !progressUnread)
                const _NothingToRaise()
              else ...<Widget>[
                // No count beside the rule when part of the list is unknown:
                // a figure there would be a total the gate does not have.
                SectionRule(
                  l10n.submitWillRaiseHeading,
                  count: progressUnread ? null : raised,
                ),
                const SizedBox(height: TiqSpace.s5),
                TorchBleed(
                  extra: context.skin.space.gutter * 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final (i, task) in review.willRaise.indexed)
                        _TaskRow(
                          task: task,
                          last:
                              cantConfirm.isEmpty &&
                              !progressUnread &&
                              i == review.willRaise.length - 1,
                        ),
                      for (final (i, entry) in cantConfirm.indexed)
                        _CantConfirmRow(
                          entry: entry,
                          last: i == cantConfirm.length - 1,
                        ),
                      if (progressUnread) const _SectionsUnreadRow(),
                    ],
                  ),
                ),
                // The whole sentence, off the row: a row caps its lines, and
                // this is the one line on the gate that must not be cut.
                if (progressUnread) ...<Widget>[
                  const SizedBox(height: TiqSpace.s4),
                  Text(
                    l10n.submitSectionsUnreadNote,
                    key: const ValueKey<String>('submit-sections-unread-note'),
                    style: context.skin.text.body.style(
                      color: context.skin.palette.ink2,
                    ),
                  ),
                ],
                if (raised > 0) ...<Widget>[
                  const SizedBox(height: TiqSpace.s4),
                  Text(
                    l10n.submitAccusation(raised),
                    style: context.skin.text.meta.style(
                      color: context.skin.palette.ink3,
                    ),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  /// "Kasi Corner Spaza · 12 min in store".
  String _inStore(AppLocalizations l10n) {
    final start = checkinTs;
    if (start == null) return outletName;
    final minutes = DateTime.now().difference(start).inMinutes;
    if (minutes < 1) return outletName;
    return l10n.submitSubtitleInStore(outletName, minutes);
  }
}

/// A section the app could not establish, as something to raise.
class _CantConfirmEntry {
  const _CantConfirmEntry({required this.section, required this.reason});

  final String section;
  final String reason;
}

/// Every can't-confirm section on this visit, fixed sections then the client's
/// questions. A store that refused four counts is four things to raise.
List<_CantConfirmEntry> _cantConfirmEntries(
  AppLocalizations l10n,
  VisitProgress? progress,
) {
  if (progress == null) return const <_CantConfirmEntry>[];
  return <_CantConfirmEntry>[
    for (final MapEntry(key: section, value: reason)
        in progress.cantConfirm.entries)
      _CantConfirmEntry(
        section: sectionLabel(l10n, section),
        reason: cantConfirmText(l10n, reason),
      ),
    if (progress.templateCantConfirm case final reason?)
      _CantConfirmEntry(
        section: l10n.visitClientQuestions,
        reason: cantConfirmText(l10n, reason),
      ),
  ];
}

/// WHAT WAS CAPTURED — the standalone block above the list.
class _CapturedBlock extends StatelessWidget {
  const _CapturedBlock({
    required this.sectionsDone,
    required this.sectionsTotal,
    required this.line,
    required this.unconfirmed,
  });

  /// Null when the visit's sections could not be read. Never read as zero:
  /// the block then says so in words, with no figure at all.
  final int? sectionsDone;
  final int? sectionsTotal;
  final String line;
  final int unconfirmed;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final done = sectionsDone;
    final total = sectionsTotal;
    final known = done != null && total != null;
    final complete = known
        ? l10n.submitSectionsComplete(done, total)
        : l10n.submitSectionsUnread;

    return Semantics(
      container: true,
      label: known
          ? l10n.submitCapturedSemantics(done, total, line)
          : l10n.submitCapturedUnreadSemantics(line),
      excludeSemantics: true,
      child: Container(
        key: const ValueKey<String>('submit-captured'),
        padding: const EdgeInsets.all(TiqSpace.s4),
        decoration: BoxDecoration(
          color: skin.palette.surface,
          borderRadius: BorderRadius.circular(skin.radii.panel),
          border: Border.all(
            color: skin.palette.edgeStructure,
            width: skin.depth.borderWidth,
          ),
          boxShadow: skin.depth.shadows,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // A tick claims the sections are done. With nothing read, the
                // informational square says only that there is something to
                // know here.
                if (known)
                  const SectionStateGlyph(state: SectionState.done)
                else
                  const RowMarkTile(mark: RowMark.square),
                const SizedBox(width: TiqSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        complete,
                        key: const ValueKey<String>('submit-sections-count'),
                        style: skin.text.titleM.style(color: skin.palette.ink1),
                      ),
                      const SizedBox(height: TiqSpace.s1),
                      Text(
                        line,
                        style: skin.text.meta.style(color: skin.palette.ink2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Two facts, not one figure: a section nobody could establish is
            // not a section somebody skipped, and it is excluded from the
            // readiness count rather than failing it.
            if (unconfirmed > 0) ...<Widget>[
              const SizedBox(height: TiqSpace.s3),
              Row(
                key: const ValueKey<String>('submit-unconfirmed'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SectionStateGlyph(state: SectionState.cantConfirm),
                  const SizedBox(width: TiqSpace.s3),
                  Expanded(
                    child: Text(
                      l10n.submitNotConfirmedLine(unconfirmed),
                      style: skin.text.label.style(color: skin.palette.ink2),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ONE ACCUSATION. The severity is the bar and the silhouette; the priority is
/// always in the word, never carried by the hue alone.
class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.last});

  final RaisedTask task;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = task.titleIn(l10n);
    final line = l10n.submitTaskForManager(l10n.submitPriority(task.priority));

    return SoftRow(
      key: ValueKey<String>('task-$title'),
      title: title,
      subtitle: line,
      leading: SeverityMark(
        kind: task.isUrgent
            ? SeverityMarkKind.critical
            : SeverityMarkKind.watch,
      ),
      severity: task.isUrgent
          ? SoftRowSeverity.critical
          : SoftRowSeverity.watch,
      severityLabel: title,
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      // Severity first, so a reader knows what kind of thing is coming before
      // they hear what it is.
      semanticsLabel: task.isUrgent
          ? l10n.submitTaskSemanticsUrgent(title, line)
          : l10n.submitTaskSemanticsRoutine(title, line),
    );
  }
}

/// A SECTION THE APP COULD NOT ESTABLISH — the row the old gate did not have.
class _CantConfirmRow extends StatelessWidget {
  const _CantConfirmRow({required this.entry, required this.last});

  final _CantConfirmEntry entry;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = l10n.submitCantConfirmTask(entry.section);

    return SoftRow(
      key: ValueKey<String>('cant-confirm-${entry.section}'),
      title: title,
      subtitle: entry.reason,
      // The barred ring, not a hatch and not a severity: nobody did anything
      // wrong, and the manager is told.
      leading: const SectionStateGlyph(state: SectionState.cantConfirm),
      meta: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          l10n.submitCantConfirmTaskLine,
          style: context.skin.text.meta.style(color: context.skin.palette.ink3),
        ),
      ),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: l10n.submitCantConfirmSemantics(
        entry.section,
        entry.reason,
      ),
    );
  }
}

/// THE SECTIONS COULD NOT BE READ — so the list above may be missing a
/// can't-confirm row, and the gate says that rather than implying a clean
/// store. An informational square, not a severity: nothing is known to be
/// wrong, and nothing is known to be right.
class _SectionsUnreadRow extends StatelessWidget {
  const _SectionsUnreadRow();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = l10n.submitSectionsUnreadTask;
    final line = l10n.submitSectionsUnreadRowLine;

    return SoftRow(
      key: const ValueKey<String>('submit-sections-unread'),
      title: title,
      subtitle: line,
      leading: const RowMarkTile(mark: RowMark.square),
      separator: SoftRowSeparator.none,
      semanticsLabel: '$title. $line',
    );
  }
}

/// A CLEAN STORE is a real result, and must not read as an empty screen.
class _NothingToRaise extends StatelessWidget {
  const _NothingToRaise();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;

    return Container(
      key: const ValueKey<String>('submit-clean'),
      padding: const EdgeInsets.all(TiqSpace.s4),
      decoration: BoxDecoration(
        color: skin.palette.surface,
        borderRadius: BorderRadius.circular(skin.radii.panel),
        border: Border.all(color: skin.palette.good, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SeverityMark(kind: SeverityMarkKind.onTarget),
          const SizedBox(width: TiqSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.submitNothingToRaiseHeadline,
                  style: skin.text.titleM.style(color: skin.palette.ink1),
                ),
                const SizedBox(height: TiqSpace.s1),
                Text(
                  l10n.submitNothingToRaise,
                  style: skin.text.body.style(color: skin.palette.ink2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The real geometry, empty. Not a spinner.
class _GateSkeleton extends StatelessWidget {
  const _GateSkeleton();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SkeletonLine(role: skin.text.body, widthFactor: 0.9),
        const SizedBox(height: TiqSpace.s4),
        const SkeletonShell(height: 96, outlined: true),
        const SizedBox(height: TiqSpace.s7),
        const SkeletonRows(count: 3),
      ],
    );
  }
}

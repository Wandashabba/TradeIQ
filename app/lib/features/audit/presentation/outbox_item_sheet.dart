import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/storage/local_db.dart';
import '../../../core/sync/sync_status.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../l10n/l10n.dart';
import '../../outlets/data/outlets_repository.dart';

/// Which of the six outbox states a queued row is in.
///
/// One function, so the row, the sheet and any test all read the same
/// derivation. The order matters: *sent* first because a synced row is
/// finished whatever else is stored on it, then the ordering dependency —
/// which throws and therefore has a `lastError`, but is not a fault and must
/// never be shown as one. Then the ended session, for the same reason: the
/// capture is fine and signing in sends it, so it is **held** — an Oatmeal
/// square and a word, never the crimson stuck state (unify §1.13). A flush
/// in flight does not move it either: with no session it sends nothing.
OutboxState outboxStateFor(SyncItem item, {required bool sending}) {
  if (item.synced) return OutboxState.sent;
  if (item.waitsForVisit) return OutboxState.waitingForVisit;
  if (item.sessionEnded) return OutboxState.queued;
  if (item.needsAttention) return OutboxState.stuck;
  if (sending) return OutboxState.sending;
  // A failure that clears itself — no signal, a 5xx. It is retrying, not
  // stuck, and the difference is the whole point of the two words.
  if (item.lastError != null) return OutboxState.retrying;
  return OutboxState.queued;
}

/// The state in one or two words. Sentence case at the `label` role: unify
/// §1.17 legalises the uppercase eyebrow in three places and a queue row's
/// trailing word is not one of them.
///
/// Pass [item] where there is one: a capture held because the session ended
/// is queued, and its word is "Held" rather than "Waiting".
String outboxStateWord(
  OutboxState state,
  AppLocalizations l10n, {
  SyncItem? item,
}) => switch (state) {
  OutboxState.queued when item?.sessionEnded ?? false => l10n.outboxHeld,
  OutboxState.queued => l10n.outboxWaiting,
  OutboxState.sending => l10n.outboxSending,
  OutboxState.retrying => l10n.outboxRetrying,
  OutboxState.sent => l10n.outboxSent,
  OutboxState.stuck => l10n.outboxNeedsYou,
  OutboxState.waitingForVisit => l10n.outboxWaitingTurn,
};

/// The state as a sentence. For everything that failed, that sentence is the
/// **stored reason**, worded in the agent's language — never a euphemism, and
/// never the raw code.
String outboxSentence(
  SyncItem item,
  OutboxState state,
  AppLocalizations l10n,
) => switch (state) {
  // Not the stored "Signed out — sign in again": that line is a failure's
  // wording, and this capture has not failed. It is held, and says why.
  OutboxState.queued when item.sessionEnded => l10n.outboxHeldUntilSignIn,
  OutboxState.queued => l10n.outboxWaitingSentence,
  OutboxState.sending => l10n.outboxSendingSentence,
  OutboxState.sent => l10n.outboxSentSentence,
  OutboxState.retrying || OutboxState.stuck || OutboxState.waitingForVisit =>
    item.problemIn(l10n) ?? l10n.outboxWaitingSentence,
};

/// "queued 07:58", "last tried 14:20", "sent 08:04".
///
/// The retrying row carries the **last** attempt and not a next-try time: the
/// queue has no scheduler to ask, and a clock time the app invented is worse
/// than one it does not show. An agent standing in a shop reads "last tried
/// 14:20" and knows exactly as much as is true.
String outboxAgeLine(BuildContext context, SyncItem item, OutboxState state) {
  final l10n = context.l10n;
  final attempt = item.lastAttemptAt;
  if (state == OutboxState.sent && attempt != null) {
    return l10n.outboxSentAt(formatClock(context, attempt));
  }
  if ((state == OutboxState.retrying || state == OutboxState.stuck) &&
      attempt != null) {
    return l10n.outboxLastTriedAt(formatClock(context, attempt));
  }
  return l10n.outboxQueuedAt(formatClock(context, item.queuedAt));
}

/// Open the sheet for one queued capture (#376).
///
/// A row never auto-deletes and a stuck row stays until the agent acts, so
/// every stuck row has to offer **something to do**. This is that something:
/// *send this one now*, or *throw it away* with a plain statement of what is
/// lost. There is deliberately no third option that quietly rewrites the
/// payload — a server that refused a body will refuse it again, and repairing
/// it behind the agent's back is the failure the ticket is about.
Future<void> showOutboxItemSheet(
  BuildContext context, {
  required SyncItem item,
  required OutboxState state,
}) => showTorchSheet<void>(
  context,
  settings: const RouteSettings(name: 'outbox-item'),
  builder: (context) => _OutboxItemSheet(item: item, state: state),
);

class _OutboxItemSheet extends ConsumerStatefulWidget {
  const _OutboxItemSheet({required this.item, required this.state});

  final SyncItem item;
  final OutboxState state;

  /// The sheet's one commit. A sheet is an untabbed route, so Night gives it
  /// two content grants and Day and Veld one — and this sheet spends at most
  /// one of them, on whichever single action is the fix.
  static const String fixClaimId = 'outbox-item-fix';

  @override
  ConsumerState<_OutboxItemSheet> createState() => _OutboxItemSheetState();
}

class _OutboxItemSheetState extends ConsumerState<_OutboxItemSheet> {
  bool _confirmingDiscard = false;
  bool _busy = false;

  /// How many other captures go with this one — a visit's sections, photos
  /// and submit. Read before the confirm pane opens, so the statement of what
  /// is lost is never shown without its second half.
  int _dependents = 0;

  SyncItem get _item => widget.item;

  /// Whether sending this exact payload again could possibly work.
  ///
  /// A 413 or a 4xx rejection is the server having *looked* at the body and
  /// said no, so an unchanged retry fails identically and a button offering it
  /// is a button that lies. Everything else — no signal, a 5xx, an ordering
  /// dependency — is worth another try right now.
  bool get _retryable =>
      widget.state != OutboxState.sent &&
      !_item.isRejected &&
      !_item.sessionEnded;

  /// Only a capture that is stuck on its own account. A session that ended is
  /// not the capture's fault — signing in sends it — and throwing work away
  /// because a token expired is the one discard nobody meant. (With no
  /// session the service could not reach the row to remove it anyway.) Such
  /// a capture is derived as held, never stuck; the second clause stays so
  /// the rule holds whatever state a caller passes.
  bool get _discardable =>
      widget.state == OutboxState.stuck && !_item.sessionEnded;

  /// A submitted visit the server has, so there is a score to go and read.
  ///
  /// This is the only way back to a visit's outcome once the agent has walked
  /// out of the shop — and the reconciliation line ("Now scored 71 — it was
  /// 84 when you saw it") only ever appears on a LATER open, so without a way
  /// back it could not appear at all.
  String? get _submittedVisit => widget.state == OutboxState.sent
      ? _item.visitDraftId
      : null;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final label = _item.labelIn(l10n);

    return TorchSheet(
      title: label,
      subtitle: outboxSentence(_item, widget.state, l10n),
      claims: <TorchClaim>[
        if (!_confirmingDiscard && (_retryable || _item.sessionEnded))
          const TorchClaim.primaryCommit(_OutboxItemSheet.fixClaimId),
      ],
      closeLabel: l10n.commonClose,
      child: TorchSheetSwap(
        paneKey: _confirmingDiscard ? 'discard' : 'actions',
        child: _confirmingDiscard
            ? _DiscardPane(
                label: label,
                dependents: _dependents,
                busy: _busy,
                onKeep: () => setState(() => _confirmingDiscard = false),
                onDiscard: _discard,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _Identifier(item: _item),
                  if (_note(l10n) case final String note) ...<Widget>[
                    SizedBox(height: skin.space.intraBlock),
                    Text(
                      note,
                      style: skin.text.body.style(color: skin.palette.ink2),
                    ),
                  ],
                  SizedBox(height: skin.space.blockGap),
                  if (_item.sessionEnded)
                    TorchPrimaryButton(
                      key: const ValueKey<String>('outbox-sign-in'),
                      claimId: _OutboxItemSheet.fixClaimId,
                      label: l10n.myWorkSignIn,
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.go('/login');
                      },
                    )
                  else if (_retryable)
                    TorchPrimaryButton(
                      key: const ValueKey<String>('outbox-send-one'),
                      claimId: _OutboxItemSheet.fixClaimId,
                      label: l10n.outboxSendThisNow,
                      busy: _busy,
                      onPressed: _busy ? null : _sendOne,
                    ),
                  if (_submittedVisit case final String draftId) ...<Widget>[
                    if (_item.sessionEnded || _retryable)
                      const SizedBox(height: TiqSpace.s2),
                    // A ghost, never the amber: reading a score you have
                    // already been shown is not the expected next move.
                    TorchSecondaryButton(
                      key: const ValueKey<String>('outbox-see-score'),
                      label: l10n.outboxSeeScore,
                      onPressed: _busy ? null : () => _openOutcome(draftId),
                    ),
                  ],
                  if (_discardable) ...<Widget>[
                    const SizedBox(height: TiqSpace.s2),
                    TorchTertiaryButton(
                      key: const ValueKey<String>('outbox-discard'),
                      label: l10n.outboxDiscard,
                      destructive: true,
                      onPressed: _busy ? null : _askToDiscard,
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  /// The one extra sentence a state needs, or nothing.
  String? _note(AppLocalizations l10n) => switch (widget.state) {
    OutboxState.sent => l10n.outboxNothingToDo,
    OutboxState.waitingForVisit => l10n.outboxWaitingTurnNote,
    _ when _item.sessionEnded => l10n.outboxSignedOutNote,
    OutboxState.stuck when _item.isRejected => l10n.outboxRejectedNote,
    _ => null,
  };

  /// Open this visit's outcome, read-only as far as the visit is concerned —
  /// a submitted visit is closed, and this route has always been forward-only.
  Future<void> _openOutcome(String draftId) async {
    final db = ref.read(localDbProvider);
    final draft = await (db.select(
      db.visitDrafts,
    )..where((t) => t.id.equals(draftId))).getSingleOrNull();
    if (!mounted) return;
    final outletId = draft?.outletId;
    if (outletId == null) return;

    // The outlet's NAME only if the list is already in memory. Opening a
    // score must not send a phone in a shop after an outlet list, and the
    // route already has a fallback for the header.
    String? name;
    if (ref.exists(outletsListProvider)) {
      for (final outlet in ref.read(outletsListProvider).value ?? const []) {
        if (outlet.id == outletId) {
          name = outlet.name;
          break;
        }
      }
    }

    final query = StringBuffer('draft=${Uri.encodeComponent(draftId)}');
    if (name != null) query.write('&name=${Uri.encodeComponent(name)}');
    Navigator.of(context).pop();
    context.go('/audit/${Uri.encodeComponent(outletId)}/done?$query');
  }

  Future<void> _sendOne() async {
    setState(() => _busy = true);
    await ref.read(sendOneProvider)(_item.id);
    if (!mounted) return;
    // The stream has already moved the row into its new group behind the
    // sheet. Closing is the honest end of the action: re-rendering this sheet
    // from a stale snapshot would show the old state next to a fresh result.
    Navigator.of(context).pop();
  }

  Future<void> _askToDiscard() async {
    setState(() => _busy = true);
    final dependents = await ref.read(discardDependentsProvider)(_item.id);
    if (!mounted) return;
    setState(() {
      _dependents = dependents;
      _busy = false;
      _confirmingDiscard = true;
    });
  }

  Future<void> _discard() async {
    setState(() => _busy = true);
    await ref.read(discardCaptureProvider)(_item.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

/// What the support desk needs, in mono, and nothing a support desk does not.
class _Identifier extends StatelessWidget {
  const _Identifier({required this.item});

  final SyncItem item;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: skin.palette.well,
        borderRadius: BorderRadius.circular(skin.radii.chip),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: TiqSpace.s3,
        vertical: TiqSpace.s3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.outboxItemId(item.id, item.entityType),
            style: skin.text.monoIdent.style(color: skin.palette.ink3),
          ),
          const SizedBox(height: TiqSpace.s1),
          Text(
            l10n.outboxAttempts(item.attempts),
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
        ],
      ),
    );
  }
}

/// The second step. Never a second sheet — the ruling forbids stacking, so the
/// same sheet cross-fades to the confirmation and back.
class _DiscardPane extends StatelessWidget {
  const _DiscardPane({
    required this.label,
    required this.dependents,
    required this.busy,
    required this.onKeep,
    required this.onDiscard,
  });

  final String label;

  /// Captures that go with this one because they cannot send without it.
  final int dependents;
  final bool busy;
  final VoidCallback onKeep;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // What is lost, said plainly and before anything happens. #376 is
        // explicit that a capture never leaves the phone on a euphemism.
        Text(
          l10n.outboxDiscardWhatIsLost(label),
          style: skin.text.body.style(color: skin.palette.ink1),
        ),
        if (dependents > 0) ...<Widget>[
          SizedBox(height: skin.space.intraBlock),
          Text(
            key: const ValueKey<String>('outbox-discard-dependents'),
            l10n.outboxDiscardTakesDependents(dependents),
            style: skin.text.body.style(color: skin.palette.ink1),
          ),
        ],
        SizedBox(height: skin.space.blockGap),
        TorchDestructiveButton.confirming(
          key: const ValueKey<String>('outbox-discard-confirm'),
          label: l10n.outboxDiscardConfirm,
          busy: busy,
          onPressed: busy ? null : onDiscard,
        ),
        const SizedBox(height: TiqSpace.s2),
        TorchSecondaryButton(
          key: const ValueKey<String>('outbox-discard-keep'),
          label: l10n.outboxDiscardKeep,
          onPressed: busy ? null : onKeep,
        ),
      ],
    );
  }
}

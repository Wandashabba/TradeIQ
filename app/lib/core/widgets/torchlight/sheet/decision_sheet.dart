import 'package:flutter/widgets.dart';

import '../../../design/torch_scope.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import '../button/buttons.dart';
import 'proof_block.dart';
import 'torch_sheet.dart';

/// CARRY ON, OR START OVER — #374.
///
/// The one component for every moment where work already exists and the user
/// is about to do something that touches it: resuming an interrupted visit,
/// leaving a form with unsaved changes, discarding a stuck item. Three
/// products of the same shape, and the shape is **evidence first, then two
/// unequal actions**.
///
/// ```dart
/// showTorchSheet<DecisionOutcome>(
///   context,
///   dismissible: false,
///   builder: (context) => DecisionSheet(
///     title: 'You have work here already',
///     proof: [
///       ProofLine(text: '6 of 9 sections captured'),
///       ProofLine(text: '3 photos held on this phone'),
///       ProofLine(text: 'Started 11:04, 41 minutes ago', state: SectionState.inProgress),
///     ],
///     carryOnLabel: 'Carry on from 11:04',
///     startOverCost: 'Loses 6 sections and 3 photos',
///   ),
/// );
/// ```
///
/// ## A sheet, not a dialog, and the safe action is on top
///
/// A centred dialog with two equal buttons is exactly how a destructive choice
/// gets tapped by accident. Here the safe action sits in the thumb's easiest
/// reach; the destructive one sits below it with its cost stated in words; and
/// the **bottom-most** control is a tertiary Close, because a control that
/// throws work away must never be the last thing under a thumb that is already
/// travelling.
///
/// ## Start over is two steps, in one sheet
///
/// Pressing it **cross-fades this sheet's own content** to a second pane
/// naming the consequence — never a second sheet, never a typed confirmation
/// (too much friction in a shop). Two taps and a named cost. Unify §1.21 drops
/// the undo toast that an earlier draft put after the destruction: the two-step
/// is the guard, and an undo that follows a guard teaches people to ignore the
/// guard.
///
/// ## The stale branch
///
/// A check-in older than twelve hours is not evidence of being *here now*, so
/// `Carry on` demotes to a ghost and `Check in again` becomes the primary. The
/// captured work is preserved and re-attached to the new check-in — nothing is
/// destroyed by a stale fix.
enum DecisionOutcome {
  /// The safe path. Scrim, back gesture and Close all map here.
  carryOn,

  /// Confirmed, at the second step.
  startOver,

  /// The stale branch's primary.
  checkInAgain,
}

class DecisionSheet extends StatefulWidget {
  const DecisionSheet({
    super.key,
    required this.title,
    required this.proof,
    this.counting = false,
    this.carryOnLabel = 'Carry on',
    this.startOverLabel = 'Start over',
    this.startOverCost,
    this.confirmLabel = 'Delete and start over',
    this.keepLabel = 'Keep it',
    this.closeLabel = 'Not now',
    this.stale = false,
    this.checkInAgainLabel = 'Check in again',
    this.countingNote = 'Checking what you have here',
    this.consequence,
  });

  final String title;

  /// What exists, in countable terms. Empty means there is nothing to lose —
  /// and then **the sheet should not have been opened at all**; the caller
  /// proceeds instead. Asserted in debug.
  final List<ProofLine> proof;

  /// The figures are still resolving. Both actions are busy-disabled and a
  /// `BarNote` says why: neither choice may be made until the cost is known.
  final bool counting;

  /// "Carry on from 11:04" — the time is the evidence, so put it in the label.
  final String carryOnLabel;

  final String startOverLabel;

  /// The exact cost, at `meta` beneath the destructive action. Never "this
  /// cannot be undone" — a number is a consequence and a warning is a mood.
  final String? startOverCost;

  final String confirmLabel;
  final String keepLabel;
  final String closeLabel;

  /// The check-in is more than twelve hours old.
  final bool stale;
  final String checkInAgainLabel;

  final String countingNote;

  /// The second pane's sentence. Defaults to a line built from
  /// [startOverCost].
  final String? consequence;

  @override
  State<DecisionSheet> createState() => _DecisionSheetState();
}

class _DecisionSheetState extends State<DecisionSheet> {
  bool _confirming = false;

  void _pop(DecisionOutcome outcome) =>
      Navigator.of(context).pop<DecisionOutcome>(outcome);

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    assert(
      widget.proof.isNotEmpty || widget.counting,
      'A decision sheet with nothing in its proof block is a sheet asking a '
      'person to weigh nothing. Where there is nothing to lose, do not open '
      'it — proceed.',
    );

    final busy = widget.counting;

    return TorchSheet(
      title: widget.title,
      // A sheet is an untabbed route: two grants in Night, one on a light
      // ground. This one spends exactly one, on the safe path.
      claims: <TorchClaim>[
        TorchPrimaryButton.claim(
          widget.stale ? 'check-in-again' : 'carry-on',
        ),
      ],
      child: TorchSheetSwap(
        paneKey: _confirming ? 'confirm' : 'decide',
        child: _confirming ? _confirmPane(skin) : _decidePane(skin, busy),
      ),
    );
  }

  Widget _decidePane(TiqSkin skin, bool busy) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      ProofBlock(lines: widget.proof, counting: widget.counting),
      SizedBox(height: skin.space.blockGap),
      if (widget.stale) ...<Widget>[
        // A geofence fix from yesterday is not evidence of being here now.
        TorchPrimaryButton(
          label: widget.checkInAgainLabel,
          claimId: 'check-in-again',
          busy: busy,
          onPressed: busy ? null : () => _pop(DecisionOutcome.checkInAgain),
        ),
        const SizedBox(height: TiqSpace.s3),
        TorchSecondaryButton(
          label: widget.carryOnLabel,
          onPressed: busy ? null : () => _pop(DecisionOutcome.carryOn),
        ),
      ] else
        TorchPrimaryButton(
          label: widget.carryOnLabel,
          claimId: 'carry-on',
          busy: busy,
          onPressed: busy ? null : () => _pop(DecisionOutcome.carryOn),
        ),
      const SizedBox(height: TiqSpace.s3),
      TorchDestructiveButton(
        label: widget.startOverLabel,
        // The note sits between the two actions while the cost is being
        // counted, because it is about BOTH of them: neither choice may be
        // made until the cost is known. The safe action shows its busy dots;
        // this one shows the sentence.
        blockedReason: busy ? widget.countingNote : null,
        onPressed: busy ? null : () => setState(() => _confirming = true),
      ),
      if (widget.startOverCost != null) ...<Widget>[
        const SizedBox(height: TiqSpace.s2),
        Text(
          widget.startOverCost!,
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
      ],
      SizedBox(height: skin.space.intraBlock),
      // The bottom-most control is never the destructive one.
      Align(
        alignment: Alignment.centerLeft,
        child: TorchTertiaryButton(
          label: widget.closeLabel,
          onPressed: () => _pop(DecisionOutcome.carryOn),
        ),
      ),
    ],
  );

  Widget _confirmPane(TiqSkin skin) {
    final sentence =
        widget.consequence ??
        '${widget.startOverCost ?? 'This deletes the work on this phone'}. '
            'It has not been sent.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          liveRegion: true,
          child: Text(
            sentence,
            style: skin.text.body.style(color: skin.palette.ink1),
          ),
        ),
        SizedBox(height: skin.space.blockGap),
        // Solid only as a sheet's confirming press — the second step, never
        // the first, and never amber in any state.
        TorchDestructiveButton.confirming(
          label: widget.confirmLabel,
          onPressed: () => _pop(DecisionOutcome.startOver),
        ),
        const SizedBox(height: TiqSpace.s3),
        TorchSecondaryButton(
          label: widget.keepLabel,
          onPressed: () => setState(() => _confirming = false),
        ),
      ],
    );
  }
}

/// THE MANAGER'S CONFIRM SHEET — an instance of the same anatomy (unify
/// §1.21).
///
/// One step back before an irreversible console action: the action as a
/// sentence, up to three consequence lines, the affected record in
/// `mono.ident` on a `well` block, then the destructive commit and a ghost
/// Cancel.
///
/// The destructive commit is the **upper** of the two controls and Cancel is
/// beneath it. That is the same rule the decision sheet obeys, stated from the
/// other side: **the bottom-most control under a travelling thumb is never the
/// one that destroys something.** In the decision sheet the safe action is on
/// top because a tertiary Close is at the bottom; here there are only two, so
/// Cancel takes the bottom.
class ConfirmSheet extends StatelessWidget {
  const ConfirmSheet({
    super.key,
    required this.action,
    required this.consequences,
    required this.commitLabel,
    this.record,
    this.cancelLabel = 'Cancel',
    this.busy = false,
    this.failure,
  });

  /// The action as a sentence, at `title.l`, max two lines.
  final String action;

  /// What will happen, each behind a square bullet.
  final List<String> consequences;

  final String commitLabel;

  /// The affected record — an outlet code, a visit id — in `mono.ident` on a
  /// `well` block, so the person can check they are destroying the right one.
  final String? record;

  final String cancelLabel;

  /// Busy dots on the commit, Cancel disabled.
  final bool busy;

  /// The sheet **stays open** on a failure, with the reason above the buttons.
  final Widget? failure;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    // In `build` because `List.length` is not a constant expression in Dart,
    // and a const-constructed sheet is the common case.
    assert(
      consequences.length <= 3,
      'Three consequences is the most a person reads before a destructive '
      'press. A fourth belongs in the screen this sheet was opened from.',
    );
    return TorchSheet(
      title: action,
      // A destructive confirm is severity, and severity never touches amber.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final line in consequences)
            Padding(
              padding: const EdgeInsets.only(bottom: TiqSpace.s2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: SizedBox.square(
                      dimension: 6,
                      child: ColoredBox(color: p.ink3),
                    ),
                  ),
                  const SizedBox(width: TiqSpace.s3),
                  Expanded(
                    child: Text(
                      line,
                      style: skin.text.body.style(color: p.ink2),
                    ),
                  ),
                ],
              ),
            ),
          if (record != null) ...<Widget>[
            const SizedBox(height: TiqSpace.s2),
            Container(
              decoration: BoxDecoration(
                color: p.well,
                borderRadius: BorderRadius.circular(skin.radii.chip),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: TiqSpace.s3,
                vertical: TiqSpace.s2,
              ),
              child: Text(
                record!,
                style: skin.text.monoIdent.style(color: p.ink3),
              ),
            ),
          ],
          if (failure != null) ...<Widget>[
            SizedBox(height: skin.space.intraBlock),
            failure!,
          ],
          SizedBox(height: skin.space.blockGap),
          TorchDestructiveButton.confirming(
            label: commitLabel,
            busy: busy,
            onPressed: busy ? null : () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: TiqSpace.s2),
          TorchSecondaryButton(
            label: cancelLabel,
            onPressed: busy ? null : () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

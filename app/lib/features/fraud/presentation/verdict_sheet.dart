import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tiq_number.dart';
import '../../../l10n/l10n.dart';
import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../data/fraud_repository.dart';
import '../data/fraud_view.dart';
import 'fraud_screen.dart' show standingSentence;

/// The verdict control's claim id, declared by the sheet that carries it.
const String kVerdictClaimId = 'record-verdict';

/// RULING ON ONE FLAGGED VISIT (#392).
///
/// The one modal container, carrying the evidence and then the decision. A
/// sheet rather than a route because the queue behind it is the context: the
/// scrim is 72% and the row this is about stays visible, which is the same
/// argument #380 made about held work.
///
/// **Ruled once.** The verdict is INSERTed against a unique `visit_id`, so a
/// second reviewer is answered 409 with the ruling that stands, and the sheet
/// prints whose decision applies instead of letting them believe theirs did.
Future<void> showVerdictSheet(
  BuildContext context,
  WidgetRef ref, {
  required FraudRow row,
  required VoidCallback onRuled,
}) {
  return showTorchSheet<void>(
    context,
    builder: (sheetContext) => _VerdictSheet(row: row, onRuled: onRuled),
  );
}

class _VerdictSheet extends ConsumerStatefulWidget {
  const _VerdictSheet({required this.row, required this.onRuled});

  final FraudRow row;
  final VoidCallback onRuled;

  @override
  ConsumerState<_VerdictSheet> createState() => _VerdictSheetState();
}

class _VerdictSheetState extends ConsumerState<_VerdictSheet> {
  bool _busy = false;
  String? _error;

  /// The ruling that ended up standing — either the one just recorded, or the
  /// one a colleague got in first with.
  FraudVerdict? _standing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final row = widget.row;
    final skin = context.skin;
    final numbers = TiqNumber.of(context);
    final standing = _standing ?? row.verdict;
    final score = numbers.format(row.riskScore, decimals: 0);

    return TorchSheet(
      title: row.agentName ?? l10n.fraudUnknownAgent,
      subtitle: l10n.fraudSheetSubtitle(
        row.outletLabel(l10n),
        score,
        row.band.word(l10n),
      ),
      // An untabbed route: Night grants two and this spends one on the commit.
      // While it is up, every amber on the queue beneath goes out.
      claims: standing == null
          ? const <TorchClaim>[TorchClaim.primaryCommit(kVerdictClaimId)]
          : const <TorchClaim>[],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SectionRule(l10n.fraudWhatEngineFound),
          const SizedBox(height: TiqSpace.s3),
          if (row.signals.isEmpty)
            EmptyState(
              key: const ValueKey<String>('verdict-no-signals'),
              scope: EmptyScope.inline,
              headline: l10n.fraudNoSignalsHeadline,
              body: l10n.fraudNoSignalsBody,
            )
          else
            for (final signal in row.signals)
              Padding(
                padding: const EdgeInsets.only(bottom: TiqSpace.s3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      signal.code,
                      style: skin.text.monoIdent.style(
                        color: skin.palette.ink2,
                      ),
                    ),
                    const SizedBox(height: TiqSpace.s1),
                    Text(
                      signal.detail,
                      style: skin.text.body.style(color: skin.palette.ink1),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: TiqSpace.s6),
          if (standing != null)
            _Standing(verdict: standing, numbers: numbers)
          else
            VerdictControl<FraudVerdictKind>(
              key: const ValueKey<String>('verdict-control'),
              label: l10n.fraudYourRuling,
              claimId: kVerdictClaimId,
              commitLabel: l10n.fraudRecordThisRuling,
              busy: _busy,
              error: _error,
              noteLabel: l10n.fraudNoteLabel,
              noteHint: l10n.fraudNoteHint,
              noteHelp: l10n.fraudNoteHelp,
              notChosenLine: l10n.fraudNotChosenLine,
              chooseFirstReason: l10n.fraudChooseFirst,
              options: <VerdictOption<FraudVerdictKind>>[
                VerdictOption<FraudVerdictKind>(
                  value: FraudVerdictKind.cleared,
                  label: l10n.fraudVerdictCleared,
                  consequence: l10n.fraudConsequenceCleared,
                ),
                VerdictOption<FraudVerdictKind>(
                  value: FraudVerdictKind.confirmed,
                  label: l10n.fraudVerdictConfirmed,
                  consequence: l10n.fraudConsequenceConfirmed,
                ),
                VerdictOption<FraudVerdictKind>(
                  value: FraudVerdictKind.needsEvidence,
                  label: l10n.fraudVerdictNeedsEvidence,
                  consequence: l10n.fraudConsequenceNeedsEvidence,
                  requiresNote: true,
                  noteIsRequiredBecause: l10n.fraudNeedsEvidenceNoteBecause,
                ),
              ],
              onCommit: _record,
            ),
          const SizedBox(height: TiqSpace.s5),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchTertiaryButton(
              key: const ValueKey<String>('verdict-close'),
              label: standing == null ? l10n.fraudNotNow : l10n.fraudClose,
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _record(FraudVerdictKind kind, String? note) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final recorded = await ref
          .read(fraudRepositoryProvider)
          .recordVerdict(
            visitId: widget.row.visitId,
            kind: kind,
            note: note,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _standing = recorded;
      });
      widget.onRuled();
    } on FraudVerdictConflict catch (conflict) {
      // Somebody else got there first. Their ruling is what applies, so it
      // replaces the control rather than sitting above a button that would
      // lose again.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _standing = conflict.standing;
      });
      widget.onRuled();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = TorchErrorMessage.sanitise(error).headline;
      });
    }
  }
}

/// The ruling that stands: who, what, when, on what number, and their note.
class _Standing extends StatelessWidget {
  const _Standing({required this.verdict, required this.numbers});

  final FraudVerdict verdict;
  final TiqNumber numbers;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final at = verdict.riskScoreAtReview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule(l10n.fraudRulingStands),
        const SizedBox(height: TiqSpace.s3),
        Text(
          // The queue's own sentence, so the sheet and the row behind it
          // cannot describe one ruling two ways. It carries the score the
          // reviewer saw; the line beneath says what a rescore does to it.
          standingSentence(l10n, verdict, numbers),
          key: const ValueKey<String>('verdict-standing'),
          style: skin.text.bodyStrong.style(color: skin.palette.ink1),
        ),
        const SizedBox(height: TiqSpace.s2),
        Text(
          at == null
              ? l10n.fraudStandingUnscored
              : l10n.fraudStandingAtRisk(numbers.format(at)),
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
        if (verdict.note != null && verdict.note!.isNotEmpty) ...<Widget>[
          const SizedBox(height: TiqSpace.s4),
          Text(
            verdict.note!,
            key: const ValueKey<String>('verdict-standing-note'),
            style: skin.text.body.style(color: skin.palette.ink1),
          ),
        ],
        const SizedBox(height: TiqSpace.s4),
        Text(
          l10n.fraudRuledOnce,
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
      ],
    );
  }
}

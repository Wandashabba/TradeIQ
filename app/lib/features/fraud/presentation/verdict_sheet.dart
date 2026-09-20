import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../data/fraud_repository.dart';
import '../data/fraud_view.dart';

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
    final row = widget.row;
    final skin = context.skin;
    final numbers = TiqNumber.of(context);
    final standing = _standing ?? row.verdict;
    final score = numbers.format(row.riskScore, decimals: 0);

    return TorchSheet(
      title: row.agentName ?? FraudView.unknownAgent,
      subtitle: '${row.outletName} · risk $score of 100 · ${row.band.word}',
      // An untabbed route: Night grants two and this spends one on the commit.
      // While it is up, every amber on the queue beneath goes out.
      claims: standing == null
          ? const <TorchClaim>[TorchClaim.primaryCommit(kVerdictClaimId)]
          : const <TorchClaim>[],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SectionRule('What the engine found'),
          const SizedBox(height: TiqSpace.s3),
          if (row.signals.isEmpty)
            const EmptyState(
              key: ValueKey<String>('verdict-no-signals'),
              scope: EmptyScope.inline,
              headline: 'No signals recorded.',
              body:
                  'The visit scored above the threshold but the rules that '
                  'fired were not stored with it. Open the visit to judge it '
                  'on its own record.',
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
              label: 'Your ruling',
              claimId: kVerdictClaimId,
              commitLabel: 'Record this ruling',
              busy: _busy,
              error: _error,
              noteLabel: 'Note',
              noteHint: 'What you checked, and what you found',
              noteHelp:
                  'Whoever reads this decision next sees only what you '
                  'write here.',
              notChosenLine: 'No ruling chosen yet',
              chooseFirstReason: 'Choose a ruling first.',
              options: const <VerdictOption<FraudVerdictKind>>[
                VerdictOption<FraudVerdictKind>(
                  value: FraudVerdictKind.cleared,
                  label: 'Cleared',
                  consequence:
                      'The visit stands and leaves the queue. The '
                      'agent keeps its points.',
                ),
                VerdictOption<FraudVerdictKind>(
                  value: FraudVerdictKind.confirmed,
                  label: 'Confirmed',
                  consequence:
                      'The work is recorded as faked. This is the '
                      'one ruling that accuses a person.',
                ),
                VerdictOption<FraudVerdictKind>(
                  value: FraudVerdictKind.needsEvidence,
                  label: 'Needs evidence',
                  consequence:
                      'Nobody can tell yet. It leaves the open queue '
                      'and the note is what somebody works from.',
                  requiresNote: true,
                  noteIsRequiredBecause:
                      'Say what evidence is missing, so somebody can go and '
                      'get it. "Needs evidence" with no note is a visit that '
                      'was processed rather than reviewed.',
                ),
              ],
              onCommit: _record,
            ),
          const SizedBox(height: TiqSpace.s5),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchTertiaryButton(
              key: const ValueKey<String>('verdict-close'),
              label: standing == null ? 'Not now' : 'Close',
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
          .recordVerdict(visitId: widget.row.visitId, kind: kind, note: note);
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
    final skin = context.skin;
    final at = verdict.riskScoreAtReview;
    final who = verdict.reviewerLabel.isEmpty
        ? 'A reviewer'
        : verdict.reviewerLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SectionRule('The ruling that stands'),
        const SizedBox(height: TiqSpace.s3),
        Text(
          '$who ruled it ${_word(verdict.kind).toLowerCase()}.',
          key: const ValueKey<String>('verdict-standing'),
          style: skin.text.bodyStrong.style(color: skin.palette.ink1),
        ),
        const SizedBox(height: TiqSpace.s2),
        Text(
          at == null
              ? 'The visit was unscored at the time, so there is no number '
                    'behind this decision.'
              : 'They were looking at risk ${numbers.format(at)} of 100. A '
                    'rescore since then does not move the ruling.',
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
          'A visit is ruled once. Reopening it is a change to the record and '
          'is not done from here.',
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
      ],
    );
  }

  static String _word(FraudVerdictKind kind) => switch (kind) {
    FraudVerdictKind.cleared => 'Cleared',
    FraudVerdictKind.confirmed => 'Confirmed',
    FraudVerdictKind.needsEvidence => 'Needs evidence',
  };
}

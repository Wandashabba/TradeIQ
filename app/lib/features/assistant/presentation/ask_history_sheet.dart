import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../l10n/l10n.dart';
import '../data/chat_controller.dart';

/// The id the start-over sheet's safe action is lit under. Rung 1.
const String askStartOverClaimId = 'ask-carry-on';

/// THE CONVERSATION HISTORY SHEET.
///
/// To get back to a question asked ten minutes ago, to be honest that this is
/// a **session rather than an archive**, and — since the header carries no
/// New button — to be where starting over begins.
///
/// There is no delete, no rename and no pin, because none exist server-side
/// and offering them would promise a persistence the product does not have.
/// The subtitle says exactly that, and it says the real replay limit too: a
/// follow-up to a question twenty-one turns back is a follow-up the model
/// will not have.
class AskHistorySheet extends ConsumerWidget {
  const AskHistorySheet({
    super.key,
    required this.onGoToTurn,
    required this.onStartOver,
  });

  /// Closes the sheet and scrolls the transcript to that question.
  final ValueChanged<int> onGoToTurn;

  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = context.skin;
    final l10n = context.l10n;
    final state = ref.watch(chatControllerProvider);
    final questions = <(int, ChatMessage)>[
      for (var i = 0; i < state.messages.length; i++)
        if (state.messages[i].role == ChatRole.user) (i, state.messages[i]),
    ];

    return TorchSheet(
      title: l10n.askHistoryTitle,
      subtitle: <String>[
        l10n.askHistorySubtitle(questions.length),
        if (questions.length > ChatController.historyLimit)
          l10n.askHistoryLimit(ChatController.historyLimit),
      ].join(' · '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (questions.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: skin.space.blockGap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    l10n.askHistoryEmpty,
                    style: skin.text.body.style(color: skin.palette.ink2),
                  ),
                  const SizedBox(height: TiqSpace.s1),
                  Text(
                    l10n.askHistoryEmptyBody,
                    style: skin.text.meta.style(color: skin.palette.ink3),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < questions.length; i++)
              _HistoryRow(
                key: ValueKey<String>('ask-history-$i'),
                message: questions[i].$2,
                // A turn still being answered shows "now" in place of a time.
                live: state.sending && i == questions.length - 1,
                last: i == questions.length - 1,
                onTap: () => onGoToTurn(questions[i].$1),
              ),
          // Starting over lives here, next to the sentence that names its
          // consequence — not in the top-right corner 8dp from another 48dp
          // target, which is the worst reachable point on a 6.5in phone.
          if (questions.isNotEmpty) ...<Widget>[
            SizedBox(height: skin.space.blockGap),
            SoftRow(
              key: const ValueKey<String>('ask-start-over-row'),
              density: SoftRowDensity.compact,
              title: l10n.askStartOver,
              leading: Icon(Icons.add, size: 16, color: skin.palette.ink2),
              separator: SoftRowSeparator.none,
              onTap: onStartOver,
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    super.key,
    required this.message,
    required this.live,
    required this.last,
    required this.onTap,
  });

  final ChatMessage message;
  final bool live;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final at = message.askedAt;
    final time = live
        ? l10n.askNow
        : (at == null
              ? ''
              : '${at.hour.toString().padLeft(2, '0')}:'
                    '${at.minute.toString().padLeft(2, '0')}');

    return SoftRow(
      density: SoftRowDensity.standard,
      leading: SizedBox(
        width: 48,
        child: Text(
          time,
          style: skin.text.monoIdent.style(color: skin.palette.ink3),
        ),
      ),
      title: message.text,
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: l10n.askHistoryRowSemantic(time, message.text),
      onTap: onTap,
    );
  }
}

/// START OVER — carry on, or lose the session. Asked once, with the
/// consequence named.
///
/// **Carry on is the primary**, because carrying on is the expected next move;
/// the destructive option is never the lit one. Dismissing the sheet is
/// equivalent to Carry on, so the destructive path is never the default
/// outcome of an accidental gesture.
///
/// Amber: exactly one — the safe action's rim in Night, its block in Day and
/// Veld. The nav pill is hidden and inert beneath the sheet, so its tab
/// contributes nothing to the count.
class AskStartOverSheet extends StatelessWidget {
  const AskStartOverSheet({
    super.key,
    required this.questions,
    required this.midTurn,
    required this.onCarryOn,
    required this.onStartOver,
  });

  final int questions;

  /// A question is still being answered. Different words, same shape.
  final bool midTurn;

  final VoidCallback onCarryOn;
  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;

    return TorchSheet(
      title: midTurn ? l10n.askStartOverMidTurnTitle : l10n.askStartOverTitle,
      claims: const <TorchClaim>[TorchClaim.primaryCommit(askStartOverClaimId)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            midTurn
                ? l10n.askStartOverMidTurnBody
                : l10n.askStartOverBody(questions),
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
          SizedBox(height: skin.space.blockGap),
          TorchPrimaryButton(
            claimId: askStartOverClaimId,
            label: midTurn ? l10n.askKeepWaiting : l10n.askCarryOn,
            onPressed: onCarryOn,
          ),
          const SizedBox(height: TiqSpace.s3),
          // Never side by side at any width: a destructive choice and a safe
          // one adjacent to a moving thumb is a design that gets people wrong.
          TorchSecondaryButton(
            label: midTurn
                ? l10n.askStopAndStartOver
                : l10n.askStartOverConfirm,
            onPressed: onStartOver,
          ),
        ],
      ),
    );
  }
}

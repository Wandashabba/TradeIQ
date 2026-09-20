import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/mark/tiq_mark.dart';
import '../../../l10n/l10n.dart';
import '../data/assistant_events.dart';

/// "THIS ANSWER MAY BE INCOMPLETE."
///
/// The turn ran out of lookups or time. It is a **component**, not a
/// paragraph the model appears to have written: without lifting it out, the
/// notice arrives as a trailing sentence below the follow-ups fence, in the
/// assistant's own voice, which reads as an apology rather than as the product
/// explaining itself.
///
/// ## Not a severity, and not the brand colour
///
/// The block takes **comparison plus a square plus the words** — the system's
/// declared "held" grammar. The answer is held short, not wrong. Giving it
/// amber would teach a manager that a thin answer is a warning; giving it
/// crimson would teach her it is a failure. It is neither: the assistant did
/// what it could inside a budget and said so.
class AnswerNotice extends StatelessWidget {
  const AnswerNotice({super.key, required this.notice});

  final NoticeEvent notice;

  /// The reason, in the reader's own language.
  ///
  /// The wire's `message` is the server's English and is deliberately not
  /// rendered: this notice is read by managers whose phones are set to
  /// Afrikaans, and the code is exactly what makes a translation possible. An
  /// unknown code still gets a true sentence.
  static String reasonFor(AppLocalizations l10n, AnswerNoticeCode code) =>
      switch (code) {
        AnswerNoticeCode.lookupBudget => l10n.askNoticeLookupBudget,
        AnswerNoticeCode.timeBudget => l10n.askNoticeTimeBudget,
        AnswerNoticeCode.toolCallRefused => l10n.askNoticeToolCallRefused,
        AnswerNoticeCode.unknown => l10n.askNoticeGeneral,
      };

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final p = skin.palette;
    final veld = skin.mode == SkinMode.veld;
    final reason = reasonFor(l10n, notice.code);

    return Semantics(
      container: true,
      label: l10n.askNoticeSemantic(reason, l10n.askNoticeNarrower),
      excludeSemantics: true,
      child: Container(
        key: const ValueKey<String>('answer-notice'),
        constraints: BoxConstraints(minHeight: skin.space.rowMinHeight),
        decoration: BoxDecoration(
          // Recessed: a caveat sits below the answer, not above it.
          color: veld ? p.ground : p.well,
          borderRadius: BorderRadius.circular(skin.radii.control),
          border: veld
              ? Border.all(color: p.ink1, width: skin.depth.borderWidth)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // A 3dp left bar, full height. Three channels carry "held": the
            // bar, the square, and the words.
            SizedBox(
              width: veld ? 4 : 3,
              child: ColoredBox(color: veld ? p.ink1 : p.comparison),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TiqSpace.s3,
                  vertical: TiqSpace.s3 + 2,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: TiqSpace.s1),
                      child: TiqMark(
                        shape: MarkShape.heldSquare,
                        color: veld ? p.ink1 : p.comparison,
                        size: MarkScale.glyph(context, 9),
                      ),
                    ),
                    const SizedBox(width: TiqSpace.s3 - 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            reason,
                            style: skin.text.body.style(color: p.ink1),
                          ),
                          const SizedBox(height: TiqSpace.s1),
                          Text(
                            l10n.askNoticeNarrower,
                            style: skin.text.meta.style(color: p.ink3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The server drew something this app build cannot render.
///
/// A normal consequence of shipping the backend and the app on separate
/// release trains — not an error, and never a blank card. No fill, no border,
/// no radius: inside the panel it needs none, and giving it one would make a
/// limitation look like a card of content.
class UnsupportedArtifactNote extends StatelessWidget {
  const UnsupportedArtifactNote({super.key, required this.type});

  /// The spec type, verbatim. A diagnostic for a support call, and excluded
  /// from the spoken label — it is not information for a manager.
  final String type;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final p = skin.palette;

    return Semantics(
      label: l10n.askUnsupportedView,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: TiqSpace.s3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.info_outline,
              size: MarkScale.glyph(context, 16),
              color: p.ink3,
            ),
            const SizedBox(width: TiqSpace.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    l10n.askUnsupportedView,
                    style: skin.text.body.style(color: p.ink2),
                  ),
                  const SizedBox(height: TiqSpace.s1),
                  Text(
                    type,
                    style: skin.text.monoIdent.style(color: p.ink3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Why a web-touched turn's figures are not shown.
///
/// Dull, and correct. The rule is in `InstrumentPanel`: a turn that ran a web
/// tool and carries an untagged figure renders **no** figure artifacts at all.
/// The prose stands, and this line sits where the panel would have been.
///
/// It is announced as part of the answer and never as an error: a blind
/// manager gets exactly the sighted one's information, which is that there are
/// no figures and why.
class UnprovenancedFiguresNote extends StatelessWidget {
  const UnprovenancedFiguresNote({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Text(
      context.l10n.askUnprovenancedFigures,
      key: const ValueKey<String>('unprovenanced-figures'),
      style: skin.text.meta.style(color: skin.palette.ink3),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart' show Icons, SelectionArea;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/mark/tiq_mark.dart';
import '../../../core/widgets/torchlight/state/toast.dart';
import '../../../l10n/l10n.dart';
import '../data/chat_controller.dart';
import 'answer_runs.dart';
import 'answer_view.dart';

/// WHAT THE MANAGER ASKED, held so the answer beneath it can be read against
/// the question.
///
/// Right-aligned inside the transcript column, and it is **the only
/// right-alignment on this surface**. That asymmetry is load-bearing: it is
/// what lets an eye scanning the left edge find every answer without reading
/// a single question.
class QuestionBubble extends StatefulWidget {
  const QuestionBubble({super.key, required this.text});

  final String text;

  /// Rendered lines before the bubble clamps and offers the full question.
  static const int clampLines = 6;

  @override
  State<QuestionBubble> createState() => _QuestionBubbleState();
}

class _QuestionBubbleState extends State<QuestionBubble> {
  bool _full = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    showTorchToast(context, message: context.l10n.askQuestionCopied);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final p = skin.palette;
    final veld = skin.mode == SkinMode.veld;

    return Semantics(
      container: true,
      label: '${l10n.askYourQuestion}. ${widget.text}',
      // THE HOLD, AS AN ACTION. `excludeSemantics` drops the descendant
      // `GestureDetector`'s node, so hold-to-copy was not in the tree at all:
      // a capability a widget test could reach by sending the gesture
      // directly, and a screen-reader user could not.
      onLongPress: _copy,
      // ...and "Show the full question" gets its own node beneath this one.
      // It is the ONLY way to read a question clamped at six lines, and
      // inside an excluded subtree it did not exist to assistive tech.
      explicitChildNodes: true,
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: GestureDetector(
          onLongPress: _copy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // The question is already this node's label; a second node
              // repeating it would read it twice.
              ExcludeSemantics(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                  ),
                  child: Container(
                    padding: EdgeInsets.all(veld ? TiqSpace.s4 : TiqSpace.s3),
                    decoration: BoxDecoration(
                      color: veld ? p.ground : p.raised,
                      borderRadius: BorderRadius.circular(
                        veld ? 0 : skin.radii.panel,
                      ),
                      border: veld ? Border.all(color: p.ink1, width: 2) : null,
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: answerSpans(
                          answerRuns(widget.text, streaming: false),
                          skin: skin,
                          base: skin.text.body.style(color: p.ink1),
                        ),
                      ),
                      // No fade over the clamp: this system draws no gradient
                      // over text, anywhere.
                      maxLines: _full ? null : QuestionBubble.clampLines,
                      overflow: _full
                          ? TextOverflow.clip
                          : TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              if (!_full && _needsExpansion(context))
                TorchTertiaryButton(
                  label: l10n.askShowFullQuestion,
                  onPressed: () => setState(() => _full = true),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Whether the question is long enough to be clamped. Measured against the
  /// rendered text rather than guessed from a character count, because
  /// Afrikaans runs 40% longer at p90 and a character cap would clamp the
  /// wrong questions in one language and none in the other.
  bool _needsExpansion(BuildContext context) {
    final skin = context.skin;
    final width = MediaQuery.sizeOf(context).width * 0.78;
    final painter = TextPainter(
      text: TextSpan(
        text: widget.text,
        style: skin.text.body.style(color: skin.palette.ink1),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: QuestionBubble.clampLines,
    )..layout(maxWidth: width);
    final exceeded = painter.didExceedMaxLines;
    painter.dispose();
    return exceeded;
  }
}

/// A FAILED TURN.
///
/// A 3dp `bad` left bar, a filled triangle, the sanitised message, an optional
/// code, and one ghost Try again. No fill and no radius: the bar plus the
/// triangle plus the words are the severity, at the critical commitment level.
///
/// **Amber: none, in any error state, in any mode.** Severity abandons the
/// amber band entirely — there is no amber warning in TradeIQ.
class AnswerErrorBlock extends StatelessWidget {
  const AnswerErrorBlock({
    super.key,
    required this.message,
    required this.onRetry,
    this.code,
    this.repeated = false,
  });

  final String message;
  final VoidCallback onRetry;

  /// The wire's code, when it was not `unknown`. A diagnostic for a support
  /// call, in mono at the block's foot.
  final String? code;

  /// The same question has now failed twice.
  final bool repeated;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final p = skin.palette;
    final veld = skin.mode == SkinMode.veld;

    return Semantics(
      container: true,
      label: l10n.askErrorSemantic(message),
      // The bar is the block's own left border, not a stretched sibling: a
      // Row asked to stretch inside a scroll view has no height to stretch
      // to, and the first error a manager met took the transcript down.
      child: DecoratedBox(
        key: const ValueKey<String>('answer-error'),
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(
              color: veld ? p.badSolid : p.bad,
              width: veld ? 4 : 3,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: (veld ? 4 : 3) + TiqSpace.s3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: TiqSpace.s1),
                    child: TiqMark(
                      shape: MarkShape.criticalTriangle,
                      color: veld ? p.badSolid : p.bad,
                      size: MarkScale.glyph(context, veld ? 14 : 9),
                    ),
                  ),
                  const SizedBox(width: TiqSpace.s3 - 2),
                  Expanded(
                    child: Text(
                      message,
                      style: skin.text.body.style(color: p.ink1),
                    ),
                  ),
                ],
              ),
              if (repeated) ...<Widget>[
                const SizedBox(height: TiqSpace.s1),
                Text(
                  l10n.askFailedTwice,
                  style: skin.text.meta.style(color: p.ink3),
                ),
              ],
              SizedBox(height: skin.space.intraBlock),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TorchSecondaryButton(
                  label: l10n.askTryAgain,
                  onPressed: onRetry,
                ),
              ),
              if (code != null) ...<Widget>[
                const SizedBox(height: TiqSpace.s2),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    code!,
                    style: skin.text.monoIdent.style(color: p.ink3),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Stopped." — one meta line and a way to ask again.
///
/// **Not an error.** No bar, no triangle, no crimson: the partial text stays
/// exactly as written, and half an answer is worth more than a message that
/// erases it.
class StoppedLine extends StatelessWidget {
  const StoppedLine({super.key, required this.onAskAgain});

  final VoidCallback onAskAgain;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    return Semantics(
      container: true,
      label: l10n.askStoppedSemantic,
      child: Column(
        key: const ValueKey<String>('answer-stopped'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.askStopped,
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
          const SizedBox(height: TiqSpace.s2),
          TorchSecondaryButton(label: l10n.askAskAgain, onPressed: onAskAgain),
        ],
      ),
    );
  }
}

/// THE HELD BAND — offline, or a session that ended.
///
/// Oatmeal grammar, not crimson and not Truffle-as-severity: a square, a
/// sentence, and a way back. Working offline is the normal state of South
/// African field work, and a token expiring at 14:00 on a Tuesday is a fact
/// about a clock.
///
/// **Amber: zero.** Send is disabled beneath it and therefore unrimmed in
/// Night and unfilled in Day and Veld.
class AskHeldBand extends StatelessWidget {
  const AskHeldBand({
    super.key,
    required this.message,
    required this.semanticsLabel,
    this.action,
    this.onAction,
  });

  final String message;
  final String semanticsLabel;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final veld = skin.mode == SkinMode.veld;

    return Semantics(
      container: true,
      // EXPLICIT CHILD NODES, not an excluded subtree. `excludeSemantics: true`
      // here swallowed the band's own action: in `sessionEnded` the composer
      // is disabled (`AskPhase.canSend` is false), so "Sign in" is the only
      // control on the route, and it was not in the accessibility tree — no
      // node to focus and no action to fire. The sentence keeps its live
      // region below; the way out gets a node of its own.
      explicitChildNodes: true,
      child: Container(
        key: const ValueKey<String>('ask-held-band'),
        constraints: BoxConstraints(minHeight: skin.space.rowMinHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: TiqSpace.s3,
          vertical: TiqSpace.s2,
        ),
        decoration: BoxDecoration(
          color: veld ? p.ground : p.well,
          borderRadius: BorderRadius.circular(veld ? 0 : skin.radii.control),
          border: veld
              ? Border.all(color: p.ink1, width: skin.depth.borderWidth)
              : null,
        ),
        child: Row(
          children: <Widget>[
            ExcludeSemantics(
              child: TiqMark(
                // The square is labelled "Held" — deliberately not a severity.
                shape: MarkShape.heldSquare,
                color: veld ? p.ink1 : p.comparison,
                size: MarkScale.glyph(context, veld ? 12 : 9),
              ),
            ),
            const SizedBox(width: TiqSpace.s2),
            Expanded(
              child: Semantics(
                liveRegion: true,
                label: semanticsLabel,
                excludeSemantics: true,
                child: Text(
                  message,
                  style: skin.text.label.style(color: p.ink2),
                ),
              ),
            ),
            if (action != null && onAction != null) ...<Widget>[
              const SizedBox(width: TiqSpace.s2),
              TorchTertiaryButton(label: action!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// A finished turn's prose, when it used none of the answer conventions.
///
/// Exactly as replies have always rendered: one selectable run of text. A
/// plain reply does not get the rich layout, and does not need it.
class PlainAnswer extends StatelessWidget {
  const PlainAnswer({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: answerProseWidth(skin)),
      child: SelectionArea(
        child: Text.rich(
          TextSpan(
            children: <InlineSpan>[
              ...answerSpans(
                answerRuns(message.text, streaming: message.streaming),
                skin: skin,
                base: skin.text.body.style(color: skin.palette.ink1),
              ),
              if (message.streaming)
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: StreamingCaret(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// WHAT A MANAGER DOES WITH AN ANSWER ONCE SHE HAS IT.
///
/// A 48dp row of ghost icon buttons at the foot of a settled, non-errored
/// turn, left-aligned at the column edge — nothing on this surface is
/// right-aligned except the question.
///
/// **Copy is the capability this row exists for.** An answer that can only be
/// read on this screen is an answer that gets retyped into WhatsApp, with the
/// figures retyped too. The text it puts on the clipboard is
/// [answerPlainText]: the prose, the figures in the reader's own separators,
/// unknowns as unknowns, and outside figures kept outside with the source
/// they came from.
///
/// **Amber: none.** A ghost control is not a claim, and the route's light is
/// spoken for by the answer's own focus object.
class AnswerActionsRow extends StatefulWidget {
  const AnswerActionsRow({
    super.key,
    required this.text,
    required this.onAskAgain,
  });

  /// What Copy puts on the clipboard, resolved by the caller so this widget
  /// never has to know what a turn is made of.
  final String text;

  final VoidCallback onAskAgain;

  /// How long the copy glyph holds its tick.
  static const Duration tick = Duration(milliseconds: 1200);

  @override
  State<AnswerActionsRow> createState() => _AnswerActionsRowState();
}

class _AnswerActionsRowState extends State<AnswerActionsRow> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    showTorchToast(context, message: context.l10n.askAnswerCopied);
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(AnswerActionsRow.tick, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      key: const ValueKey<String>('answer-actions'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TorchIconButton(
          key: const ValueKey<String>('answer-copy'),
          icon: _copied ? Icons.check : Icons.copy_all_outlined,
          semanticLabel: l10n.askCopyAnswer,
          onPressed: _copy,
        ),
        const SizedBox(width: TiqSpace.s2),
        TorchIconButton(
          key: const ValueKey<String>('answer-ask-again'),
          icon: Icons.refresh,
          semanticLabel: l10n.askAskAgainAnswer,
          onPressed: widget.onAskAgain,
        ),
      ],
    );
  }
}

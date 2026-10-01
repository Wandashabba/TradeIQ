import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/torch_press.dart';
import '../../../core/widgets/torchlight/input/text_field.dart';
import '../../../core/widgets/torchlight/mark/tiq_mark.dart';
import '../../../l10n/l10n.dart';
import 'ask_light.dart';
import 'ask_phase.dart';

/// THE QUESTION COMPOSER — where the manager types, and the one place on this
/// surface that commits an action.
///
/// A standing label, a trough, and a 48dp Send key. The label is a **real
/// label and it never moves**: the critic's suggestion to fold it into the
/// trough while the keyboard is up was measured and rejected — the label
/// inside the trough forces it from 56 to 72 to hold it, so the net win is
/// 10dp, not 26, and it costs the composer its most-defended property. The
/// 84dp comes from the nav pill instead, which is chrome that has nothing to
/// say while someone is typing.
///
/// ## Amber
///
/// Send's rim in Night, its block in Day, and **only while Send is armed** —
/// which is [AskPhase.armed]: the at-rest screen and the typed one, never
/// offline and never a dead session. It is the route's rung-1 claim. A
/// disabled Send is never amber in any skin.
///
/// **It is armed at rest since 1 October 2026**, and the reasoning is written
/// out on [AskPhase.claims] rather than here because it is a statement about
/// the route's light budget and not about this widget. What belongs here is
/// the behaviour that earns it: see [_sendOrFocus].
///
/// Two things the direction drew are deliberately absent. The 6dp amber top
/// bleed is cut: an emitted gradient is indistinguishable in kind from the
/// answer's focus bloom, so it was a second lit object standing permanently on
/// the screen. And the focused trough's rule is **ink**, thickening 1px → 2px,
/// which is the channel a reader who cannot separate two greys still gets.
class QuestionComposer extends StatefulWidget {
  const QuestionComposer({
    super.key,
    required this.controller,
    required this.phase,
    required this.onSend,
    required this.onStop,
    this.focusNode,
    this.onChanged,
    this.band,
    this.hint,
    this.lastTurnErrored = false,
  });

  final TextEditingController controller;
  final AskPhase phase;

  /// Null-safe by construction: the button is disabled unless there is
  /// something to send.
  final VoidCallback onSend;
  final VoidCallback onStop;

  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  /// The offline or session-ended band, pinned above the label.
  final Widget? band;

  /// Overrides the trough's placeholder.
  ///
  /// Ask leaves it null and keeps `askComposerHint`. The Floor passes
  /// `Ask about Gauteng North…` — the composer sits under a plate carrying one
  /// territory, and a placeholder that named no scope on a screen that is
  /// entirely about one would be the composer declining to say what it is for.
  /// The **label** above the trough is untouched in both: it is the accessible
  /// name of the field and it is the same field on both surfaces.
  final String? hint;

  /// Turns the label into "Ask again, or rephrase".
  final bool lastTurnErrored;

  /// The hard stop. Past this the field refuses more; the counter warns at
  /// 45% of it.
  static const int maximumQuestion = 1000;

  @override
  State<QuestionComposer> createState() => _QuestionComposerState();
}

class _QuestionComposerState extends State<QuestionComposer> {
  /// Only built when the caller does not supply one, and only so [_sendOrFocus]
  /// has something to move focus to. Neither caller passes a node today; both
  /// are free to, and then this stays null and is never disposed.
  FocusNode? _own;

  FocusNode get _node => widget.focusNode ?? (_own ??= FocusNode());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  /// ── PRESS IT EMPTY AND YOU ARE TYPING ────────────────────────────────
  ///
  /// Send is live from the first frame, which is what lets it be amber (see
  /// [AskPhase.claims]). This is the half of that decision that makes the
  /// light honest: a lit control has to *do* something, and The Floor's own
  /// nav circle is the recorded case of what happens when it does not —
  /// *"a circle that names two verbs and performs neither is worse than no
  /// circle: it teaches a manager that the chrome on this screen is
  /// decoration."*
  ///
  /// With nothing typed, the real question is not "what is missing" — the
  /// empty trough beside the button already answers that better than any
  /// message could — it is "where do I put it". So the press puts the cursor
  /// there and brings the keyboard up. One tap, from reading the briefing to
  /// asking about it, which is the move the whole screen exists to make easy.
  ///
  /// It deliberately does **not** send a suggestion chip, pick a question or
  /// guess. The chips are directly above and they send what they print; a
  /// button that invented a question would be the one behaviour that makes a
  /// manager stop trusting the row.
  void _sendOrFocus() {
    if (widget.controller.text.trim().isEmpty) {
      _node.requestFocus();
      return;
    }
    widget.onSend();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final phase = widget.phase;
    final streaming = phase == AskPhase.thinking || phase == AskPhase.writing;
    final canType = phase.canSend && !streaming;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.band != null) ...<Widget>[
          widget.band!,
          SizedBox(height: skin.space.intraBlock),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TorchTextField(
                key: const ValueKey<String>('ask-composer-field'),
                // The label is the semantic label, not a duplicate of a hint.
                label: widget.lastTurnErrored
                    ? l10n.askComposerRephrase
                    : l10n.askComposerLabel,
                controller: widget.controller,
                focusNode: _node,
                hint: widget.hint ?? l10n.askComposerHint,
                enabled: canType,
                minLines: 1,
                maximumLines: 5,
                maximumLength: QuestionComposer.maximumQuestion,
                textInputAction: TextInputAction.send,
                onChanged: widget.onChanged,
                // Read the trough, not the phase this closure was built
                // with: a paste and a Return inside one frame arrive before
                // the rebuild that would have moved the phase to typing, and
                // a question the keyboard said was sent must be sent.
                onSubmitted: (text) {
                  if (canType && text.trim().isNotEmpty) widget.onSend();
                },
              ),
            ),
            const SizedBox(width: TiqSpace.s2),
            Padding(
              // The label sits above the trough, so the key aligns to the
              // trough's own bottom edge rather than to the block's.
              padding: const EdgeInsets.only(bottom: 0),
              child: streaming
                  ? _StopKey(onPressed: widget.onStop)
                  : _SendKey(
                      // PRESSES WHENEVER THE CONNECTION ALLOWS, and is amber
                      // only where the route declares rung 1. The two are
                      // different questions and this is where they separate —
                      // see [AskPhase.armed]. It was `phase ==
                      // AskPhase.typing` for both.
                      enabled: phase.canSend,
                      nothingTyped: widget.controller.text.trim().isEmpty,
                      onPressed: _sendOrFocus,
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The key's TAP TARGET: 48dp, which is `torchTapTarget`'s floor for a glyph
/// action and is not negotiable.
double _keySize(TiqSkin skin) => 48;

/// ── THE DRAWN DISC, AND WHY IT IS SMALLER THAN THE TARGET ──────────────
///
/// 36dp. The mockup's send is `width:27px; height:27px; border-radius:50%`,
/// which is **35dp** at 1.3 dp/px, and 36 is that on the 4dp scale.
///
/// **A MOCKUP-VERSUS-LAW COLLISION, RESOLVED IN FAVOUR OF THE LAW, AND
/// RECORDED RATHER THAN SPLIT THE DIFFERENCE.** 35dp is under the 44dp floor
/// WCAG 2.5.5 sets and under the 48 `torchTapTarget` holds a glyph action at.
/// The one object on this surface that commits an action is the last place to
/// go under it. So the target stays 48 and the *paint* comes down to the
/// drawing's 36: 6dp of transparent ring on every side, which a finger lands
/// in and an eye does not see.
///
/// The same split is made for both controls on the plate and for the
/// suggestion chips — see `plateQuietExtent` and `TorchFilterChip.quiet`. It
/// is the through-line of the 1 October weight pass: **every number in the
/// drawing's chrome is between 29 and 35dp, every one of them is under the
/// product's tap-target floor, and the answer at all five is to draw at the
/// drawing's size and target at the rule's.**
const double _sendDisc = 36;

class _SendKey extends StatelessWidget {
  const _SendKey({
    required this.enabled,
    required this.nothingTyped,
    required this.onPressed,
  });

  /// [AskPhase.canSend] — whether the key **presses**. Whether it is **amber**
  /// is a different question and the answer comes from [TorchScope], not from
  /// here; see [AskPhase.armed].
  ///
  /// Since 1 October 2026 the only reason this is ever false is that there is
  /// no connection or no session. An empty trough no longer disables the key,
  /// it redirects the press into the trough.
  final bool enabled;

  /// Whether there is anything in the trough to send.
  ///
  /// It changes **what the key announces, not whether it works**. A screen
  /// reader is told the truth about what a press will do, which with nothing
  /// typed is "this opens the question field" rather than "this sends your
  /// question" — a label that promised sending and then moved focus would be
  /// the kind of lie that teaches somebody to stop trusting the labels. The
  /// printed glyph does not change: there is one Send key, not two.
  final bool nothingTyped;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final size = _keySize(skin);
    // A CIRCLE, NOT A RADIUS-16 SQUARE — the mockup's `border-radius:50%`.
    // `radii.control` is 16, which at 48dp is a rounded square, and against
    // the drawing's disc it is one of the places the owner read our chrome as
    // louder. The key is the one round object in the composer and the trough
    // beside it is the one soft rectangle; nothing else in the row is at risk
    // of being confused with it.
    final radius = BorderRadius.circular(_sendDisc / 2);
    final lit = TorchScope.lit(context, AskLight.sendClaimId);

    // The node is the pressable's, so its `onTap` is the SAME debounced,
    // haptic fire the finger goes through. Wrapped around it instead, with
    // `excludeSemantics: true` and no `onTap`, the route's one primary action
    // announced itself as a button and then did nothing when activated.
    return TorchPressable(
      onPressed: enabled ? onPressed : null,
      semanticsEnabled: enabled,
      // THREE STATES, THREE SENTENCES. A disabled Send announces WHY rather
      // than being silently inert; a live one announces what the press will
      // actually do, which is not the same sentence with nothing typed.
      semanticsLabel: !enabled
          ? l10n.askSendUnavailable
          : (nothingTyped ? l10n.askSendNothingTyped : l10n.askSend),
      borderRadius: radius,
      debounce: const Duration(milliseconds: 400),
      builder: (context, pressed) {
        final look = AskLight.send(
          skin,
          lit: lit,
          pressed: pressed,
          disabled: !enabled,
        );
        // 48dp of target around a 36dp disc. See [_sendDisc].
        return SizedBox.square(
          dimension: size,
          child: Center(
            child: Container(
              width: _sendDisc,
              height: _sendDisc,
              decoration: BoxDecoration(
                color: look.fill,
                borderRadius: radius,
                border: look.edge == null
                    ? null
                    : Border.all(color: look.edge!, width: look.edgeWidth),
              ),
              child: Center(
                // The mockup's `font-size:12px` is 16dp at 1.3 dp/px. It was
                // 20, sized for the 48dp square the disc replaced.
                child: _Arrow(
                  colour: look.ink,
                  size: MarkScale.glyph(context, 16),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Stop. A ghost square with a filled square glyph — never amber, because
/// stopping is not the expected next move, it is the escape from one.
class _StopKey extends StatelessWidget {
  const _StopKey({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final size = _keySize(skin);
    final radius = BorderRadius.circular(skin.radii.control);

    return TorchPressable(
      onPressed: onPressed,
      semanticsLabel: context.l10n.askStop,
      borderRadius: radius,
      builder: (context, pressed) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: pressed ? torchPressSurface(skin).fill : null,
          borderRadius: radius,
          border: Border.all(
            color: p.edgeControl,
            width: pressed ? 2 : skin.depth.borderWidth,
          ),
        ),
        child: Center(
          child: SizedBox.square(
            dimension: MarkScale.glyph(context, 12),
            child: ColoredBox(color: p.ink1),
          ),
        ),
      ),
    );
  }
}

/// A 2px-stroke arrow-up, drawn rather than set.
class _Arrow extends StatelessWidget {
  const _Arrow({required this.colour, required this.size});

  final Color colour;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.arrow_upward, size: size, color: colour);
}

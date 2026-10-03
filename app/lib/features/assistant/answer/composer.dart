import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/torch_press.dart';
import '../../../core/widgets/torchlight/input/text_field.dart';
import '../../../core/widgets/torchlight/input/trough.dart';
import '../../../core/widgets/torchlight/mark/tiq_mark.dart';
import '../../../l10n/l10n.dart';
import 'ask_light.dart';
import 'ask_phase.dart';

/// THE QUESTION COMPOSER — where the manager types, and the one place on this
/// surface that commits an action.
///
/// ```text
///   ╭──╮ ╭───────────────────────────╮ ╭──╮
///   │▦▦│ │ Ask about your tasks…     │ │ ↑│
///   ╰──╯ ╰───────────────────────────╯ ╰──╯
///   48dp  48dp                          48dp
/// ```
///
/// ## ONE HEIGHT, ONE CORNER LANGUAGE — 3 October 2026
///
/// > *"the bottom doesn't look proportioned"* — the owner, on a screenshot of
/// > the bar.
///
/// They were right, and it was three defects at once rather than a styling
/// preference. Measured on `main` at 390×844, Night, console density:
///
/// | object | was | is |
/// |---|---|---|
/// | the grid key | 44dp drawn, round | **48dp**, round |
/// | the field | 54dp drawn, radius 16 | **48dp**, radius 24 |
/// | the Send disc | 36dp drawn, round | **48dp**, round |
/// | the standing label | 16dp of text + an 8dp gap | **gone** |
///
/// Three heights in one row and two corner languages in it. [barExtent] is now
/// the only size in the row, so the three objects cannot drift apart again,
/// and every one of them is a full pill — `extent / 2` on all four corners.
///
/// **The standing label goes**, which is the part that was not only geometry.
/// It read *"Ask a question"* directly above a placeholder reading *"Ask about
/// your territories…"*: the same sentence twice, and the upper one indented to
/// the FIELD's left edge rather than the row's — **56dp in**, measured, which
/// is the grid key's 48 plus the 8dp gap — so the bar's left margin was
/// ragged. It survives as the field's accessible name — see
/// [TorchTextField.labelVisible] — and the one thing it said that the hint did
/// not, *"Ask again, or rephrase"* after a failed turn, moves into the hint
/// rather than being dropped. See [_hint].
///
/// The earlier defence of the label is kept here because it still holds for
/// the thing it was defending against: the critic's suggestion was to fold the
/// label **into** the trough as a floating placeholder, which forces the
/// trough from 56 to 72 to hold it. That is not what happened. The label was
/// not moved anywhere; it was deleted as a drawn object, and the trough got
/// 6dp SHORTER rather than 16dp taller.
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
    this.leading,
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

  /// ── THE LEADING SLOT, WHICH IS WHERE THE CONSOLE'S NAVIGATION LIVES ──
  ///
  /// One control before the trough, aligned to the trough's own bottom edge
  /// exactly as Send is. Null on no console route since 2 October 2026: it
  /// carries [TorchAskDestinations], and the bar it makes —
  /// `[grid] [the ask field] [send]` — is the whole of the bottom region on
  /// every manager screen.
  ///
  /// It is a slot on **this** widget rather than a second composer wrapped
  /// around it because the thing being fixed is that the bottom of the screen
  /// meant two different things depending on where you stood. One widget is
  /// how "identical geometry everywhere" stops being a thing somebody has to
  /// keep true and becomes a thing that cannot come apart.
  final Widget? leading;

  /// Turns the label into "Ask again, or rephrase".
  final bool lastTurnErrored;

  /// The hard stop. Past this the field refuses more; the counter warns at
  /// 45% of it.
  ///
  /// **A KNOWN MISALIGNMENT, PRE-DATING THIS WIDGET'S PROPORTION PASS AND NOT
  /// FIXED BY IT.** The counter appears at 80% of the cap — 800 characters —
  /// and `TorchFieldShell` draws it beneath the trough, inside the block the
  /// `Row` bottom-aligns the two keys to. So past 800 characters the keys sit
  /// `helpGap` + a line of `axisLabel` below the pill's bottom edge: **23dp**
  /// at 390×844, measured, where it measured 17dp before — the key's BOX was
  /// always 23dp down and 6dp of it used to be the transparent ring around a
  /// 36dp disc. It is the same defect at the same place; growing the disc took
  /// the ring off it and made the whole of it visible.
  ///
  /// It is written down rather than fixed because the fix is to lift the
  /// counter out of the shell's column for this one field — a change to a
  /// shared widget's layout, for a state the ask bar reaches at 800 characters
  /// of a 1000-character cap, and the owner's brief was the three objects at
  /// rest.
  static const int maximumQuestion = 1000;

  /// ── THE ONE SIZE IN THE ROW ───────────────────────────────────────────
  ///
  /// 48dp: the grid key, the field and the Send disc, drawn and targeted, in
  /// every state the bar has. It is `torchTapTarget`'s floor for a glyph
  /// action, it clears WCAG 2.5.5's 44dp, and it is the number
  /// [TorchAskDestinations] and [TroughGeometry.pill] both read rather than
  /// restate — a row whose three objects each carried their own number is how
  /// 44, 54 and 36 ended up beside one another.
  ///
  /// It is **not** `space.primaryActionHeight` (44). That token is the height
  /// of a commit button inside a form, and the two numbers being different is
  /// what `TroughSpec`'s own comment warns about. The bar is not in a form: it
  /// is chrome standing on the ground on 29 screens, its two keys are glyph
  /// actions at 48, and a 44dp field between two 48dp keys is the defect this
  /// replaced, one notch smaller.
  static const double barExtent = 48;

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

  /// ── WHAT THE EMPTY FIELD SAYS, AND THE ONE THING THE LABEL TOOK WITH IT ──
  ///
  /// The standing label is gone because it repeated the hint. In one state it
  /// did not: after a failed turn it read *"Ask again, or rephrase"*, which is
  /// the only place on the screen that says what to do next — the error block
  /// above says what went wrong. Deleting the label and letting that sentence
  /// go with it would have been the change costing a behaviour nobody asked
  /// to lose, so it lands in the hint instead.
  ///
  /// It costs the scope: The Floor's `Ask about Gauteng North…` is not printed
  /// for the one turn after an error. That is the right way round. The scope is
  /// a standing invitation and the rephrase is a reply to something that just
  /// happened, and only one of the two can hold a placeholder.
  ///
  /// It also costs the sentence the moment somebody types, because a hint is
  /// not drawn over a value. By then they are rephrasing.
  ///
  /// **Neither ARB key is dead.** `askComposerRephrase` is now printed here
  /// as well as announced, and `askComposerLabel` is unrendered everywhere but
  /// is still the field's accessible name — see the `label:` argument in
  /// [build]. A pass that swept the ARB for unused keys would take a screen
  /// reader's only name for the one control this product is built around.
  String _hint(AppLocalizations l10n) => widget.lastTurnErrored
      ? l10n.askComposerRephrase
      : (widget.hint ?? l10n.askComposerHint);

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
            if (widget.leading != null) ...<Widget>[
              widget.leading!,
              const SizedBox(width: TiqSpace.s2),
            ],
            Expanded(
              child: TorchTextField(
                key: const ValueKey<String>('ask-composer-field'),
                // STILL THE SEMANTIC LABEL, no longer a drawn one. A reader
                // lands on the trough and hears this; an eye sees the hint,
                // which was saying the same thing one line lower.
                label: widget.lastTurnErrored
                    ? l10n.askComposerRephrase
                    : l10n.askComposerLabel,
                labelVisible: false,
                // A 48dp PILL, and the only trough in the app that is not
                // `radii.input`. The row's three objects are one height and
                // one shape or the bar is not one object — see [barExtent].
                geometry: TroughGeometry.pill(QuestionComposer.barExtent),
                controller: widget.controller,
                focusNode: _node,
                hint: _hint(l10n),
                // ONE GRADE UP FROM EVERY OTHER TROUGH'S HINT, in both skins
                // and on all 29 console screens. See [TorchTextField.hintInk]
                // for the measurement: on The Floor's washed Day ground
                // `ink3` is 4.17:1 against a 4.5:1 floor, and a prompt is not
                // a format restatement anyway.
                hintInk: skin.palette.ink2,
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
              // Zero, and kept as a named zero rather than deleted: the keys
              // align to the BOTTOM of the field's block, and the block is the
              // trough alone only while no counter is showing. See the comment
              // on [QuestionComposer.maximumQuestion].
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

/// The key's TAP TARGET, and since 3 October 2026 its DRAWN size too:
/// [QuestionComposer.barExtent]. Both keys read this, in every state.
double _keySize(TiqSkin skin) => QuestionComposer.barExtent;

/// ── THE DRAWN DISC: 48dp, AND IT IS THE TARGET ─────────────────────────
///
/// It was 36 — the mockup's `width:27px; height:27px; border-radius:50%`,
/// which is 35dp at 1.3 dp/px and 36 on the 4dp scale — inside a 48dp target,
/// so 6dp of transparent ring on every side that a finger landed in and an eye
/// did not see.
///
/// **THE OWNER OVERRODE THE MOCKUP ON 3 OCTOBER 2026 AND THIS RECORDS IT
/// RATHER THAN LEAVING A DERIVATION FOR A NUMBER NO LONGER IN THE CODE.** The
/// eye did see it, in the one place a composed row makes it visible: beside a
/// 48dp grid key and a 54dp field, a 36dp disc was the smallest of three
/// objects that should have read as one row, and the first thing the owner said
/// about the bar was that it *"doesn't look proportioned"*. Drawn and targeted
/// are now the same number and that number is the row's.
///
/// What the 1 October weight pass argued — *draw at the drawing's size, target
/// at the rule's* — still stands for the two controls it was about, which sit
/// **on a photograph** where the picture carries the weight: see
/// `plateQuietExtent` and `TorchFilterChip.quiet`. The grid key already left
/// that rule on 2 October for the same reason this disc does, and with the
/// same words in `ask_bar.dart`: a control standing on the ground in a row
/// with two others is not a control on a picture.
///
/// The disc now fills the target exactly, so there is no transparent ring left
/// to hold the two apart; the constant is kept rather than inlined because
/// `_sendDisc` is what the amber census measures and a reader asking "how big
/// is the lit object" should find it named.
const double _sendDisc = QuestionComposer.barExtent;

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
    // `radii.control` is 16, which at 48dp is a rounded square.
    //
    // It was the one round object in a row with a radius-16 trough, which is
    // the half of the shape argument that turned out to be the defect rather
    // than the fix: two corner languages in one row of three objects. The
    // whole row is `extent / 2` now — the trough included, through
    // `TroughGeometry.pill` — so the radius below is the row's, not this
    // key's.
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
        // ONE BOX: the target IS the disc. See [_sendDisc].
        return SizedBox.square(
          dimension: size,
          child: Center(
            child: Container(
              width: _sendDisc,
              height: _sendDisc,
              decoration: BoxDecoration(
                // `color` is the flat fallback and `gradient` wins wherever it
                // is non-null — which is only the granted state, and only in a
                // skin with a gradient budget. See `AskLight.sendBloom`.
                color: look.fill,
                gradient: look.bloom,
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

/// Stop. A ghost disc with a filled square glyph — never amber, because
/// stopping is not the expected next move, it is the escape from one.
///
/// The glyph stays a square. A round key with a round glyph in it would be two
/// concentric circles saying nothing; the square is the universal stop mark and
/// it is the one thing in the row that is allowed a corner.
class _StopKey extends StatelessWidget {
  const _StopKey({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final size = _keySize(skin);
    // THE SAME PILL AS EVERY OTHER OBJECT IN THE ROW. It was
    // `radii.control` — 16, a rounded square — which meant the bar changed
    // corner language the moment a turn started streaming. The point of the
    // proportion pass is that nothing in the row disagrees, and "in every
    // state" includes this one.
    final radius = BorderRadius.circular(size / 2);

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

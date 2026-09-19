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
/// Send's rim in Night, its block in Day and Veld, and **only while Send is
/// enabled** — which is only when the manager has typed something, i.e. when
/// sending is the expected next move. It is the route's rung-1 claim. A
/// disabled Send is never amber in any skin, so most states of this screen
/// carry no composer amber at all.
///
/// Two things the direction drew are deliberately absent. The 6dp amber top
/// bleed is cut: an emitted gradient is indistinguishable in kind from the
/// answer's focus bloom, so it was a second lit object standing permanently on
/// the screen. And the focused trough's rule is **ink**, thickening 1px → 2px,
/// which is the channel a reader who cannot separate two greys still gets.
class QuestionComposer extends StatelessWidget {
  const QuestionComposer({
    super.key,
    required this.controller,
    required this.phase,
    required this.onSend,
    required this.onStop,
    this.focusNode,
    this.onChanged,
    this.band,
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

  /// Turns the label into "Ask again, or rephrase".
  final bool lastTurnErrored;

  /// The hard stop. Past this the field refuses more; the counter warns at
  /// 45% of it.
  static const int maximumQuestion = 1000;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final streaming =
        phase == AskPhase.thinking || phase == AskPhase.writing;
    final canType = phase.canSend && !streaming;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (band != null) ...<Widget>[
          band!,
          SizedBox(height: skin.space.intraBlock),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TorchTextField(
                key: const ValueKey<String>('ask-composer-field'),
                // The label is the semantic label, not a duplicate of a hint.
                label: lastTurnErrored
                    ? l10n.askComposerRephrase
                    : l10n.askComposerLabel,
                controller: controller,
                focusNode: focusNode,
                hint: l10n.askComposerHint,
                enabled: canType,
                minLines: 1,
                maximumLines: 5,
                maximumLength: maximumQuestion,
                textInputAction: TextInputAction.send,
                onChanged: onChanged,
                onSubmitted: (_) {
                  if (phase == AskPhase.typing) onSend();
                },
              ),
            ),
            const SizedBox(width: TiqSpace.s2),
            Padding(
              // The label sits above the trough, so the key aligns to the
              // trough's own bottom edge rather than to the block's.
              padding: const EdgeInsets.only(bottom: 0),
              child: streaming
                  ? _StopKey(onPressed: onStop)
                  : _SendKey(
                      enabled: phase == AskPhase.typing,
                      offline: !phase.canSend,
                      onPressed: onSend,
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A 48dp square (56 in Veld), radius 10.
double _keySize(TiqSkin skin) =>
    skin.density == TiqDensity.veld ? TiqSpace.s9 : 48;

class _SendKey extends StatelessWidget {
  const _SendKey({
    required this.enabled,
    required this.offline,
    required this.onPressed,
  });

  final bool enabled;

  /// Disabled because there is no connection or no session, rather than
  /// because nothing is typed. The two announce differently, because the two
  /// are different problems.
  final bool offline;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final size = _keySize(skin);
    final radius = BorderRadius.circular(skin.radii.control);
    final lit = TorchScope.lit(context, AskLight.sendClaimId);

    return Semantics(
      button: true,
      enabled: enabled,
      // A disabled Send announces WHY rather than being silently inert.
      label: enabled
          ? l10n.askSend
          : (offline ? l10n.askSendUnavailable : l10n.askSendNothingTyped),
      excludeSemantics: true,
      child: TorchPressable(
        onPressed: enabled ? onPressed : null,
        borderRadius: radius,
        debounce: const Duration(milliseconds: 400),
        builder: (context, pressed) {
          final look = AskLight.send(
            skin,
            lit: lit,
            pressed: pressed,
            disabled: !enabled,
          );
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: look.fill,
              borderRadius: radius,
              border: look.edge == null
                  ? null
                  : Border.all(color: look.edge!, width: look.edgeWidth),
            ),
            child: Center(
              child: _Arrow(
                colour: look.ink,
                size: MarkScale.glyph(context, 20),
                // A SHAPE change, not only a colour one: a colour-only
                // disabled state is invisible at 40% backlight in sun, which
                // is the one place Veld exists for.
                struck: !enabled && skin.mode == SkinMode.veld,
              ),
            ),
          );
        },
      ),
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

    return Semantics(
      button: true,
      label: context.l10n.askStop,
      excludeSemantics: true,
      child: TorchPressable(
        onPressed: onPressed,
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
      ),
    );
  }
}

/// A 2px-stroke arrow-up, drawn rather than set, and optionally struck
/// through for Veld's disabled state.
class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.colour,
    required this.size,
    required this.struck,
  });

  final Color colour;
  final double size;
  final bool struck;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: <Widget>[
      Icon(Icons.arrow_upward, size: size, color: colour),
      if (struck)
        SizedBox(
          width: size,
          height: 2,
          child: ColoredBox(color: colour),
        ),
    ],
  );
}

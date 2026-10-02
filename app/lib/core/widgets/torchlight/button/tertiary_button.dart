import 'package:flutter/widgets.dart';

import '../../../design/torch_scope.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import 'torch_button.dart';
import 'torch_press.dart';

/// THE INLINE ACTION. Text, underlined, in a 48dp target.
///
/// "Retry", "Fix", "Copy id", "Undo". It has no fill and no border, so the
/// **underline is what makes it findable without colour** — a coloured word
/// with no rule under it is a word, and this system does not identify anything
/// by hue alone.
///
/// The underline is drawn as a rule 3dp below the text rather than set as
/// `TextDecoration.underline`, because a text decoration sits on the baseline,
/// cannot be given a weight independent of the font, and thickens
/// unpredictably across the two faces. A 2px rule that steps to 3px on press is
/// a second press channel that costs nothing.
///
/// At most twice in any one container. Inside a soft row it sits at the
/// trailing edge and takes the tap from the row.
///
/// **Amber: none.** No [TorchClaim].
class TorchTertiaryButton extends StatelessWidget {
  const TorchTertiaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.destructive = false,
    this.litClaimId,
    this.busy = false,
    this.semanticLabel,
  });

  /// Specific enough to be unique on the screen. "Retry" alone is forbidden
  /// where two retries can appear — "Retry sending the shelf photo".
  final String label;

  final VoidCallback? onPressed;

  /// A 16dp 2px-stroke leading glyph with a 6dp gap.
  final IconData? icon;

  /// Ink and rule step to `bad`, and a 12dp filled triangle precedes the
  /// label. The triangle is a shape, so it survives greyscale.
  final bool destructive;

  /// The [TorchClaim] id under which this underline asks to be amber, or null
  /// for the ordinary `edgeControl` rule.
  ///
  /// **It asks; it never decides.** The approved sign-in mockup draws this
  /// underline in Burning Flame, and on a dark ground that fits — the door's
  /// budget is two and the commit is the other one. On a **light** ground the
  /// budget is one, and measuring it is what settled this: button plus
  /// underline painted *"2 amber objects against a budget of 1"*.
  ///
  /// So it goes through the ladder like every other lit object. At rung 5 it
  /// sits under `primaryCommit`, which means:
  ///
  /// * empty form — nothing is armed, no grant, neutral rule. The census's own
  ///   standing rule is that a screen with nothing to do carries no light, and
  ///   an always-amber underline would have made the way *out* the brightest
  ///   thing on a form you cannot yet submit.
  /// * dark, armed — commit takes rung 1, this takes rung 5, two objects
  ///   against a budget of two. The mockup, exactly.
  /// * light, armed — the commit takes the only grant and this falls back.
  ///
  /// That is not "a door lit differently per skin" by accident; it is the
  /// documented precedence doing the job it exists for, the same way the
  /// plate's strip light already gives way.
  final String? litClaimId;

  final bool busy;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final enabled = onPressed != null && !busy;
    final disabled = onPressed == null && !busy;
    final target = torchTapTarget(skin);
    final token = torchTextLabelToken(skin);

    return TorchPressable(
      onPressed: enabled ? onPressed : null,
      // The node lives on the pressable, so `onTap` is the same debounced,
      // haptic fire the finger gets.
      semanticsEnabled: enabled,
      semanticsLabel: busy
          ? '${semanticLabel ?? label}, working'
          : (semanticLabel ?? label),
      // No fill and no scale: the underline and the weight are the two
      // channels, which is why this one does not move.
      pressScale: 1,
      builder: (context, pressed) {
        final ink = disabled ? p.inkMute : (destructive ? p.bad : p.ink1);
        // THE RULE, AND WHEN IT IS AMBER.
        //
        // `edgeControl` by default: this control is findable by its underline
        // and its weight, not by hue, which is what lets it survive greyscale.
        //
        // [lit] is the approved sign-in mockup's own treatment — *"do it
        // exactly"*, 30 September 2026 — and it is amber because on that
        // screen the underline is the only thing marking the way out of a
        // form whose one other object is the commit. It is opt-in and it is
        // used once: amber is emitted light and the budget is counted, so a
        // second caller is a decision, not a style.
        final rule = disabled
            ? null
            : destructive
            ? p.bad
            : (litClaimId != null && TorchScope.lit(context, litClaimId!))
            ? p.flame600
            : p.edgeControl;
        final style = token
            .style(color: ink)
            .copyWith(fontWeight: pressed ? FontWeight.w700 : token.weight);
        return ConstrainedBox(
          constraints: BoxConstraints(minWidth: target, minHeight: target),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TiqSpace.s3,
              vertical: 14,
            ),
            child: Center(
              heightFactor: 1,
              widthFactor: 1,
              // `IntrinsicWidth` is what makes the rule exactly as long as
              // the label, at any text scale and in any language, without
              // anybody measuring a string.
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (destructive) ...<Widget>[
                          Padding(
                            padding: EdgeInsets.only(top: token.size * 0.25),
                            child: TorchTriangle(
                              color: ink,
                              size: 12,
                              filled: !disabled,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ] else if (icon != null) ...<Widget>[
                          Padding(
                            padding: EdgeInsets.only(top: token.size * 0.1),
                            child: TorchGlyph(icon, size: 16, color: ink),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: busy
                              ? TorchBusyDots(color: p.ink2, size: 4, gap: 6)
                              : Text(label, style: style),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (rule != null)
                      Container(
                        // One step over the skin's structural width, and one
                        // step thicker again while it is held.
                        height: skin.depth.borderWidth + 1 + (pressed ? 1 : 0),
                        color: rule,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

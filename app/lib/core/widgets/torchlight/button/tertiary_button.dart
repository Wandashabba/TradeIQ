import 'package:flutter/widgets.dart';

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
        final rule = disabled ? null : (destructive ? p.bad : p.edgeControl);
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
                        // 2px in Night and Day, 3px in Veld, and one step
                        // thicker while it is held.
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

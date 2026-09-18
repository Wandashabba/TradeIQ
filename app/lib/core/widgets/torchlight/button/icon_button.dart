import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import 'torch_button.dart';
import 'torch_press.dart';

/// A SINGLE GLYPH, WITH A LABEL THAT CANNOT BE OMITTED.
///
/// Back, close, overflow, torch, skin cycle. [semanticLabel] is a **required**
/// constructor argument: this widget will not compile without one. That is the
/// whole reason it exists in a system that already had `IconButton` — the audit
/// found 26 unlabelled ones, every single one of them added by someone
/// reasonable who was going to come back to it.
///
/// ## Toggled on is a block plus a word, never a colour
///
/// unify §1.23 is the one place the reconciled system corrects the spec's own
/// text: the spec gave a toggled-on icon button an amber glyph on light grounds,
/// and it does not get one. A toggle state is a **label**. So toggled-on is a
/// solid Abyssal block (`lifted`, in every skin) carrying Palladian or white
/// ink, **plus the state word**, which is why [stateWord] is required whenever
/// [toggledOn] is true.
///
/// **Amber: none, in any skin.** No [TorchClaim].
class TorchIconButton extends StatelessWidget {
  const TorchIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.toggledOn = false,
    this.stateWord,
    this.onLongPress,
    this.glyphSize,
  }) : assert(
         semanticLabel.length > 0,
         'An icon button with an empty label is an unlabelled icon button.',
       ),
       assert(
         !toggledOn || stateWord != null,
         'A toggled-on icon button carries the word as well as the block. '
         'Colour is never the only signal, and neither is a fill step: '
         'unify §1.23 replaced the spec\'s amber glyph with a block and a '
         'word precisely so the state survives greyscale and a screen reader.',
       );

  final IconData icon;

  /// What the button does, as a phrase a screen reader can read on its own.
  /// "Back to Today", never "Back".
  final String semanticLabel;

  final VoidCallback? onPressed;

  /// Torch on, skin pinned, filter active.
  final bool toggledOn;

  /// "On", "Veld", "3 filters" — rendered beside the glyph inside the block.
  final String? stateWord;

  final VoidCallback? onLongPress;

  /// 24dp by default, 26 in Veld. A component that carries meaning in this
  /// glyph — a nav slot gone icon-only — passes a bigger number rather than
  /// letting the ambient scaler do it.
  final double? glyphSize;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final enabled = onPressed != null;
    final floor = torchTapTarget(skin);
    // The glyph does not scale with the text — a chevron is not a word — but
    // the TARGET does, because a reader at 2.0× is usually a reader whose aim
    // is also less precise. 48 grows to 56, and Veld's 56 to 64.
    final target = MediaQuery.textScalerOf(
      context,
    ).scale(floor).clamp(floor, floor >= 56 ? 64.0 : 56.0);
    final radius = BorderRadius.circular(skin.radii.control);
    final press = torchPressSurface(skin);
    final size = glyphSize ?? (skin.mode == SkinMode.veld ? 26 : 24);

    return Semantics(
      button: true,
      enabled: enabled,
      toggled: toggledOn,
      label: semanticLabel,
      excludeSemantics: true,
      child: TorchPressable(
        onPressed: onPressed,
        onLongPress: onLongPress,
        borderRadius: radius,
        pressScale: torchPressScaleGlyph,
        builder: (context, pressed) {
          final Color? fill;
          final Color ink;
          final Color? edge;
          if (!enabled) {
            fill = null;
            ink = p.inkMute;
            edge = null;
          } else if (toggledOn) {
            fill = torchAbyssal(skin);
            ink = torchOnAbyssal(skin);
            edge = p.edgeControl;
          } else if (pressed) {
            fill = press.fill;
            ink = press.ink;
            edge = null;
          } else {
            fill = null;
            ink = p.ink1;
            edge = null;
          }

          final word = toggledOn ? stateWord : null;
          return Container(
            constraints: BoxConstraints(minWidth: target, minHeight: target),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: radius,
              border: edge == null
                  ? null
                  : Border.all(color: edge, width: skin.depth.borderWidth),
            ),
            padding: word == null
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: TiqSpace.s3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                TorchGlyph(icon, size: size, color: ink),
                if (word != null) ...<Widget>[
                  const SizedBox(width: 6),
                  Text(word, style: skin.text.eyebrow.style(color: ink)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

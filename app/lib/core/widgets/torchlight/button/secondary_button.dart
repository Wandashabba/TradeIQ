import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import 'torch_button.dart';
import 'torch_press.dart';

/// THE CREDIBLE ALTERNATIVE. A ghost, at the primary's exact geometry.
///
/// "Start over", "Search by name", "Keep it on my route". It differs from the
/// primary by **fill** and by nothing else: same height, same radius, same
/// label role, same wrap-and-grow behaviour at 2.0×. That is deliberate — a
/// secondary that was also shorter and quieter would read as a hint rather than
/// a choice, and the whole point of the pairing is that the alternative is
/// genuinely available.
///
/// Never more than one beside a primary. A third option becomes a
/// [TorchTertiaryButton] or moves into an overflow sheet. In a two-button
/// column — the Field default — the primary is on top and the secondary sits
/// beneath it at a 12dp gap, because the bottom-most control under a thumb must
/// not be the one that throws work away.
///
/// **Amber: none, ever.** It declares no [TorchClaim] and names no flame token.
class TorchSecondaryButton extends StatelessWidget {
  const TorchSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.blockedReason,
    this.busy = false,
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;

  /// A disabled secondary explains itself for the same reason a primary does.
  /// It is not asserted here only because a secondary is sometimes disabled by
  /// the same blocker the primary above it already named, and two copies of one
  /// sentence is worse than one.
  final String? blockedReason;

  final bool busy;
  final IconData? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final enabled = onPressed != null && !busy;
    final disabled = onPressed == null && !busy;
    final radius = BorderRadius.circular(skin.radii.control);
    final press = torchPressSurface(skin);

    final button = TorchPressable(
      onPressed: enabled ? onPressed : null,
      // The node lives on the pressable, so `onTap` is the same
      // debounced, haptic fire the finger gets. A `Semantics` wrapped
      // AROUND this with `excludeSemantics: true` and no `onTap` is a
      // button a screen reader can read and cannot press.
      semanticsEnabled: enabled,
      semanticsLabel: busy
          ? '${semanticLabel ?? label}, working'
          : (semanticLabel ?? label),
      borderRadius: radius,
      builder: (context, pressed) {
        final ink = disabled ? p.inkMute : (pressed ? press.ink : p.ink1);
        final edge = disabled ? p.inkMute : p.edgeControl;
        return Container(
          constraints: BoxConstraints(minHeight: torchBlockHeight(skin)),
          decoration: BoxDecoration(
            color: pressed ? press.fill : null,
            borderRadius: radius,
            border: Border.all(
              color: edge,
              // The press steps the edge as well as the fill. Night's fill step
              // is 1.67:1 on the ground — real, but not enough on a 6-bit panel
              // at 40% backlight, and under reduce-motion the scale is gone. An
              // edge that doubles is the channel that survives both.
              width: pressed
                  ? skin.depth.borderWidth * 2
                  : skin.depth.borderWidth,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: torchBlockPadding(skin),
              vertical: torchBlockGrowthPadding,
            ),
            child: Center(
              heightFactor: 1,
              child: busy
                  ? TorchBusyDots(color: p.ink2)
                  : TorchButtonLabel(
                      label: label,
                      icon: icon,
                      style: torchBlockLabelToken(skin).style(color: ink),
                    ),
            ),
          ),
        );
      },
    );

    final semantics = button;

    final note = blockedReason;
    if (!disabled || note == null) return semantics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TorchBarNote(note),
        const SizedBox(height: TiqSpace.s2),
        semantics,
      ],
    );
  }
}

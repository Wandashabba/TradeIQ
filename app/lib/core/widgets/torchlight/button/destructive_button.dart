import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import 'torch_button.dart';
import 'torch_press.dart';

/// THROWING CAPTURED WORK AWAY. Outlined crimson, with a drawn triangle.
///
/// "Start over", "Discard this visit", "Remove competitor". It never takes the
/// primary's geometry-and-fill — a solid crimson block at the bottom of a thumb
/// zone is a primary action that happens to be red, and the one thing this
/// button must never look like is the thing the thumb is resting on.
///
/// The **solid** form exists for exactly one place: the confirming button
/// inside a decision sheet, where the user has already read the proof block and
/// the destruction is the thing they came to do. [TorchDestructiveButton.confirming]
/// is that form, and its name is the documentation.
///
/// It **always opens a decision sheet** and never acts on first press. The
/// first press is `Buzz.warning`; the safe path completes with `Buzz.success`;
/// the destructive path completes with nothing at all, because a congratulatory
/// buzz after deleting a morning's work is an insult.
///
/// **Guarded.** Where the work being destroyed is unsent, the label carries the
/// count — "Discard 12 held captures" — and the button will not render without
/// it. Pass [busy] while the count is still resolving: busy, never enabled.
///
/// **Amber: none, categorically.** There is no amber warning in TradeIQ.
class TorchDestructiveButton extends StatelessWidget {
  const TorchDestructiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.blockedReason,
    this.busy = false,
    this.semanticLabel,
  }) : solid = false,
       assert(
         onPressed != null || busy || blockedReason != null,
         'A disabled destructive button says what is missing, like every '
         'other disabled control in this system.',
       );

  /// The confirming press **inside a decision sheet**, and nowhere else.
  const TorchDestructiveButton.confirming({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.semanticLabel,
  }) : solid = true,
       blockedReason = null;

  /// The verb and what is lost: "Start over, 12 captures are deleted".
  final String label;

  final VoidCallback? onPressed;
  final String? blockedReason;
  final bool busy;
  final String? semanticLabel;

  /// True only for [TorchDestructiveButton.confirming].
  final bool solid;

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
      borderRadius: radius,
      // Heavier than a tick, because what happens next is heavier.
      haptic: TorchBuzz.warning,
      builder: (context, pressed) {
        final Color? fill;
        final Color ink;
        final Color edge;
        if (solid) {
          fill = p.badSolid;
          ink = p.onBadSolid;
          // Veld's `bad` and `badSolid` are the same hex, so a fill step is not
          // available there at all. The edge stepping to ink-1 is the press
          // channel that exists in every skin.
          edge = pressed ? p.ink1 : p.badSolid;
        } else if (disabled) {
          fill = null;
          ink = p.inkMute;
          edge = p.inkMute;
        } else {
          fill = pressed ? press.fill : null;
          ink = p.bad;
          edge = p.bad;
        }
        return Container(
          constraints: BoxConstraints(minHeight: torchBlockHeight(skin)),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: radius,
            border: Border.all(
              color: edge,
              // 2px in Night and Day, 4px in Veld — the destructive outline is
              // the loudest edge in the system and it says so in every skin.
              width: skin.depth.borderWidth * 2,
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
                  ? TorchBusyDots(color: ink)
                  : TorchButtonLabel(
                      label: label,
                      style: torchBlockLabelToken(skin).style(color: ink),
                      // Filled means live, outlined means disabled. Two
                      // silhouettes, no hue required.
                      leading: TorchTriangle(
                        color: ink,
                        size: 16,
                        filled: !disabled,
                      ),
                    ),
            ),
          ),
        );
      },
    );

    final semantics = Semantics(
      button: true,
      enabled: enabled,
      label: busy
          ? '${semanticLabel ?? label}, working'
          : (semanticLabel ?? label),
      excludeSemantics: true,
      child: button,
    );

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

import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';

/// THE 96DP REGION AT THE BOTTOM OF THE THUMB.
///
/// It holds the skin cycle at the leading gutter and the primary action beside
/// it, and it is separated from the body by a rule across the **full bleed** —
/// a gutter-inset rule under a full-bleed region reads as an underline on the
/// content rather than a floor under the controls.
///
/// Three shapes, one of which always applies:
///
/// | | height | contents |
/// |---|---|---|
/// | a screen with a primary | 96 (Veld 112) | `[cycle 56] [12] [primary, Expanded]` |
/// | with a second action | 160 | the ghost above the primary at 8dp |
/// | a screen with no primary | 76 | the skin cycle alone, no rule |
///
/// The second action goes **above** the primary, not beneath it. The thumb
/// rests at the bottom of the screen, the primary is what the thumb is for, and
/// a control that throws work away must never be the bottom-most thing under a
/// thumb that is already moving.
///
/// Every height here is a **minimum**. At 2.0× the zone grows to about 128dp on
/// its own, because the primary's label wraps and the primary grows — nothing
/// in this region is pinned.
class TorchThumbZone extends StatelessWidget {
  const TorchThumbZone({
    super.key,
    this.skinCycle,
    this.primary,
    this.secondary,
  }) : assert(
         skinCycle != null || primary != null,
         'A thumb zone with neither a primary nor a skin cycle is 96dp of '
         'nothing above a hairline. Render no zone at all instead.',
       );

  /// The skin cycle, at the leading gutter. Never absent on an agent screen:
  /// the one control that gets a person out of a skin they cannot read has to
  /// be on every screen they can get stuck on.
  final Widget? skinCycle;

  /// The route's one commit action.
  final Widget? primary;

  /// A ghost alternative, above the primary.
  final Widget? secondary;

  /// The zone's minimum height for this skin and shape.
  static double minHeightFor(
    TiqSkin skin, {
    required bool hasPrimary,
    required bool hasSecondary,
  }) {
    if (!hasPrimary) return 76;
    final base = skin.mode == SkinMode.veld ? 112.0 : 96.0;
    return hasSecondary ? base + 64 : base;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final hasPrimary = primary != null;
    final gutter = skin.space.gutter;

    final rule = hasPrimary
        ? Container(
            height: skin.depth.borderWidth,
            color: skin.mode == SkinMode.veld ? p.edgeStructure : p.hairline,
          )
        // Never a rule over nothing: the cycle-only zone is the ground it sits
        // on, and a line there would announce a region that has no contents.
        : const SizedBox.shrink();

    return ColoredBox(
      color: p.ground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          rule,
          Container(
            constraints: BoxConstraints(
              minHeight: minHeightFor(
                skin,
                hasPrimary: hasPrimary,
                hasSecondary: secondary != null,
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              gutter,
              skin.space.intraBlock,
              gutter,
              skin.space.intraBlock,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (secondary != null) ...<Widget>[
                  secondary!,
                  const SizedBox(height: TiqSpace.s2),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    if (skinCycle != null) ...<Widget>[
                      skinCycle!,
                      if (hasPrimary) const SizedBox(width: TiqSpace.s3),
                    ],
                    if (hasPrimary) Expanded(child: primary!),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

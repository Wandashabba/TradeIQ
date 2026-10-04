import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';

/// THE 96DP REGION AT THE BOTTOM OF THE THUMB.
///
/// It holds the primary action, and it is separated from the body by a rule
/// across the **full bleed** — a gutter-inset rule under a full-bleed region
/// reads as an underline on the content rather than a floor under the controls.
///
/// Four shapes, one of which always applies:
///
/// | | height | contents |
/// |---|---|---|
/// | a screen with a primary | 96 | `[primary, Expanded]` |
/// | with a second action | 160 | the ghost above the primary at 8dp |
/// | a ghost and no primary | 76 | the ghost alone, no rule |
/// | neither | — | no zone at all; [TorchShell] renders none |
///
/// The second action goes **above** the primary, not beneath it. The thumb
/// rests at the bottom of the screen, the primary is what the thumb is for, and
/// a control that throws work away must never be the bottom-most thing under a
/// thumb that is already moving.
///
/// Every height here is a **minimum**. At 2.0× the zone grows to about 128dp on
/// its own, because the primary's label wraps and the primary grows — nothing
/// in this region is pinned.
///
/// ## The cycle column is empty, and the row goes with it
///
/// Row three used to read *"a screen with no primary | 76 | the skin cycle
/// alone, no rule"*. The theme control left every screen but Me on 4 October
/// 2026 (see [TorchShell.skinCycle]), so the shape it named is now the shape
/// **a lone ghost** has — the store picker's *Add a store*, and the visit's
/// *Back to my route* while the radar is still looking for a fix.
///
/// Two things had to move for that to render rather than crash. The constructor
/// asserted `skinCycle != null || primary != null`, which a secondary-only zone
/// fails; and the control [Row] was built unconditionally with an 8dp gap above
/// it, so a zone whose row had emptied carried 8dp of nothing under its ghost.
class TorchThumbZone extends StatelessWidget {
  const TorchThumbZone({
    super.key,
    this.skinCycle,
    this.primary,
    this.secondary,
    this.underPrimary,
  }) : assert(
         skinCycle != null ||
             primary != null ||
             secondary != null ||
             underPrimary != null,
         'An empty thumb zone is 76dp of nothing above a hairline. Render no '
         'zone at all instead — TorchShell._bottomRegion returns null when '
         'all four slots are empty, and that is the only correct answer.',
       );

  /// The skin cycle, at the leading gutter.
  ///
  /// **Null everywhere.** The theme control is the `THIS APP` row on Me and
  /// the menu sheet's `THIS APP` section, and nowhere else — see
  /// [TorchShell.skinCycle] for the owner's three asks.
  final Widget? skinCycle;

  /// The route's one commit action.
  final Widget? primary;

  /// A ghost alternative, above the primary.
  final Widget? secondary;

  /// One quiet action directly UNDER the commit, centred.
  ///
  /// [secondary] sits above the primary and is a second *action*; this is the
  /// way out of the screen, and the approved sign-in mockup puts it here. Null
  /// everywhere else, so no existing thumb zone moves.
  final Widget? underPrimary;

  /// The zone's minimum height for this skin and shape.
  static double minHeightFor(
    TiqSkin skin, {
    required bool hasPrimary,
    required bool hasSecondary,
  }) {
    if (!hasPrimary) return 76;
    const base = 96.0;
    return hasSecondary ? base + 64 : base;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final hasPrimary = primary != null;
    final gutter = skin.space.gutter;

    final rule = hasPrimary
        ? Container(height: skin.depth.borderWidth, color: p.hairline)
        // Never a rule over nothing: a zone with no commit is the ground it
        // sits on, and a line there would announce a floor under a region
        // that carries a single ghost.
        : const SizedBox.shrink();

    // The leading-gutter row exists only if something goes in it. With the
    // cycle gone from every screen, a zone with no primary has an empty row —
    // and an empty Row still consumes the 8dp gap written above it.
    final hasRow = skinCycle != null || hasPrimary;

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
                  if (hasRow) const SizedBox(height: TiqSpace.s2),
                ],
                if (hasRow)
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
                if (underPrimary != null) ...<Widget>[
                  // Only a gap between two things. A zone holding nothing but
                  // the under-primary would otherwise open with one.
                  if (hasRow || secondary != null)
                    SizedBox(height: skin.space.intraBlock),
                  Center(child: underPrimary),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

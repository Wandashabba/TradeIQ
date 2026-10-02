import 'package:flutter/widgets.dart';

import '../../../design/torch_scope.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import '../button/torch_button.dart';
import '../button/torch_press.dart';
import 'nav_pill.dart' show torchPillRadius;

/// THE ROLE'S STANDING ACTION. 64dp, outside the bar, 12dp gap.
///
/// A manager raises a task; an agent starts an unplanned visit. It is the one
/// thing a person can always do from a tab root, which is why it sits outside
/// the pill rather than inside it — a destination and an action are different
/// kinds of thing and a bar that mixes them teaches neither.
///
/// ## Amber, and the rung it sits on
///
/// It declares [TorchClaimKind.navCircle], **rung 4**, and the allocator denies
/// it outright — not on budget, but by rule — on any route that has a primary
/// commit action. The circle is below the primary on the ladder because a
/// screen with a commit action on it is a screen about that commit action.
///
/// So it is amber **only** when it is the expected next move *and* there is no
/// primary on the route *and* the ground is dark. On a light ground it is
/// never amber at all: there, one amber block per screen exists and it belongs
/// to the primary.
///
/// ## Expected is not a colour
///
/// Whether the circle is the expected next move is carried by the **glyph**
/// (outlined plus → filled arrow) and by the **spoken label**, before any fill
/// changes. That is what makes the state survive greyscale, deuteranopia, a
/// light ground where it is never amber, and a screen reader.
class TorchNavCircle extends StatelessWidget {
  const TorchNavCircle({
    super.key,
    required this.claimId,
    required this.expected,
    required this.icon,
    required this.expectedIcon,
    required this.semanticLabel,
    required this.expectedSemanticLabel,
    required this.onPressed,
    this.busy = false,
    this.blockedReason,
  }) : assert(
         semanticLabel.length > 0 && expectedSemanticLabel.length > 0,
         'The circle takes a verb phrase — "Start a visit here", never "Add".',
       );

  /// The id this circle is registered under in the route's [TorchScope].
  final String claimId;

  /// Whether this is the expected next move: the route is finished, or the
  /// agent is standing still inside an unplanned outlet's fence.
  final bool expected;

  /// The not-expected glyph. An outlined plus.
  final IconData icon;

  /// The expected glyph. A filled arrow — a different silhouette, not a
  /// different colour.
  final IconData expectedIcon;

  final String semanticLabel;
  final String expectedSemanticLabel;

  /// Null disables it: the role has the action but not right now — no GPS fix,
  /// say. A disabled circle's tap should raise a toast naming the blocker
  /// rather than doing nothing; [blockedReason] is that sentence.
  final VoidCallback? onPressed;

  final bool busy;

  /// Why it cannot fire. Spoken, and available to the caller for its toast.
  final String? blockedReason;

  /// The claim a route declares for a circle with this [id] — **only** when it
  /// is the expected next move. Declaring it unconditionally would spend a
  /// grant on a circle that is not asking for one.
  static TorchClaim claim(String id) => TorchClaim.navCircle(id);

  /// 64dp in every skin. It is the primary action of a tab root, so it cannot
  /// be the 56 the manager surface drew.
  static const double diameter = 64;

  /// The gap between the pill and the circle.
  static const double gap = TiqSpace.s3;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final enabled = onPressed != null && !busy;
    final granted = expected && TorchScope.lit(context, claimId);
    // Four inputs — `enabled`, `granted`, `pressed`, and `expected` inside
    // `granted` — and every one of them changes under a live tree: the agent
    // finishes their last stop and the circle becomes the expected next move;
    // a sheet opens and the allocator takes the grant back; a GPS fix is lost
    // and the circle goes dead. Each of those was a one-frame jump between two
    // fills, two inks and two border widths. `AnimatedContainer` lerps the
    // whole decoration — fill, rim colour, rim width and Day's shadow — in one
    // widget, and [TorchInk] brings the glyph with it.
    final duration = torchStateDuration(context, TiqMotion.press);

    return Semantics(
      button: true,
      enabled: enabled,
      label: enabled
          ? (expected ? expectedSemanticLabel : semanticLabel)
          : '${expected ? expectedSemanticLabel : semanticLabel}'
                '${blockedReason == null ? '' : ', $blockedReason'}',
      // THE ACTION, not only the flag: `excludeSemantics` drops the
      // gesture detector's own node, so without `onTap` here this is a
      // control a screen reader can focus and cannot activate.
      onTap: onPressed,
      excludeSemantics: true,
      child: TorchPressable(
        onPressed: onPressed,
        shape: BoxShape.circle,
        borderRadius: BorderRadius.circular(torchPillRadius),
        pressScale: torchPressScaleGlyph,
        builder: (context, pressed) {
          final Color fill;
          final Color ink;
          final Color? edge;
          double edgeWidth = skin.depth.borderWidth;
          // THE GRANTED DISC IS A GRADIENT AS OF 1 OCTOBER 2026 — see
          // `_grantedRamp`. Non-null only in the one granted, unpressed state.
          Gradient? ramp;
          if (!enabled) {
            fill = p.well;
            ink = p.inkMute;
            edge = p.edgeControl;
          } else if (granted && pressed) {
            fill = p.amberPressed;
            ink = p.onAmberPressed;
            edge = skin.amberIsInk ? p.ink1 : null;
          } else if (granted) {
            fill = p.flame600;
            ink = p.onAmber;
            // On a light ground an amber disc on paper is 1.6:1 against its
            // own ground, so it carries a real edge like every other block.
            edge = skin.amberIsInk ? p.ink1 : null;
            ramp = _grantedRamp(skin);
          } else if (pressed) {
            final press = torchPressSurface(skin);
            fill = press.fill;
            ink = press.ink;
            edge = p.edgeControl;
            edgeWidth = skin.depth.borderWidth * 2;
          } else {
            // Not expected, or expected and denied. On a dark ground it is the
            // `lifted` disc with an edge-control rim; on a light one it is the
            // panel surface, because `lifted` there is an ink block and an ink
            // block is what the nav's *selected* tab looks like.
            fill = skin.amberIsInk ? p.surface : p.lifted;
            ink = p.ink1;
            edge = p.edgeControl;
          }

          return TorchInk(
            color: ink,
            duration: duration,
            builder: (context, ink) => AnimatedContainer(
              duration: duration,
              curve: TiqMotion.stateCurve,
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                // `color` is the flat fallback and `gradient` wins wherever it
                // is non-null, which is the granted disc alone. See
                // `_grantedRamp`.
                color: fill,
                gradient: ramp,
                shape: BoxShape.circle,
                border: edge == null
                    ? null
                    : Border.all(color: edge, width: edgeWidth),
                // Day is the one skin with a shadow budget, and a floating
                // disc is exactly what sh2 is for. Night has none (black on
                // black).
                boxShadow:
                    skin.mode == SkinMode.day &&
                        enabled &&
                        skin.depth.sh2 != null
                    ? <BoxShadow>[skin.depth.sh2!]
                    : null,
              ),
              child: Center(
                child: busy
                    ? TorchBusyDots(color: ink, size: 5, gap: 5)
                    : TorchGlyph(
                        expected ? expectedIcon : icon,
                        size: 26,
                        color: ink,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// THE STANDING ACTION'S GRADIENT — a radial, off-centre, 1 October 2026.
///
/// The owner: *"the send button on the app and everywhere else for orange is
/// very dull, it need to be lumunous and bright and inviting."* This disc was
/// a flat `flame600` at value 1.00, so a hot core is the only luminosity left
/// to add; the chroma half is in `tiq_palette.dart`.
///
/// **Radial, and the same geometry as the composer's send disc** — centre at
/// `Alignment(-0.35, -0.45)`, radius `0.95`. It is a circle, so it wants a
/// point source rather than the linear wash a wide block wants; and it is the
/// *same* control in a different place, so it must be lit from the same
/// direction as the send key. Two round amber objects lit from two different
/// corners would read as two light sources in one room, which is the sort of
/// thing nobody can name and everybody notices.
///
/// 64dp here against the send disc's 36dp, and the geometry is in fractional
/// units, so the falloff scales with the object and the two read as the same
/// material at two sizes.
///
/// THE WORST POINT UNDER THE GLYPH is `flame600`: [TiqSkin.amberFillRamp]'s
/// last stop is `flame600` and the ramp goes no further, so the 26dp glyph's
/// coldest pixel is the colour the flat disc painted. 9.68:1 on Night and
/// 7.78:1 on Day, both unchanged by this gradient.
///
/// The Day `sh2` shadow is untouched and still sits on the decoration beside
/// this — that is the one skin with a shadow budget, and this is a gradient
/// rather than an added shadow precisely because the paint budget forbids a
/// `BoxShadow` for an amber glow.
Gradient? _grantedRamp(TiqSkin skin) => skin.depth.allowsGradients
    ? RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 0.95,
        colors: skin.amberFillRamp,
      )
    : null;

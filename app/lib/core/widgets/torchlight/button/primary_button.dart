import 'package:flutter/widgets.dart';

import '../../../design/torch_scope.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import 'torch_button.dart';
import 'torch_press.dart';

/// THE COMMIT ACTION. One per route, and the first rung of the amber ladder.
///
/// ## It claims amber; it does not paint it
///
/// The button never asks "am I on a dark ground" or "is something else already
/// lit". It asks [TorchScope] whether the id it was given is lit on this route,
/// and it paints its granted or its denied form accordingly. The route declares
/// the claim:
///
/// ```dart
/// TorchScope(
///   skin: context.skin,
///   phase: 'loaded',
///   navRenders: true,
///   tabbedRoute: true,
///   claims: <TorchClaim>[TorchPrimaryButton.claim('submit-visit')],
///   child: TorchShell(
///     primary: TorchPrimaryButton(
///       claimId: 'submit-visit',
///       label: 'Send this visit',
///       onPressed: _submit,
///     ),
///     …
///   ),
/// )
/// ```
///
/// That separation is the whole mechanism. A button that decided for itself
/// would be lit on every route including the ones that already have two lights,
/// and the census would catch it a week later on the one screen somebody
/// remembered to write a golden for.
///
/// ## What it looks like
///
/// * **Night, granted** — a `lifted` block with a **1px flame-600 rim** and a
///   **2dp amber gradient bleed along the top inside edge**, label in Palladian.
///   The rim and the bleed touch, so the pixel census counts them as **one**
///   object, which is what unify §1.7 means by "rim + 2dp top bleed is one
///   object". The block itself is not amber; it is a dark block that is *lit*.
/// * **Day and Veld** — a solid amber block with dark ink on it. On a light
///   ground amber stops being light and becomes a carrier of ink, and there is
///   exactly one of those per screen.
/// * **Pressed** — floods to `amberPressed` with `onAmberPressed` on it. In
///   Night that is flame-500 with `#0B1017` at 8.59:1, exactly as §1.7 asks.
///   Veld does **not** lighten: `#0E141A` on flame-500 is 8.34:1, under the 9:1
///   floor Veld declares for every word it shows, so Veld's press inverts to the
///   ink block with white on it. That is the palette's own argued answer and it
///   is read from the token rather than restated here.
/// * **Disabled** — a `well` block with ink-mute on it, its edge-control
///   outline retained, and a [TorchBarNote] **above it naming exactly what is
///   missing**. The note is a constructor requirement, not a convention.
class TorchPrimaryButton extends StatelessWidget {
  const TorchPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.claimId,
    this.blockedReason,
    this.busy = false,
    this.icon,
    this.semanticLabel,
  }) : assert(
         onPressed != null || busy || blockedReason != null,
         'A disabled primary carries a BarNote naming exactly what is '
         'missing. A dead grey button with no explanation is, in a shop, a '
         'phone call to the office — so `blockedReason` is required whenever '
         '`onPressed` is null and the button is not busy.',
       );

  /// The verb phrase. Never "OK", never "Submit" on its own.
  final String label;

  /// Null disables the button, and then [blockedReason] must say why.
  final VoidCallback? onPressed;

  /// The id this button is registered under in the route's [TorchScope].
  final String claimId;

  /// What is missing. Rendered above the button at meta 12/400 ink-3, wrapping,
  /// never truncated, as a live region.
  final String? blockedReason;

  /// Committing. The label becomes three dots, the button keeps its exact
  /// width, taps are swallowed and the semantic label gains ", sending".
  final bool busy;

  /// An 18dp 2px-stroke leading glyph with an 8dp gap.
  final IconData? icon;

  /// Overrides the spoken label where the visible verb is not the whole
  /// sentence.
  final String? semanticLabel;

  /// The claim a route declares for a primary with this [id].
  static TorchClaim claim(String id) => TorchClaim.primaryCommit(id);

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final lit = TorchScope.lit(context, claimId);
    final enabled = onPressed != null && !busy;
    final disabled = onPressed == null && !busy;
    final radius = BorderRadius.circular(skin.radii.control);
    final labelStyle = torchBlockLabelToken(skin);

    final button = TorchPressable(
      onPressed: enabled ? onPressed : null,
      // The node lives on the pressable, so `onTap` is the same
      // debounced, haptic fire the finger gets. A `Semantics` wrapped
      // AROUND this with `excludeSemantics: true` and no `onTap` is a
      // button a screen reader can read and cannot press.
      semanticsEnabled: enabled,
      semanticsLabel: busy
          ? '${semanticLabel ?? label}, sending'
          : (semanticLabel ?? label),
      borderRadius: radius,
      // The cost of a double-tapped commit is a duplicate visit, not a
      // duplicate keystroke.
      debounce: const Duration(milliseconds: 400),
      builder: (context, pressed) {
        final look = _look(
          skin: skin,
          lit: lit,
          disabled: disabled,
          pressed: pressed,
        );
        Widget content = Padding(
          padding: EdgeInsets.symmetric(
            horizontal: torchBlockPadding(skin),
            vertical: torchBlockGrowthPadding,
          ),
          child: Center(
            heightFactor: 1,
            child: busy
                ? TorchBusyDots(color: look.ink)
                : TorchButtonLabel(
                    label: label,
                    icon: icon,
                    style: labelStyle.style(color: look.ink),
                  ),
          ),
        );

        if (look.bleed) {
          content = Stack(
            children: <Widget>[
              content,
              // The bleed is inset by the radius so it runs along the flat top
              // edge and never paints over the rim's corner arcs — which also
              // means no clip, and this system has a zero-`saveLayer` budget.
              Positioned(
                left: skin.radii.control,
                right: skin.radii.control,
                top: 0,
                height: 2,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: TiqPalette.glowAmber,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Container(
          constraints: BoxConstraints(minHeight: torchBlockHeight(skin)),
          decoration: BoxDecoration(
            color: look.fill,
            borderRadius: radius,
            border: look.edge == null
                ? null
                : Border.all(color: look.edge!, width: look.edgeWidth),
          ),
          child: content,
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

  _PrimaryLook _look({
    required TiqSkin skin,
    required bool lit,
    required bool disabled,
    required bool pressed,
  }) {
    final p = skin.palette;
    if (disabled) {
      // Disabled ink is deliberately sub-AA — a disabled control is exempt
      // under 1.4.3 and has to look disabled. The reason it is disabled is
      // carried by the BarNote, in ink-3, at full contrast.
      return _PrimaryLook(
        fill: p.well,
        ink: p.inkMute,
        edge: p.edgeControl,
        edgeWidth: skin.depth.borderWidth,
        bleed: false,
      );
    }
    if (pressed) {
      return _PrimaryLook(
        fill: p.amberPressed,
        ink: p.onAmberPressed,
        // Veld's press is an ink block, and an ink block on white needs its
        // border as much as an amber one does.
        edge: skin.amberIsInk ? p.ink1 : null,
        edgeWidth: skin.depth.borderWidth,
        bleed: false,
      );
    }
    if (!lit) {
      // DENIED. Still the heaviest thing on the screen by fill and by
      // position — it is simply not carrying the route's light. In Night that
      // is the `lifted` block it always was, minus the rim and the bleed; on a
      // light ground `lifted` is an ink block, so the denied form recedes to
      // the well instead.
      return _PrimaryLook(
        fill: skin.amberIsInk ? p.well : p.lifted,
        ink: p.ink1,
        edge: p.edgeControl,
        edgeWidth: skin.depth.borderWidth,
        bleed: false,
      );
    }
    if (skin.amberIsInk) {
      // Day and Veld: a solid amber block carrying dark ink. It gets a real
      // edge because a `#FFB162` block on Palladian is 1.6:1 against its own
      // ground, and nothing in this system is identified by a fill alone.
      return _PrimaryLook(
        fill: p.flame600,
        ink: p.onAmber,
        edge: p.ink1,
        edgeWidth: skin.depth.borderWidth,
        bleed: false,
      );
    }
    // Night, granted.
    //
    // The rim is 2px and the design says 1px. That is a deliberate deviation
    // with a measurement behind it: a 1px stroke on a radius-10 shoulder
    // anti-aliases to roughly 72% value at the corner, which falls under the
    // pixel census's 0.90 value floor — so the census reads a 1px rim as
    // FOUR separate lights (top, bottom, left, right) instead of one rim, and
    // a correctly built commit button fails the budget it obeys. A rim the
    // enforcement mechanism cannot count is a rim that fails the law it
    // exists to serve. At 2px the corner pixels are fully covered, the ring
    // is one connected region, and it is still unmistakably a rim rather than
    // a block.
    return _PrimaryLook(
      fill: p.lifted,
      ink: p.ink1,
      edge: p.flame600,
      edgeWidth: 2,
      bleed: true,
    );
  }
}

@immutable
class _PrimaryLook {
  const _PrimaryLook({
    required this.fill,
    required this.ink,
    required this.edge,
    required this.edgeWidth,
    required this.bleed,
  });

  final Color fill;
  final Color ink;
  final Color? edge;
  final double edgeWidth;
  final bool bleed;
}

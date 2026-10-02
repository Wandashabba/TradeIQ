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
/// * **Night, granted, [filled]** — a solid `flame600` block carrying
///   `onAmber` at 9.68:1, no rim and no bleed. One call site (Today's
///   "Check in here"), by owner decision on 29 September 2026; see [filled].
/// * **Day** — a solid amber block with dark ink on it. On a light
///   ground amber stops being light and becomes a carrier of ink, and there is
///   exactly one of those per screen.
/// * **Pressed** — floods to `amberPressed` with `onAmberPressed` on it. In
///   Night that is flame-500 with `#0B1017` at 7.72:1, exactly as §1.7 asks.
///   The value is read from the token rather than restated here.
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
    this.filled = false,
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

  /// **THE FILLED FORM — one call site, by owner decision, 29 September 2026.**
  ///
  /// When this button is *granted* the route's light in **Night**, it paints a
  /// solid `flame600` block carrying `onAmber` (9.68:1) instead of the
  /// `lifted` block with the 2px flame rim and the 2dp top bleed. Day is
  /// unaffected: the Day granted form has been a solid amber block all along,
  /// which is why this is one branch and not two. Denied, pressed and disabled
  /// are all untouched, and so is [TiqRadii.control] — the radius does not
  /// move, because moving it would move the sign-in screen, and that is a
  /// question the owner is answering separately.
  ///
  /// ## Why it is a parameter rather than the new default
  ///
  /// §1.7's Night primary is deliberately *not* amber: "a dark block that is
  /// **lit**", on the reading that on a dark ground amber is light rather than
  /// paint, and a 2px rim plus a touching 2dp bleed is one object to the pixel
  /// census. That reading is intact and is still what every other primary in
  /// the app does.
  ///
  /// What it does not survive is the one screen the owner photographed. The
  /// approved mockup's Today draws this exact control as `.cta` — `background:
  /// #FFB162; color: #16202B; border-radius: 16px` for the in-row variant,
  /// — `#FFB162` being what `flame600` was until the ramp gained chroma on
  /// 1 October 2026; the token is `#FFA447` now and this control follows the
  /// token, not the drawing's literal hex —
  /// which is `radii.control` **exactly** — and the owner's note on the
  /// running build was that Check in here "reads weak and boxy". An outlined
  /// block among filled cards is the same complaint as an outlined tile among
  /// filled chips, one component up.
  ///
  /// It changes no budget. The census counts connected flame-hued *regions*,
  /// not area: a rim is one region and a filled block is one region, so Today
  /// still lights two objects in Night (the nav's active tab, then this) and
  /// one in Day (this; the tab has no amber form on a light ground). The lit
  /// *fraction* of the frame grows, which the census reports and does not
  /// budget.
  final bool filled;

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
            // `color` is the flat fallback and `gradient` wins wherever it is
            // non-null — which is only the two filled amber faces, and only in
            // a skin with a gradient budget. See [_amberFace].
            color: look.fill,
            gradient: look.ramp,
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

    // THE NOTE DOES NOT NEED A DEAD BUTTON — 30 September 2026.
    //
    // It used to render only while `disabled`, which quietly made press-time
    // validation impossible: a live button that knows what is missing had no
    // way to say it, and sign-in's note vanished the moment the button became
    // pressable. A button that can be pressed and refuses has MORE to explain
    // than one that cannot be pressed at all.
    //
    // Every existing caller is unchanged: they pass a reason only alongside a
    // null `onPressed`, so their note still appears exactly where it did.
    final note = blockedReason;
    if (note == null) return semantics;
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
      // Day: a solid amber block carrying dark ink. It gets a real
      // edge because a `#FFB162` block on Palladian is 1.6:1 against its own
      // ground, and nothing in this system is identified by a fill alone.
      return _PrimaryLook(
        fill: p.flame600,
        ink: p.onAmber,
        edge: p.ink1,
        edgeWidth: skin.depth.borderWidth,
        bleed: false,
        // Day's ramp stops at flame-700 rather than flame-900: on paper a
        // near-white core is 1.04:1 against Palladian and reads as a hole in
        // the block. See [TiqSkin.amberFillRamp].
        ramp: _amberFace(skin),
      );
    }
    if (filled) {
      // Night, granted, FILLED — see [filled]. A solid flame block carrying
      // `onAmber` at 9.68:1, and no rim: the rim exists to make a dark block
      // read as lit, and a block that IS the light has nothing to be rimmed
      // against. One connected region either way, so the budget does not move.
      return _PrimaryLook(
        fill: p.flame600,
        ink: p.onAmber,
        edge: null,
        edgeWidth: 0,
        bleed: false,
        ramp: _amberFace(skin),
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
    this.ramp,
  });

  final Color fill;
  final Color ink;
  final Color? edge;
  final double edgeWidth;
  final bool bleed;

  /// The filled face's own gradient, hot end at the top edge falling to
  /// [TiqPalette.flame600]. Null on every form that is not a filled amber
  /// block, and then [fill] is painted flat. See [_amberFace].
  final Gradient? ramp;
}

/// THE FILLED COMMIT FACE'S GRADIENT — linear, top down, 1 October 2026.
///
/// The owner: *"the send button on the app and everywhere else for orange is
/// very dull, it need to be lumunous and bright and inviting."* The two forms
/// this applies to — Night `filled` and the Day block — were flat swatches of
/// `flame600` at value 1.00, so there was no brightness left to add and the
/// thing they were missing is that **a flat fill cannot glow.**
///
/// ## Linear and not radial, unlike the send disc
///
/// This is a 56dp-tall block across the full width of a bar — roughly 340dp on
/// a 390dp phone. A radial gradient on a 6:1 rectangle is a spotlight on a
/// wall: it puts a visible ellipse in the middle of the button and leaves the
/// two ends dark, which reads as a badly lit surface rather than a lit object.
/// A 36dp disc wants a point source; a wide short block wants a wash from one
/// edge. The send disc chose a radial for the same reason in the opposite
/// direction, and the two are deliberately different.
///
/// **From the top**, because that is already where this button's light comes
/// from: the Night *unfilled* granted form draws a 2dp amber bleed along the
/// top inside edge and has since §1.7. The filled form is the same lighting
/// moved inward, so the two forms of one control are lit from one direction.
///
/// ## THE SOURCE SITS ABOVE THE BLOCK, NOT INSIDE IT
///
/// `begin` is `Alignment(0, -1.4)` — above the widget's own top edge — rather
/// than `topCenter`, and that one number is the difference between a lit object
/// and a glossy one. With the hot stop *at* the top edge the block's first row
/// is full `flame900`, a near-white band across the top of an amber face: that
/// is a specular highlight, and a specular highlight is a cue about a plastic
/// surface catching a light somewhere else in the room. It is the opposite of
/// what this control is claiming to be.
///
/// Starting the axis 1.4 half-heights above the block means the block catches
/// the light's *falloff* rather than its core. The gradient's axis runs 2.4
/// half-heights, so the top edge sits at t = 0.167 — already 40% of the way
/// from `flame900` to `flame600` — and reaches flat `flame600` about 30% down.
/// A warm cream edge going amber, with no white in it, which is what a surface
/// under a light actually looks like.
///
/// The label is centred, so at 56dp it spans roughly 20–36dp down and sits
/// entirely on the flat `flame600` below the ramp's end.
///
/// ## The worst point under the text
///
/// `flame600`, exactly. [TiqSkin.amberFillRamp]'s last stop is `flame600` and
/// the ramp goes no further, so no pixel under the label is darker than the
/// colour the flat fill painted — 9.68:1 on Night, 7.78:1 on Day, both against
/// a 4.5 floor and both unchanged by this gradient. That is the reason the ramp
/// stops where it does instead of running on to `flame500`. Moving `begin`
/// outside the box cannot weaken that either: it only ever removes the ramp's
/// *hottest* part from view, and every colour it removes is lighter than
/// `flame600`.
Gradient? _amberFace(TiqSkin skin) => skin.depth.allowsGradients
    ? LinearGradient(
        begin: const Alignment(0, -1.4),
        end: Alignment.bottomCenter,
        colors: skin.amberFillRamp,
        stops: const <double>[0, 0.42],
      )
    : null;

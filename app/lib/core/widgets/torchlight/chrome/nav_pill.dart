import 'package:flutter/widgets.dart';

import '../../../design/torch_scope.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import '../button/torch_button.dart';
import '../button/torch_press.dart';

/// The 999 radius, which [TiqRadii] deliberately does not carry.
///
/// The radius set was written when the active-tab pill had been cut, and its
/// doc comment says so: "the 999 pill radius is gone entirely". Owner decision
/// 3 reinstated the pill, and unify §1.2 rules for it over three surfaces'
/// radius-14 bars. It is declared here rather than added to [TiqRadii] because
/// it is legal on exactly three objects — the floating bar, its active tab and
/// the nav circle — and all three are in this folder. A token that only one
/// component may use is a value.
///
/// **Two of those three objects are gone as of 4 October 2026** — shape A took
/// the bar's own pill and the active tab's block away (see [TorchNavPill]) —
/// so the surviving users are the nav circle, the badge and the 2dp tab edge.
/// The name is kept because `nav_circle.dart` imports it by it.
const double torchPillRadius = 999;

/// One destination in the bar.
@immutable
class TorchNavSlot {
  const TorchNavSlot({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount,
    this.semanticLabel,
  });

  /// The inactive silhouette. Outlined.
  final IconData icon;

  /// The active silhouette. Filled, and a **different shape** — not the same
  /// glyph on a different ground.
  ///
  /// It is required rather than defaulted because of what happens at 2.0×: the
  /// bar goes icon-only, the label and its 700 weight disappear, and if the
  /// glyph did not change then "selected" would be carried by the amber fill
  /// and nothing else. Colour is never the only signal — least of all on the
  /// screens whose readers asked for bigger text.
  final IconData activeIcon;

  /// Localised, and measured. See [TorchNavPill]'s large-text rule.
  final String label;

  /// A count that needs the person. Never the ordinary held count, never
  /// amber, never crimson.
  final int? badgeCount;

  final String? semanticLabel;
}

/// THE BAR ON THE GROUND. Four slots, one **named** tab, and no material.
///
/// ```
/// agent     Today · My work · Map · Me
/// ```
///
/// ## SHAPE A — 4 October 2026, and it is agent-only
///
/// > *"LETS DO A, MAKE IT PRODUCTON LEVEL AND HIGH QUALITY"* — the owner, from
/// > four mockups of the agent's bottom bar.
///
/// This widget used to be a floating pill: radius 999, a 1px `edgeStructure`
/// outline, an opaque `well` fill, and an active tab that was a **solid block**
/// — `flame600` in Night, Abyssal on paper. That is the shape the console
/// retired on 2 October 2026 (`console_frame.dart`, "MODEL 1: ONE OBJECT AT
/// THE BOTTOM, AND THE PILL IS GONE"), and the owner's four mockups were about
/// what the agent gets instead of it.
///
/// Shape A is three changes and one addition:
///
/// 1. **The outline and the fill go.** The bar paints nothing of its own; the
///    slots sit directly on the shell's ground. There is no material, so there
///    is nothing for a scroll listener to swap, nothing to frost, and no
///    disagreement between a flat fill and a washed ground to have.
/// 2. **The filled tab goes.** The active slot is named by a **short 2dp amber
///    edge under its label**, 24dp wide and centred, not by a blob the size of
///    the slot. See [edgeExtent].
/// 3. **The forward key is untouched.** It already carries its own hot-core
///    radial (`nav_circle.dart`'s `_grantedRamp`, 1 October 2026) and the
///    mockup was drawn against an older state of it.
/// 4. **A fade above the bar**, so the body's hard clip at the bar's top edge
///    stops reading as a printing fault. It is not in this widget — it belongs
///    to the body whose clip it hides. See [TorchShell.bandScrimExtent].
///
/// ## WHAT IT COSTS: THE SELECTION CUE IS SKIN-DEPENDENT
///
/// Stated first because it is the one thing about shape A that is worse than
/// the pill, and it is not a budget question — it is a **rule**.
/// `torch_scope.dart`'s `amberIsInk` branch returns before the nav-tab claim is
/// even added and denies everything that is not a `primaryCommit`, so on Day
/// there is no light available for the tab edge at any budget. The edge is
/// therefore Night-only, and on Day the tab is named by the other three
/// channels: `well` groove, `ink1` over `navInkInactive`, w700 over w500, and
/// the filled glyph silhouette. Those are exactly [MenuFlatRow]'s four — the
/// row grammar the manager's own rail and menu use for "the one you are
/// standing on" — so Day is not an improvisation, it is the house form.
///
/// **Selection is readable without colour in both skins.** Weight, ink step and
/// glyph silhouette are all non-chromatic and all present in both; the amber
/// edge and the groove are the fourth channel, and which of the two it is
/// depends on the skin. A reader moving between skins meets two different
/// drawings of the same state, and that is the cost.
///
/// ## It claims amber; it does not paint it
///
/// The active tab asks [TorchScope] about [TorchScope.navActiveTabId], the id
/// the allocator grants itself whenever `navRenders` is true. The bar is
/// **counted**, not exempt — which is why a Night tab root has exactly one
/// content grant left, and why the edge goes out when a sheet opens and the
/// groove takes over. The denial path and the Day path are therefore the same
/// code, which is what makes "amber withdrawn" a state this widget has already
/// been drawn in rather than a branch nobody has looked at.
///
/// ## Large text
///
/// At build the bar lays out **every localised label** with a [TextPainter] at
/// the ambient scaler against the computed slot width. If any one of them
/// overflows, the whole bar goes icon-only — **all four, never a mixed bar and
/// never a two-row grid**. A 132dp nav grid plus a circle plus a thumb zone is
/// a third of a 640dp screen.
///
/// The failure case is real and it is Afrikaans: "Kompetisies" at 11/700 is
/// about 67px against a 63dp slot, and at the 1.3× that is common on cheap
/// Androids every label in the bar overflows at once. Shape A gives that case
/// 3dp per slot back, because the 6dp horizontal inset existed only to keep
/// the active block off the bar's own rim and there is no rim and no block.
class TorchNavPill extends StatelessWidget {
  const TorchNavPill({
    super.key,
    required this.slots,
    required this.activeIndex,
    required this.onSelect,
  }) : assert(
         slots.length >= 2 && slots.length <= 4,
         'Four slots maximum. At 360dp the bar has 252dp to give away once '
         'the insets and the circle are drawn; five slots is 50dp each, which '
         'is under the tap-target floor before the active pill takes its 6dp '
         'inset. A fifth destination goes behind Menu.',
       );

  final List<TorchNavSlot> slots;
  final int activeIndex;
  final ValueChanged<int> onSelect;

  /// The bar's outer height, before any text-scale growth.
  static const double height = 64;

  /// THE TAB EDGE — 24dp long, 2dp thick, and both numbers are decisions.
  ///
  /// **2dp** is the thickness this system already uses for an amber rule under
  /// a word: `TorchClaimKind.textFieldFocus` is "the 2px flame-700 rule under a
  /// focused text field". A tab indicator and a focus rule are the same object
  /// doing the same job in two places, so they are the same thickness rather
  /// than two numbers a reader has to notice are different.
  ///
  /// **24dp** is short on purpose — "a short amber edge under its label, not a
  /// blob". The narrowest label in the English set is "Map" at about 23dp and
  /// the widest is "My work" at about 44dp, so a 24dp edge is under the first
  /// one end to end and under the middle of the second. An edge as wide as the
  /// label would be a different length on every tab and would read as an
  /// underline of the word; an edge as wide as the slot is the blob again at
  /// 2dp. It does not scale with the text: the edge is a marker, not a glyph,
  /// and at 2.0× the bar is icon-only and there is no label to be as wide as.
  static const double edgeExtent = 24;
  static const double edgeThickness = 2;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final lit = TorchScope.lit(context, TorchScope.navActiveTabId);
    final scaler = MediaQuery.textScalerOf(context);

    // A meaning-bearing glyph scales with the text, and in an icon-only bar it
    // is the only thing carrying the destination. It is capped at 32 because
    // the active pill is 48 and a 48dp glyph in a 48dp pill is a glyph with no
    // pill around it.
    final glyphSize = scaler.scale(24).clamp(24.0, 32.0);

    final labelToken = skin.text.label.copyWith(
      size: 11,
      weight: FontWeight.w500,
    );
    final activeLabelToken = labelToken.copyWith(weight: FontWeight.w700);

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth;
        // THE 6dp HORIZONTAL INSET IS GONE WITH THE THING IT WAS FOR. It kept
        // the active block off the bar's own rim; shape A has neither, and a
        // slot that starts at the bar's edge is 3dp wider on a 360dp phone —
        // which is 3dp the Afrikaans measurement below gets to spend.
        final slotWidth = barWidth / slots.length;

        // THE MEASUREMENT. Every label, at the real scaler, against the real
        // slot. Not a guess at a text-scale threshold — layouts collapse on
        // measured width, never on a scale factor.
        var labelsFit = true;
        var labelHeight = 0.0;
        for (final slot in slots) {
          final painter = TextPainter(
            text: TextSpan(
              text: slot.label,
              style: activeLabelToken.style(color: skin.palette.ink1),
            ),
            textDirection: Directionality.of(context),
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          if (painter.width > slotWidth - TiqSpace.s2) labelsFit = false;
          if (painter.height > labelHeight) labelHeight = painter.height;
          painter.dispose();
        }

        // THE EDGE LANE IS RESERVED IN EVERY SLOT, NOT ONLY THE ACTIVE ONE.
        //
        // An edge that existed only under the selected tab would make that
        // slot's column 2dp taller than the other three, so the glyph and the
        // label of the tab you are standing on would sit 1dp higher than the
        // ones beside it. A 1dp vertical step across a four-slot bar is the
        // kind of defect nobody can name and everybody reads as cheap, so
        // every slot carries the lane and three of the four draw nothing in
        // it.
        //
        // It is counted here with **no gap above it**, which is what keeps the
        // published 64 a fact: `24 + 4 + 14.3 + 2 = 44.3` against 48dp of
        // content box, so the air between the label's box and the edge is the
        // 1.85dp of centring slack plus the label's own descent. A
        // [TiqSpace.s1] gap here would take the measured content to 48.3 and
        // the bar to 64.3 — a published height that is no longer a round
        // number, for 4dp nothing asked for.
        final contentHeight =
            glyphSize +
            (labelsFit ? TiqSpace.s1 + labelHeight : 0) +
            edgeThickness;
        // 8dp above and below the slots, which is what makes a 64dp bar hold a
        // 48dp content box. The bar only grows past 64 when the measured
        // content will not fit inside it — it is a minimum, never a pin.
        const vInset = 8.0;
        final barHeight = [
          height,
          contentHeight + vInset * 2,
        ].reduce((a, b) => a > b ? a : b);

        // A `SizedBox` and a `Padding`, not a `Container` with a decoration:
        // there is no decoration to carry, and a `DecoratedBox` with a null
        // fill is still a render object that paints. Shape A's bar costs
        // exactly the four slots.
        return SizedBox(
          height: barHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: vInset),
            child: Row(
              children: <Widget>[
                for (var i = 0; i < slots.length; i++)
                  Expanded(
                    child: _Slot(
                      slot: slots[i],
                      index: i,
                      count: slots.length,
                      active: i == activeIndex,
                      lit: lit,
                      showLabel: labelsFit,
                      glyphSize: glyphSize,
                      labelToken: i == activeIndex
                          ? activeLabelToken
                          : labelToken,
                      onSelect: onSelect,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.slot,
    required this.index,
    required this.count,
    required this.active,
    required this.lit,
    required this.showLabel,
    required this.glyphSize,
    required this.labelToken,
    required this.onSelect,
  });

  final TorchNavSlot slot;
  final int index;
  final int count;
  final bool active;
  final bool lit;
  final bool showLabel;
  final double glyphSize;
  final TiqTypeToken labelToken;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final radius = BorderRadius.circular(skin.radii.control);
    final press = torchPressSurface(skin);

    // ── THE FOURTH CHANNEL, AND WHICH OF ITS TWO FORMS THIS FRAME GETS ──
    //
    // `lit` is the allocator's answer for [TorchScope.navActiveTabId]. It is
    // true on Night with nothing above the route, and false on Day at any
    // budget — `torch_scope.dart`'s `amberIsInk` branch returns before the nav
    // tab is added to the pending set and denies it
    // [TorchDenial.notAmberOnLightGround] — and false on Night beneath a
    // sheet. So these two lines are the whole of the skin-dependent cue the
    // class comment names as shape A's cost:
    //
    //   granted  →  a 2dp amber edge under the label, no fill.
    //   denied   →  a `well` groove, which is [MenuFlatRow]'s own form for the
    //               row you are standing on.
    //
    // The groove is a fill and the edge is not, and that is deliberate: two
    // objects both saying "this one" on the same slot would be the blob back
    // with a line under it.
    final bool edge = active && lit;
    final bool groove = active && !lit;

    // THE GROOVE IS FLAT, AND THERE IS NO GRADIENT LEFT IN THIS WIDGET.
    //
    // The lit tab's linear ramp and the Abyssal form's two-identical-stop
    // companion both went with the block they filled. The companion existed
    // for one reason — `BoxDecoration.lerp` runs `Gradient.lerp(a, b, t)` and
    // lerping a gradient against null scales its alpha, so a lit→unlit
    // cross-fade between a gradient and a flat colour sent a half-transparent
    // shader over the bar — and with no gradient in either state there is no
    // such transition to protect. `well` → `well` is a colour lerp.
    //
    // What the amber ramp was *for* is still served, and by the object that
    // wanted it: the owner's *"it need to be lumunous and bright"* was about
    // the send disc and "everywhere else for orange", and the forward key
    // beside this bar keeps its hot-core radial untouched. A 24×2dp edge has
    // no room for a core.

    // THE THING THAT ACTUALLY MOVES HERE, and it is worth being exact about
    // which: it is NOT the pill travelling between tabs. Every screen builds
    // its own [TorchNavPill] with a constant `activeIndex`, so the index never
    // changes inside a live tree — the whole page is replaced and the new bar
    // is born already lit. A travelling indicator would need the bar to
    // outlive the route (a `StatefulShellRoute`), which is a restructure and
    // not this change.
    //
    // What does change under a live tree, on a real device, today:
    //
    //  * `pressed` — every single tap, and the fill and ink both jumped;
    //  * `lit` — the amber grant is withdrawn the moment a sheet opens and
    //    returned when it closes, so the active tab's edge goes out and the
    //    groove comes in. That is the nav going out and coming on, and it was
    //    one frame each way.
    //
    // 120ms on the state curve, the same pair the toggle and the stepper use.
    final duration = torchStateDuration(context, TiqMotion.press);

    return Semantics(
      button: true,
      selected: active,
      label: '${slot.semanticLabel ?? slot.label}, tab ${index + 1} of $count',
      // THE ACTION, not only the flag: `excludeSemantics` drops the
      // gesture detector's own node, so without `onTap` here this is a
      // control a screen reader can focus and cannot activate.
      onTap: () => onSelect(index),
      excludeSemantics: true,
      child: TorchPressable(
        onPressed: () => onSelect(index),
        borderRadius: radius,
        pressScale: torchPressScaleGlyph,
        builder: (context, pressed) {
          // ink-1 on the tab you are standing on, the nav's own inactive ink
          // on the other three. `torchPressSurface(skin).ink` is ink-1 in both
          // skins, so a pressed inactive slot steps up to the active ink and
          // the active slot's ink does not move under a press.
          final ink = active || pressed ? press.ink : p.navInkInactive;
          // THE GROOVE AND THE PRESS ARE THE SAME LANE, and on Day they are
          // the same colour: `torchPressSurface` steps Day down to `well`,
          // which is exactly what the denied form fills with. So pressing the
          // tab you are already on is carried by `pressScale` alone there. It
          // is reported rather than worked around — the press is a no-op
          // navigation, and giving the active slot a fifth fill to distinguish
          // a press that does nothing would be a colour spent on nothing.
          final Color? fill = pressed
              ? press.fill
              : (groove ? p.well : null);
          // Both channels on the same clock. An eased fill under an ink that
          // jumped reads worse than neither moving.
          return TorchInk(
            color: ink,
            duration: duration,
            builder: (context, ink) => AnimatedContainer(
              duration: duration,
              curve: TiqMotion.stateCurve,
              // `AnimatedContainer` with nothing but a decoration and a child
              // builds exactly the `DecoratedBox` this used to be — same
              // layout, same paint, no extra layer. No gradient in any state;
              // see the note above the `edge`/`groove` pair.
              decoration: BoxDecoration(color: fill, borderRadius: radius),
              child: Column(
                children: <Widget>[
                  // TWO SPACERS, AND THE EDGE OUTSIDE THEM. The slack in the
                  // 48dp box is split equally above the glyph and between the
                  // label and the edge — about 1.9dp each at 1.0× — which is
                  // what keeps the edge the last 2dp of the box in every slot
                  // and at every scale, with the label's own descent doing the
                  // rest of the separating.
                  const Spacer(),
                  _Glyph(
                    icon: active ? slot.activeIcon : slot.icon,
                    size: glyphSize,
                    color: ink,
                    badgeCount: slot.badgeCount,
                  ),
                  if (showLabel) ...<Widget>[
                    const SizedBox(height: TiqSpace.s1),
                    Text(
                      slot.label,
                      style: labelToken.style(color: ink),
                      maxLines: 1,
                      // The measurement upstream guarantees this never
                      // fires. It is here so that a bug in the measurement
                      // clips one label rather than throwing a yellow
                      // overflow stripe across a shop floor.
                      overflow: TextOverflow.clip,
                      softWrap: false,
                    ),
                  ],
                  const Spacer(),
                  // ── THE EDGE. The lane is in every slot; the paint is not.
                  //
                  // `TorchNavPill.edgeExtent` × `edgeThickness`, centred,
                  // radius 999 so a 2dp rule has ends rather than corners. Its
                  // colour is `flame600` — the tab's own token, flat, read off
                  // the skin like every other amber in this file — and
                  // `transparent` on the three inactive slots and on the active
                  // one whenever the grant is denied.
                  //
                  // It animates with the rest: `TorchInk` is for the glyph and
                  // the label, and this is an `AnimatedContainer` of its own so
                  // that the edge fades rather than popping when a sheet takes
                  // the grant away. Same clock, same curve.
                  AnimatedContainer(
                    duration: duration,
                    curve: TiqMotion.stateCurve,
                    width: TorchNavPill.edgeExtent,
                    height: TorchNavPill.edgeThickness,
                    decoration: BoxDecoration(
                      // The same token at zero alpha rather than a transparent
                      // literal, so the 120ms fade is a pure alpha ramp with
                      // no hue travelling through it, and so this line is a
                      // palette read like every other colour in the file.
                      color: edge ? p.flame600 : p.flame600.withValues(alpha: 0),
                      borderRadius: BorderRadius.circular(torchPillRadius),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({
    required this.icon,
    required this.size,
    required this.color,
    required this.badgeCount,
  });

  final IconData icon;
  final double size;
  final Color color;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final glyph = TorchGlyph(icon, size: size, color: color);
    final badge = badgeCount;
    if (badge == null || badge <= 0) return glyph;

    final skin = context.skin;
    final p = skin.palette;
    // Never amber and never crimson: a badge is a count, and a count is not a
    // severity. ink-1 on the nav body is the loudest neutral there is.
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        glyph,
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            padding: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: p.ink1,
              borderRadius: BorderRadius.circular(torchPillRadius),
            ),
            child: Center(
              child: Text(
                badge <= 9 ? '$badge' : '9+',
                style: skin.text.monoIdent
                    .copyWith(size: 10, weight: FontWeight.w600)
                    .style(color: p.ground),
                textScaler: TextScaler.noScaling,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

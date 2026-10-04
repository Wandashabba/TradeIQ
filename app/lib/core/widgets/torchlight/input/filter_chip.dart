import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../design/figure_slot.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import '../button/torch_press.dart';
import '../chrome/nav_pill.dart' show torchPillRadius;
import '../mark/tiq_mark.dart';

/// NARROWING A LIST — territory, date window, status.
///
/// Selected is **lifted fill + a tick + weight 700 + ink-1**, and it is
/// **never amber**, on any screen, in any skin (unify §1.6). The written
/// direction specified an amber selected edge; all five design surfaces
/// overruled it, and the reason is arithmetic rather than taste — a rail is a
/// row of chips, a selected chip in a multi-select rail is three or four of
/// them, and four amber edges in one horizontal scroller is the repeated-fill
/// violation the whole amber law exists to prevent.
///
/// A disabled filter — one with no possible results — **stays visible**, with
/// its count at zero. Hiding a filter because it is empty hides the fact that
/// it is empty, which is usually the thing worth knowing.
class TorchFilterChip extends StatelessWidget {
  const TorchFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.count,
    this.countLoading = false,
    this.glyph,
    this.semanticsLabel,
    this.quiet = false,
  });

  /// ── THE PLATE-SIDE WEIGHT, OPT-IN — 1 October 2026 ──────────────────
  ///
  /// False everywhere except The Floor's suggestion row, and it has to be
  /// opt-in rather than a new default: a filter rail is a row of controls a
  /// manager *works*, and the 44dp `chipHeight` is the right drawn size for
  /// one. The 44 is not negotiable as a TARGET anywhere — see below — but as a
  /// drawn height it belongs to a rail.
  ///
  /// A suggestion is not a filter. It is an **offer**, in a row pinned above
  /// the composer, and the mockup draws it at `padding:5px 9px;
  /// font-size:8.5px` — about 29dp tall with 11dp type, which is roughly half
  /// the weight of the rail chip this component was built for. Drawn at 44dp
  /// the owner's render fitted one and a bit: *"large enough that the second
  /// one is cut off at the screen edge"*. Two chips is the mockup's count and
  /// `FloorSuggestionChips.maximum`'s arithmetic, so a row that cannot hold
  /// two is the row failing at its one job.
  ///
  /// **The tap target does not shrink with the paint.** The chip still
  /// occupies `space.chipHeight` of the row; what changes is that the painted
  /// pill is centred inside it at 29dp. That split is the same one
  /// `plateQuietExtent` makes for the two controls on the plate, and it is the
  /// only way to take the drawing's weight without dropping under WCAG
  /// 2.5.5's floor — the mockup's chrome is 29–35dp throughout and every one
  /// of those numbers is under 44.
  ///
  /// It is a density, not a second look: the pill, the fill tiers, the ink
  /// tiers, the weight step, the tick disc, the press treatment and the
  /// never-amber rule are all exactly the rail chip's. Only the drawn box and
  /// the type role move.
  final bool quiet;

  final String label;
  final bool selected;

  /// Null disables the chip; it still renders.
  final VoidCallback? onSelected;

  /// Rendered after the label in tabular mono.
  final int? count;

  /// While a count is resolving, a skeleton block renders at exactly the width
  /// the count will occupy, so the rail does not reflow when it arrives.
  final bool countLoading;

  /// An optional leading silhouette, from the drawn mark set.
  final MarkShape? glyph;

  final String? semanticsLabel;

  /// The chip's height, which is [TiqSpace.chipHeight] — **44 at both
  /// densities** since 29 September 2026.
  ///
  /// > *"Fix the spacing also please check if everything matches with the
  /// > manager side"* — the owner, 29 September 2026.
  ///
  /// SUPERSEDED: `TiqDensity.console => 44, TiqDensity.field => 48`, which
  /// restated `TiqSpace`'s own `chipHeight` as a second switch and so made
  /// that token dead — nothing in `lib/` read it. The ruling was written
  /// twice, which is how two copies of one number drift apart. It is read
  /// rather than restated now, so a density change lands here for free, the
  /// way `torchBlockHeight` already reads `primaryActionHeight` next door.
  ///
  /// The console value is 44 either way, so no manager pixel moved when this
  /// was rewired.
  static double heightFor(TiqSkin skin) => skin.space.chipHeight;

  /// The drawn height of a [quiet] chip: the mockup's 22px at 1.3 dp/px. The
  /// TARGET is still [heightFor] — see [quiet].
  static const double quietExtent = 29;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final enabled = onSelected != null;

    // A PILL, NOT A BOX — owner override, 29 September 2026.
    //
    // `radii.chip` is 6, and at 44dp tall that is a rectangle with the corners
    // taken off. Looking at the Tasks rail the owner said *"let's remove this
    // lined, rectangular style"*, which is the second time the same note has
    // landed on the same shape — "It's still very boxy and I don't need that"
    // was the first, and it is what made a list row a radius-22 card.
    //
    // 999, and it is the approved mockup's own number: every chip in it is
    // `border-radius: 999px` over a quiet fill with **no border at all**.
    // `TiqRadii` deliberately carries no 999 — see its doc comment — because
    // the pill belonged to the nav alone; this is the second grant, recorded
    // the same way the nav's was rather than smuggled in as a token change.
    // `radii.chip` keeps its 6 for the ladder glyph tiles that also use it, so
    // this is a decision about *this control* and not a silent edit to
    // twenty-three call sites.
    final radius = BorderRadius.circular(torchPillRadius);

    // AND NO OUTLINE, which is the other half of "rectangular". The unselected
    // chip was a bare outline — no fill, a 1px `edgeControl` box — so the rail
    // read as four empty boxes. It is a filled pill now.
    //
    // The honest trade-off, written down rather than discovered later: a fill
    // step on a near-black ground is small in ratio terms, and it gets
    // SMALLER, not larger, as the ladder is tuned. Measured on `ground`:
    // `surface` 1.24:1 and `lifted` 1.67:1 against the blue ladder this landed
    // on; 1.11:1 and 1.32:1 once the warm-neutral ladder recasts the tiers.
    // Every one of those is under WCAG 1.4.11's 3:1, on either ladder, which
    // is the point — the FILL is not what identifies the control or its
    // state, and no future tuning of the tiers will make it so. Four other
    // channels do, and every one survives greyscale: the label itself at full
    // text contrast, the tick disc on the selected chip, the weight step
    // (700 against 500), and the ink step (the selected chip's ink is chosen
    // against its own dark fill, the unselected chip's against the surface).
    // The outline was belt-and-braces over those, and the owner has now twice
    // said the braces are what they can see.
    final Color? fill;
    final Color ink;
    if (!enabled) {
      fill = null;
      ink = p.inkMute;
    } else if (selected) {
      fill = p.lifted;
      // `torchOnAbyssal`, NOT `ink1`. `lifted` is a dark navy in BOTH skins —
      // it is the one fill that does not flip with the ground — so Day's
      // `ink1` (`#1B2632`) on it is dark on dark. Rendering the Day chip after
      // this change is what caught it; the ink has to be chosen against the
      // fill, not against the skin.
      ink = torchOnAbyssal(skin);
    } else {
      fill = p.surface;
      ink = p.ink2;
    }

    // ── SELECTION IS PAINT, NEVER LAYOUT — 4 October 2026 ───────────────
    //
    // > *"Theres also an issue of pressing moving from filters, 7days and all
    // > the other filters"* — the owner, on the dashboard's rail, who then
    // > characterised it as *"Jumpy or janky movement — the selection or the
    // > chips visibly jump, flicker or slide badly when you move between
    // > filters."*
    //
    // It read as a motion bug and it was arithmetic. The tick disc was built
    // only when `selected`, with its 6dp gap, and the label stepped w500 →
    // w700, which measures wider. Both of those are LAYOUT.
    //
    // Measured on Schibsted Grotesk, all four faces, the six rail labels:
    // selecting a chip with no `glyph` grew it **21.92–24.41dp at 1.0× and
    // 26.70–29.93dp at 1.3×**. Twenty of that is fixed — the 14dp mark, which
    // scales with text, plus the 6dp gap, which does not — and the remaining
    // 1.92–4.41dp is the weight step, which is why the figure depends on the
    // word. So tapping a different range shrank one chip and grew another in
    // the same frame and slid every chip after them sideways while the fill
    // was still cross-fading.
    //
    // A chip with a `glyph` moved the other way and by almost nothing — the
    // 16dp glyph was replaced by the 14dp tick, and the weight step very
    // nearly paid the 2dp back, for **−0.23dp**. Nothing in `lib/` passes
    // `glyph`, so that one is latent rather than fixed by luck.
    //
    // So both channels are reserved in both states, and the fix is NOT an
    // animation: animating a whole row's reflow is a nicer-looking shuffle,
    // not a still row. `filter_chip_layout_test.dart` holds the widths equal
    // and holds the rail's rects identical across a selection move — and it
    // loads the real fonts, because `flutter_test`'s own face has one advance
    // width per glyph at every weight and cannot see the weight step at all.
    //
    // THE COST, written down: an unselected chip is now as wide as a selected
    // one — 22–24dp wider at 1.0× than it used to be — so a rail is wider
    // than it was and its horizontal scroller starts working sooner. That is
    // the trade, and it is the right way round: the rail scrolls, so width it
    // does not have costs a drag, while a row that moves under the thumb
    // costs a mis-tap.
    //
    // IT IS NOT FREE FOR EVERY CALLER. A rail absorbs the width by scrolling
    // and eleven of the fourteen call sites are rails. Two are not, and both
    // are measured rather than assumed:
    //
    // 1. `FloorSuggestionChips` — `quiet` chips, hard-coded `selected: false`,
    //    reserving a tick that can never appear. Its two chips measured
    //    313.00dp against 320.00 available at 1.3× on a 360dp phone and now
    //    measure 370.21, so `FloorSuggestionChips.maximum`'s claim that "two
    //    fits one line on every supported phone" is false above roughly 1.1×
    //    where it used to hold to roughly 1.33×. Nothing clips — that row is a
    //    `SingleChildScrollView` and its own comment says an offer may sit
    //    just off the edge.
    // 2. The scope sheet's window chips, which are a `Wrap` of
    //    `IntrinsicWidth` chips rather than a rail. The extra width buys a
    //    third 44dp line there, every territory row below it moves down 52dp,
    //    and on a 360dp phone four of thirteen territories now sit past the
    //    fold where two did. Remeasured and re-pinned in
    //    `filter_groups_test.dart`, which asks in its own words to be. The
    //    390dp case — the width the owner reviews on — is unchanged.
    //
    // Both are reported rather than bought back with a flag here, because a
    // chip that sometimes reserves the slot is a chip whose width depends on
    // the caller instead of on the selection, which is the same bug wearing a
    // different hat.

    /// The mark's box, reserved whether or not a mark is drawn in it.
    ///
    /// `glyph`'s 16 and the tick's 14 are different numbers, so a chip that
    /// carries both over its life reserves the larger and centres whichever
    /// one it is drawing. Scales with text, because the marks do (unify §4).
    final markBox = MarkScale.glyph(context, glyph != null ? 16 : 14);

    // Built per frame against the ink the fade is currently on, so the mark,
    // the label and the count arrive with the fill rather than a frame ahead
    // of it. The WEIGHT does not animate and must not: 500 → 700 is one of the
    // two non-motion channels that carry `selected` on their own.
    List<Widget> childrenWith(Color ink) => <Widget>[
      SizedBox.square(
        dimension: markBox,
        // Nothing to draw on an unselected chip with no `glyph` — and an
        // empty `SizedBox` paints nothing at all, so the reservation costs a
        // layout and no raster work.
        child: switch (selected) {
          true => Center(
            child: TiqMark(
              shape: MarkShape.sectionTickDisc,
              color: ink,
              ground: fill ?? p.ground,
              size: MarkScale.glyph(context, 14),
            ),
          ),
          false when glyph != null => Center(
            child: TiqMark(
              shape: glyph!,
              color: ink,
              size: MarkScale.glyph(context, 16),
            ),
          ),
          false => null,
        },
      ),
      // 6, and STILL 6 — it is the gap the selected chip has always had, and
      // `TiqSpace` carries no 6 (s1 is 4, s2 is 8). Reserving it is a layout
      // change for the unselected chip and must not be a paint change for the
      // selected one, so the number is held rather than rounded to a step.
      const SizedBox(width: _markGap),
      Flexible(
        child: _ReservedWeightLabel(
          label: label,
          // `meta` is 12 against `label`'s 13, which is the declared role
          // nearest the mockup's 11dp. See [quiet].
          role: quiet ? skin.text.meta : skin.text.label,
          selected: selected,
          ink: ink,
        ),
      ),
      if (countLoading) ...<Widget>[
        const SizedBox(width: TiqSpace.s2),
        const _CountSkeleton(),
      ] else if (count != null) ...<Widget>[
        const SizedBox(width: TiqSpace.s2),
        FigureSlot(value: count, role: skin.text.figureS, color: ink),
      ],
    ];

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label:
          semanticsLabel ?? (count == null ? label : '$label, $count results'),
      // THE ACTION, not only the flag: `excludeSemantics` drops the
      // gesture detector's own node, so without `onTap` here this is a
      // control a screen reader can focus and cannot activate.
      onTap: onSelected,
      excludeSemantics: true,
      child: TorchPressable(
        onPressed: onSelected,
        borderRadius: radius,
        // `TiqMotion.press` is documented as "press, toggle, CHIP SELECT" —
        // this is the third of those, and the one that was still snapping. A
        // filter rail is the manager's most-tapped control on Tasks and on
        // Alerts, and selecting a chip moved the fill, the ink, the glyph and
        // the count all in a single frame.
        //
        // The two non-motion channels are untouched and still carry the state
        // on their own: the label steps to 700 and the tick disc appears.
        builder: (context, pressed) {
          final duration = torchStateDuration(context, TiqMotion.press);
          // The chip's ink is chosen against `fill` and deliberately does NOT
          // step on press — that is the existing behaviour and this change is
          // motion only. (It leaves a real contrast bug alone on purpose: a
          // *selected* Day chip presses to the pale `well` while keeping the
          // Palladian ink it was given for the dark `lifted`. Reported, not
          // fixed here, because fixing it is a rendering change and this
          // branch is not allowed to make one.)
          return TorchInk(
            color: ink,
            duration: duration,
            // THE TARGET IS THE ROW'S, THE PAINT IS THE CHIP'S. A quiet chip
            // keeps `heightFor` as the box a finger lands in and centres a
            // 29dp pill inside it; a rail chip paints the whole box, which is
            // the behaviour every existing call site has.
            builder: (context, ink) => ConstrainedBox(
              constraints: BoxConstraints(minHeight: heightFor(skin)),
              child: Center(
                child: AnimatedContainer(
                  duration: duration,
                  curve: TiqMotion.stateCurve,
                  constraints: BoxConstraints(
                    minHeight: quiet ? quietExtent : heightFor(skin),
                  ),
                  decoration: BoxDecoration(
                    color: pressed ? torchPressSurface(skin).fill : fill,
                    borderRadius: radius,
                    // A DISABLED CHIP KEEPS ITS OUTLINE. It has no fill to be
                    // seen by and `inkMute` on the bare ground is the one
                    // state where the silhouette really is all there is.
                    border: enabled
                        ? null
                        : Border.all(
                            color: p.inkMute,
                            width: skin.depth.borderWidth,
                          ),
                  ),
                  // The mockup's `padding:5px 9px` is 6.5/11.7dp at 1.3 dp/px;
                  // s3 and s1 are the nearest steps, and the vertical one is a
                  // floor under `quietExtent` rather than the height itself.
                  padding: EdgeInsets.symmetric(
                    horizontal: TiqSpace.s3,
                    vertical: quiet ? TiqSpace.s1 : TiqSpace.s2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: childrenWith(ink),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The gap between the mark's reserved box and the label. See the comment at
/// its only use for why this is 6 and not a [TiqSpace] step.
const double _markGap = 6;

/// The label, in a box the width of its **w700** measurement in both states.
///
/// The weight step is one of the two non-colour channels that carry `selected`
/// (unify §4) and it deliberately does not animate — so it cannot be allowed
/// to change the label's measured width either, or every chip after this one
/// slides when the selection moves. The box is the heavy measurement always;
/// the glyphs still render at w500 when unselected.
///
/// THE HEAVY COPY IS MEASURED, NOT BUILT — and that is not a micro-optimisation,
/// it is the only version of this that does not break the suite. The obvious
/// shape is a `Stack` with an invisible w700 `Text` sizing the box under the
/// real one; it reserves the width correctly and it puts **a second `Text`
/// carrying the same words** into the tree, so `find.text('Limpopo')` starts
/// matching twice. That failed seven tests across four files — the disabled-chip
/// case in `input_test.dart`, both follow-up cases in `rich_answer_test.dart`,
/// the Afrikaans artifact case, a scope-sheet geometry case and two Trends
/// cases — none of which was asserting an old width. They were right and the
/// widget was wrong: a label that renders once must appear in the tree once.
///
/// So the reservation is a `TextPainter` laid out against the same constraints
/// the child gets, and the box is the larger of the two on each axis. That is a
/// max rather than "the sizer wins", which is what makes it hold without
/// assuming bold is the wider face.
///
/// The cost is one extra text layout per chip per frame, no extra paint, and
/// one duplicated detail: the painter has to be configured exactly as `Text`
/// configures its own `RichText`, which is why [build] reads the merged
/// `DefaultTextStyle`, the `MediaQuery` scaler and the width basis rather than
/// assuming them.
class _ReservedWeightLabel extends StatelessWidget {
  const _ReservedWeightLabel({
    required this.label,
    required this.role,
    required this.selected,
    required this.ink,
  });

  final String label;
  final TiqTypeToken role;
  final bool selected;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final heavy = role.copyWith(weight: FontWeight.w700);
    final shown = heavy.copyWith(
      weight: selected ? FontWeight.w700 : FontWeight.w500,
    );
    final defaults = DefaultTextStyle.of(context);
    return _ReserveTextWidth(
      // `Text` merges its style onto the ambient one, so the measurement has
      // to merge it the same way or the two can disagree about a fallback.
      span: TextSpan(
        text: label,
        style: defaults.style.merge(heavy.style(color: ink)),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      textWidthBasis: defaults.textWidthBasis,
      textHeightBehavior:
          defaults.textHeightBehavior ??
          DefaultTextHeightBehavior.maybeOf(context),
      maxLines: _labelMaxLines,
      child: Text(
        label,
        style: shown.style(color: ink),
        // Never ellipsised: a truncated filter name is a filter you cannot
        // identify. At 2.0× the chip grows and wraps instead — and it wraps
        // against the HEAVY measurement in both states, so the height is
        // selection-independent for the same reason the width is.
        maxLines: _labelMaxLines,
      ),
    );
  }
}

/// Two, and the measurement below has to be given the same number.
const int _labelMaxLines = 2;

/// Sizes to the larger of its child and [span], and draws only the child.
class _ReserveTextWidth extends SingleChildRenderObjectWidget {
  const _ReserveTextWidth({
    required this.span,
    required this.textDirection,
    required this.textScaler,
    required this.textWidthBasis,
    required this.textHeightBehavior,
    required this.maxLines,
    required super.child,
  });

  final TextSpan span;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final TextWidthBasis textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final int maxLines;

  @override
  _RenderReserveTextWidth createRenderObject(BuildContext context) =>
      _RenderReserveTextWidth(
        span: span,
        textDirection: textDirection,
        textScaler: textScaler,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        maxLines: maxLines,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderReserveTextWidth renderObject,
  ) {
    renderObject
      ..span = span
      ..textDirection = textDirection
      ..textScaler = textScaler
      ..textWidthBasis = textWidthBasis
      ..textHeightBehavior = textHeightBehavior
      ..maxLines = maxLines;
  }
}

class _RenderReserveTextWidth extends RenderShiftedBox {
  _RenderReserveTextWidth({
    required TextSpan span,
    required TextDirection textDirection,
    required TextScaler textScaler,
    required TextWidthBasis textWidthBasis,
    required TextHeightBehavior? textHeightBehavior,
    required int maxLines,
  }) : _painter = TextPainter(
         text: span,
         textDirection: textDirection,
         textScaler: textScaler,
         textWidthBasis: textWidthBasis,
         textHeightBehavior: textHeightBehavior,
         maxLines: maxLines,
       ),
       super(null);

  final TextPainter _painter;

  set span(TextSpan value) {
    if (_painter.text == value) return;
    _painter.text = value;
    markNeedsLayout();
  }

  set textDirection(TextDirection value) {
    if (_painter.textDirection == value) return;
    _painter.textDirection = value;
    markNeedsLayout();
  }

  set textScaler(TextScaler value) {
    if (_painter.textScaler == value) return;
    _painter.textScaler = value;
    markNeedsLayout();
  }

  set textWidthBasis(TextWidthBasis value) {
    if (_painter.textWidthBasis == value) return;
    _painter.textWidthBasis = value;
    markNeedsLayout();
  }

  set textHeightBehavior(TextHeightBehavior? value) {
    if (_painter.textHeightBehavior == value) return;
    _painter.textHeightBehavior = value;
    markNeedsLayout();
  }

  set maxLines(int value) {
    if (_painter.maxLines == value) return;
    _painter.maxLines = value;
    markNeedsLayout();
  }

  Size _reserved(double maxWidth) {
    _painter.layout(maxWidth: maxWidth);
    return _painter.size;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    _painter.layout();
    return math.max(
      super.computeMinIntrinsicWidth(height),
      _painter.minIntrinsicWidth,
    );
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    _painter.layout();
    return math.max(
      super.computeMaxIntrinsicWidth(height),
      _painter.maxIntrinsicWidth,
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    final reserved = _reserved(constraints.maxWidth);
    if (child == null) return constraints.constrain(reserved);
    final childSize = child.getDryLayout(constraints);
    return constraints.constrain(
      Size(
        math.max(childSize.width, reserved.width),
        math.max(childSize.height, reserved.height),
      ),
    );
  }

  @override
  void performLayout() {
    final child = this.child;
    final reserved = _reserved(constraints.maxWidth);
    if (child == null) {
      size = constraints.constrain(reserved);
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(
      Size(
        math.max(child.size.width, reserved.width),
        math.max(child.size.height, reserved.height),
      ),
    );
    // Start-aligned across, centred down — the position the `Stack` this
    // replaces gave it, and the one that keeps the label's first glyph at the
    // same x whether or not the slack is there.
    final dx = textDirection == TextDirection.rtl
        ? size.width - child.size.width
        : 0.0;
    (child.parentData! as BoxParentData).offset = Offset(
      dx,
      (size.height - child.size.height) / 2,
    );
  }

  TextDirection get textDirection => _painter.textDirection!;

  @override
  void dispose() {
    _painter.dispose();
    super.dispose();
  }
}

/// Exactly the width the count will occupy, so nothing reflows on arrival.
class _CountSkeleton extends StatelessWidget {
  const _CountSkeleton();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return SizedBox(
      width: 24,
      height: 14,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(skin.radii.chip),
          border: Border.all(
            color: skin.palette.edgeStructure,
            width: skin.depth.borderWidth,
          ),
        ),
      ),
    );
  }
}

/// THE RAIL — a horizontally scrolling row of chips with a gutter at each end.
///
/// The last chip is never flush to the screen edge and selected chips are
/// **never reordered to the front** — reordering under a thumb is a mis-tap.
///
/// There is never a rail with no selection. When nothing else is chosen, the
/// leading "All" chip is the selected one — an empty rail and a rail showing
/// everything look identical otherwise.
class TorchFilterRail extends StatelessWidget {
  const TorchFilterRail({
    super.key,
    required this.chips,
    this.controller,
    this.semanticsLabel,
  }) : assert(chips.length > 0, 'A rail with no chips is a rail nobody needs.');

  final List<Widget> chips;

  /// Held by the screen so the rail's position survives a rebuild.
  final ScrollController? controller;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final gutter = skin.space.gutter;

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: SizedBox(
        // The rail grows with the text so a two-line chip label is not clipped
        // by a pinned rail height.
        height: TorchFilterChip.heightFor(skin) * MarkScale.factor(context),
        child: ListView.separated(
          controller: controller,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: gutter),
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: TiqSpace.s2),
          itemBuilder: (context, index) =>
              Align(alignment: Alignment.center, child: chips[index]),
        ),
      ),
    );
  }
}

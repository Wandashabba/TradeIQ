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

    // Built per frame against the ink the fade is currently on, so the mark,
    // the label and the count arrive with the fill rather than a frame ahead
    // of it. The WEIGHT does not animate and must not: 500 → 700 is one of the
    // two non-motion channels that carry `selected` on their own.
    List<Widget> childrenWith(Color ink) => <Widget>[
      if (selected)
        TiqMark(
          shape: MarkShape.sectionTickDisc,
          color: ink,
          ground: fill ?? p.ground,
          size: MarkScale.glyph(context, 14),
        )
      else if (glyph != null)
        TiqMark(shape: glyph!, color: ink, size: MarkScale.glyph(context, 16)),
      if (selected || glyph != null) const SizedBox(width: 6),
      Flexible(
        child: Text(
          label,
          // `meta` is 12 against `label`'s 13, which is the declared role
          // nearest the mockup's 11dp. See [quiet].
          style: (quiet ? skin.text.meta : skin.text.label)
              .copyWith(weight: selected ? FontWeight.w700 : FontWeight.w500)
              .style(color: ink),
          // Never ellipsised: a truncated filter name is a filter you cannot
          // identify. At 2.0× the chip grows and wraps instead.
          maxLines: 2,
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

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
  });

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

  /// 44 Console / 48 Field.
  static double heightFor(TiqSkin skin) => switch (skin.density) {
    TiqDensity.console => 44,
    TiqDensity.field => 48,
  };

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
    // step on a near-black ground is small in ratio terms — `surface` is
    // 1.24:1 on `ground` and `lifted` 1.67:1, both under WCAG 1.4.11's 3:1 —
    // so the FILL is not what identifies the control or its state. Four other
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

    final labelStyle = skin.text.label
        .copyWith(weight: selected ? FontWeight.w700 : FontWeight.w500)
        .style(color: ink);

    final children = <Widget>[
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
          style: labelStyle,
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
        builder: (context, pressed) => Container(
          constraints: BoxConstraints(minHeight: heightFor(skin)),
          decoration: BoxDecoration(
            color: pressed ? torchPressSurface(skin).fill : fill,
            borderRadius: radius,
            // A DISABLED CHIP KEEPS ITS OUTLINE. It has no fill to be seen by
            // and `inkMute` on the bare ground is the one state where the
            // silhouette really is all there is.
            border: enabled
                ? null
                : Border.all(
                    color: p.inkMute,
                    width: skin.depth.borderWidth,
                  ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: TiqSpace.s3,
            vertical: TiqSpace.s2,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
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

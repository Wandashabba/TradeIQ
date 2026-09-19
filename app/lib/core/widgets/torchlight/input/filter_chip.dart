import 'package:flutter/widgets.dart';

import '../../../design/figure_slot.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import '../button/torch_press.dart';
import '../mark/tiq_mark.dart';

/// NARROWING A LIST — territory, date window, status.
///
/// Selected is **lifted fill + a 1px ink-1 border + a tick + weight 700**, and
/// it is **never amber**, on any screen, in any skin (unify §1.6). The written
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

  /// 44 Console / 48 Field / 56 Veld.
  static double heightFor(TiqSkin skin) => switch (skin.density) {
    TiqDensity.console => 44,
    TiqDensity.field => 48,
    TiqDensity.veld => TiqSpace.s9,
  };

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final enabled = onSelected != null;
    final radius = BorderRadius.circular(skin.radii.chip);

    final Color? fill;
    final Color border;
    final Color ink;
    if (!enabled) {
      fill = null;
      border = p.inkMute;
      ink = p.inkMute;
    } else if (selected) {
      fill = p.lifted;
      border = p.ink1;
      ink = torchOnAbyssal(skin);
    } else {
      fill = null;
      border = p.edgeControl;
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
      excludeSemantics: true,
      child: TorchPressable(
        onPressed: onSelected,
        borderRadius: radius,
        builder: (context, pressed) => Container(
          constraints: BoxConstraints(minHeight: heightFor(skin)),
          decoration: BoxDecoration(
            color: pressed ? torchPressSurface(skin).fill : fill,
            borderRadius: radius,
            border: Border.all(color: border, width: skin.depth.borderWidth),
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
/// The last chip is never flush to the screen edge, selected chips are **never
/// reordered to the front** (reordering under a thumb is a mis-tap), and in
/// Veld the rail does not scroll at all: horizontal-scroll discovery fails
/// outdoors, so it becomes a wrap of full-width chips.
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

    if (skin.density == TiqDensity.veld) {
      return Semantics(
        container: true,
        label: semanticsLabel,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: Wrap(
            spacing: TiqSpace.s2,
            runSpacing: TiqSpace.s2,
            children: <Widget>[
              for (final chip in chips)
                // Two columns of full-width chips: a 56dp target in sun is the
                // floor, and two per row is what a 360dp phone holds.
                FractionallySizedBox(widthFactor: 1, child: chip),
            ],
          ),
        ),
      );
    }

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

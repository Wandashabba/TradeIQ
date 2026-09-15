import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/lumen_glass.dart';
import '../theme/lumen_palette.dart';
import '../theme/tiq_colors.dart';

/// The console's segmented-pill idiom, single-sourced: active is a solid
/// `brand` fill under white; inactive a `surface1` chip with a `line` hairline
/// under `ink2`; fully rounded (`radiusPill`), 11px w600, with a 160ms fill
/// transition on tap.
///
/// White-on-brand is a self-contained AA pair — brand is the same #0A6CF0 in
/// both themes (4.98:1 under white) — so neither theme's ink may sit on it
/// (dark ink1 on brand would fail AA). The pinning lives in pill_segment_test.
///
/// The active state is otherwise colour-only to a screen reader, so [selected]
/// is announced via `Semantics(selected:)` and every segment reads as a
/// `button`. Callers key the segment itself (`range-<name>`, `filter-<name>`,
/// `scope-mine`/`scope-all`); the `Semantics` sits just inside, so a segment's
/// selected state is read via `getSemantics`/a descendant finder off that key.
///
/// Two layouts share the one idiom: a [Wrap]/[Row] of intrinsic-width pills
/// (dashboard range control, tasks filter chips) and a 2-up [Row] of
/// equal-width, fixed-height segments (the outlet picker's scope control). The
/// latter passes [expand] (wraps in [Expanded]) plus a [height]; a segment with
/// a [height] centres its label and drops the pill padding, otherwise the pill
/// sizes to its label.
class PillSegment extends StatelessWidget {
  const PillSegment({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.expand = false,
    this.height,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Wrap in [Expanded] so the segment fills its share of a [Row]/[Flex].
  final bool expand;

  /// A fixed height centres the label and drops the pill padding; null lets the
  /// pill size to its label (the Wrap-of-chips layout).
  final double? height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final segment = Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: height,
          alignment: height == null ? null : Alignment.center,
          padding: height == null
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 5)
              : null,
          decoration: BoxDecoration(
            // Active is the theme's primary action: brand in dark, the dark
            // #241F47 pill in Lumen Glass — each with its own AA ink.
            color: selected ? colors.action : colors.surface1,
            border: Border.all(color: selected ? colors.action : colors.line),
            borderRadius: BorderRadius.circular(AppColors.radiusPill),
            // Glass lifts the active pill off its pane with the handoff's pill
            // shadow; the fills are already the composited glass tokens.
            boxShadow: colors.glass && selected
                ? [
                    BoxShadow(
                      color: context.lumen.shadow,
                      blurRadius: LumenGlass.shadowPill.blurRadius,
                      offset: LumenGlass.shadowPill.offset,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? colors.onAction : colors.ink2,
            ),
          ),
        ),
      ),
    );

    return expand ? Expanded(child: segment) : segment;
  }
}

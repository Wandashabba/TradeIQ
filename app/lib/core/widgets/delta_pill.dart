import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/lumen_glass.dart';
import '../theme/status_pill_colors.dart';
import '../theme/tiq_colors.dart';

/// How a [DeltaPill] should read: improving, needs watching, or degrading.
///
/// The tone is the caller's judgement, not the sign's — a metric where down is
/// good must pass [DeltaTone.good] for a negative delta. The glyph alone
/// carries the direction; the tone carries the verdict.
enum DeltaTone { good, warn, bad }

/// The redesign's delta language: a signed change inside a rounded status
/// wash — `▲ 4.2` on green, `▼ 1.8` on red, amber for a metric that is
/// lagging rather than falling.
///
/// This is the ONE pill the whole premium restyle speaks (dashboard hero, KPI
/// tiles, and every screen the batch passes touch later) — do not fork a
/// local variant; extend this.
///
/// Not to be unified with `DeltaBadge` (`charts.dart`): that is the
/// chart-scrub-tooltip delta (an arrow icon + optional value suffix, in the
/// theme's good/crit colours). This is the status *pill* — a `▲`/`▼`/`–` glyph
/// on a fixed [DeltaTone] wash, no suffix. Tooltip vs. pill: intentionally
/// distinct, not a fork to merge.
///
/// The direction is spelled out by the `▲`/`▼` glyph, never carried by colour
/// alone (#144), and each wash/text pair clears WCAG AA 4.5:1 for its 10.5px
/// text — pinned by `test/core/widgets/delta_pill_test.dart`. The washes are
/// fixed status colours rather than theme slots: a status wash is the same
/// verdict in both themes, and the pair's contrast is self-contained. Lumen
/// Glass draws the same verdict in its own status swatch (a mono figure on an
/// opaque tint composite, with a rim), equally self-contained.
class DeltaPill extends StatelessWidget {
  const DeltaPill({super.key, required this.delta, required this.tone});

  /// The signed change. Only the sign picks the glyph; the magnitude is
  /// rendered absolute, to one decimal. Callers gate pills on a real move
  /// (|Δ| ≥ 0.05, see KpiDelta.hasDelta) — but an exact zero that slips
  /// through renders `–`, never an invented direction (house precedent).
  final double delta;

  final DeltaTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final glyph = delta < 0
        ? '▼'
        : delta > 0
        ? '▲'
        : '–';

    if (colors.glass) {
      // Glass: the status swatch's wash, composited OPAQUE over surface1 so
      // the ink clears AA whatever pane or ground the pill lands on.
      final sw = switch (tone) {
        DeltaTone.good => LumenStatus.good,
        DeltaTone.warn => LumenStatus.warn,
        DeltaTone.bad => LumenStatus.crit,
      }.swatchOf(colors);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: Color.alphaBlend(sw.tint, colors.surface1),
          border: Border.all(color: sw.rim),
          borderRadius: BorderRadius.circular(LumenGlass.radiusChip),
        ),
        child: Text(
          '$glyph ${delta.abs().toStringAsFixed(1)}',
          style: LumenGlass.figure(
            size: 10.5,
            color: sw.ink,
            weight: FontWeight.w700,
          ),
        ),
      );
    }

    // Fixed status washes, single-sourced — see status_pill_colors.dart.
    final wash = switch (tone) {
      DeltaTone.good => statusPillGood,
      DeltaTone.warn => statusPillWarn,
      DeltaTone.bad => statusPillBad,
    };
    final (bg, fg) = (wash.bg, wash.fg);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
      ),
      child: Text(
        '$glyph ${delta.abs().toStringAsFixed(1)}',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

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
/// The direction is spelled out by the `▲`/`▼` glyph, never carried by colour
/// alone (#144), and each wash/text pair clears WCAG AA 4.5:1 for its 10.5px
/// text — pinned by `test/core/widgets/delta_pill_test.dart`. The washes are
/// fixed status colours rather than theme slots: a status wash is the same
/// verdict in both themes, and the pair's contrast is self-contained.
class DeltaPill extends StatelessWidget {
  const DeltaPill({super.key, required this.delta, required this.tone});

  /// The signed change. Only the sign picks the glyph; the magnitude is
  /// rendered absolute, to one decimal.
  final double delta;

  final DeltaTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      DeltaTone.good => (const Color(0xFFE7F5E7), const Color(0xFF0B6B0B)),
      DeltaTone.warn => (const Color(0xFFFDF3E2), const Color(0xFF8A5A00)),
      DeltaTone.bad => (const Color(0xFFFDEEEE), const Color(0xFFA52A2A)),
    };
    final glyph = delta < 0 ? '▼' : '▲';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
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

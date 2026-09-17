import 'package:flutter/material.dart';

import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../answer/answer_motion.dart';
import '../data/chat_controller.dart';
import 'rich_figures.dart';
import 'stat_tiles_card.dart' show sentimentColor;

/// The `ranked_bars` spec: a ranking, as bars.
///
/// **Two shapes, chosen by the data.** When every value is non-negative (the
/// common case — "out-of-stock lines by outlet"), bars grow from a left
/// baseline across the full track, in the accent: a count has no verdict of
/// its own. When any value is negative, the bars **diverge** around a centre
/// zero line — falls in critical, rises in good — and every value is printed
/// with its sign, so direction never rides on colour alone. Either way each
/// bar is scaled against the largest magnitude in the set.
///
/// Items keep the server's order, which is worst-first, and the **first**
/// item leads in a heavier weight.
class RankedBarsCard extends StatelessWidget {
  const RankedBarsCard({super.key, required this.artifact});

  final ChatArtifact artifact;

  @override
  Widget build(BuildContext context) {
    final data = RankedBarsData.from(artifact.data);
    final max = data.maxAbs;
    final leader = data.leaderIndex;

    return PanelCard(
      title: data.title ?? 'Ranking',
      subtitle: data.comparedTo,
      child: data.items.isEmpty
          ? Text(
              'Nothing to rank.',
              style: TextStyle(
                fontSize: 12.5,
                color: context.colors.glass
                    ? context.lumen.inkMuted
                    : context.colors.ink3,
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 360;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < data.items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 7),
                      _BarRow(
                        key: ValueKey(i == leader
                            ? 'ranked-bars-leader'
                            : 'ranked-bars-row-$i'),
                        item: data.items[i],
                        fraction: max == 0 ? 0 : data.items[i].value.abs() / max,
                        valueLabel: data.label(data.items[i].value),
                        diverging: data.diverging,
                        lead: i == leader,
                        index: i,
                        nameWidth: narrow ? 92 : 118,
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    super.key,
    required this.item,
    required this.fraction,
    required this.valueLabel,
    required this.diverging,
    required this.lead,
    required this.index,
    required this.nameWidth,
  });

  final RankedBarItem item;

  /// |value| / the largest |value|, 0–1.
  final double fraction;
  final String valueLabel;
  final bool diverging;
  final bool lead;
  final int index;
  final double nameWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final glass = colors.glass;
    final lumen = context.lumen;
    final negative = item.value < 0;
    final ink = glass ? lumen.ink : colors.ink1;
    final Color barColor;
    final Color valueColor;
    if (!diverging) {
      barColor = glass ? lumen.accentSolid : colors.series1;
      valueColor = ink;
    } else if (item.value == 0) {
      barColor = valueColor = sentimentColor(context, DeltaSentiment.neutral);
    } else {
      barColor = valueColor = sentimentColor(
        context,
        negative ? DeltaSentiment.bad : DeltaSentiment.good,
      );
    }
    final zeroLine = glass ? lumen.inkMuted.withValues(alpha: 0.28) : colors.axis;

    Widget bar(Alignment from) => item.value == 0
        ? const SizedBox.shrink()
        : GrowIn(
            delay: Duration(milliseconds: 60 * index),
            builder: (context, t) => FractionallySizedBox(
              key: ValueKey('ranked-bar-fill-$index'),
              alignment: from,
              widthFactor: (fraction * t).clamp(0.0, 1.0),
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          );

    final Widget track;
    if (diverging) {
      track = Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: negative ? bar(Alignment.centerRight) : null,
            ),
          ),
          Container(width: 1, height: 16, color: zeroLine),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: negative ? null : bar(Alignment.centerLeft),
            ),
          ),
        ],
      );
    } else {
      track = Row(
        children: [
          Container(width: 1, height: 16, color: zeroLine),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: bar(Alignment.centerLeft),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(
          width: nameWidth,
          child: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: lead ? FontWeight.w600 : FontWeight.w400,
              color: ink,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: SizedBox(height: 16, child: track)),
        const SizedBox(width: 10),
        SizedBox(
          width: 56,
          // Scaled down rather than clipped: a long count still reads whole.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              valueLabel,
              maxLines: 1,
              style: LumenGlass.figure(
                size: 12,
                color: valueColor,
                weight: lead ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

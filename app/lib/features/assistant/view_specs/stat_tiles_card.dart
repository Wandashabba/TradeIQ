import 'package:flutter/material.dart';

import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/agent_motion.dart';
import '../../../core/widgets/glass.dart';
import '../answer/answer_motion.dart';
import '../data/chat_controller.dart';
import 'rich_figures.dart';

/// The ink for a delta's verdict. Shared with the ranked bars so "bad" is the
/// same colour wherever a number falls.
Color sentimentColor(BuildContext context, DeltaSentiment sentiment) {
  final colors = context.colors;
  final glass = colors.glass;
  return switch (sentiment) {
    DeltaSentiment.good => colors.good,
    DeltaSentiment.warn => colors.warn,
    DeltaSentiment.bad => glass ? context.lumen.critical : colors.critText,
    DeltaSentiment.neutral => glass ? context.lumen.inkMuted : colors.ink3,
  };
}

/// The `stat_tiles` spec: the answer's figures as a two-column grid of tiles.
///
/// Each tile is a big mono figure that counts up as it arrives, a delta pill
/// whose colour is the server's verdict (never inferred from the sign — a
/// stock-out count going up is bad), what it is compared against, and an
/// optional meter.
class StatTilesCard extends StatelessWidget {
  const StatTilesCard({super.key, required this.artifact});

  final ChatArtifact artifact;

  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    final tiles = StatTileData.listFrom(artifact.data);
    if (tiles.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _tile(tiles[i], i)),
            const SizedBox(width: _gap),
            Expanded(
              child: i + 1 < tiles.length
                  ? _tile(tiles[i + 1], i + 1)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ));
      if (i + 2 < tiles.length) rows.add(const SizedBox(height: _gap));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  Widget _tile(StatTileData tile, int index) => Arrive(
        // The mockup's stagger, tightened: four tiles land inside 300ms.
        delay: Duration(milliseconds: 80 * index),
        child: StatTileView(tile: tile, index: index),
      );
}

class StatTileView extends StatelessWidget {
  const StatTileView({super.key, required this.tile, this.index = 0});

  final StatTileData tile;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final glass = colors.glass;
    final lumen = context.lumen;
    final ink = glass ? lumen.ink : colors.ink1;
    final muted = glass ? lumen.inkMuted : colors.ink3;
    final delta = tile.delta;
    final meter = tile.meter;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tile.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, height: 1.3, color: muted),
        ),
        const SizedBox(height: 5),
        CountUpFigure(
          value: tile.value,
          unit: tile.unit,
          style: LumenGlass.figure(size: 24, color: ink),
        ),
        if (meter != null) ...[
          const SizedBox(height: 7),
          _Meter(fraction: meter / 100, label: tile.formatted),
        ],
        if (delta != null || tile.comparedTo != null) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (delta != null) DeltaChip(delta: delta),
              if (tile.comparedTo != null)
                Text(
                  tile.comparedTo!,
                  style: LumenGlass.figure(
                    size: 11.5,
                    color: muted,
                    weight: FontWeight.w500,
                  ).copyWith(height: 1.2),
                ),
            ],
          ),
        ],
      ],
    );

    const padding = EdgeInsets.fromLTRB(13, 12, 13, 12);
    if (glass) {
      return GlassPane(
        kind: GlassKind.tile,
        // A grid of repeated tiles in the transcript never pays for a blur.
        blur: false,
        shadow: false,
        radius: LumenGlass.radiusControl,
        padding: padding,
        child: body,
      );
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(colors.radiusCard),
      ),
      child: body,
    );
  }
}

/// A figure sweeping 0 → value, formatted in its unit at every frame.
class CountUpFigure extends StatelessWidget {
  const CountUpFigure({
    super.key,
    required this.value,
    required this.unit,
    required this.style,
  });

  final num value;
  final String? unit;
  final TextStyle style;

  Widget _text(num v) => Text(
        formatAmount(v, unit),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return _text(value);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeOutCubic,
      // The last frame is the exact value, not the tween's float.
      builder: (context, v, _) => _text(v == value ? value : v),
    );
  }
}

/// `▼ 12.4%` on a wash of its verdict's colour.
class DeltaChip extends StatelessWidget {
  const DeltaChip({super.key, required this.delta});

  final TileDelta delta;

  @override
  Widget build(BuildContext context) {
    final color = sentimentColor(context, delta.sentiment);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        delta.text,
        style: LumenGlass.figure(
          size: 11.5,
          color: color,
          weight: FontWeight.w600,
        ).copyWith(height: 1.2),
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.fraction, required this.label});

  final double fraction;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final glass = colors.glass;
    return Semantics(
      label: '$label meter',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: Container(
          height: 5,
          color: glass ? context.lumen.track : colors.grid,
          alignment: Alignment.centerLeft,
          child: GrowIn(
            duration: const Duration(milliseconds: 900),
            delay: const Duration(milliseconds: 120),
            builder: (context, t) => FractionallySizedBox(
              key: const ValueKey('stat-tile-meter-fill'),
              widthFactor: (fraction * t).clamp(0.0, 1.0),
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: glass ? context.lumen.accentSolid : colors.brand,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

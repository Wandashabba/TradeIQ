import 'package:flutter/widgets.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/figure/sample_threshold.dart';
import '../../../core/widgets/torchlight/figure/stat_cluster.dart';
import '../../../core/widgets/torchlight/figure/stat_tile.dart';
import '../../../core/widgets/torchlight/mark/delta.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../l10n/l10n.dart';
import '../data/chat_controller.dart';
import 'rich_figures.dart';

/// The `stat_tiles` spec, as the kit's [StatCluster].
///
/// ## What this replaces, and why it is smaller than it was
///
/// The old card built its own tile: a `Container` with a border and a radius,
/// a `CountUpFigure` that tweened through numbers that were never true, a
/// `DeltaChip` on a 14%-alpha wash of its verdict's hue, and a meter in the
/// brand colour. All four are gone. `StatTile` owns the layout, the unknown
/// states, the delta's shape and the meter; `FigureSlot` owns the faces, the
/// locale and the em dash; `DeltaRule` owns when a delta may stand at all.
///
/// **The tile grid does not exist on a phone.** unify §1.4 rules the phone
/// layout horizontal — eyebrow left, figure right-aligned, meter and delta
/// beneath — with a two-column grid only above 320dp of *inner* width, which
/// is no phone this product ships to. The assistant surface argued for a 2×2
/// at 138dp cells and lost on its own arithmetic: "R 1,28 mln" at JBM 32 is
/// about 192dp.
///
/// **Amber: none, deliberately.** The shared component draws a meter's target
/// tick in ink-1 everywhere and `TorchClaim.meterTick` does not exist: four
/// repeated amber ticks in one cluster would be exactly the repeated fill the
/// law bans.
class StatTilesCard extends StatefulWidget {
  const StatTilesCard({super.key, required this.artifact});

  final ChatArtifact artifact;

  /// Four on a phone, three recommended, two in Veld.
  static int limitFor(TiqSkin skin) => skin.density == TiqDensity.veld
      ? StatCluster.maximumInVeld
      : StatCluster.maximumOnPhone;

  /// The tiles the fold shows before "Show all".
  static List<StatTileData> capped(List<StatTileData> tiles, TiqSkin skin) {
    final limit = limitFor(skin);
    return tiles.length <= limit ? tiles : tiles.sublist(0, limit);
  }

  @override
  State<StatTilesCard> createState() => _StatTilesCardState();
}

class _StatTilesCardState extends State<StatTilesCard> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final tiles = StatTileData.listFrom(widget.artifact.data);
    // A block with nothing in it is dropped, never rendered empty.
    if (tiles.isEmpty) return const SizedBox.shrink();

    // The fold holds four (two in Veld). The figures past it are not
    // dropped: stat tiles are answer-only — there is no full view to send a
    // reader to — so a figure cut here would be a figure the narrative
    // mentions and the screen cannot show. They wait behind one row, and
    // open as further clusters of the same size, never as one cluster
    // bigger than the law allows.
    final limit = StatTilesCard.limitFor(skin);
    final shown = _all ? tiles.length : StatTilesCard.capped(tiles, skin).length;
    final clusters = <Widget>[
      for (var i = 0; i < shown; i += limit)
        StatCluster(
          key: ValueKey<String>('stat-cluster-${i ~/ limit}'),
          semanticsLabel: i == 0 ? l10n.askFigures : null,
          tiles: <StatTile>[
            for (final tile in tiles.sublist(
              i,
              i + limit > shown ? shown : i + limit,
            ))
              askStatTile(context, tile),
          ],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < clusters.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: skin.space.intraBlock),
          clusters[i],
        ],
        if (shown < tiles.length) ...<Widget>[
          SizedBox(height: skin.space.intraBlock),
          SoftRow(
            key: const ValueKey<String>('stat-tiles-show-all'),
            density: SoftRowDensity.compact,
            title: l10n.askShowAll(tiles.length),
            separator: SoftRowSeparator.none,
            onTap: () => setState(() => _all = true),
          ),
        ],
      ],
    );
  }
}

/// One wire tile as the kit's [StatTile].
///
/// Everything the wire knows is handed over rather than re-decided here: the
/// metric's `decimals`, its `sampleSize` and its `baselineSampleSize`, and the
/// delta's direction and sentiment as two separate fields. Neither is derived
/// from the other — a stock-out count going up is bad and a spoilage count
/// going down is good, and only the server knows which this is.
StatTile askStatTile(BuildContext context, StatTileData tile) {
  final l10n = context.l10n;
  final delta = tile.delta;
  return StatTile(
    eyebrow: tile.label,
    value: tile.value,
    // An unknown figure keeps its tile, drops its unit and its delta, and
    // says so in words.
    noDataReason: tile.value == null ? l10n.askTileNoData : null,
    unit: askUnitFor(l10n, tile.unit, (tile.value ?? 0).abs()),
    decimals: tile.decimals,
    sampling: FigureSampling(
      kind: _kindOf(tile.unit),
      n: tile.sampleSize,
      baselineN: tile.baselineSampleSize,
    ),
    delta: delta == null || tile.value == null
        ? null
        : DeltaData(
            direction: switch (delta.up) {
              true => DeltaDirection.up,
              false => DeltaDirection.down,
              null => DeltaDirection.flat,
            },
            sentiment: switch (delta.sentiment) {
              DeltaSentiment.good => TiqSentiment.good,
              DeltaSentiment.bad => TiqSentiment.bad,
              // The wire's `warn` maps to neutral: there is no amber warning
              // in this system, and a delta is never a severity carrier.
              DeltaSentiment.warn => TiqSentiment.neutral,
              DeltaSentiment.neutral => TiqSentiment.neutral,
            },
            magnitude: delta.value,
            unit: askUnitFor(l10n, delta.unit, delta.value.abs()),
            decimals: delta.decimals ?? tile.decimals,
            comparedTo: tile.comparedTo,
          ),
    meter: tile.meter == null ? null : MeterData(value: tile.meter!),
  );
}

/// The wire's unit as the formatter's, with `pts` localised.
TiqUnit askUnitFor(AppLocalizations l10n, String? unit, num magnitude) =>
    unitFor(unit, magnitude, pointsWord: l10n.askPoints);

/// What kind of metric this is, for the sample thresholds.
///
/// A percentage or a points delta is a rate and needs n ≥ 5; a bare count is
/// a total and has no denominator to be thin.
MetricKind _kindOf(String? unit) =>
    unit == 'pct' || unit == 'pts' ? MetricKind.rate : MetricKind.count;

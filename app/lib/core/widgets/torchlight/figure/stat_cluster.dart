import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import 'stat_tile.dart';

/// The instrument panel that holds the tiles.
///
/// ## Separation: a gap **and** a rule
///
/// 12dp of gap with a centred 1px `edge-structure` rule in Night, a hairline
/// in Day (unify §1.4). Both, not either:
///
/// * A **hairline alone** measures 1.72:1 on the Night surface. It is exempt
///   from 3:1 as a decorative rule, which is precisely why it cannot be the
///   thing that separates two readings of an instrument.
/// * A **gap alone** was the manager surface's proposal, and it fails on its
///   own arithmetic: every inter-cell space has to exceed every intra-cell
///   space, and a tile's own rows are 8dp apart.
///
/// In Veld the rule is the 2px border every hairline becomes there.
///
/// ## Count
///
/// Four tiles maximum on a phone and three recommended — the fourth is the one
/// a reader least often acts on and it belongs in the table twin. Four
/// horizontal tiles plus a footer is about 470dp, which is most of a phone's
/// fold, and a route should pay that deliberately. Veld takes two: outdoors,
/// four figures is analysis, and nobody does analysis outdoors.
///
/// ## No amber
///
/// The cluster is where a route's amber *budget* is read, and it emits nothing
/// of its own. It declares no `TorchClaim`.
class StatCluster extends StatelessWidget {
  StatCluster({
    super.key,
    required this.tiles,
    this.footer,
    this.semanticsLabel,
  }) : assert(
         tiles.length <= maximumOnPhone,
         'StatCluster: ${tiles.length} tiles. Four is the maximum on a phone '
         'and three is the recommendation. The fourth figure is the one a '
         'reader least often acts on; it belongs in the table twin, not in '
         'the fold.',
       ),
       assert(
         tiles.isNotEmpty,
         'StatCluster: an empty cluster is an empty '
         'state, not a cluster. Render the empty state instead — a cluster '
         'of four em dashes reads as a broken screen.',
       );

  final List<StatTile> tiles;

  /// The held chip, the source line, one retry, "See the numbers". Mandatory
  /// whenever the cluster is accompanied by any chart.
  final Widget? footer;

  /// "Four figures for Gauteng North, week 38."
  final String? semanticsLabel;

  static const int maximumOnPhone = 4;
  static const int maximumInVeld = 2;

  /// 12dp gap, rule centred in it.
  static const double gap = 12;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    assert(
      skin.density != TiqDensity.veld || tiles.length <= maximumInVeld,
      'StatCluster: ${tiles.length} tiles in Veld. Veld halves density by '
      'rule; two figures is a reading and four is analysis, which nobody does '
      'in the sun.',
    );
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final column =
              constraints.maxWidth < StatTile.consoleWidth || tiles.length == 1;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (column) _column(skin) else _grid(skin),
              if (footer != null) ...<Widget>[
                const SizedBox(height: gap),
                _rule(skin),
                const SizedBox(height: gap),
                footer!,
              ],
            ],
          );
        },
      ),
    );
  }

  /// The phone: one column of horizontal tiles, full-bleed rules between them.
  Widget _column(TiqSkin skin) {
    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) {
        children
          ..add(const SizedBox(height: gap / 2))
          ..add(_rule(skin))
          ..add(const SizedBox(height: gap / 2));
      }
      children.add(
        // The layout is declared here rather than measured per tile, so every
        // tile in a column is the same shape even when one of them is narrow.
        _withLayout(tiles[i], StatTileLayout.horizontal),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  /// Tablet and desktop: two columns of vertical cells, with the same rule in
  /// both directions.
  ///
  /// An odd count leaves the last cell empty and draws no rules into it —
  /// never a stretched third tile, which would make one figure look more
  /// important than its neighbours for a reason that is purely arithmetic.
  Widget _grid(TiqSkin skin) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      final left = _withLayout(tiles[i], StatTileLayout.vertical);
      final right = i + 1 < tiles.length
          ? _withLayout(tiles[i + 1], StatTileLayout.vertical)
          : null;
      if (rows.isNotEmpty) {
        rows
          ..add(const SizedBox(height: gap / 2))
          ..add(_rule(skin))
          ..add(const SizedBox(height: gap / 2));
      }
      final cells = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: left),
          const SizedBox(width: gap),
          Expanded(child: right ?? const SizedBox.shrink()),
        ],
      );
      rows.add(
        right == null
            ? cells
            : Stack(
                children: <Widget>[
                  cells,
                  // The rule is an overlay rather than a Row child inside an
                  // `IntrinsicHeight`, because a `FigureSlot` measures itself
                  // with a `LayoutBuilder` and a `LayoutBuilder` cannot answer
                  // an intrinsic query. Two equal `Expanded` cells put the
                  // gap's centre at the row's centre, so `Center` is exact.
                  Positioned.fill(
                    child: Center(
                      child: SizedBox(
                        width: skin.depth.borderWidth,
                        child: ColoredBox(color: _ruleColour(skin)),
                      ),
                    ),
                  ),
                ],
              ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  StatTile _withLayout(StatTile tile, StatTileLayout layout) => StatTile(
    key: tile.key,
    eyebrow: tile.eyebrow,
    value: tile.value,
    unit: tile.unit,
    decimals: tile.decimals,
    sampling: tile.sampling,
    delta: tile.delta,
    meter: tile.meter,
    noDataReason: tile.noDataReason,
    sampleNote: tile.sampleNote,
    stateLine: tile.stateLine,
    freshness: tile.freshness,
    provisional: tile.provisional,
    reconciliation: tile.reconciliation,
    lead: tile.lead,
    severity: tile.severity,
    subordinates: tile.subordinates,
    layout: layout,
    strings: tile.strings,
    deltaStrings: tile.deltaStrings,
    onTap: tile.onTap,
    semanticsHint: tile.semanticsHint,
  );

  /// The separator. `edge-structure` in Night at 3:1 against the surface it
  /// divides; the decorative hairline on paper, where the fill step is already
  /// visible; 2px in Veld.
  Widget _rule(TiqSkin skin) => SizedBox(
    height: skin.depth.borderWidth,
    width: double.infinity,
    child: ColoredBox(color: _ruleColour(skin)),
  );

  Color _ruleColour(TiqSkin skin) => skin.brightness == Brightness.dark
      ? skin.palette.edgeStructure
      : skin.palette.hairline;
}

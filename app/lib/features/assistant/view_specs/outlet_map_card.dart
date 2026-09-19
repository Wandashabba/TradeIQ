import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/design/figure_slot.dart';
import '../../../core/geo/mercator_fit.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/basemap.dart';
import '../../../core/widgets/torchlight/figure/eyebrow.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../l10n/l10n.dart';
import '../data/chat_controller.dart';

/// The `outlet_map` spec, rendered inline in the chat stream.
///
/// The data it reads is `getStockLevels`' result — pins come from
/// `worstOutlets: [{ outletId, outletName, outOfStockLines, lat, lng }]` —
/// a convention with the emitting tool, not part of the server-validated spec
/// contract. Rows without a finite coordinate are skipped rather than guessed:
/// a pin at (0, 0) is an answer about the Gulf of Guinea, not about stock.
///
/// The map itself is the dashboard island's recipe — the Tiq basemap kit,
/// [fitFor] instead of flutter_map's own fit machinery (which computes against
/// a camera size that can still be zero when `onMapReady` fires), and the
/// scroll wheel left to the page, because this map is a passenger inside the
/// chat's ListView.
class OutletMapCard extends StatelessWidget {
  const OutletMapCard({super.key, required this.artifact});

  final ChatArtifact artifact;

  /// The dashboard island's height. Intrinsic height is what the chat column
  /// needs, and a map has none of its own.
  static const double _mapHeight = 260;

  List<_MappedOutlet> _outlets() {
    final data = artifact.data;
    if (data is! Map<String, dynamic>) return const [];
    final raw = data['worstOutlets'];
    if (raw is! List) return const [];

    final outlets = <_MappedOutlet>[];
    for (final row in raw) {
      if (row is! Map<String, dynamic>) continue;
      final lat = row['lat'];
      final lng = row['lng'];
      if (lat is! num || lng is! num) continue;
      final latValue = lat.toDouble();
      final lngValue = lng.toDouble();
      if (!latValue.isFinite || !lngValue.isFinite) continue;

      final id = row['outletId'];
      final name = row['outletName'];
      final lines = row['outOfStockLines'];
      outlets.add(_MappedOutlet(
        id: id is String ? id : '$latValue,$lngValue',
        name: name is String ? name : 'Outlet',
        outOfStockLines: lines is num ? lines.toInt() : null,
        point: LatLng(latValue, lngValue),
      ));
    }
    return outlets;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final outlets = _outlets();

    final Widget body;
    if (outlets.isEmpty) {
      // The tool only declares this spec when it has outlets to point at, so
      // arriving here means the result's shape moved under this build. An
      // empty world map would read as "no problem anywhere", which is not
      // something we know — say what happened instead.
      body = Text(
        l10n.askMapUnreadable,
        style: skin.text.meta.style(color: skin.palette.ink3),
      );
    } else if (skin.mode == SkinMode.veld) {
      // Veld draws no maps (unify §4): a tile layer in glare is a smudge.
      // The same outlets, as a list a thumb can read.
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.askMapNotInVeld,
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
          for (var i = 0; i < outlets.length; i++)
            SoftRow(
              key: ValueKey<String>('stockout-row-${outlets[i].id}'),
              density: SoftRowDensity.compact,
              title: outlets[i].name,
              trailing: FigureSlot(
                value: outlets[i].outOfStockLines,
                role: skin.text.figureS,
                decimals: 0,
                color: skin.palette.ink1,
              ),
              semanticsLabel: _pinLabel(l10n, outlets[i]),
              separator: i == outlets.length - 1
                  ? SoftRowSeparator.none
                  : SoftRowSeparator.auto,
            ),
        ],
      );
    } else {
      body = SizedBox(
        height: _mapHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(skin.radii.control),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final degenerate = !size.width.isFinite ||
                  !size.height.isFinite ||
                  size.width <= 0 ||
                  size.height <= 0;
              if (degenerate) return const SizedBox.shrink();

              final (center, zoom) = fitFor(
                [for (final outlet in outlets) outlet.point],
                size: size,
              );

              return FlutterMap(
                key: ValueKey<Size>(size),
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: zoom,
                  // The wheel keeps scrolling the transcript — the same
                  // correctness fix as the dashboard island, for the same
                  // reason: this map cannot own the one gesture the page
                  // around it depends on.
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.scrollWheelZoom,
                  ),
                ),
                children: [
                  const TiqTileLayer(),
                  const TiqNavyTint(),
                  // Place names ride above the tint so the wash cannot mute them.
                  const TiqBasemapLabels(),
                  MarkerLayer(
                    markers: [
                      for (final outlet in outlets)
                        Marker(
                          point: outlet.point,
                          width: 34,
                          height: 34,
                          child: _StockoutPin(
                            key: ValueKey<String>('stockout-pin-${outlet.id}'),
                            outlet: outlet,
                          ),
                        ),
                    ],
                  ),
                  const TiqBasemapAttribution(),
                ],
              );
            },
          ),
        ),
      );
    }

    return Column(
      key: const ValueKey<String>('outlet-map'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Eyebrow(l10n.askMapTitle),
        if (outlets.isNotEmpty) ...<Widget>[
          const SizedBox(height: TiqSpace.s1),
          Text(
            l10n.askMapCount(outlets.length),
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
        ],
        SizedBox(height: skin.space.intraBlock),
        body,
      ],
    );
  }
}

String _pinLabel(AppLocalizations l10n, _MappedOutlet outlet) {
  final lines = outlet.outOfStockLines;
  return lines == null ? outlet.name : l10n.askMapPin(outlet.name, lines);
}

class _MappedOutlet {
  const _MappedOutlet({
    required this.id,
    required this.name,
    required this.outOfStockLines,
    required this.point,
  });

  final String id;
  final String name;
  final int? outOfStockLines;
  final LatLng point;
}

/// One stocked-out outlet on the map — the territory screen's white-disc pin.
///
/// Every pin on this card carries the same state, so there is no two-state
/// silhouette to distinguish; the severity lives in the semantics label,
/// where a screen reader gets the count in words instead of a set of
/// identically-labelled dots.
class _StockoutPin extends StatelessWidget {
  const _StockoutPin({super.key, required this.outlet});

  final _MappedOutlet outlet;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;

    return Semantics(
      // Its own node, not a merge into the map's: a screen reader should walk
      // N outlets as N stops, and without `container` the label folds into an
      // ancestor (the territory pin gets the same effect from `button: true`,
      // which would be a lie here — these pins do nothing when tapped).
      container: true,
      label: _pinLabel(context.l10n, outlet),
      child: DecoratedBox(
        // A ground disc under the glyph with a real edge: tiles range from
        // pale fields to dark roads, so a bare icon has no guaranteed
        // contrast anywhere. No shadow — the edge is the separation.
        decoration: BoxDecoration(
          color: p.surface,
          shape: BoxShape.circle,
          border: Border.all(color: p.edgeControl, width: 1),
        ),
        child: Center(
          child: Icon(
            Icons.location_on,
            key: ValueKey<String>('stockout-pin-icon-${outlet.id}'),
            // Crimson with its silhouette: a stock-out is a finding, and the
            // pin's shape and the label carry it without the hue.
            color: p.bad,
            size: 22,
          ),
        ),
      ),
    );
  }
}

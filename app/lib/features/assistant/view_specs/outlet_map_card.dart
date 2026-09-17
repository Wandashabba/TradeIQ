import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/geo/mercator_fit.dart';
import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/basemap.dart';
import '../../../core/widgets/console.dart';
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
    final outlets = _outlets();

    if (outlets.isEmpty) {
      // The tool only declares this spec when it has outlets to point at, so
      // arriving here means the result's shape moved under this build. An
      // empty world map would read as "no problem anywhere", which is not
      // something we know — say what happened instead.
      return PanelCard(
        title: 'Outlets with stockouts',
        child: Text(
          'The outlet locations for this answer could not be read. '
          'The summary above still applies.',
          style: TextStyle(fontSize: 12, color: context.colors.ink3),
        ),
      );
    }

    return PanelCard(
      title: 'Outlets with stockouts',
      subtitle: '${outlets.length} outlet${outlets.length == 1 ? '' : 's'}',
      child: SizedBox(
        height: _mapHeight,
        child: ClipRRect(
          // Glass rounds the map to the control radius, so it nests inside
          // the panel's larger corners rather than fighting them.
          borderRadius: BorderRadius.circular(
            context.colors.glass ? LumenGlass.radiusControl : 10,
          ),
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
      ),
    );
  }
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
    final colors = context.colors;
    final lines = outlet.outOfStockLines;

    return Semantics(
      // Its own node, not a merge into the map's: a screen reader should walk
      // N outlets as N stops, and without `container` the label folds into an
      // ancestor (the territory pin gets the same effect from `button: true`,
      // which would be a lie here — these pins do nothing when tapped).
      container: true,
      label: lines == null
          ? outlet.name
          : '${outlet.name}, $lines ${lines == 1 ? 'line' : 'lines'} out of stock',
      child: DecoratedBox(
        // A white disc under the glyph: tiles range from pale fields to dark
        // roads, so a bare icon has no guaranteed contrast anywhere.
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: colors.line, width: 1),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.location_on,
            key: ValueKey<String>('stockout-pin-icon-${outlet.id}'),
            color: colors.crit,
            size: 22,
          ),
        ),
      ),
    );
  }
}

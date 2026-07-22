import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/worklist.dart';
import '../../outlets/data/outlets_repository.dart';
import '../data/territories_repository.dart';

/// Coverage for one territory, kept per-id and cached by Riverpod so a
/// rebuild (e.g. the map panning) does not re-fetch and reset the camera.
///
/// Retries are disabled: Riverpod's default retry policy backs off silently
/// for several seconds (up to 10 attempts) before surfacing an error, which
/// would leave the screen showing a bare spinner with no explanation. Failing
/// fast and offering [AsyncSection]'s explicit Retry button is the better
/// trade for a screen the user is actively looking at.
final _territoryCoverageProvider =
    FutureProvider.family<TerritoryCoverage, String>(
  (ref, territoryId) {
    return ref.read(territoriesRepositoryProvider).getCoverage(territoryId);
  },
  retry: (retryCount, error) => null,
);

/// A pin map of one territory's outlets — a check disc where a visit landed
/// inside the coverage query's default window, a teardrop where one is still
/// outstanding. Reached from a "Map" action
/// on [TerritoriesScreen]; every role that can see the territories list can
/// open it, since the underlying coverage endpoint has no role restriction.
class TerritoryMapScreen extends ConsumerWidget {
  const TerritoryMapScreen({super.key, required this.territory});

  final Territory territory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverage = ref.watch(_territoryCoverageProvider(territory.id));
    return Scaffold(
      appBar: AppBar(title: Text('${territory.name} — Map')),
      body: AsyncSection<TerritoryCoverage>(
        value: coverage,
        label: 'territory coverage',
        onRetry: () => ref.invalidate(_territoryCoverageProvider(territory.id)),
        builder: (data) {
          final outlets = data.outlets;
          if (outlets.isEmpty) {
            return const Center(
              child: Text('No outlets in this territory yet.'),
            );
          }

          final points = [for (final o in outlets) LatLng(o.lat, o.lng)];
          // A single-outlet bounds box has zero area, so center on it
          // directly instead of asking flutter_map to "fit" a point.
          final cameraFit = outlets.length > 1
              ? CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints(points),
                  padding: const EdgeInsets.all(40),
                )
              : null;

          return FlutterMap(
            options: MapOptions(
              initialCenter: points.first,
              initialZoom: 14,
              initialCameraFit: cameraFit,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tradeiq.tradeiq_app',
              ),
              MarkerLayer(
                markers: [
                  for (final outlet in outlets)
                    Marker(
                      point: LatLng(outlet.lat, outlet.lng),
                      width: 34,
                      height: 34,
                      child: GestureDetector(
                        onTap: () => _showOutletSheet(context, outlet),
                        child: _OutletPin(
                          outlet: outlet,
                          key: ValueKey<String>('outlet-pin-${outlet.id}'),
                        ),
                      ),
                    ),
                ],
              ),
              // Required by OSM's ODbL license — visible attribution is
              // separate from (and in addition to) the TileLayer's
              // userAgentPackageName, which only satisfies the tile-usage
              // policy, not the license itself.
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showOutletSheet(BuildContext context, Outlet outlet) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              outlet.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(outlet.code),
            const SizedBox(height: 8),
            Text(outlet.visited ? 'Visited' : 'Not visited'),
          ],
        ),
      ),
    );
  }
}

/// One outlet on the coverage map.
///
/// The pins used to be the same [Icons.location_on] in red or green, which
/// broke the rule this codebase states in `console.dart` and `tiq_colors.dart`
/// — *state is never colour alone* — and put the entire visited/not-visited
/// distinction out of reach for a red-green colour-vision deficiency, the
/// commonest kind. It also read poorly against OpenStreetMap tiles, which are
/// busy and carry their own reds and greens.
///
/// Now the two states differ in **silhouette** first: a filled check disc for
/// visited, the classic teardrop for outstanding. Colour still carries the
/// same meaning for those who can see it, but nothing depends on it, and the
/// pins survive greyscale.
class _OutletPin extends StatelessWidget {
  const _OutletPin({super.key, required this.outlet});

  final Outlet outlet;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final visited = outlet.visited;

    return Semantics(
      button: true,
      // Screen readers get the state in words. Without this the map is a set
      // of identically-labelled buttons.
      label: '${outlet.name}, ${visited ? 'visited' : 'not yet visited'}',
      child: DecoratedBox(
        // A white disc under the glyph. OSM tiles range from pale fields to
        // dark roads and green parks, so a bare icon has no guaranteed
        // contrast anywhere; the disc gives it one background it can rely on.
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
            visited ? Icons.check_circle : Icons.location_on,
            key: ValueKey<String>('outlet-pin-icon-${outlet.id}'),
            color: visited ? colors.good : colors.crit,
            size: 22,
          ),
        ),
      ),
    );
  }
}

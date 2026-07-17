import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../outlets/data/outlets_repository.dart';
import '../data/territories_repository.dart';

/// A pin map of one territory's outlets — green if visited, red if not,
/// within the coverage query's default window. Reached from a "Map" action
/// on [TerritoriesScreen]; every role that can see the territories list can
/// open it, since the underlying coverage endpoint has no role restriction.
class TerritoryMapScreen extends ConsumerWidget {
  const TerritoryMapScreen({super.key, required this.territory});

  final Territory territory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('${territory.name} — Map')),
      body: FutureBuilder<TerritoryCoverage>(
        future: ref.read(territoriesRepositoryProvider).getCoverage(territory.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load coverage: ${snapshot.error}'),
            );
          }
          final outlets = snapshot.data!.outlets;
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
                      width: 32,
                      height: 32,
                      child: GestureDetector(
                        onTap: () => _showOutletSheet(context, outlet),
                        child: Icon(
                          Icons.location_on,
                          key: ValueKey<String>('outlet-pin-icon-${outlet.id}'),
                          color: outlet.visited ? Colors.green : Colors.red,
                          size: 32,
                        ),
                      ),
                    ),
                ],
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

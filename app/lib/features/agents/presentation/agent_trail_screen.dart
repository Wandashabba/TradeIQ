import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateProvider moved to legacy.dart in riverpod 3.x — still the right tool
// for a single piece of client-only UI state (the selected day) with no
// business logic attached.
import 'package:flutter_riverpod/legacy.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/basemap.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/agents_repository.dart';

/// The selected day, defaulting to today. Local dates only — the day boundary
/// is a client-side decision, see [dayBoundsLocal].
///
/// `.autoDispose`, like [agentActivityForDayProvider] itself: without it, a
/// manager who picks an earlier day and later navigates away would find the
/// screen re-open on that stale day rather than today, and a long-lived web
/// tab left open across midnight would keep "today" pinned to whenever the
/// tab first built this provider.
final agentTrailDayProvider = StateProvider.autoDispose<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Each agent's confirmed stops for one day, drawn in sequence.
///
/// This map shows where agents HAVE BEEN, not where they are. Everything about
/// its presentation is chosen to keep that distinction visible — see the
/// dashed polylines and the numbered markers below.
class AgentTrailScreen extends ConsumerWidget {
  const AgentTrailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(agentTrailDayProvider);
    final activity = ref.watch(agentActivityForDayProvider(day));

    return ManagerScaffold(
      title: 'Agent trail',
      actions: [
        TextButton.icon(
          key: const ValueKey<String>('agent-trail-date'),
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text('${day.year}-${_two(day.month)}-${_two(day.day)}'),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: day,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              ref.read(agentTrailDayProvider.notifier).state =
                  DateTime(picked.year, picked.month, picked.day);
            }
          },
        ),
      ],
      body: AsyncSection<AgentActivityPage>(
        value: activity,
        label: 'agent activity',
        onRetry: () => ref.invalidate(agentActivityForDayProvider(day)),
        builder: (page) {
          final withStops = page.agents.where((a) => a.stops.isNotEmpty).toList();
          if (withStops.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No check-ins on this day.'),
              ),
            );
          }

          final points = [
            for (final a in withStops)
              for (final s in a.stops) LatLng(s.lat, s.lng),
          ];

          // A single point has a zero-area bounds box, so centre on it rather
          // than asking flutter_map to "fit" it — same reasoning as
          // territory_map_screen.dart.
          final cameraFit = points.length > 1
              ? CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints(points),
                  padding: const EdgeInsets.all(40),
                )
              : null;

          return Column(
            children: [
              _TrailLegend(truncated: page.truncated),
              Expanded(
                child: FlutterMap(
                  // Keyed on the day: flutter_map's `_initialCameraFitApplied`
                  // flag is one-shot per State (see its own widget.dart), so
                  // without this key, picking a new day would rebuild the same
                  // State and leave the camera pointed at the old day's
                  // bounds — the pins would move, the camera would not.
                  key: ValueKey<DateTime>(day),
                  options: MapOptions(
                    initialCenter: points.first,
                    initialZoom: 13,
                    initialCameraFit: cameraFit,
                  ),
                  children: [
                    const TiqTileLayer(),
                    PolylineLayer(
                      polylines: [
                        for (final a in withStops)
                          if (a.stops.length > 1)
                            Polyline(
                              points: [
                                for (final s in a.stops) LatLng(s.lat, s.lng),
                              ],
                              strokeWidth: 3,
                              color: context.colors.brand,
                              // Dashed, deliberately. A solid line would claim
                              // we know the route between two check-ins. We
                              // know two points; the rest is inference, and
                              // the stroke should look like inference.
                              pattern: StrokePattern.dashed(segments: const [8.0, 6.0]),
                            ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        for (final a in withStops)
                          for (var i = 0; i < a.stops.length; i++)
                            Marker(
                              point: LatLng(a.stops[i].lat, a.stops[i].lng),
                              width: 34,
                              height: 34,
                              child: _StopPin(
                                key: ValueKey<String>('agent-stop-${a.agentId}-$i'),
                                agentName: a.name,
                                stop: a.stops[i],
                                ordinal: i + 1,
                                isLast: i == a.stops.length - 1,
                              ),
                            ),
                      ],
                    ),
                    // Required by CARTO's terms (and, through them, OSM's
                    // ODbL licence) — separate from, and in addition to, the
                    // TileLayer's userAgentPackageName.
                    const TiqBasemapAttribution(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Says in words what the dashes mean. Without this the map still overstates
/// its own certainty to anyone who does not read stroke styles as semantics.
class _TrailLegend extends StatelessWidget {
  const _TrailLegend({required this.truncated});

  final bool truncated;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: colors.surface2,
      child: Text(
        'Numbered pins are confirmed check-ins. Dashed lines connect them in '
        'order — they are not a recorded route.'
        // A partial map that looks complete is worse than no map. If the
        // server had more agents than we asked for, say so here rather than
        // let the manager read empty space as "nobody else worked".
        '${truncated ? ' Showing the first 200 agents only.' : ''}',
        style: TextStyle(fontSize: 12, color: colors.ink3),
      ),
    );
  }
}

/// One stop. Numbered so the sequence reads without needing colour, and the
/// final stop is filled so "where they ended up" is findable at a glance.
class _StopPin extends StatelessWidget {
  const _StopPin({
    super.key,
    required this.agentName,
    required this.stop,
    required this.ordinal,
    required this.isLast,
  });

  final String agentName;
  final AgentStop stop;
  final int ordinal;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '$agentName, stop $ordinal, ${stop.outletName}, '
          '${_two(stop.checkinTs.hour)}:${_two(stop.checkinTs.minute)}',
      child: Tooltip(
        // Leads with the agent name: every agent's pins restart at "1" in
        // the same brand colour, so on a multi-agent day the tooltip is the
        // only thing a sighted manager has to tell three identical "1"
        // pins apart — the Semantics label above says the same thing, but
        // `excludeSemantics: true` makes that screen-reader-only.
        message: '$agentName · ${stop.outletName} · '
            '${_two(stop.checkinTs.hour)}:${_two(stop.checkinTs.minute)}',
        child: DecoratedBox(
          // A white disc under the glyph. OSM tiles range from pale fields to
          // dark roads, so a bare numeral has no reliable contrast anywhere.
          decoration: BoxDecoration(
            color: isLast ? colors.brand : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: colors.line, width: 1),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1)),
            ],
          ),
          child: Center(
            child: Text(
              '$ordinal',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isLast ? Colors.white : colors.ink1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

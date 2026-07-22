import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateProvider moved to legacy.dart in riverpod 3.x — still the right tool
// for a single piece of client-only UI state (the selected day) with no
// business logic attached.
import 'package:flutter_riverpod/legacy.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/geo/mercator_fit.dart';
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

          return Column(
            children: [
              _TrailLegend(truncated: page.truncated),
              Expanded(child: _TrailMap(day: day, withStops: withStops)),
            ],
          );
        },
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// A stable fingerprint of where the pins actually are, for keying the map
/// alongside the day (see `_TrailMap`'s `FlutterMap` key comment). Built from
/// coordinates rather than agent identity so a same-data re-fetch (this
/// screen's own retry, or a background refresh) can't remount the map and
/// throw away the manager's pan/zoom for no reason — only a real change in
/// where the pins are should do that. Rounded to 4 decimal places (~11m) so
/// floating-point noise can't cause a spurious remount either.
String _pointsSignature(List<LatLng> points) => points
    .map(
      (p) =>
          '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}',
    )
    .join('|');

/// The trail map's fixed fallback/single-pin zoom, shared between
/// `fitFor`'s `singleZoom` and the degenerate-viewport fallback so the two
/// can't drift apart.
const _trailZoom = 13.0;

/// The trail map itself.
///
/// The centre/zoom are computed OURSELVES, by `fitFor` — not by
/// flutter_map's own `CameraFit.bounds`/`initialCameraFit`, and not by
/// calling `fitCamera` from `onMapReady` either. Both of those depend on
/// flutter_map's own internal camera size, which — confirmed against the
/// running web build, with a live debug overlay reading correct points, a
/// real bounds `CameraFit`, and a non-degenerate widget viewport already
/// measured — was STILL zero at the moment `onMapReady` fired, silently
/// producing a near-world zoom centred nowhere near the data. `fitFor` uses
/// the real pixel size this screen's own `LayoutBuilder` has in hand and
/// plain Web Mercator maths (see core/geo/mercator_fit.dart), so there is no
/// flutter_map camera state left to race — the result is handed to
/// flutter_map as plain `initialCenter`/`initialZoom`, values it applies
/// synchronously and unconditionally on every mount.
class _TrailMap extends StatelessWidget {
  const _TrailMap({required this.day, required this.withStops});

  final DateTime day;

  /// Must all have `stops.isNotEmpty` — the caller filters before
  /// constructing.
  final List<AgentActivity> withStops;

  @override
  Widget build(BuildContext context) {
    final points = [
      for (final a in withStops)
        for (final s in a.stops) LatLng(s.lat, s.lng),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final degenerate =
            !size.width.isFinite ||
            !size.height.isFinite ||
            size.width <= 0 ||
            size.height <= 0;
        if (degenerate) return const SizedBox.shrink();

        final (center, zoom) = fitFor(
          points,
          size: size,
          padding: 40,
          singleZoom: _trailZoom,
        );

        return FlutterMap(
          // Keyed on the day AND a fingerprint of the plotted coordinates: a
          // key change is what mounts a fresh State, and because we don't
          // hold or reuse our own `MapController` across mounts,
          // flutter_map creates a brand new internal one each time, which
          // always seeds its camera fresh from that mount's
          // `initialCenter`/`initialZoom`. The day alone isn't enough — this
          // screen's provider also watches `dashboardFilterProvider`, so a
          // manager switching territories without changing the date
          // re-fetches a completely different set of pins on the SAME day,
          // and the camera would stay pointed at the old territory. The
          // fingerprint is rounded (~11m) so a same-data re-fetch (this
          // screen's own refresh) can't remount the map and throw away a
          // pan/zoom for no reason.
          key: ValueKey<(DateTime, String)>((day, _pointsSignature(points))),
          // Deliberately keeps flutter_map's default interactionOptions,
          // scroll-wheel zoom included — unlike the dashboard panel's map
          // (dashboard_shell_screen.dart), which disables it. This screen IS
          // the page: it's a full-screen map inside ManagerScaffold with no
          // scrollable parent competing for the wheel, so there is nothing
          // for a wheel-zoom to fight with. The asymmetry between the two
          // maps is deliberate, not a missed case.
          options: MapOptions(initialCenter: center, initialZoom: zoom),
          children: [
            const TiqTileLayer(),
            PolylineLayer(
              polylines: [
                for (final a in withStops)
                  if (a.stops.length > 1)
                    Polyline(
                      points: [for (final s in a.stops) LatLng(s.lat, s.lng)],
                      strokeWidth: 3,
                      color: context.colors.brand,
                      // Dashed, deliberately. A solid line would claim we
                      // know the route between two check-ins. We know two
                      // points; the rest is inference, and the stroke
                      // should look like inference.
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
            // Required by CARTO's terms (and, through them, OSM's ODbL
            // licence) — separate from, and in addition to, the TileLayer's
            // userAgentPackageName.
            const TiqBasemapAttribution(),
          ],
        );
      },
    );
  }
}

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

  /// The non-last disc is a **fixed** white, chosen so it reads against
  /// unpredictable map tiles rather than the app theme — so its numeral must
  /// be pinned to a fixed dark ink too, not pulled from `colors.ink1`.
  /// `ink1` is near-white in dark theme (it is meant to sit on a dark panel,
  /// not a white disc), which made every non-final stop a blank white circle
  /// in the dark console: the numbering is the entire reason the sequence
  /// survives greyscale (#144), so a theme-dependent numeral on a
  /// theme-fixed disc quietly defeated its own accessibility property. This
  /// is the light theme's ink1 value, kept as a literal on purpose — do not
  /// swap it back to `colors.ink1`.
  static const _nonLastNumeralColor = Color(0xFF14161C);

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
                // isLast sits on colors.brand (a fixed blue, shared by both
                // themes) so white reads there regardless of theme; the
                // non-last numeral sits on the fixed white disc above, so it
                // gets the matching fixed dark ink rather than colors.ink1.
                color: isLast ? Colors.white : _nonLastNumeralColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

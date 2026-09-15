import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateProvider moved to legacy.dart in riverpod 3.x — still the right tool
// for a single piece of client-only UI state (the selected day) with no
// business logic attached.
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/geo/label_declutter.dart';
import '../../../core/geo/mercator_fit.dart';
import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/agent_motion.dart' show reduceMotion;
import '../../../core/widgets/basemap.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/lumen_kit.dart';
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

  /// Test-only kill-switch for the pins' glow-breathing loop (see [_StopPin]).
  ///
  /// The breathing is the design's single infinite animation, and an infinite
  /// animation makes `pumpAndSettle` time out in every widget test that
  /// renders this screen — so the test suite turns it off in `setUp` and the
  /// two motion tests turn it back on deliberately. Production never touches
  /// this; the *user-facing* off-switch is the OS reduce-motion setting,
  /// which [_StopPin] honours independently of this flag.
  @visibleForTesting
  static bool debugDisableGlowBreathing = false;

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
          final glass = context.colors.glass;
          if (withStops.isEmpty && glass) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GlassPane(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                  child: Text(
                    'No check-ins on this day.',
                    style: TextStyle(fontSize: 13, color: context.lumen.ink),
                  ),
                ),
              ),
            );
          }
          if (withStops.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No check-ins on this day.'),
              ),
            );
          }

          if (glass) {
            // Glass: the legend is a pane on the lit ground and the map is
            // framed beneath it as one rounded island — the basemap itself is
            // unchanged, the dark world it has always been.
            final radius = BorderRadius.circular(LumenGlass.radiusCard);
            final lumen = context.lumen;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  _TrailLegend(truncated: page.truncated),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        boxShadow: [
                          BoxShadow(
                            color: lumen.shadow,
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      foregroundDecoration: BoxDecoration(
                        borderRadius: radius,
                        border: Border.all(color: lumen.panelRim),
                      ),
                      child: ClipRRect(
                        borderRadius: radius,
                        child: _TrailMap(day: day, withStops: withStops),
                      ),
                    ),
                  ),
                ],
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

/// The stop-marker box: the glowing disc on top, the outlet label hanging
/// below it. Wide enough for a two-line label, tall enough for disc + label.
const _markerWidth = 128.0;
const _markerHeight = 72.0;

/// The glowing disc's diameter, within the box above.
const _discSize = 34.0;

/// The marker anchor: the geographic point sits at the centre of the DISC
/// (half the disc's height below the box's top-centre), not the centre of the
/// whole box — otherwise growing the box for the label would visibly slide
/// every pin off its coordinate. Computed with flutter_map's own helper
/// because its `Marker.alignment` named values are inverted relative to
/// Flutter's (see the call-site comment in `_TrailMap`).
final _markerAlignment = Marker.computePixelAlignment(
  width: _markerWidth,
  height: _markerHeight,
  left: _markerWidth / 2,
  top: _discSize / 2,
);

/// The trail map's fixed fallback/single-pin zoom, shared between
/// `fitFor`'s `singleZoom` and the degenerate-viewport fallback so the two
/// can't drift apart.
const _trailZoom = 13.0;

/// The label box relative to a marker's geographic point: the full marker
/// width, starting just below the disc. Deliberately the box width rather than
/// the measured text width — conservative (it suppresses slightly more than
/// strictly necessary) and deterministic, needing no text layout pass.
final _labelRect = Rect.fromLTWH(
  -_markerWidth / 2,
  _discSize / 2 + 3,
  _markerWidth,
  _markerHeight - _discSize - 3,
);

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
///
/// It IS stateful, but only to observe the camera for label decluttering
/// (#197) — see `_TrailMapState._camera`. Nothing observed there flows back
/// into the centre/zoom above.
class _TrailMap extends StatefulWidget {
  const _TrailMap({required this.day, required this.withStops});

  final DateTime day;

  /// Must all have `stops.isNotEmpty` — the caller filters before
  /// constructing.
  final List<AgentActivity> withStops;

  @override
  State<_TrailMap> createState() => _TrailMapState();
}

class _TrailMapState extends State<_TrailMap> {
  /// The live camera, used ONLY to decide which labels collide (#197).
  ///
  /// This does not reintroduce the race the class docstring above warns about.
  /// That race came from *seeding* the camera from flutter_map before it had a
  /// size; nothing here flows back into `initialCenter`/`initialZoom`, which
  /// are still computed by `fitFor` from our own measured viewport. Null until
  /// the first `onPositionChanged`, and until then decluttering runs against
  /// the same fit we handed flutter_map — so the very first frame is already
  /// correct rather than briefly garbled.
  ({LatLng center, double zoom})? _camera;

  @override
  Widget build(BuildContext context) {
    final withStops = widget.withStops;
    final day = widget.day;
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

        // Decluttering runs against the live camera once flutter_map reports
        // one, and against our own fit before that — so the first frame is
        // already correct rather than briefly showing the garbled overlap.
        final camera = _camera ?? (center: center, zoom: zoom);

        // Priority, lower wins: an agent's LAST stop is where they are now,
        // which is the question a manager opens this screen to answer, so it
        // outranks every earlier stop. Within each group, earlier ordinals
        // win — a reader follows the trail forwards.
        final labelVisible = declutterLabels(
          points: points,
          priority: [
            for (final a in withStops)
              for (var i = 0; i < a.stops.length; i++)
                (i == a.stops.length - 1 ? 0 : 1000) + i,
          ],
          center: camera.center,
          zoom: camera.zoom,
          labelRect: _labelRect,
        );

        // `points`, `labelVisible` and the marker loop below must all walk the
        // agents/stops in the same order for the flags to line up. One shared
        // flat index keeps that honest.
        var flatIndex = 0;

        // Glass draws the trail in the Lumen accent. Still a literal, not a
        // palette read: the line sits on the dark basemap in both themes, so
        // it takes the pale accent that reads over navy, whichever theme the
        // console around the map is in.
        final trailColor = context.colors.glass
            ? const Color(0xE6B5ABFC)
            // 0xFF4D9BFF at .8 alpha (0.8 × 255 = 0xCC): luminous against the
            // navy ground without competing with the pin glow.
            : const Color(0xCC4D9BFF);

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
          options: MapOptions(
            initialCenter: center,
            initialZoom: zoom,
            // Observed, never fed back (#197). `initialCenter`/`initialZoom`
            // above still come from our own `fitFor`; this only tells the
            // label declutterer where things currently sit, so a pan or zoom
            // re-resolves which captions collide. Guarded against redundant
            // setState so an idle map does not rebuild every frame.
            onPositionChanged: (position, _) {
              final next = (center: position.center, zoom: position.zoom);
              if (_camera?.center == next.center &&
                  _camera?.zoom == next.zoom) {
                return;
              }
              setState(() => _camera = next);
            },
          ),
          children: [
            const TiqTileLayer(),
            // The navy wash sits between the tiles and the trail geometry:
            // the ground reads as the deep-blue Tide Guide world while the
            // pins, labels and lines above keep full brightness.
            const TiqNavyTint(),
            PolylineLayer(
              polylines: [
                for (final a in withStops)
                  if (a.stops.length > 1)
                    Polyline(
                      points: [for (final s in a.stops) LatLng(s.lat, s.lng)],
                      strokeWidth: 3,
                      color: trailColor,
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
                      width: _markerWidth,
                      height: _markerHeight,
                      // Anchors the DISC's centre — not the box's centre — on
                      // the geographic point, so the label hangs below it.
                      // NOTE: flutter_map's Marker.alignment is INVERTED
                      // relative to Flutter's own semantics (its docs:
                      // `Alignment.topCenter` puts the whole box ABOVE the
                      // point — which would sit the label on the coordinate
                      // and float the disc over it), so this is computed with
                      // flutter_map's own pixel helper instead of named
                      // constants: the point sits _discSize/2 below the box's
                      // top-centre, dead centre of the disc.
                      alignment: _markerAlignment,
                      child: _StopPin(
                        key: ValueKey<String>('agent-stop-${a.agentId}-$i'),
                        agentName: a.name,
                        stop: a.stops[i],
                        ordinal: i + 1,
                        isLast: i == a.stops.length - 1,
                        showLabel: labelVisible[flatIndex++],
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
    final message =
        'Numbered pins are confirmed check-ins. Dashed lines connect them in '
        'order — they are not a recorded route.'
        // A partial map that looks complete is worse than no map. If the
        // server had more agents than we asked for, say so here rather than
        // let the manager read empty space as "nobody else worked".
        '${truncated ? ' Showing the first 200 agents only.' : ''}';

    if (context.colors.glass) {
      // Glass: the legend leaves the map's navy world and becomes a pane on
      // the console's own ground, above the framed map it explains.
      final lumen = context.lumen;
      return GlassPane(
        radius: LumenGlass.radiusControl,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Kicker('How to read it', color: lumen.kicker),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: lumen.inkMuted,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      // Fixed translucent dark chrome, not a theme token: this strip belongs
      // to the map's Tide Guide world (deep navy in BOTH app themes), so it
      // matches the tiles it sits against rather than the console around it.
      color: const Color(0xCC050A16),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12, color: Color(0xFF8FA5C6)),
      ),
    );
  }
}

/// One stop: a glowing numbered disc with a luminous outlet label hanging
/// below it — the Tide Guide pin.
///
/// The numbering carries the sequence and the halo is only enhancement
/// (honesty rule #144: the trail must survive greyscale, colour-blindness and
/// a screenshot in an email). The last stop's brighter core + stronger halo
/// says "where they ended up" at a glance, but a reader who can't see the
/// glow loses nothing: the highest numeral says the same thing.
///
/// Every colour here is a fixed literal, not a theme token — the pin sits on
/// map tiles (the same deep-navy world in both app themes), not on console
/// chrome. The white numeral is guarded by contrast tests against the
/// gradient's deep core; the light highlight is offset away from the centre
/// precisely so the numeral never sits on it (white on the highlight colour
/// would be ~1.9:1).
///
/// Stateful only for the glow "breathing" — the design's ONLY looping
/// animation (spec motion table): the halo opacity swings ±3% over a 2400ms
/// repeating curve. Subtle by intent — visible if you look, invisible if you
/// don't. Under [reduceMotion] the controller never runs and the halo holds
/// the mid value (exactly the specced alphas); same when
/// [AgentTrailScreen.debugDisableGlowBreathing] is set by tests.
class _StopPin extends StatefulWidget {
  const _StopPin({
    super.key,
    required this.agentName,
    required this.stop,
    required this.ordinal,
    required this.isLast,
    required this.showLabel,
  });

  final String agentName;
  final AgentStop stop;
  final int ordinal;
  final bool isLast;

  /// False when this label would collide with a higher-priority one (#197).
  ///
  /// Only the label is dropped — never the disc — so no stop disappears from
  /// the map, and the Semantics label below still carries outlet and time for
  /// a screen reader regardless.
  final bool showLabel;

  @override
  State<_StopPin> createState() => _StopPinState();
}

class _StopPinState extends State<_StopPin>
    with SingleTickerProviderStateMixin {
  /// The glow blue — rgba(64,156,255) — that both halo shadows are cut from.
  static const _glow = Color(0xFF409CFF);

  // Created eagerly, NOT `late final`, and NOT started in initState — the
  // same two traps PulseDot (agent_motion.dart) documents: a lazily-created
  // controller can be first constructed by dispose(), and MediaQuery (the
  // reduce-motion preference) isn't readable until didChangeDependencies.
  late AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this, // SingleTickerProviderStateMixin: respects TickerMode.
      duration: const Duration(milliseconds: 2400),
      // The mid value: when the loop never starts (reduced motion, tests)
      // the curve below maps 0.5 → a breathing factor of exactly 1.0, i.e.
      // the specced halo alphas, statically.
      value: 0.5,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBreathing();
  }

  @override
  void didUpdateWidget(_StopPin old) {
    super.didUpdateWidget(old);
    _syncBreathing();
  }

  void _syncBreathing() {
    final shouldBreathe = !reduceMotion(context) &&
        !AgentTrailScreen.debugDisableGlowBreathing;
    if (shouldBreathe && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
    } else if (!shouldBreathe && _breath.isAnimating) {
      _breath.stop();
      _breath.value = 0.5;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stop = widget.stop;
    final time = '${_two(stop.checkinTs.hour)}:${_two(stop.checkinTs.minute)}';
    // The last stop gets the brighter core and the stronger halo.
    //
    // Glass trades the Tide Guide blues for the Lumen accent. Still literals,
    // not palette reads: the pin sits on the dark basemap in both themes, and
    // the white numeral is held to 3:1 against each core (6.8:1 and 4.3:1).
    final glass = context.colors.glass;
    final highlight = glass
        ? (widget.isLast ? const Color(0xFFCFC7FF) : const Color(0xFF9184D9))
        : (widget.isLast ? const Color(0xFF9FD4FF) : const Color(0xFF7CC0FF));
    final core = glass
        ? (widget.isLast ? const Color(0xFF7A6FC0) : const Color(0xFF5D5294))
        : (widget.isLast ? const Color(0xFF3B93F5) : const Color(0xFF1F7AE0));
    final glow = glass ? const Color(0xFFB5ABFC) : _glow;
    final innerHaloAlpha = widget.isLast ? 0.65 : 0.5;
    final outerHaloAlpha = widget.isLast ? 0.25 : 0.18;

    // Every stop is a confirmed visit, so a tap opens it for review (#208).
    // The pin was already announced as a button; now it behaves like one.
    void openVisit() => context.push('/visits/${stop.visitId}');

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${widget.agentName}, stop ${widget.ordinal}, '
          '${stop.outletName}, $time',
      onTap: openVisit,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: openVisit,
        child: Tooltip(
        // Leads with the agent name: every agent's pins restart at "1", so on
        // a multi-agent day the tooltip is what tells three identical "1"
        // pins apart for a sighted manager — the Semantics label above says
        // the same thing, but `excludeSemantics: true` makes that
        // screen-reader-only. The label below shows outlet + time already;
        // the agent name is the part only the tooltip carries visually.
        message: '${widget.agentName} · ${stop.outletName} · $time',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _discSize,
              height: _discSize,
              child: AnimatedBuilder(
                animation: _breath,
                builder: (context, child) {
                  // easeInOut(0.5) == 0.5 → factor 1.0 at rest; the swing is
                  // ±3% — ambient, not attention-seeking.
                  final breathe = 0.97 +
                      0.06 * Curves.easeInOut.transform(_breath.value);
                  return DecoratedBox(
                    key: widget.isLast
                        ? const ValueKey<String>('agent-stop-last-halo')
                        : null,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // Lit-sphere gradient: a small highlight pushed to the
                      // top-left, the rest of the disc the deep core the
                      // white numeral is contrast-tested against.
                      gradient: RadialGradient(
                        center: const Alignment(-0.4, -0.5),
                        radius: 1.0,
                        colors: [highlight, core],
                        stops: const [0.0, 0.75],
                      ),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: glow.withValues(
                              alpha: innerHaloAlpha * breathe),
                          blurRadius: 22,
                          spreadRadius: 6,
                        ),
                        BoxShadow(
                          color: glow.withValues(
                              alpha: outerHaloAlpha * breathe),
                          blurRadius: 44,
                          spreadRadius: 12,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: Center(
                  child: Text(
                    '${widget.ordinal}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            // The luminous label: what the old map hid in a hover tooltip,
            // now readable on the map itself. The heavy dark shadow is what
            // keeps it legible over whatever tile detail sits beneath.
            //
            // Suppressed when it would collide with a higher-priority label
            // (#197) — two stops at outlets ~20m apart drew their labels over
            // each other as garbled text. The disc above always survives, so
            // the stop itself is never lost, only its caption.
            if (widget.showLabel)
              Text(
                '${stop.outletName} · $time',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  // Glass tints the luminous label toward the accent, still
                  // near-white over the dark basemap.
                  color: glass
                      ? const Color(0xFFEDE9FF)
                      : const Color(0xFFD9E6FF),
                  shadows: const [Shadow(blurRadius: 5, color: Colors.black)],
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

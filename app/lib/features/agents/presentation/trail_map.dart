import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
// `hide Path`: latlong2 exports a `Path` of its own, and the pins below are
// drawn with dart:ui's.
import 'package:latlong2/latlong.dart' hide Path;

import '../../../core/design/tiq_number.dart';
import '../../../core/geo/label_declutter.dart';
import '../../../core/geo/mercator_fit.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../l10n/l10n.dart';
import '../../../core/widgets/basemap.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../data/agent_locations_repository.dart';
import '../data/agents_repository.dart';
import 'live_location_layer.dart';

/// THE TRAIL MAP — a fixed-height band above the trail list, or nothing.
///
/// Three conditions remove it, and each says so in words rather than leaving a
/// grey rectangle. They are the same three the agent's own map declares, and
/// for the same reasons:
///
/// 1. **Veld.** Maps do not render in the outdoor skin (unify §4). The list
///    beneath is not a fallback — it is the same day in the same order, with
///    the agent named and every stop numbered.
/// 2. **No room.** The band takes the plate's fold budget and does not render
///    below 200dp: 96dp of basemap at street zoom is four buildings and no
///    orientation.
/// 3. **No tiles.** A forecourt with no signal. A tile request that fails *is*
///    the offline signal on this screen.
///
/// ## The paint budget
///
/// The pins this replaced were the most expensive objects in the console: a
/// `RadialGradient` plus **two** `BoxShadow`s each, breathing on a 2400ms loop
/// — per pin, on a map that draws up to two hundred of them. That is four
/// hundred shadows in Night, where the budget is **zero**, and two hundred
/// gradient decorations against a ceiling of twelve. The numbered disc here is
/// two `CustomPaint` strokes and a numeral: no gradient, no shadow, no
/// `saveLayer`, and no ticker at all. What the glow was for — "this is where
/// they ended up" — is carried by a filled disc against the earlier stops'
/// outlined ones, which is a silhouette and therefore survives greyscale, a
/// screenshot in an email and a reader.
double trailMapHeight(BuildContext context) {
  final skin = context.skin;
  if (skin.mode == SkinMode.veld) return 0;
  final viewport = MediaQuery.sizeOf(context).height;
  final budget = math.min(
    (viewport * 0.44).clamp(200.0, 360.0),
    viewport - 440,
  );
  return budget < 200 ? 0 : budget;
}

/// How many stops may be drawn before the map stops being readable.
///
/// Two hundred agents times a day of stops is a blob, not a map; the list
/// beneath carries every one of them whatever this cap does.
const int trailMarkerBudget = 120;

class TrailMap extends StatefulWidget {
  const TrailMap({
    super.key,
    required this.day,
    required this.withStops,
    this.live = const <AgentLocation>[],
  });

  final DateTime day;

  /// Every agent that has at least one stop on [day].
  final List<AgentActivity> withStops;

  /// Today's live positions; all have `hasPosition`. Empty on a past day —
  /// this minute's positions drawn over a past day's trail would put two
  /// different moments on one screen.
  final List<AgentLocation> live;

  /// How many tile failures mean *offline* rather than *one bad tile*.
  @visibleForTesting
  static int debugFailureThreshold = 6;

  @override
  State<TrailMap> createState() => _TrailMapState();
}

class _TrailMapState extends State<TrailMap> {
  /// The live camera, used ONLY to decide which labels collide (#197).
  ///
  /// Nothing observed here flows back into `initialCenter`/`initialZoom`,
  /// which are still computed by `fitFor` from this screen's own measured
  /// viewport — see the note on that race below.
  ({LatLng center, double zoom})? _camera;

  int _failures = 0;

  void _cameraMoved(LatLng center, double zoom) {
    if (_camera?.center == center && _camera?.zoom == zoom) return;
    setState(() => _camera = (center: center, zoom: zoom));
  }

  void _tileFailed() {
    if (_failures >= TrailMap.debugFailureThreshold || !mounted) {
      _failures += 1;
      return;
    }
    setState(() => _failures += 1);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final height = trailMapHeight(context);
    if (skin.mode == SkinMode.veld) return const _VeldNote();
    if (height <= 0) return const SizedBox.shrink();
    if (_failures >= TrailMap.debugFailureThreshold) return const _TilesOff();

    return TorchBleed(
      extra: skin.space.gutter * 2,
      child: SizedBox(
        height: height,
        child: _Basemap(state: this),
      ),
    );
  }
}

class _Basemap extends StatelessWidget {
  const _Basemap({required this.state});

  final _TrailMapState state;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final widget = state.widget;
    final withStops = widget.withStops;
    final day = widget.day;

    // Flattened once, in the order the markers walk, so the declutter flags
    // and the markers cannot fall out of step.
    final points = <LatLng>[
      for (final a in withStops)
        for (final s in a.stops) LatLng(s.lat, s.lng),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (!size.width.isFinite ||
            !size.height.isFinite ||
            size.width <= 0 ||
            size.height <= 0) {
          return const SizedBox.shrink();
        }

        // The centre and zoom are computed HERE, from the pixel size this
        // LayoutBuilder has in hand, and not by flutter_map's own
        // `initialCameraFit` or a `fitCamera` from `onMapReady`: both read
        // flutter_map's internal camera size, which is still zero when
        // `onMapReady` fires and silently produces a near-world zoom centred
        // nowhere near the data.
        final (center, zoom) = fitFor(
          points.isNotEmpty
              ? points
              : <LatLng>[for (final a in widget.live) LatLng(a.lat!, a.lng!)],
          size: size,
          padding: 40,
          singleZoom: 13,
        );
        final camera = state._camera ?? (center: center, zoom: zoom);

        // Priority, lower wins: an agent's LAST stop is where they ended up,
        // which is the question a manager opens this screen to answer, so it
        // outranks every earlier stop. Within each group, earlier ordinals
        // win — a reader follows the trail forwards.
        final labelVisible = declutterLabels(
          points: points,
          priority: <int>[
            for (final a in withStops)
              for (var i = 0; i < a.stops.length; i++)
                (i == a.stops.length - 1 ? 0 : 1000) + i,
          ],
          center: camera.center,
          zoom: camera.zoom,
          labelRect: _labelRect,
        );

        var flat = 0;
        var drawn = 0;
        final markers = <Marker>[];
        for (final a in withStops) {
          for (var i = 0; i < a.stops.length; i++) {
            final index = flat++;
            if (drawn >= trailMarkerBudget) continue;
            drawn++;
            markers.add(
              Marker(
                point: LatLng(a.stops[i].lat, a.stops[i].lng),
                width: _markerWidth,
                height: _markerHeight,
                // Anchors the DISC's centre on the geographic point, so the
                // caption hangs below it. flutter_map's `Marker.alignment`
                // named values are inverted relative to Flutter's own, so this
                // uses its pixel helper rather than a named constant.
                alignment: _markerAlignment,
                child: TrailStopPin(
                  key: ValueKey<String>('agent-stop-${a.agentId}-$i'),
                  agentName: a.name,
                  stop: a.stops[i],
                  ordinal: i + 1,
                  isLast: i == a.stops.length - 1,
                  showLabel: labelVisible[index],
                  // Every stop is a confirmed visit, so a tap opens it for
                  // review (#208). The pin announces itself as a button, and
                  // a button that a screen reader can read but not press is
                  // the kit-wide defect this project already fixed once —
                  // dropping the callback here would have reintroduced it
                  // behind a local `excludeSemantics` wrapper.
                  onTap: () => context.push('/visits/${a.stops[i].visitId}'),
                ),
              ),
            );
          }
        }

        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: skin.palette.edgeStructure,
              width: skin.depth.borderWidth,
            ),
          ),
          child: FlutterMap(
            // Keyed on the day AND a fingerprint of the plotted coordinates.
            // The day alone is not enough: the provider also watches the
            // dashboard filter, so a manager switching territories without
            // changing the date re-fetches a different set of pins on the
            // same day and the camera would stay pointed at the old one. The
            // fingerprint is rounded to ~11 m so a same-data refetch cannot
            // throw away a pan the manager just made.
            key: ValueKey<(DateTime, String)>((day, _signature(points))),
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              minZoom: 9,
              maxZoom: 17,
              // No rotation: every glyph here is read upright and a rotated
              // map re-rasterises the label layer on every frame. No
              // scroll-wheel zoom either — this map lives inside the shell's
              // scroll view, and a wheel that sometimes zooms and sometimes
              // scrolls is a wheel nobody trusts.
              interactionOptions: const InteractionOptions(
                flags:
                    InteractiveFlag.drag |
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.pinchMove,
              ),
              // Observed, never fed back (#197): `initialCenter` and
              // `initialZoom` above still come from this screen's own
              // `fitFor`. This only tells the declutterer where things
              // currently sit, so a pan or a zoom re-resolves which captions
              // collide. Guarded against a redundant setState so an idle map
              // does not rebuild every frame.
              onPositionChanged: (position, _) =>
                  state._cameraMoved(position.center, position.zoom),
            ),
            children: <Widget>[
              TiqTileLayer(onTileError: state._tileFailed),
              // The navy wash sits between the tiles and the trail geometry,
              // so the ground reads as one world while the marks above it
              // keep full contrast.
              const TiqNavyTint(),
              const TiqBasemapLabels(),
              _TrailLines(withStops: withStops),
              MarkerLayer(
                markers: <Marker>[
                  ...markers,
                  // Live squares last, on top of the trail.
                  ...liveAgentMarkers(widget.live),
                ],
              ),
              // Esri's credit is a licence requirement, not decoration.
              const TiqBasemapAttribution(),
            ],
          ),
        );
      },
    );
  }

  /// A fingerprint of the plotted points, rounded to ~11 m. Integers of
  /// ten-thousandths rather than formatted decimals: this is a key, not a
  /// figure, and a key has no business going near a formatter.
  static String _signature(List<LatLng> points) => points
      .map(
        (p) => '${(p.latitude * 1e4).round()},${(p.longitude * 1e4).round()}',
      )
      .join(';');
}

/// The dashes between two check-ins.
///
/// **Dashed, deliberately.** A solid line would claim we know the route
/// between two check-ins. We know two points; the rest is inference, and the
/// stroke should look like inference. The line takes `ink2` on the map's own
/// dark ground — the Oatmeal neutral, never amber: amber is a light that says
/// where to look, and every agent's trail would be claiming it at once.
class _TrailLines extends StatelessWidget {
  const _TrailLines({required this.withStops});

  final List<AgentActivity> withStops;

  @override
  Widget build(BuildContext context) {
    // The basemap is the same dark canvas in every skin, so the geometry over
    // it reads the Night palette whatever the console around it wears.
    final night = TiqSkin.night();
    return PolylineLayer<Object>(
      polylines: <Polyline<Object>>[
        for (final a in withStops)
          if (a.stops.length > 1)
            Polyline<Object>(
              points: <LatLng>[for (final s in a.stops) LatLng(s.lat, s.lng)],
              strokeWidth: 3,
              color: night.palette.ink2,
              pattern: StrokePattern.dashed(segments: const <double>[8, 6]),
            ),
      ],
    );
  }
}

/// Above this scale a marker's caption is dropped rather than shrunk. See
/// [TrailStopPin].
const double _captionCeiling = 1.3;

const double _markerWidth = 128;
const double _markerHeight = 72;
const double _discSize = 32;

final Alignment _markerAlignment = Marker.computePixelAlignment(
  width: _markerWidth,
  height: _markerHeight,
  left: _markerWidth / 2,
  top: _discSize / 2,
);

/// The caption box relative to a marker's point. The full marker width rather
/// than the measured text width: conservative, deterministic, and needing no
/// layout pass.
final Rect _labelRect = Rect.fromLTWH(
  -_markerWidth / 2,
  _discSize / 2 + 3,
  _markerWidth,
  _markerHeight - _discSize - 3,
);

/// ONE CONFIRMED CHECK-IN: a numbered disc with its outlet caption beneath.
///
/// Two channels and no colour among them. The **numeral** carries the
/// sequence and the **fill** carries "where they ended up": the last stop is a
/// filled disc, every earlier one an outlined one. A reader who cannot tell
/// the two inks apart still has the highest numeral saying the same thing.
///
/// Nothing here breathes, glows or casts. The glow this replaced was the
/// design's only infinite animation and it ran once per pin.
class TrailStopPin extends StatelessWidget {
  const TrailStopPin({
    super.key,
    required this.agentName,
    required this.stop,
    required this.ordinal,
    required this.isLast,
    required this.showLabel,
    this.onTap,
  });

  final String agentName;
  final AgentStop stop;
  final int ordinal;
  final bool isLast;

  /// False when this caption would collide with a higher-priority one (#197).
  ///
  /// Only the caption is dropped — never the disc — so no stop leaves the map,
  /// and the semantics label still carries the outlet and the time whatever is
  /// painted.
  final bool showLabel;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // The basemap is the same dark canvas in every skin, so the pin takes the
    // Night palette wherever the console is — rather than painting Veld's
    // near-black ink on a near-black tile.
    final night = TiqSkin.night();
    final p = night.palette;
    final time = trailStopTime(stop.checkinTs);
    final scale = MediaQuery.textScalerOf(context).scale(1);

    // A MARKER IS POSITIONED, NOT LAID OUT. Its box is a fixed 128x72 of
    // ground, and type that grows inside one does not push the map around —
    // it spills over the tiles. So above 1.3x the caption is **dropped**
    // rather than shrunk: every one of these outlets and times is in the
    // trail list beneath at full scale, with the agent named above it, which
    // is where a reader who needs 2.0x text is actually being served. The
    // numeral is clamped for the same reason — a 26dp digit in a 32dp disc is
    // a digit with no disc around it.
    final captionFits = showLabel && scale <= _captionCeiling;
    final numeral = MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(math.min(scale, _captionCeiling)));

    // `button` FOLLOWS the callback rather than being asserted beside it. A
    // pin with nothing to open is a label, not a control: announcing it as a
    // button would promise a screen reader an action that does not exist,
    // which is exactly the defect the kit's button family was fixed for.
    final pressable = onTap != null;

    return Semantics(
      button: pressable,
      excludeSemantics: true,
      label: context.l10n.trailPinLabel(
        agentName,
        '$ordinal',
        stop.outletName,
        time,
      ),
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: _discSize,
              height: _discSize,
              child: CustomPaint(
                painter: _StopDiscPainter(
                  ink: p.ink1,
                  ground: p.ground,
                  filled: isLast,
                ),
                child: MediaQuery(
                  data: numeral,
                  child: Center(
                    child: Text(
                      TiqNumber.of(context).format(ordinal),
                      maxLines: 1,
                      style: night.text.figureS.style(
                        color: isLast ? p.ground : p.ink1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (captionFits) ...<Widget>[
              const SizedBox(height: 3),
              // A dark plate behind the caption rather than a text shadow: a
              // shadow is a blur, the budget bans them, and a declared block
              // is legible over any tile detail beneath it.
              DecoratedBox(
                decoration: BoxDecoration(color: p.ground),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: TiqSpace.s1),
                  child: MediaQuery(
                    data: numeral,
                    child: Text(
                      '${stop.outletName} · $time',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: night.text.meta.style(color: p.ink1),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A disc: a 2px ring, filled on the last stop. No gradient, no shadow.
class _StopDiscPainter extends CustomPainter {
  const _StopDiscPainter({
    required this.ink,
    required this.ground,
    required this.filled,
  });

  final Color ink;
  final Color ground;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    // The ground disc first, so an outlined pin is readable over a pale road
    // rather than showing the tile through its middle.
    canvas.drawCircle(centre, radius, Paint()..color = filled ? ink : ground);
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_StopDiscPainter old) =>
      old.ink != ink || old.ground != ground || old.filled != filled;
}

/// Wall-clock, to the minute, in the manager's own zone.
String trailStopTime(DateTime at) {
  final t = at.toLocal();
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// Veld does not draw a map. It says so, and the trail list below is the day.
class _VeldNote extends StatelessWidget {
  const _VeldNote();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return EmptyState(
      key: const ValueKey<String>('trail-map-veld'),
      scope: EmptyScope.inPanel,
      headline: l10n.trailNoMapHeadline,
      body: l10n.trailNoMapBody,
    );
  }
}

/// Tiles that never arrived. A forecourt with no signal is a normal Tuesday.
class _TilesOff extends StatelessWidget {
  const _TilesOff();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return EmptyState(
      key: const ValueKey<String>('trail-map-offline'),
      scope: EmptyScope.inPanel,
      headline: l10n.trailMapOfflineHeadline,
      body: l10n.trailMapOfflineBody,
    );
  }
}

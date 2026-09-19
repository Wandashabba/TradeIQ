import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
// `hide Path`: latlong2 exports a `Path` of its own (a list of coordinates
// with a length), and the pins below are drawn with dart:ui's.
import 'package:latlong2/latlong.dart' hide Path;

import '../../../core/geo/mercator_fit.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/basemap.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../../outlets/data/outlets_repository.dart';
import '../data/agent_map.dart';
import 'agent_map_screen.dart' show mapStateWord;
import 'outlet_sheet.dart';

/// THE MAP REGION — a fixed-height band above the list, or nothing at all.
///
/// ## When there is no map
///
/// Three conditions, all of them ordinary rather than exceptional, and each
/// one says so in words rather than leaving a grey rectangle:
///
/// 1. **Veld.** Maps do not render in the outdoor skin (unify §4: "the plate,
///    sparklines, trend charts, maps and thumbnails do not render; figure
///    lists replace them"). This is not a concession — a dark basemap read in
///    direct sun at 40% backlight is a black rectangle, and the one screen an
///    agent uses standing in a forecourt at midday is the last place to ship
///    one. The figure list that replaces it is the store list, which was
///    always there: name, code, state word and distance, nearest first.
/// 2. **No room.** The region takes the plate's fold budget —
///    `min(clamp(0.44·vh, 200, 360), vh − 440)` — and below 200dp it does not
///    render. The plate collapses to a 96dp band at that point; a map does
///    not, because 96dp of basemap at street zoom is four buildings and no
///    orientation. A short phone (a 560dp viewport) and any phone held
///    sideways are exactly this case: 440dp is the header, the legend, two
///    rows and the nav, and a map that ate them would be a map of nothing you
///    could act on.
/// 3. **No tiles.** See [_TilesOff].
///
/// ## The paint budget
///
/// Esri serves 256px tiles. A 360×300dp region at devicePixelRatio 2 covers
/// about 3×4 tiles, and the labels are a second layer over the same grid — so
/// roughly 24 tile requests for a first view, and flutter_map keeps them.
/// Zoom is clamped to 9–17 so a pinch cannot walk into a new tile pyramid,
/// rotation is off (a rotated map re-rasterises every label and none of these
/// glyphs mean anything sideways), and the marker count is capped by
/// [agentMapMarkerBudget]. There is no `BackdropFilter`, no `saveLayer` and no
/// shadow anywhere in the region: the pins are `CustomPaint` strokes.
class AgentOutletMap extends StatefulWidget {
  const AgentOutletMap({super.key, required this.view});

  final AgentMapView view;

  /// How many failures mean *offline* rather than *one bad tile*.
  ///
  /// Two rows of a 3×4 grid. Past this, nothing is arriving.
  ///
  /// A test sets it to `0` for a region that is offline from its first frame,
  /// and to a large number for one that never gives up — both without a
  /// network, which is the only way this is deterministic: in a widget test
  /// every tile fetch fails, so a real threshold would make "is the map
  /// drawn?" a question about how many frames were pumped.
  @visibleForTesting
  static int debugFailureThreshold = 6;


  @override
  State<AgentOutletMap> createState() => _AgentOutletMapState();
}

class _AgentOutletMapState extends State<AgentOutletMap> {
  /// How many tiles have failed. Counted rather than latched on the first
  /// failure: one dropped tile on a moving vehicle is not the same fact as a
  /// forecourt with no signal, and swapping the map out for a sentence because
  /// of one 504 would be its own kind of lie.
  int _failures = 0;


  void _tileFailed() {
    if (_failures >= AgentOutletMap.debugFailureThreshold || !mounted) {
      _failures += 1;
      return;
    }
    setState(() => _failures += 1);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final height = agentMapHeight(context);

    if (skin.mode == SkinMode.veld) return const _VeldNote();
    if (height <= 0) return const SizedBox.shrink();

    final offline = _failures >= AgentOutletMap.debugFailureThreshold;
    return TorchBleed(
      extra: skin.space.gutter * 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // The band is the map's height; the panel that replaces it takes its
          // own. Reserving 300dp of nothing to say "there is no map" would
          // spend the fold on an absence.
          if (offline)
            const _TilesOff()
          else
            SizedBox(
              height: height,
              child: _Basemap(view: widget.view, onTileError: _tileFailed),
            ),
          if (!offline) ...<Widget>[
            SizedBox(height: skin.space.intraBlock),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: skin.space.gutter),
              child: MapLegend(view: widget.view),
            ),
          ],
        ],
      ),
    );
  }
}

/// The map's height, or 0 when it does not render.
///
/// Exported because the skeleton reserves the same band: a skeleton that
/// promised a map to a screen that has no room for one would push the whole
/// list down and then snap it back.
double agentMapHeight(BuildContext context) {
  final skin = context.skin;
  if (skin.mode == SkinMode.veld) return 0;
  final viewport = MediaQuery.sizeOf(context).height;
  final budget = math.min(
    (viewport * 0.44).clamp(200.0, 360.0),
    viewport - 440,
  );
  return budget < 200 ? 0 : budget;
}

/// The basemap, its markers, and the credit it is licensed under.
class _Basemap extends StatelessWidget {
  const _Basemap({required this.view, required this.onTileError});

  final AgentMapView view;
  final VoidCallback onTileError;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final pins = view.drawn;
    final points = <LatLng>[
      for (final pin in pins) LatLng(pin.outlet.lat, pin.outlet.lng),
    ];
    final here = view.here;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (!size.width.isFinite ||
            !size.height.isFinite ||
            size.width <= 0 ||
            size.height <= 0) {
          return const SizedBox.shrink();
        }

        // The camera is computed here, from the size this LayoutBuilder
        // actually has, and handed to flutter_map as plain
        // initialCenter/initialZoom — never through `CameraFit` or
        // `onMapReady`, both of which read flutter_map's own camera size,
        // which is zero at that moment and silently fits the world. See
        // `agent_trail_screen.dart`, where this cost a day.
        final (center, zoom) = fitFor(
          <LatLng>[...points, if (here != null) LatLng(here.lat, here.lng)],
          size: size,
          padding: 48,
          singleZoom: 15,
          maxZoom: 16,
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: skin.palette.edgeStructure,
              width: skin.depth.borderWidth,
            ),
          ),
          child: FlutterMap(
            // Keyed on what is plotted, so a refreshed route re-fits rather
            // than keeping a camera pointed at yesterday's stores.
            key: ValueKey<String>(_signature(points)),
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              minZoom: 9,
              maxZoom: 17,
              // No rotation: every glyph here is read upright, and a rotated
              // map re-rasterises the label layer on every frame of the
              // gesture. No scroll-wheel zoom either — this map lives inside
              // the shell's scroll view, and a wheel that sometimes zooms and
              // sometimes scrolls is a wheel nobody trusts.
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag |
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.pinchMove,
              ),
            ),
            children: <Widget>[
              TiqTileLayer(onTileError: onTileError),
              const TiqNavyTint(),
              const TiqBasemapLabels(),
              MarkerLayer(
                markers: <Marker>[
                  for (final pin in pins)
                    Marker(
                      point: LatLng(pin.outlet.lat, pin.outlet.lng),
                      width: _markerBox,
                      height: _markerBox,
                      child: _OutletMarker(pin: pin),
                    ),
                  if (here != null)
                    Marker(
                      point: LatLng(here.lat, here.lng),
                      width: _markerBox,
                      height: _markerBox,
                      child: const _HereMarker(),
                    ),
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

  /// A fingerprint of the plotted points, rounded to ~11 m so the same data
  /// fetched twice does not throw away a pan the agent just made.
  ///
  /// Integers of ten-thousandths rather than formatted decimals: this is a
  /// key, not a figure, and a key has no business going near a formatter.
  static String _signature(List<LatLng> points) => points
      .map(
        (p) =>
            '${(p.latitude * 1e4).round()},'
            '${(p.longitude * 1e4).round()}',
      )
      .join(';');
}

/// The marker's box. Deliberately not text-scaled past a cap — see
/// [MapPinGlyph.mapSize].
const double _markerBox = 44;

/// One store on the map.
class _OutletMarker extends StatelessWidget {
  const _OutletMarker({required this.pin});

  final MapOutlet pin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = mapStateWord(l10n, pin.state);
    return Semantics(
      button: true,
      label: l10n.mapPinHint(
        pin.outlet.name,
        pin.disputed ? '$state, ${l10n.mapStateDisputed}' : state,
      ),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showOutletSheet(context, pin),
        child: Center(
          child: MapPinGlyph(
            pin: pin,
            size: MapPinGlyph.mapSize(context),
            onDarkGround: true,
          ),
        ),
      ),
    );
  }
}

/// Where the phone says it is — and it is drawn **only** when the phone said
/// so. A position we are guessing at is the one thing a map of somebody's
/// working day must never draw.
class _HereMarker extends StatelessWidget {
  const _HereMarker({this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    final night = TiqSkin.night();
    return Semantics(
      label: context.l10n.mapYouAreHere,
      excludeSemantics: true,
      child: Center(
        child: CustomPaint(
          size: Size.square(size),
          painter: _HerePainter(ink: night.palette.ink1, ground: night.palette.ground),
        ),
      ),
    );
  }
}

class _HerePainter extends CustomPainter {
  const _HerePainter({required this.ink, required this.ground});

  final Color ink;
  final Color ground;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    // A ring in the ground colour under the ink ring, so the mark reads over a
    // pale road as well as a dark block — two strokes, no shadow.
    canvas
      ..drawCircle(centre, size.width / 2 - 1, Paint()
        ..color = ground
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4)
      ..drawCircle(centre, size.width / 2 - 1, Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2)
      ..drawCircle(centre, size.width / 5, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(_HerePainter old) =>
      old.ink != ink || old.ground != ground;
}

/// THE FOUR SILHOUETTES — one per pin state, plus the bar that says a pin is
/// under review.
///
/// It is the same widget in the map and in the list, at two sizes. That is the
/// whole point: a reader learns four shapes once, and the row beside the shape
/// spells the state out in words, so nothing here is carried by hue alone.
///
/// ```text
///   ✓  visited today      a filled disc with a tick knocked out of it
///   ▲  next up            a filled triangle
///   ○  on today's route   a ring
///   □  in your patch      a square outline
///   ⃠   under review       any of the above, crossed by a bar
/// ```
class MapPinGlyph extends StatelessWidget {
  const MapPinGlyph({
    super.key,
    required this.pin,
    this.size,
    this.onDarkGround = false,
  });

  final MapOutlet pin;

  /// Defaults to the row size, which scales with the text like every other
  /// meaning-bearing glyph.
  final double? size;

  /// True on the basemap, which is the same dark canvas in every skin (see
  /// [TiqTileLayer]) — so the glyph takes the Night palette there whatever the
  /// app around it is wearing, rather than painting Veld's near-black ink on a
  /// near-black tile.
  final bool onDarkGround;

  /// The glyph size in a list row: 24dp, scaling to 48 at 2.0× like every
  /// other meaning-bearing glyph.
  static double rowSize(BuildContext context) =>
      MarkScale.glyph(context, 24);

  /// The glyph size **on the map**: 24dp, scaling to at most 32.
  ///
  /// The one documented departure from the glyph-scale rule, and the reason is
  /// geometric rather than typographic: markers are positioned, not laid out.
  /// At 2.0× a 48dp pin on a 360dp-wide map covers about 400 m of ground at
  /// street zoom, so four neighbouring shops become one blob and the mark
  /// hides the thing it marks. The same four states are in the list beneath at
  /// full scale, with the word beside them, which is where a reader who needs
  /// 2.0× text is being served — not by a pin they cannot aim at anyway.
  static double mapSize(BuildContext context) =>
      math.min(MarkScale.glyph(context, 24), 32);

  @override
  Widget build(BuildContext context) {
    final skin = onDarkGround ? TiqSkin.night() : context.skin;
    final p = skin.palette;
    final extent = size ?? rowSize(context);
    // Hue is the second channel here, never the first: the silhouettes differ,
    // and the row says the state in words. `good` for a store already done,
    // ink-1 for the two that are still to do, ink-2 for the rest of the patch —
    // and no amber anywhere, because a marker is a state and amber is a move.
    final ink = switch (pin.state) {
      MapPinState.doneToday => p.good,
      MapPinState.nextUp => p.ink1,
      MapPinState.plannedAhead => p.ink1,
      MapPinState.territory => p.ink2,
    };
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(extent),
        painter: _PinPainter(
          state: pin.state,
          disputed: pin.disputed,
          ink: ink,
          ground: onDarkGround ? p.ground : p.surface,
          stroke: MarkScale.track(context, 2),
        ),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  const _PinPainter({
    required this.state,
    required this.disputed,
    required this.ink,
    required this.ground,
    required this.stroke,
  });

  final MapPinState state;
  final bool disputed;
  final Color ink;
  final Color ground;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2;
    final centre = Offset(size.width / 2, size.height / 2);
    final fill = Paint()..color = ink;
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    switch (state) {
      case MapPinState.doneToday:
        canvas.drawCircle(centre, r - stroke / 2, fill);
        // The tick is knocked out of the disc in the ground colour, so the
        // mark still reads as "done" in greyscale and at 40% backlight.
        final tick = Path()
          ..moveTo(centre.dx - r * 0.42, centre.dy)
          ..lineTo(centre.dx - r * 0.1, centre.dy + r * 0.34)
          ..lineTo(centre.dx + r * 0.45, centre.dy - r * 0.34);
        canvas.drawPath(
          tick,
          Paint()
            ..color = ground
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(stroke, r * 0.28)
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      case MapPinState.nextUp:
        final triangle = Path()
          ..moveTo(centre.dx, centre.dy - r + stroke / 2)
          ..lineTo(centre.dx + r - stroke / 2, centre.dy + r - stroke)
          ..lineTo(centre.dx - r + stroke / 2, centre.dy + r - stroke)
          ..close();
        canvas.drawPath(triangle, fill);
      case MapPinState.plannedAhead:
        canvas.drawCircle(centre, r - stroke, line);
      case MapPinState.territory:
        canvas.drawRect(
          Rect.fromCenter(
            center: centre,
            width: (r - stroke / 2) * 1.6,
            height: (r - stroke / 2) * 1.6,
          ),
          line,
        );
    }

    if (!disputed) return;
    // The bar of the "can't confirm" vocabulary (unify §1.5): a pin under
    // review is still on the route or still in the patch, so it keeps its
    // silhouette and takes a bar across it rather than becoming a fifth shape
    // nobody has learned.
    canvas
      ..drawLine(
        Offset(centre.dx - r, centre.dy + r),
        Offset(centre.dx + r, centre.dy - r),
        Paint()
          ..color = ground
          ..strokeWidth = stroke * 2.4
          ..strokeCap = StrokeCap.round,
      )
      ..drawLine(
        Offset(centre.dx - r, centre.dy + r),
        Offset(centre.dx + r, centre.dy - r),
        Paint()
          ..color = ink
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(_PinPainter old) =>
      old.state != state ||
      old.disputed != disputed ||
      old.ink != ink ||
      old.ground != ground ||
      old.stroke != stroke;
}

/// What the pins mean, said in words under the map.
///
/// A legend is not decoration on this screen: four silhouettes on a dark
/// canvas are four shapes until something names them, and the list below only
/// names the ones that are in it.
class MapLegend extends StatelessWidget {
  const MapLegend({super.key, required this.view});

  final AgentMapView view;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final present = <MapPinState>{for (final pin in view.drawn) pin.state};
    final disputed = view.drawn.any((pin) => pin.disputed);

    // A key, not a pin: 16dp, scaling with the text to the same 24dp the map
    // draws a marker at. It carries meaning, so it scales; it is also the
    // thing standing between the map and the first row of the list, so it
    // scales from lower down and stops where the marker does.
    final glyphSize = math.min(MarkScale.glyph(context, 16), 24.0);

    Widget item(Widget glyph, String word) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        glyph,
        const SizedBox(width: TiqSpace.s2),
        // Flexible, because a `Wrap` wraps BETWEEN its children and never
        // inside one: at 2.0× "On today's route" is wider than the phone, and
        // without this the item overflows instead of taking a second line.
        Flexible(
          child: Text(word, style: skin.text.meta.style(color: skin.palette.ink2)),
        ),
      ],
    );

    return Semantics(
      container: true,
      label: l10n.mapLegendLabel,
      child: Wrap(
        spacing: TiqSpace.s4,
        runSpacing: TiqSpace.s2,
        children: <Widget>[
          for (final state in MapPinState.values)
            if (present.contains(state))
              item(
                MapPinGlyph(
                  pin: MapOutlet(outlet: _legendOutlet, state: state),
                  size: glyphSize,
                ),
                mapStateWord(l10n, state),
              ),
          if (disputed)
            item(
              MapPinGlyph(
                pin: const MapOutlet(
                  outlet: _legendOutlet,
                  state: MapPinState.territory,
                  disputed: true,
                ),
                size: glyphSize,
              ),
              l10n.mapStateDisputed,
            ),
          if (view.hasLocation)
            item(
              SizedBox(
                width: glyphSize,
                height: glyphSize,
                child: _HereMarker(size: glyphSize),
              ),
              l10n.mapYouAreHere,
            ),
        ],
      ),
    );
  }
}

/// A stand-in for the legend's glyphs, which are about a state rather than a
/// store.
const _legendOutlet = Outlet(id: '', name: '', code: '', lat: 0, lng: 0);

/// NO TILES. The normal case on a rural forecourt, not an error.
///
/// ## What "offline" means for the tiles
///
/// flutter_map 8's `NetworkTileProvider` keeps a disk cache of every tile it
/// has fetched (`BuiltInMapCachingProvider`, on by default on phones, 1 GB,
/// in the OS cache directory). A tile still fresh by Esri's own HTTP headers
/// is drawn from disk with no connection at all, so a patch the agent opened
/// the map over yesterday, in signal, still has a map today. A tile that has
/// gone stale, or was never fetched, fails when there is no signal —
/// flutter_map does not fall back to a stale copy — and those failures are
/// what [AgentOutletMap] counts.
///
/// We deliberately do **not** stretch the cache's freshness past what Esri's
/// headers say (`overrideFreshAge`): that would be keeping a licensed
/// provider's tiles longer than it serves them, which is a licence question
/// for the owner (see `basemap.dart`'s caveats), not a design one. The list
/// beneath carries every store either way, so nothing the agent needs rides
/// on the tiles arriving.
///
/// It is an inline empty state rather than an error state on purpose: nothing
/// has failed that the agent can act on, and a crimson block for "you are
/// where you said you would be" would be the app shouting at the job.
class _TilesOff extends StatelessWidget {
  const _TilesOff();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    return Container(
      alignment: AlignmentDirectional.centerStart,
      padding: EdgeInsets.all(skin.space.gutter),
      decoration: BoxDecoration(
        color: skin.palette.well,
        border: Border.all(
          color: skin.palette.edgeStructure,
          width: skin.depth.borderWidth,
        ),
      ),
      child: EmptyState(
        headline: l10n.mapTilesOffTitle,
        scope: EmptyScope.inline,
        body: l10n.mapTilesOffBody,
      ),
    );
  }
}

/// Veld has no map, and says so once.
class _VeldNote extends StatelessWidget {
  const _VeldNote();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: EdgeInsets.only(bottom: skin.space.intraBlock),
      child: Text(
        context.l10n.mapVeldNote,
        style: skin.text.body.style(color: skin.palette.ink2),
      ),
    );
  }
}

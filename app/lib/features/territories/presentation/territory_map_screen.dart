import 'dart:math' as math;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `hide Path`: latlong2 exports a `Path` of its own (a list of coordinates
// with a length), and the pins below are drawn with dart:ui's.
import 'package:latlong2/latlong.dart' hide Path;

import '../../../core/design/torch_scope.dart';
import '../../../core/geo/mercator_fit.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/basemap.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../../outlets/data/outlets_repository.dart';
import '../data/territories_repository.dart';
import '../data/territories_view.dart';

/// THE TERRITORY, AS GROUND — every outlet in it, and whether anyone has been.
///
/// ```text
///   ←  Gauteng North                        (header)
///      GP-N · 3 outlets · 2 visited
///   ┌────────────────────────────────┐
///   │        the basemap             │      (never in Veld)
///   └────────────────────────────────┘
///   ✓ Visited   ◉ Not visited yet          (the legend, in words)
///   ── Outlets  3 ────────────────────
///   ✓ Kasi Corner Spaza      Visited
///     KCS-001
///   ◉ Shoprite Klipspruit    Not visited yet
///   …
/// ```
///
/// ## The list is not the map's caption — it is the map's equal
///
/// Every store is in the list at full text scale with its state in words,
/// whether or not the tiles arrive, whether or not the reader can see a map,
/// and whether or not the skin draws one. That is what makes the three "no
/// map" cases ordinary rather than degraded:
///
/// 1. **Veld.** unify §4: maps do not render in the outdoor skin — a dark
///    basemap read in direct sun at 40% backlight is a black rectangle. The
///    figure list that replaces it is the list that was always there.
/// 2. **No tiles.** Counted, not latched on the first failure: one dropped
///    tile in a lift is not a forecourt with no signal.
/// 3. **No outlets.** A designed state with a sentence, not a blank panel and
///    not a map of the whole world, which is what `CameraFit` over an empty
///    bounds box produces.
///
/// ## The amber
///
/// A pushed route: no nav, no primary, **nothing lit in any skin**. A map is a
/// reading. The pins are two silhouettes plus two words; "visited" is never
/// carried by a hue alone, which was already true here before Torchlight and
/// stays true after it.
class TerritoryMapScreen extends ConsumerStatefulWidget {
  const TerritoryMapScreen({super.key, required this.territory});

  final Territory territory;

  /// How many tile failures mean *offline* rather than *one bad tile*.
  ///
  /// A test sets it to `0` for a region offline from its first frame and to a
  /// large number for one that never gives up — both without a network, which
  /// is the only way this is deterministic: in a widget test every tile fetch
  /// fails.
  @visibleForTesting
  static int debugFailureThreshold = 6;

  @override
  ConsumerState<TerritoryMapScreen> createState() => _TerritoryMapScreenState();
}

class _TerritoryMapScreenState extends ConsumerState<TerritoryMapScreen> {
  int _failures = 0;

  void _tileFailed() {
    if (_failures >= TerritoryMapScreen.debugFailureThreshold || !mounted) {
      _failures += 1;
      return;
    }
    setState(() => _failures += 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final async = ref.watch(territoryCoverageProvider(widget.territory.id));

    Widget frame({required String phase, required List<Widget> children}) {
      return TorchSheetAware(
        builder: (context, beneathSheet) => TorchScope(
          skin: skin,
          phase: phase,
          navRenders: false,
          tabbedRoute: false,
          beneathSheet: beneathSheet,
          // A map is a reading. Nothing on this route is armed, in any skin.
          claims: const <TorchClaim>[],
          child: TorchShell(
            profile: TorchShellProfile.console,
            header: TorchAppHeader(
              title: widget.territory.name,
              facts: _facts(context, async),
              back: TorchIconButton(
                key: const ValueKey<String>('back-to-territories'),
                icon: Icons.arrow_back,
                semanticLabel: l10n.territoryBackToList,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            children: children,
          ),
        ),
      );
    }

    return async.when(
      loading: () => frame(
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: widget.territory.name,
            slowLine: l10n.torchStillFetching,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // The skeleton reserves the band the map will take, so the
                // list does not get pushed down and snapped back.
                if (_mapHeight(context) > 0)
                  SkeletonShell(height: _mapHeight(context)),
                SizedBox(height: skin.space.intraBlock),
                const SkeletonRows(count: 3, rowHeight: 64),
              ],
            ),
          ),
        ],
      ),
      error: (error, _) => frame(
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'territory coverage',
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('territory-map-retry'),
                label: l10n.torchTryAgain,
                onPressed: () => ref.invalidate(
                  territoryCoverageProvider(widget.territory.id),
                ),
              ),
            ),
          ),
        ],
      ),
      data: (coverage) {
        final outlets = coverage.outlets;
        if (outlets.isEmpty) {
          return frame(
            phase: 'empty',
            children: <Widget>[
              EmptyState(
                drawing: EmptyDrawing.shelf,
                headline: l10n.territoryMapEmptyHeadline,
                body: l10n.territoryMapEmptyBody,
              ),
            ],
          );
        }

        // Nearest-to-nothing ordering would be arbitrary here — this is a
        // manager's view of a patch, not an agent's walking order — so the
        // outstanding stores come first. The list is the work.
        final ordered = <Outlet>[
          ...outlets.where((o) => !o.visited),
          ...outlets.where((o) => o.visited),
        ];
        final offline = _failures >= TerritoryMapScreen.debugFailureThreshold;
        final height = _mapHeight(context);
        final veld = skin.mode == SkinMode.veld;

        return frame(
          phase: veld
              ? 'veld'
              : offline
              ? 'tiles-off'
              : 'loaded',
          children: <Widget>[
            if (veld)
              Padding(
                padding: EdgeInsets.only(bottom: skin.space.intraBlock),
                child: Text(
                  l10n.mapVeldNote,
                  style: skin.text.body.style(color: skin.palette.ink2),
                ),
              )
            else if (offline)
              _TilesOff(territoryName: widget.territory.name)
            else if (height > 0)
              TorchBleed(
                extra: skin.space.gutter * 2,
                child: SizedBox(
                  height: height,
                  child: _Basemap(outlets: outlets, onTileError: _tileFailed),
                ),
              ),

            if (!veld && !offline && height > 0) ...<Widget>[
              SizedBox(height: skin.space.intraBlock),
              const _MapLegend(),
            ],

            SizedBox(height: skin.space.blockGap),
            SectionRule(l10n.territoryOutletsWord, count: ordered.length),
            const SizedBox(height: TiqSpace.s3),
            TorchBleed(
              extra: skin.space.gutter * 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (var i = 0; i < ordered.length; i++)
                    _OutletRow(
                      key: ValueKey<String>('outlet-row-${ordered[i].id}'),
                      outlet: ordered[i],
                      last: i == ordered.length - 1,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<String> _facts(
    BuildContext context,
    AsyncValue<TerritoryCoverage> async,
  ) {
    final l10n = context.l10n;
    final region = widget.territory.region;
    final coverage = async.value;
    return <String>[
      widget.territory.code,
      ?region,
      ?coverage != null ? l10n.territoryOutlets(coverage.outletCount) : null,
      // A measured count, never a defaulted zero: `outletsVisited` is null
      // when the server sent no coverage block at all.
      if (coverage?.outletsVisited != null)
        l10n.territoryVisitedCount(coverage!.outletsVisited!),
    ];
  }
}

/// The map's height, or 0 when there is no room for one.
///
/// It takes the plate's fold budget — `min(clamp(0.44·vh, 200, 360), vh − 380)`
/// — and below 200dp it does not render at all. 96dp of basemap at street zoom
/// is four buildings and no orientation, which is why a map collapses to
/// nothing where a plate collapses to a band.
double _mapHeight(BuildContext context) {
  if (context.skin.mode == SkinMode.veld) return 0;
  final viewport = MediaQuery.sizeOf(context).height;
  final budget = math.min(
    (viewport * 0.44).clamp(200.0, 360.0),
    viewport - 380,
  );
  return budget < 200 ? 0 : budget;
}

/// The basemap, its pins, and the credit it is licensed under.
class _Basemap extends StatelessWidget {
  const _Basemap({required this.outlets, required this.onTileError});

  final List<Outlet> outlets;
  final VoidCallback onTileError;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final points = <LatLng>[for (final o in outlets) LatLng(o.lat, o.lng)];

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (!size.width.isFinite ||
            !size.height.isFinite ||
            size.width <= 0 ||
            size.height <= 0) {
          return const SizedBox.shrink();
        }

        // The camera is computed from the size this LayoutBuilder actually
        // has and handed to flutter_map as plain initialCenter/initialZoom —
        // never through `CameraFit`, which reads flutter_map's own camera
        // size, and that is zero at the moment it is asked.
        final (centre, zoom) = fitFor(
          points,
          size: size,
          padding: 40,
          singleZoom: 14,
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
            key: ValueKey<String>(_signature(points)),
            options: MapOptions(
              initialCenter: centre,
              initialZoom: zoom,
              minZoom: 9,
              maxZoom: 17,
              // No rotation: every glyph here is read upright. No scroll-wheel
              // zoom either — this map lives inside the shell's scroll view,
              // and a wheel that sometimes zooms and sometimes scrolls is a
              // wheel nobody trusts.
              interactionOptions: const InteractionOptions(
                flags:
                    InteractiveFlag.drag |
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
                  for (final outlet in outlets)
                    Marker(
                      point: LatLng(outlet.lat, outlet.lng),
                      width: 44,
                      height: 44,
                      child: _OutletMarker(outlet: outlet),
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

  /// A fingerprint of the plotted points, rounded to ~11 m, so the same data
  /// fetched twice does not throw away a pan the manager just made.
  static String _signature(List<LatLng> points) => points
      .map(
        (p) => '${(p.latitude * 1e4).round()},${(p.longitude * 1e4).round()}',
      )
      .join(';');
}

/// One store on the map.
class _OutletMarker extends StatelessWidget {
  const _OutletMarker({required this.outlet});

  final Outlet outlet;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: '${outlet.name}, ${_stateWord(l10n, outlet.visited)}',
      // The ACTION, not only the flag: a gesture detector under an excluding
      // node carries no tap, so `button: true` alone gives a reader a node it
      // can focus and cannot activate.
      onTap: () => showTerritoryOutletSheet(context, outlet),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showTerritoryOutletSheet(context, outlet),
        child: Center(
          child: OutletVisitGlyph(
            visited: outlet.visited,
            size: math.min(MarkScale.glyph(context, 24), 32),
            onDarkGround: true,
          ),
        ),
      ),
    );
  }
}

String _stateWord(AppLocalizations l10n, bool visited) =>
    visited ? l10n.territoryOutletVisited : l10n.territoryOutletNotVisited;

/// Visited, or not — as a **silhouette** first.
///
/// The pins were the same `Icons.location_on` in red and green until #? ; that
/// broke the rule this codebase states out loud — state is never colour alone
/// — and put the whole distinction out of reach for a red-green colour-vision
/// deficiency, the commonest kind. It also read poorly against a busy basemap,
/// which carries its own reds and greens.
///
/// Now the two states differ in shape first: a **tick inside a disc** for
/// visited, an **open ring with a centre dot** for outstanding. Hue still
/// carries the same meaning for those who can see it, nothing depends on it,
/// and both survive greyscale, glare and a printed page.
class OutletVisitGlyph extends StatelessWidget {
  const OutletVisitGlyph({
    super.key,
    required this.visited,
    this.size,
    this.onDarkGround = false,
  });

  final bool visited;
  final double? size;

  /// True on the basemap, which is the same dark canvas in every skin (see
  /// [TiqTileLayer]) — so the glyph takes the Night palette there whatever the
  /// app around it is wearing, rather than painting Veld's near-black ink on a
  /// near-black tile.
  final bool onDarkGround;

  @override
  Widget build(BuildContext context) {
    final skin = onDarkGround ? TiqSkin.night() : context.skin;
    final p = skin.palette;
    final extent = size ?? MarkScale.glyph(context, 24);
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(extent),
        painter: _VisitPinPainter(
          visited: visited,
          ink: visited ? p.good : p.ink1,
          ground: onDarkGround ? p.ground : p.surface,
          stroke: MarkScale.track(context, 2),
        ),
      ),
    );
  }
}

class _VisitPinPainter extends CustomPainter {
  const _VisitPinPainter({
    required this.visited,
    required this.ink,
    required this.ground,
    required this.stroke,
  });

  final bool visited;
  final Color ink;
  final Color ground;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - stroke;

    // A disc of the ground colour under everything, so the mark reads over a
    // pale road as well as a dark block. Two fills, no shadow — the paint
    // budget forbids a BoxShadow on this route and a halo is a saveLayer.
    canvas.drawCircle(centre, radius + stroke / 2, Paint()..color = ground);

    if (visited) {
      // A filled disc carrying a tick: the strongest silhouette, for the
      // state that needs no further action.
      canvas.drawCircle(centre, radius, Paint()..color = ink);
      final tick = Path()
        ..moveTo(centre.dx - radius * 0.45, centre.dy)
        ..lineTo(centre.dx - radius * 0.1, centre.dy + radius * 0.38)
        ..lineTo(centre.dx + radius * 0.5, centre.dy - radius * 0.35);
      canvas.drawPath(
        tick,
        Paint()
          ..color = ground
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      return;
    }

    // An open ring with a centre dot: hollow reads as outstanding, and the
    // dot keeps it from being mistaken for a smudge at 24dp.
    canvas
      ..drawCircle(
        centre,
        radius,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      )
      ..drawCircle(centre, radius * 0.28, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(_VisitPinPainter old) =>
      old.visited != visited ||
      old.ink != ink ||
      old.ground != ground ||
      old.stroke != stroke;
}

/// The key to the two pins, in words as well as in shapes.
class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    Widget entry(bool visited) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        OutletVisitGlyph(visited: visited),
        const SizedBox(width: TiqSpace.s2),
        Flexible(
          child: Text(
            _stateWord(l10n, visited),
            style: skin.text.meta.style(color: skin.palette.ink2),
          ),
        ),
      ],
    );

    // A Wrap, because at 2.0x in Afrikaans two legend entries do not share a
    // 360dp line, and a key that ellipsised would be a key you cannot read.
    return Wrap(
      spacing: TiqSpace.s5,
      runSpacing: TiqSpace.s2,
      children: <Widget>[entry(true), entry(false)],
    );
  }
}

/// One store in the list beneath the map — and the whole of the map in Veld.
class _OutletRow extends StatelessWidget {
  const _OutletRow({super.key, required this.outlet, required this.last});

  final Outlet outlet;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final word = _stateWord(l10n, outlet.visited);
    return SoftRow(
      density: SoftRowDensity.tall,
      title: outlet.name,
      titleTruncation: SoftRowTruncation.middle,
      subtitle: word,
      leading: OutletVisitGlyph(visited: outlet.visited),
      meta: Text(
        outlet.code,
        style: skin.text.monoIdent.style(color: skin.palette.ink3),
      ),
      onTap: () => showTerritoryOutletSheet(context, outlet),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: '${outlet.name}. ${outlet.code}. $word',
    );
  }
}

/// NO TILES — the normal case on a rural forecourt, not an error.
///
/// An inline empty state rather than an error state on purpose: nothing has
/// failed that the manager can act on, the list below carries every store
/// either way, and a crimson block for "the tiles did not arrive" would be the
/// app shouting at the weather.
class _TilesOff extends StatelessWidget {
  const _TilesOff({required this.territoryName});

  final String territoryName;

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
        scope: EmptyScope.inline,
        headline: l10n.mapTilesOffTitle,
        body: l10n.territoryTilesOffBody(territoryName),
      ),
    );
  }
}

/// One store, opened — from a pin or from a row, which is what makes the
/// sheet reachable at all in Veld, where there is no pin to tap.
Future<void> showTerritoryOutletSheet(BuildContext context, Outlet outlet) {
  return showTorchSheet<void>(
    context,
    builder: (_) => _OutletSheet(outlet: outlet),
  );
}

class _OutletSheet extends StatelessWidget {
  const _OutletSheet({required this.outlet});

  final Outlet outlet;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    return TorchSheet(
      title: outlet.name,
      subtitle: outlet.code,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              OutletVisitGlyph(visited: outlet.visited),
              const SizedBox(width: TiqSpace.s3),
              Expanded(
                child: Text(
                  _stateWord(l10n, outlet.visited),
                  style: skin.text.bodyStrong.style(color: skin.palette.ink1),
                ),
              ),
            ],
          ),
          const SizedBox(height: TiqSpace.s3),
          Text(
            outlet.visited
                ? l10n.territoryOutletVisitedLine
                : l10n.territoryOutletNotVisitedLine,
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
          const SizedBox(height: TiqSpace.s5),
          // The coordinates, as an identifier rather than as a figure: they
          // locate a shop, they do not measure one.
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.territoryOutletPosition,
                  style: skin.text.meta.style(color: skin.palette.ink3),
                ),
              ),
              FigureSlot(
                value: outlet.lat,
                role: skin.text.monoIdent,
                unit: TiqUnit.none,
                decimals: 4,
              ),
              const SizedBox(width: TiqSpace.s3),
              FigureSlot(
                value: outlet.lng,
                role: skin.text.monoIdent,
                unit: TiqUnit.none,
                decimals: 4,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../theme/lumen_palette.dart';
import '../theme/tiq_colors.dart';

/// The one basemap every flutter_map screen in the manager console draws —
/// Esri's "World Dark Gray Canvas" under a navy tint ([TiqNavyTint]), used in
/// both the light and dark app themes deliberately, not switched by
/// [Theme.of]: these maps are the "dark islands" of the design, the Tide
/// Guide world the user explicitly chose on 2026-07-24 (premium-ui spec,
/// "Sub-project 3 · Maps"), reversing the 2026-07-23 decision to use the
/// pale Positron tiles recorded here previously. That earlier Positron pick
/// was itself a rejection of a *flat*, unstyled dark basemap; this dark
/// canvas + navy-tint treatment is the styled replacement the user asked
/// for, not a reversion to what was rejected then.
///
/// **Why not CARTO any more (2026-09-17).** These tiles were CARTO's "Dark
/// Matter" (`basemaps.cartocdn.com/dark_all`) until CARTO began watermarking
/// keyless traffic: the tiles still return HTTP 200 with a valid PNG, but
/// "API KEY REQUIRED — carto.com/basemaps/apikey" is drawn diagonally into
/// every image. Nothing in our code or response headers reveals it, because
/// it is pixels rather than text — it is only visible on screen. Getting a
/// CARTO key means registering an account, which the product owner declined,
/// so this moved to Esri's keyless equivalent.
///
/// **Two caveats to revisit before this carries real customer traffic:**
/// 1. Esri's own service metadata reports this layer as "In mature support;
///    no longer updated." It serves fine today (HTTP 200, zoom to 23) but it
///    is a legacy endpoint, not one Esri is investing in.
/// 2. Esri's basemap terms are more restrictive than OpenStreetMap's own.
///    Keyless use is fine for development; confirm the licence before a
///    commercial launch, or move to a provider with a paid tier.
///
/// Labels are a **separate layer** here ([TiqBasemapLabels]) — unlike CARTO's
/// Dark Matter, Esri splits terrain and place names into two tile services. A
/// map drawn without the labels layer has no place names at all.
class TiqTileLayer extends StatelessWidget {
  const TiqTileLayer({super.key});

  /// Note the axis order: Esri serves `{z}/{y}/{x}`, not the `{z}/{x}/{y}`
  /// that CARTO and OpenStreetMap use. There is no `{r}` retina variant, so
  /// unlike the CARTO layer this one sets no `retinaMode`.
  static const _url =
      'https://services.arcgisonline.com/ArcGIS/rest/services/Canvas/'
      'World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}';

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: _url,
      userAgentPackageName: 'com.tradeiq.tradeiq_app',
    );
  }
}

/// The place names for [TiqTileLayer], as a transparent overlay.
///
/// Every map that draws [TiqTileLayer] must also draw this, **after**
/// [TiqNavyTint]: the tint is a wash over the ground, so labels placed under
/// it come out muddy and half-legible. Ground, then wash, then words.
class TiqBasemapLabels extends StatelessWidget {
  const TiqBasemapLabels({super.key});

  static const _url =
      'https://services.arcgisonline.com/ArcGIS/rest/services/Canvas/'
      'World_Dark_Gray_Reference/MapServer/tile/{z}/{y}/{x}';

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: _url,
      userAgentPackageName: 'com.tradeiq.tradeiq_app',
      // The reference tiles are mostly transparent — only the lettering is
      // opaque — and flutter_map paints nothing behind a TileLayer, so the
      // ground and the navy wash below show through untouched.
    );
  }
}

/// The navy wash that turns the grey dark canvas into the deep-blue
/// "Tide Guide" world the maps spec calls for. A separate layer (not a tile
/// filter) so markers and labels above it stay at full brightness. Wrapped
/// in IgnorePointer so it never eats map gestures.
class TiqNavyTint extends StatelessWidget {
  const TiqNavyTint({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.4),
              radius: 1.4,
              colors: const [Color(0x3312294A), Color(0x66081226)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Esri's required credit, taken verbatim from the service's own
/// `copyrightText` metadata rather than paraphrased — the underlying data is
/// not Esri's alone, which is why HERE, Garmin and OpenStreetMap are all
/// named. This is a licence requirement, not decoration: do not shorten it to
/// "OpenStreetMap contributors", or to "Esri", even though either still
/// compiles.
const String tiqBasemapAttributionText =
    'Esri, HERE, Garmin, © OpenStreetMap contributors, and the GIS user '
    'community';

/// The attribution layer every [TiqTileLayer] map must include as a sibling
/// child inside its [FlutterMap]. Kept as a widget (rather than just the
/// string above) so every screen renders the same visible credit the same
/// way.
class TiqBasemapAttribution extends StatelessWidget {
  const TiqBasemapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    // Rich, not Simple. Esri's required credit names four parties and runs to
    // ~76 characters; SimpleAttributionWidget lays its text out in a Row that
    // never wraps, which overflowed the map by ~500px and would have been
    // unreadable on a phone. RichAttributionWidget exists for credits this
    // long: a compact trigger that opens the complete string. Shortening the
    // text instead was not an option — see [tiqBasemapAttributionText].
    //
    // The tiles stay the dark island in both themes (see TiqTileLayer); only
    // the popup follows the material — a near-opaque pane under full ink, so
    // the licence text stays legible over the darkest tile.
    final glass = context.colors.glass;
    final lumen = context.lumen;
    return RichAttributionWidget(
      showFlutterMapAttribution: false,
      popupBackgroundColor: glass ? lumen.solidFill : null,
      attributions: [
        TextSourceAttribution(
          tiqBasemapAttributionText,
          // The string already carries its own "©" where the licence wants
          // one; prepending another would misattribute the whole list to Esri.
          prependCopyright: false,
          textStyle: glass ? TextStyle(color: lumen.ink) : null,
        ),
      ],
    );
  }
}

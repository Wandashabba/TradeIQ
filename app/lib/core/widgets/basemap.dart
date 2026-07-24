import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// The one basemap every flutter_map screen in the manager console draws —
/// CARTO's "Dark Matter" tiles under a navy tint ([TiqNavyTint]), used in
/// both the light and dark app themes deliberately, not switched by
/// [Theme.of]: these maps are the "dark islands" of the design, the Tide
/// Guide world the user explicitly chose on 2026-07-24 (premium-ui spec,
/// "Sub-project 3 · Maps"), reversing the 2026-07-23 decision to use the
/// pale Positron tiles recorded here previously. That earlier Positron pick
/// was itself a rejection of a *flat*, unstyled dark basemap; this dark_all
/// + navy-tint treatment is the styled replacement the user asked for, not
/// a reversion to what was rejected then. Free, keyless, and verified
/// serving HTTP 200; CARTO asks in return only for the attribution
/// [tiqBasemapAttributionText] carries.
class TiqTileLayer extends StatelessWidget {
  const TiqTileLayer({super.key});

  static const _url = 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: _url,
      userAgentPackageName: 'com.tradeiq.tradeiq_app',
      // Fills the `{r}` placeholder with `@2x` on high-density displays so
      // retina screens get a sharp tile instead of an upscaled blurry one.
      retinaMode: RetinaMode.isHighDensity(context),
    );
  }
}

/// The navy wash that turns CARTO's grey dark tiles into the deep-blue
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

/// CARTO's terms require crediting both the data source (OpenStreetMap) and
/// the styling/hosting provider (CARTO) — the OSM-only string every other
/// screen used under plain OSM tiles is not sufficient once the tiles come
/// from CARTO. This is a licence requirement, not decoration: do not shorten
/// it back to "OpenStreetMap contributors" even though that string still
/// compiles.
const String tiqBasemapAttributionText = 'OpenStreetMap contributors © CARTO';

/// The attribution layer every [TiqTileLayer] map must include as a sibling
/// child inside its [FlutterMap]. Kept as a widget (rather than just the
/// string above) so every screen renders the same visible credit the same
/// way.
class TiqBasemapAttribution extends StatelessWidget {
  const TiqBasemapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimpleAttributionWidget(
      source: Text(tiqBasemapAttributionText),
    );
  }
}

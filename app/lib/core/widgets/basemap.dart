import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// The one basemap every flutter_map screen in the manager console draws —
/// CARTO's "Positron" tiles, used in both the light and dark app themes
/// deliberately, not switched by [Theme.of]. The manager compared this
/// against a dark basemap and OSM's own default and chose Positron for
/// both: these maps are small dashboard panels showing a handful of pins,
/// and a quiet, pale ground keeps the pins themselves the dominant thing on
/// screen rather than competing with a busy or high-contrast basemap. Free,
/// keyless, and verified serving HTTP 200; CARTO asks in return only for
/// the attribution [tiqBasemapAttributionText] carries.
class TiqTileLayer extends StatelessWidget {
  const TiqTileLayer({super.key});

  static const _url = 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

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

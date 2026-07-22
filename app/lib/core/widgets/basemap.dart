import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// The one basemap every flutter_map screen in the manager console draws —
/// CARTO's "Positron"/"Dark Matter" tiles, chosen by the app's own
/// light/dark toggle rather than always shipping OSM's fixed light style.
/// Both endpoints are free, keyless, and verified serving HTTP 200; CARTO
/// asks in return only for the attribution [tiqBasemapAttribution] carries.
///
/// A dark-themed manager opening a map used to land on a jarring pale OSM
/// tile with no way to match it to the rest of the console; this fixes that
/// without asking every map screen to know the two URLs itself.
class TiqTileLayer extends StatelessWidget {
  const TiqTileLayer({super.key});

  static const _darkUrl =
      'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
  static const _lightUrl =
      'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return TileLayer(
      urlTemplate: dark ? _darkUrl : _lightUrl,
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

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/widgets/basemap.dart';

import '../theme/tiq_colors_test.dart' show contrastRatio;

Widget _creditOn(ThemeData theme) => MaterialApp(
  theme: theme,
  home: const Scaffold(
    body: SizedBox(
      width: 800,
      height: 400,
      child: FlutterMap(
        options: MapOptions(),
        children: [TiqNavyTint(), TiqBasemapAttribution()],
      ),
    ),
  ),
);

/// The single text source inside the credit popup.
TextSourceAttribution _creditSource(WidgetTester tester) {
  final credit = tester.widget<RichAttributionWidget>(
    find.byType(RichAttributionWidget),
  );
  expect(credit.attributions, hasLength(1));
  return credit.attributions.single as TextSourceAttribution;
}

void main() {
  testWidgets('glass: the credit popup is a near-opaque glass pane whose '
      'words clear AA over the darkest tile', (tester) async {
    await tester.pumpWidget(_creditOn(AppTheme.light()));

    final credit = tester.widget<RichAttributionWidget>(
      find.byType(RichAttributionWidget),
    );
    expect(credit.popupBackgroundColor, LumenPalette.light.solidFill);

    final ink = _creditSource(tester).textStyle!.color!;
    expect(ink, LumenPalette.light.ink);
    // Measured against the pane over black — the worst tile it can meet.
    final ground = Color.alphaBlend(credit.popupBackgroundColor!, Colors.black);
    expect(contrastRatio(ink, ground), greaterThanOrEqualTo(4.5));
    // The licence text itself is never shortened.
    expect(_creditSource(tester).text, tiqBasemapAttributionText);
  });

  testWidgets('dark: night credit is a near-opaque night pane whose light '
      'words clear AA over the lightest and darkest tile', (tester) async {
    await tester.pumpWidget(_creditOn(AppTheme.dark()));

    final credit = tester.widget<RichAttributionWidget>(
      find.byType(RichAttributionWidget),
    );
    expect(credit.popupBackgroundColor, LumenPalette.dark.solidFill);

    final ink = _creditSource(tester).textStyle!.color!;
    expect(ink, LumenPalette.dark.ink);
    // A light ink: measure over white (the worst tile) and black alike.
    for (final tile in [Colors.white, Colors.black]) {
      final ground = Color.alphaBlend(credit.popupBackgroundColor!, tile);
      expect(contrastRatio(ink, ground), greaterThanOrEqualTo(4.5));
    }
    expect(_creditSource(tester).text, tiqBasemapAttributionText);
  });

  testWidgets('flat fallback (no theme): the credit keeps flutter_map\'s '
      'default popup', (tester) async {
    await tester.pumpWidget(_creditOn(ThemeData()));

    final credit = tester.widget<RichAttributionWidget>(
      find.byType(RichAttributionWidget),
    );
    expect(credit.popupBackgroundColor, isNull);
    expect(_creditSource(tester).textStyle, isNull);
  });

  testWidgets('the credit never renders flutter_map\'s own branding', (
    tester,
  ) async {
    await tester.pumpWidget(_creditOn(AppTheme.light()));

    final credit = tester.widget<RichAttributionWidget>(
      find.byType(RichAttributionWidget),
    );
    expect(credit.showFlutterMapAttribution, isFalse);
    // Esri's list already carries its own ©; a second one would read as
    // though Esri alone owned the data.
    expect(_creditSource(tester).prependCopyright, isFalse);
  });

  testWidgets('the credit fits the map instead of overflowing it', (
    tester,
  ) async {
    // A phone-width map: the regression that prompted RichAttributionWidget
    // overflowed an 800px surface by ~500px with the Esri credit inline.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: FlutterMap(
              options: MapOptions(),
              children: [TiqNavyTint(), TiqBasemapAttribution()],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('TiqTileLayer serves the dark canvas, not the light one', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: FlutterMap(
              options: MapOptions(),
              children: [
                TiqTileLayer(),
                TiqNavyTint(),
              ],
            ),
          ),
        ),
      ),
    );

    final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(tileLayer.urlTemplate, contains('World_Dark_Gray_Base'));
    expect(tileLayer.urlTemplate, isNot(contains('Light_Gray')));
    // Esri serves {z}/{y}/{x}; getting this backwards silently shows the
    // wrong part of the world rather than failing to load.
    expect(tileLayer.urlTemplate, endsWith('/tile/{z}/{y}/{x}'));
    // CARTO watermarks keyless traffic (2026-09-17) — never go back without
    // an API key.
    expect(tileLayer.urlTemplate, isNot(contains('cartocdn')));
  });

  testWidgets('TiqBasemapLabels serves the transparent reference layer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: FlutterMap(
              options: MapOptions(),
              children: [TiqBasemapLabels()],
            ),
          ),
        ),
      ),
    );

    final labels = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(labels.urlTemplate, contains('World_Dark_Gray_Reference'));
    expect(labels.urlTemplate, endsWith('/tile/{z}/{y}/{x}'));
  });

  testWidgets('TiqNavyTint renders an ignore-pointer navy radial gradient wash', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: FlutterMap(
              options: MapOptions(),
              children: [
                TiqTileLayer(),
                TiqNavyTint(),
              ],
            ),
          ),
        ),
      ),
    );

    final ignorePointer = tester.widget<IgnorePointer>(
      find.descendant(
        of: find.byType(TiqNavyTint),
        matching: find.byType(IgnorePointer),
      ),
    );
    expect(ignorePointer.ignoring, isTrue);

    final decoratedBox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(TiqNavyTint),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = decoratedBox.decoration as BoxDecoration;
    final gradient = decoration.gradient as RadialGradient;
    expect(gradient.colors, [
      const Color(0x3312294A),
      const Color(0x66081226),
    ]);
  });
}

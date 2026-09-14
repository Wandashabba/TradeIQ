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
    // Full test-surface width: the licence string is long, and flutter_map's
    // credit row does not wrap (the credit is never shortened to fit).
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

void main() {
  testWidgets('glass: the credit is a near-opaque glass chip whose words '
      'clear AA over the darkest tile', (tester) async {
    await tester.pumpWidget(_creditOn(AppTheme.light()));

    final credit = tester.widget<SimpleAttributionWidget>(
      find.byType(SimpleAttributionWidget),
    );
    expect(credit.backgroundColor, LumenPalette.light.solidFill);
    final ink = credit.source.style!.color!;
    expect(ink, LumenPalette.light.ink);
    // Measured against the chip over black — the worst tile it can meet.
    final ground = Color.alphaBlend(credit.backgroundColor!, Colors.black);
    expect(contrastRatio(ink, ground), greaterThanOrEqualTo(4.5));
    // The licence text itself is never shortened.
    expect(credit.source.data, tiqBasemapAttributionText);
  });

  testWidgets('dark: night glass credit is a near-opaque night chip whose '
      'light words clear AA over the lightest and darkest tile', (
    tester,
  ) async {
    await tester.pumpWidget(_creditOn(AppTheme.dark()));

    final credit = tester.widget<SimpleAttributionWidget>(
      find.byType(SimpleAttributionWidget),
    );
    expect(credit.backgroundColor, LumenPalette.dark.solidFill);
    final ink = credit.source.style!.color!;
    expect(ink, LumenPalette.dark.ink);
    // A light ink: measure over white (the worst tile) and black alike.
    for (final tile in [Colors.white, Colors.black]) {
      final ground = Color.alphaBlend(credit.backgroundColor!, tile);
      expect(contrastRatio(ink, ground), greaterThanOrEqualTo(4.5));
    }
    expect(credit.source.data, tiqBasemapAttributionText);
  });

  testWidgets('flat fallback (no theme): the credit keeps flutter_map\'s '
      'default chip', (tester) async {
    await tester.pumpWidget(_creditOn(ThemeData()));

    final credit = tester.widget<SimpleAttributionWidget>(
      find.byType(SimpleAttributionWidget),
    );
    expect(credit.backgroundColor, isNull);
    expect(credit.source.style, isNull);
  });

  testWidgets('TiqTileLayer serves CARTO dark_all, not light_all', (tester) async {
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
    expect(tileLayer.urlTemplate, contains('dark_all'));
    expect(tileLayer.urlTemplate, isNot(contains('light_all')));
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

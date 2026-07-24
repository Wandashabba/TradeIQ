import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/widgets/basemap.dart';

void main() {
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

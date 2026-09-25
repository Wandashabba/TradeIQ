import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/plate/plate.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/dashboard/presentation/the_floor_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import 'floor_harness.dart';

/// THE PLATE IS A GROUND, NOT A COLOUR FIELD.
///
/// `direction-torchlight.json` bakes a plate at 12% chroma under a `#474747`
/// luminance ceiling. Only the ceiling was ever applied on the device, as a
/// multiply — and a multiply by a neutral grey scales all three channels
/// equally, which darkens a colour and never desaturates it. Against the
/// seeded dev data, whose shelf photos are blocks of fully saturated random
/// colour, the plate came out a dim rainbow.
///
/// Nothing failed, because nothing measured it. These tests measure it twice:
/// once in arithmetic, where the filter's twenty numbers are pinned, and once
/// in pixels, on the real screen, against a fixture that reproduces the seed's
/// own generator.
void main() {
  const ceiling = TiqPalette.plateCeiling;

  /// The filter, applied by hand, so a claim about a photograph is a claim
  /// about a number.
  ({int r, int g, int b}) toned(
    Color source, {
    double chroma = TiqPlate.chroma,
  }) {
    final m = plateToneMatrix(chroma: chroma, ceiling: ceiling);
    final r = source.r * 255, g = source.g * 255, b = source.b * 255;
    int row(int i) => (m[i * 5] * r + m[i * 5 + 1] * g + m[i * 5 + 2] * b)
        .round()
        .clamp(0, 255);
    return (r: row(0), g: row(1), b: row(2));
  }

  group('the tone, as arithmetic', () {
    test('is the ceiling AND the chroma, not one of the two', () {
      // The old treatment, for comparison: a multiply against the ceiling.
      // Pure red kept every scrap of its hue and simply got dark.
      final wasRed = (
        r: (255 * ceiling.r).round(),
        g: 0,
        b: 0,
      );
      expect(wasRed, (r: 71, g: 0, b: 0));
      expect(wasRed.r - wasRed.b, 71, reason: 'a dark red block');

      final red = toned(const Color(0xFFFF0000));
      expect(
        red.r - red.b,
        lessThanOrEqualTo(9),
        reason: 'the same pixel, now a warm dark grey: $red',
      );
    });

    test('white lands exactly on the ceiling, and nothing lands above it', () {
      final white = toned(const Color(0xFFFFFFFF));
      expect(white.r, 0x47);
      expect(white.g, 0x47);
      expect(white.b, 0x47);

      for (final source in <Color>[
        const Color(0xFFFF0000),
        const Color(0xFF00FF00),
        const Color(0xFF0000FF),
        const Color(0xFFFFFF00),
        const Color(0xFF00FFFF),
        const Color(0xFFFF00FF),
        const Color(0xFF808080),
        const Color(0xFFEBEBE4),
      ]) {
        final out = toned(source);
        expect(
          math.max(out.r, math.max(out.g, out.b)),
          lessThanOrEqualTo(0x47),
          reason: '$source came out above the ceiling as $out',
        );
      }
    });

    test('a neutral stays neutral and is scaled, not shifted', () {
      final grey = toned(const Color(0xFF808080));
      expect(grey.r, grey.g);
      expect(grey.g, grey.b);
      expect(grey.r, (128 * ceiling.r).round());
    });

    test('no input can produce a channel spread wider than 8.5 of 255', () {
      // ceiling × chroma × 255 = 0.278 × 0.12 × 255. It is the whole point of
      // composing the two operations rather than picking one.
      final bound = ceiling.r * TiqPlate.chroma * 255;
      expect(bound, closeTo(8.52, 0.01));
      for (var i = 0; i < 512; i++) {
        final source = Color.fromARGB(
          255,
          (i * 97) % 256,
          (i * 37) % 256,
          (i * 211) % 256,
        );
        final out = toned(source);
        final spread =
            math.max(out.r, math.max(out.g, out.b)) -
            math.min(out.r, math.min(out.g, out.b));
        expect(spread, lessThanOrEqualTo(bound.ceil()), reason: '$source');
      }
    });

    test('chroma is 12%, and the filter the plate hands out is this one', () {
      expect(TiqPlate.chroma, 0.12);
      expect(TiqPlate.ceiling, ceiling);
      expect(TiqPlate.tone, ColorFilter.matrix(plateToneMatrix()));
      // The thing that regressed: a treatment that is only the ceiling.
      expect(
        TiqPlate.tone,
        isNot(ColorFilter.mode(ceiling, BlendMode.multiply)),
      );
    });
  });

  group('the tone, in pixels, on the real screen', () {
    testWidgets('the seeded rainbow shelf renders dim and neutral', (
      tester,
    ) async {
      final rainbow = await SyncImage.seededShelf(tester);

      // The fixture really is a rainbow before the plate touches it — if the
      // generator ever stops making colour blocks, this test stops proving
      // anything and should say so here rather than pass quietly.
      final sourceSpread = await tester.runAsync(
        () => _maxChannelSpread(rainbow.image),
      );
      expect(
        sourceSpread,
        greaterThan(150),
        reason: 'the fixture is not a colour field to begin with',
      );

      await pumpFloor(
        tester,
        const TheFloorScreen(),
        plateImage: rainbow,
        alerts: <AlertItem>[alert(outletId: 'o1', photoId: 'p1')],
        outlets: <Outlet>[outlet('o1', 'Kasi Corner Spaza')],
      );

      // The band of plate above the strip light's bloom: pure photograph, no
      // amber, no scrim, no hero cluster. Measured off the plate's own rect,
      // not off the viewport, because the shell puts the body's top padding
      // above it.
      final spec = PlateSpec.resolve(skin: TiqSkin.night(), viewportHeight: 640);
      final plate = tester.getRect(find.byType(TiqPlate));
      final top = plate.top.ceil() + 2;
      final bottom =
          (plate.top + spec.stripLightY - spec.bloomHeight).floor() - 2;
      expect(bottom, greaterThan(top + 8), reason: 'no clean band to sample');

      // Inset past the card's corners. The plate has been a rounded card
      // since 25 September 2026, and its corner pixels are the photograph
      // antialiased against the ground — a blend of two colours, which reads
      // as a colour cast that is not on the plate. The radius is the exact
      // inset that clears it, and 300dp of a 360dp band is still a band.
      final sample = await _sample(
        tester,
        top: top,
        bottom: bottom,
        left: (plate.left + spec.radius).ceil() + 1,
        right: (plate.right - spec.radius).floor() - 1,
      );

      expect(
        sample.maxChannel,
        lessThanOrEqualTo(0x47 + 2),
        reason:
            'a pixel brighter than the #474747 ceiling: the plate is not a '
            'dim ground. Brightest was ${sample.maxChannel}.',
      );
      expect(
        sample.maxSpread,
        lessThanOrEqualTo(12),
        reason:
            'a colour cast of ${sample.maxSpread}/255 on the plate. The bake '
            'allows 8.5 and the multiply-only treatment allowed 71 — this is '
            'the rainbow.',
      );
    });

    testWidgets('the filter is on the image paint, not on a layer', (
      tester,
    ) async {
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        plateImage: await SyncImage.seededShelf(tester),
        alerts: <AlertItem>[alert(outletId: 'o1', photoId: 'p1')],
        outlets: <Outlet>[outlet('o1', 'Kasi Corner Spaza')],
      );

      expect(platedImage(tester)?.colorFilter, TiqPlate.tone);
      // unify §4's paint budget: zero saveLayer. `ColorFiltered` is the
      // obvious way to write this and it pushes a ColorFilterLayer, which is
      // a saveLayer per frame in a list that scrolls.
      expect(
        find.descendant(
          of: find.byType(TiqPlate),
          matching: find.byType(ColorFiltered),
        ),
        findsNothing,
      );
    });
  });
}

/// The widest gap between any pixel's brightest and dimmest channel.
Future<int> _maxChannelSpread(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  var worst = 0;
  final bytes = data!.buffer.asUint8List();
  for (var i = 0; i < bytes.length; i += 4) {
    final int r = bytes[i];
    final int g = bytes[i + 1];
    final int b = bytes[i + 2];
    final int spread =
        math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
    if (spread > worst) worst = spread;
  }
  return worst;
}

/// What the rasteriser actually put on the screen, between two rows.
Future<({int maxChannel, int maxSpread})> _sample(
  WidgetTester tester, {
  required int top,
  required int bottom,
  required int left,
  required int right,
}) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey<String>('amber-golden-boundary')),
  );
  // `toImage` hands the layer tree to the rasteriser, which lives outside the
  // test binding's fake clock — the same escape hatch the amber census uses.
  final result = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final width = image.width;
    image.dispose();
    final bytes = data!.buffer.asUint8List();
    var maxChannel = 0;
    var maxSpread = 0;
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < math.min(right, width); x++) {
        final i = (y * width + x) * 4;
        final int r = bytes[i];
        final int g = bytes[i + 1];
        final int b = bytes[i + 2];
        final int high = math.max(r, math.max(g, b));
        final int low = math.min(r, math.min(g, b));
        if (high > maxChannel) maxChannel = high;
        if (high - low > maxSpread) maxSpread = high - low;
      }
    }
    return (maxChannel: maxChannel, maxSpread: maxSpread);
  });
  return result!;
}

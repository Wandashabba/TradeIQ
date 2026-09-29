import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_contrast.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/plate/plate.dart';

/// THE INK ON THE PLATE, MEASURED OVER THE PICTURES THAT ARE ACTUALLY IN THE
/// REPOSITORY.
///
/// `torchlight_contrast_test.dart` measures the declared pairings — ink against
/// the worst ground the scrim *could* produce, computed from the palette. That
/// is the right test and it is not this one. This one rasterises the real plate
/// over each of the **committed place images** and measures what the ink
/// actually lands on, because the worst ground a plate produces is a property
/// of the photograph as much as of the palette: a bright sky or a pale map
/// shape moves it, and until 29 September 2026 every one of these pictures was
/// generated under a prompt that never asked for a blown-out sky.
///
/// Twelve of the fourteen are now photographs the owner supplied, chosen by a
/// person rather than written by a prompt, and two of those are map composites
/// with a near-white polygon over most of the frame. So this stops being a
/// theoretical bound and starts being a measurement.
///
/// ## How the background is sampled
///
/// The hero cluster is the last thing drawn in the plate's stack and it sits
/// exactly where the measurement has to look, so the plate is pumped a second
/// time with an empty hero. Everything this measures — the picture, its
/// `BoxFit.cover` into the same rect, the bottom-up scrim — is decided by
/// [PlateSpec] and the plate's width, and the hero touches neither. The rects
/// the ink occupies are taken off a real hero once, in plate-relative
/// coordinates.
///
/// The worst pixel is the brightest one on a dark ground and the darkest one on
/// a light ground, which is the same rule `plateFloor` in `tiq_contrast.dart`
/// states. The whole bounding box of the glyphs counts, not just the strokes:
/// that is the conservative reading and it is the one this product already
/// uses.
void main() {
  const places = '../backend/assets/places';

  /// The two inks that sit on the picture, and what each one needs.
  ///
  /// `ink1` is the hero figure's fallback ink at `hero.figure` — 72px, which
  /// WCAG counts as large text at a 3:1 floor. `ink2` is the "Territory
  /// health" line at `label`, which is ordinary text at 4.5:1. 4.5 is asserted
  /// for both, because the hero has the larger allowance and does not need it.
  const floor = 4.5;

  late Rect hero;
  late Rect health;
  late List<String> codes;

  setUpAll(() {
    codes =
        Directory(places)
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .where((n) => n.endsWith('.jpg'))
            .map((n) => n.substring(0, n.length - 4))
            .toList()
          ..sort();
  });

  testWidgets('there are committed place images to measure', (tester) async {
    // A guard, not a formality: if the assets folder is ever emptied or moved,
    // every assertion below becomes vacuously green and this file starts
    // proving nothing while still passing.
    expect(codes.length, greaterThanOrEqualTo(14));
  });

  testWidgets('the plate ink clears 4.5:1 on Night over every committed '
      'picture, supplied and generated alike', (tester) async {
    (hero, health) = await _inkRects(tester);
    final skin = TiqSkin.night();
    final worst = <String, double>{};

    for (final code in codes) {
      final image = await _decode(tester, '$places/$code.jpg');
      final plate = await _pumpBarePlate(tester, image, skin);
      final frame = await _grab(tester);
      final figure = contrastRatio(
        skin.palette.ink1,
        _worstPixel(frame, hero.shift(plate.topLeft), dark: true),
      );
      final meta = contrastRatio(
        skin.palette.ink2,
        _worstPixel(frame, health.shift(plate.topLeft), dark: true),
      );
      worst[code] = math.min(figure, meta);
      expect(
        figure,
        greaterThanOrEqualTo(floor),
        reason:
            '$code: the hero figure measures ${figure.toStringAsFixed(2)}:1 on '
            'the Night plate. A picture bright enough to push it under $floor '
            'is a picture the #474747 ceiling is not saving — reshoot it or '
            'crop away the blown-out part.',
      );
      expect(
        meta,
        greaterThanOrEqualTo(floor),
        reason:
            '$code: the "Territory health" line measures '
            '${meta.toStringAsFixed(2)}:1 on the Night plate.',
      );
    }
    // Measured 29 September 2026: 8.40 (GP-EKU) to 10.59 (ALL) for the meta
    // line and 8.88 (WC) to 13.16 (ALL) for the figure. The margin is wide on
    // purpose — this exists to catch a future picture that is nothing like
    // these, not to pin a number to two decimal places across rasterisers.
    expect(worst.values.reduce(math.min), greaterThan(6.0));
  });

  testWidgets('DAY IS THE KNOWN GAP, and it is not the pictures', (
    tester,
  ) async {
    // THIS TEST ASSERTS A DEFECT, DELIBERATELY, AND IT IS WRITTEN TO DELETE
    // ITSELF.
    //
    // PR #473 reported that the Day meta line over the plate measures 2.92:1
    // against a 4.5 minimum, and that the plate scrim is under-specified for a
    // light ground: it ramps `ground` from 0% at the top of the text zone to
    // 80% at the foot, so the "Territory health" line sits at roughly 57% and
    // the hero figure's cap height at about 17%. On a dark ground that is
    // fine — the ink is light and the picture is dark. On a light ground the
    // ink is dark and the picture is ALSO dark, because every plate pixel is
    // capped at #474747, so the two converge.
    //
    // Twelve supplied photographs were the obvious thing to blame for it, so
    // it is measured here with a generated picture beside them: the band is
    // the same either way, which means the scrim is the defect and the
    // pictures are not. If this test ever fails because a figure went ABOVE
    // 4.5, somebody fixed the scrim — delete this test and the note in §9g of
    // docs/design/torchlight-aisle.md.
    (hero, health) = await _inkRects(tester);
    final skin = TiqSkin.day();
    final metas = <String, double>{};

    for (final code in codes) {
      final image = await _decode(tester, '$places/$code.jpg');
      final plate = await _pumpBarePlate(tester, image, skin);
      final frame = await _grab(tester);
      metas[code] = contrastRatio(
        skin.palette.ink2,
        _worstPixel(frame, health.shift(plate.topLeft), dark: false),
      );
    }

    for (final entry in metas.entries) {
      expect(
        entry.value,
        lessThan(floor),
        reason:
            '${entry.key} measures ${entry.value.toStringAsFixed(2)}:1, which '
            'is ABOVE the 4.5 floor. That is good news and this test is now '
            'wrong: the plate scrim was fixed. Delete this test.',
      );
    }

    // AND THE SUPPLIED PICTURES DID NOT MOVE IT. `ALL` and `NW` are the two
    // still generated, and the whole supplied set sits inside a tenth of a
    // point of them. Measured 29 September 2026: generated 2.77 and 2.82,
    // supplied 2.63 (EC-BCM) to 2.99 (GP-TSH).
    final generated = <double>[metas['ALL']!, metas['NW']!];
    final supplied = metas.entries
        .where((e) => e.key != 'ALL' && e.key != 'NW')
        .map((e) => e.value)
        .toList();
    expect(
      supplied.reduce(math.min),
      greaterThan(generated.reduce(math.min) - 0.4),
      reason:
          'a supplied picture is materially worse for the Day meta line than '
          'the generated ones were. The Day gap is pre-existing, but a new '
          'picture making it worse is a new problem and belongs to whoever '
          'added the picture.',
    );
  });
}

/// Where the hero figure and the health line sit, relative to the plate.
///
/// Taken off a real [PlateHeroCluster] rather than recomputed, so the
/// measurement cannot drift from the layout it is about.
Future<(Rect, Rect)> _inkRects(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final skin = TiqSkin.night();
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: Size(390, 844), devicePixelRatio: 1.0),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: ThemeData(extensions: <ThemeExtension<dynamic>>[skin]),
          child: ColoredBox(
            color: skin.palette.ground,
            child: SizedBox(
              width: 390,
              height: 844,
              child: Column(
                children: <Widget>[
                  TiqPlate(
                    claimId: 'contrast',
                    viewportHeight: 844,
                    image: await _solid(tester),
                    devicePixelRatio: 1.0,
                    hero: PlateHeroCluster(
                      figure: Text(
                        '73',
                        style: skin.text.heroFigure.style(
                          color: skin.palette.ink1,
                        ),
                      ),
                      healthLine: Text(
                        'Territory health',
                        style: skin.text.label.style(color: skin.palette.ink2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  final plate = tester.getRect(find.byType(TiqPlate));
  return (
    tester.getRect(find.text('73')).shift(-plate.topLeft),
    tester.getRect(find.text('Territory health')).shift(-plate.topLeft),
  );
}

/// The plate alone, with no hero over the band being measured.
Future<Rect> _pumpBarePlate(
  WidgetTester tester,
  ImageProvider<Object> image,
  TiqSkin skin,
) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: Size(390, 844), devicePixelRatio: 1.0),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: ThemeData(extensions: <ThemeExtension<dynamic>>[skin]),
          child: RepaintBoundary(
            key: const ValueKey<String>('plate-contrast'),
            child: ColoredBox(
              color: skin.palette.ground,
              child: SizedBox(
                width: 390,
                height: 844,
                child: Column(
                  children: <Widget>[
                    TiqPlate(
                      claimId: 'contrast',
                      viewportHeight: 844,
                      image: image,
                      hero: const SizedBox.shrink(),
                      devicePixelRatio: 1.0,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return tester.getRect(find.byType(TiqPlate));
}

Future<({Uint8List bytes, int width})> _grab(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey<String>('plate-contrast')),
  );
  // `toImage` hands the layer tree to the rasteriser, which lives outside the
  // test binding's fake clock — the same escape hatch the tone census uses.
  final result = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final width = image.width;
    image.dispose();
    return (bytes: data!.buffer.asUint8List(), width: width);
  });
  return result!;
}

/// The background pixel in [rect] that is hardest for the ink on this ground.
Color _worstPixel(
  ({Uint8List bytes, int width}) frame,
  Rect rect, {
  required bool dark,
}) {
  Color? worst;
  var worstL = dark ? -1.0 : 2.0;
  for (var y = rect.top.ceil(); y < rect.bottom.floor(); y++) {
    for (
      var x = rect.left.ceil();
      x < math.min(rect.right.floor(), frame.width);
      x++
    ) {
      final i = (y * frame.width + x) * 4;
      final colour = Color.fromARGB(
        255,
        frame.bytes[i],
        frame.bytes[i + 1],
        frame.bytes[i + 2],
      );
      final l = relativeLuminance(colour);
      if (dark ? l > worstL : l < worstL) {
        worstL = l;
        worst = colour;
      }
    }
  }
  return worst!;
}

Future<ImageProvider<Object>> _decode(WidgetTester tester, String path) async {
  final made = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(
      await File(path).readAsBytes(),
    );
    return (await codec.getNextFrame()).image;
  });
  return _Decoded(made!);
}

Future<ImageProvider<Object>> _solid(WidgetTester tester) async {
  final made = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 8, 8),
      Paint()..color = const Color(0xFF808080),
    );
    return recorder.endRecording().toImage(8, 8);
  });
  return _Decoded(made!);
}

/// An already-decoded frame, so the plate paints in the frame under test
/// rather than one or two frames later on the engine's own clock.
class _Decoded extends ImageProvider<_Decoded> {
  _Decoded(this.image);

  final ui.Image image;

  @override
  Future<_Decoded> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_Decoded>(this);

  @override
  ImageStreamCompleter loadImage(_Decoded key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(
        SynchronousFuture<ImageInfo>(ImageInfo(image: image)),
      );
}

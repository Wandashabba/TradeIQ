import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/plate/plate.dart';

import '../../design/amber_golden.dart';
import 'torch_harness.dart';

/// The plate's goldens are **measurements**, not PNGs. A byte-comparison
/// golden of a photograph fails on a font hint and passes on a fold-budget
/// regression, which is exactly backwards for a component whose whole contract
/// is arithmetic.
void main() {
  const claim = 'plate';

  Widget plate({
    ImageProvider<Object>? image,
    String? caption,
    String? sentence,
    double viewportHeight = 720,
  }) => TiqPlate(
    claimId: claim,
    viewportHeight: viewportHeight,
    image: image,
    caption: caption,
    fallbackSentence: sentence ?? 'No shelf photo from this outlet yet.',
    devicePixelRatio: 1,
    hero: const PlateHeroCluster(
      eyebrow: 'Gauteng North · Week 38',
      figure: Text('72'),
      healthLine: Text('Territory health'),
    ),
  );

  group('the fold budget', () {
    test('is one expression, and it is the second term that bites', () {
      // 0.44 x 640 = 281.6, clamped to [200, 360] = 281.6.
      // 640 - 440 = 200. The list wins.
      expect(PlateSpec.heightFor(640), 200);
      // A tall phone: 0.44 x 892 = 392.5 -> clamped to 360; 892-440 = 452.
      expect(PlateSpec.heightFor(892), 360);
      // A short one: 600-440 = 160, under the 200 floor.
      expect(PlateSpec.heightFor(600), 160);
    });

    test('under the floor the plate does not render at all', () {
      final spec = PlateSpec.resolve(
        skin: TiqSkin.night(),
        viewportHeight: 600,
      );
      expect(spec.form, PlateForm.collapsed);
      expect(spec.height, 96);
      expect(spec.drawsImage, isFalse);
      expect(spec.drawsStripLight, isFalse);
    });

    test('the strip light is clamped out of the lower 40%', () {
      for (final vh in <double>[640, 720, 892, 1200]) {
        final spec = PlateSpec.resolve(
          skin: TiqSkin.night(),
          viewportHeight: vh,
        );
        if (spec.form != PlateForm.photographic) continue;
        expect(
          spec.stripLightY,
          lessThanOrEqualTo(spec.height * 0.60),
          reason: 'A light low in the frame is a backlight behind the figure.',
        );
        expect(spec.stripLightY, closeTo(spec.height * 0.38, 0.01));
      }
    });

    test('the text-safe zone always starts at or below the light', () {
      for (final vh in <double>[640, 720, 892, 1200]) {
        final spec = PlateSpec.resolve(
          skin: TiqSkin.night(),
          viewportHeight: vh,
        );
        if (spec.form != PlateForm.photographic) continue;
        expect(
          spec.textZoneTop,
          greaterThanOrEqualTo(spec.stripLightY),
          reason:
              'The caption sits on the zone\'s first line. A zone that starts '
              'above the light puts provenance text across it.',
        );
      }
    });

    test('the compact hero face arrives before the plate gets small', () {
      expect(
        PlateSpec.resolve(
          skin: TiqSkin.night(),
          viewportHeight: 640,
        ).figureRole.name,
        'hero.figure.compact',
      );
      expect(
        PlateSpec.resolve(
          skin: TiqSkin.night(),
          viewportHeight: 1200,
        ).figureRole.name,
        'hero.figure',
      );
    });
  });

  group('the goldens', () {
    test('Night, three viewports', () {
      final lines = <String>[
        for (final vh in <double>[640, 720, 892])
          'vh=$vh  ${PlateSpec.resolve(skin: TiqSkin.night(), viewportHeight: vh).describe()}',
      ];
      expect(lines, <String>[
        'vh=640.0  form=photographic  height=200.0  stripLightY=76.0  '
            'bloom=48.0  scrim=58%  zoneTop=84.0  figure=hero.figure.compact  '
            'inset=20.0',
        'vh=720.0  form=photographic  height=280.0  stripLightY=106.4  '
            'bloom=48.0  scrim=52%  zoneTop=134.4  figure=hero.figure  '
            'inset=20.0',
        'vh=892.0  form=photographic  height=360.0  stripLightY=136.8  '
            'bloom=48.0  scrim=52%  zoneTop=172.8  figure=hero.figure  '
            'inset=20.0',
      ]);
    });

    test('Day keeps the geometry; only the light changes', () {
      expect(
        PlateSpec.resolve(skin: TiqSkin.day(), viewportHeight: 720).describe(),
        PlateSpec.resolve(
          skin: TiqSkin.night(),
          viewportHeight: 720,
        ).describe(),
      );
    });

    test('Veld draws no plate', () {
      expect(
        PlateSpec.resolve(skin: TiqSkin.veld(), viewportHeight: 720).describe(),
        startsWith('form=none  height=0.0'),
      );
    });
  });

  group('amber', () {
    testWidgets('a lit plate is exactly one object — line plus bloom', (
      tester,
    ) async {
      final image = await _solid(tester);
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        claims: const <TorchClaim>[TorchClaim.plateStripLight(claim)],
        child: plate(image: image, caption: 'Kasi Corner Spaza · 17 Sep 06:40'),
      );

      final census = await amberCensus(tester);
      expect(
        census.objectCount,
        1,
        reason:
            'The line and the gradient above it are one light, and the census '
            'counts what it looks like.\n${census.describe()}',
      );
    });

    testWidgets('an unlit claim paints no amber', (tester) async {
      final image = await _solid(tester);
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        claims: const <TorchClaim>[],
        child: plate(image: image, caption: 'Kasi Corner Spaza'),
      );

      final census = await amberCensus(tester);
      expect(census.objectCount, 0, reason: census.describe());
    });

    testWidgets('the fallback is never lit, even with the grant in hand', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        claims: const <TorchClaim>[TorchClaim.plateStripLight(claim)],
        child: plate(),
      );

      expect(find.byType(PlateFallback), findsOneWidget);
      final census = await amberCensus(tester);
      expect(
        census.objectCount,
        0,
        reason:
            'A light needs something to be a light ON. A lit drawing is a '
            'decoration wearing the screen\'s one grant.\n${census.describe()}',
      );
    });

    testWidgets('Day keeps the image and takes an ink rule instead', (
      tester,
    ) async {
      final image = await _solid(tester);
      await pumpTorch(
        tester,
        skin: TiqSkin.day(),
        claims: const <TorchClaim>[TorchClaim.plateStripLight(claim)],
        child: plate(image: image, caption: 'Kasi Corner Spaza'),
      );

      expect(find.byType(PlateFallback), findsNothing);
      final census = await amberCensus(tester);
      expect(
        census.objectCount,
        0,
        reason:
            'Amber on a light-ground photograph is decoration, not emitted '
            'light.\n${census.describe()}',
      );
    });
  });

  group('the fallback', () {
    testWidgets('says why, and is obviously a drawing', (tester) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: plate(sentence: 'No shelf photo from Kasi Corner Spaza yet.'),
      );

      expect(find.byType(PlateFallback), findsOneWidget);
      expect(
        find.text('No shelf photo from Kasi Corner Spaza yet.'),
        findsOneWidget,
      );
      // The hero cluster stays: the photograph is the specimen, not the
      // subject.
      expect(find.byType(PlateHeroCluster), findsOneWidget);
    });

    testWidgets('announces itself as a drawing, not as a shelf', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpTorch(tester, skin: TiqSkin.night(), child: plate());

      expect(
        find.bySemanticsLabel('Generated shelf illustration'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('text scale', () {
    testWidgets('2.0x does not overflow the text-safe zone', (tester) async {
      final image = await _solid(tester);
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        textScale: 2.0,
        size: const Size(360, 640),
        claims: const <TorchClaim>[TorchClaim.plateStripLight(claim)],
        child: plate(
          image: image,
          caption: 'Kasi Corner Spaza · 17 Sep 06:40',
          viewportHeight: 640,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(PlateHeroCluster), findsOneWidget);
    });
  });
}

Future<ImageProvider<Object>> _solid(WidgetTester tester) async {
  final image = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 8, 8),
      Paint()..color = const Color(0xFF808080),
    );
    return recorder.endRecording().toImage(8, 8);
  });
  return _SyncImage(image!);
}

class _SyncImage extends ImageProvider<_SyncImage> {
  _SyncImage(this.image);

  final ui.Image image;

  @override
  Future<_SyncImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_SyncImage>(this);

  @override
  ImageStreamCompleter loadImage(_SyncImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(
        SynchronousFuture<ImageInfo>(ImageInfo(image: image)),
      );
}

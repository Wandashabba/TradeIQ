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

/// THE PLATE IS A GROUND, NOT A COLOUR FIELD — AND IT IS A DIFFERENT GROUND IN
/// EACH SKIN.
///
/// This file exists because the treatment was once **half** applied and nothing
/// failed: `direction-torchlight.json` baked a plate at reduced chroma under a
/// luminance ceiling, only the ceiling ever reached the device, and a multiply
/// by a neutral grey darkens a colour without ever desaturating it. Against
/// the seeded dev data, whose shelf photos are blocks of fully saturated random
/// colour, the plate came out a dim rainbow. Nothing measured it.
///
/// **That is still the spirit and it is now a bigger claim.** As of 29
/// September 2026 the tone is a chroma reduction *and* a map into a per-skin
/// range `[plateLift, plateCeiling]` — Night `[0, #666666]`, Day
/// `[#999999, #E6E6E6]`. So there are three operations to keep honest and two
/// skins to keep them honest in:
///
/// 1. the chroma really is reduced (not a ceiling pretending to be a tone),
/// 2. nothing lands **above** the skin's ceiling,
/// 3. nothing lands **below** the skin's lift — which is the half that is new,
///    and the half that closes the Day contrast defect. A lift that quietly
///    went back to zero would leave every "no pixel above the ceiling" test
///    green and put the Day plate straight back under 4.5:1.
///
/// Measured twice: once in arithmetic, where the filter's twenty numbers are
/// pinned, and once in pixels, on the real screen, against a fixture that
/// reproduces the seed's own generator.
void main() {
  final night = TiqSkin.night().palette;
  final day = TiqSkin.day().palette;

  /// The filter, applied by hand, so a claim about a photograph is a claim
  /// about a number.
  ({int r, int g, int b}) toned(
    Color source,
    TiqPalette skin, {
    double? chroma,
  }) {
    final m = plateToneMatrix(
      chroma: chroma ?? TiqPlate.chroma,
      ceiling: skin.plateCeiling,
      lift: skin.plateLift,
    );
    final r = source.r * 255, g = source.g * 255, b = source.b * 255;
    int row(int i) =>
        (m[i * 5] * r + m[i * 5 + 1] * g + m[i * 5 + 2] * b + m[i * 5 + 4])
            .round()
            .clamp(0, 255);
    return (r: row(0), g: row(1), b: row(2));
  }

  /// Every corner and midpoint of the colour cube the plate has to survive.
  const probes = <Color>[
    Color(0xFF000000),
    Color(0xFFFFFFFF),
    Color(0xFFFF0000),
    Color(0xFF00FF00),
    Color(0xFF0000FF),
    Color(0xFFFFFF00),
    Color(0xFF00FFFF),
    Color(0xFFFF00FF),
    Color(0xFF808080),
    Color(0xFFEBEBE4),
    Color(0xFF1B2632),
  ];

  group('the tone, as arithmetic', () {
    test('is the range AND the chroma, not one of the two', () {
      // The defect this file was written for: a treatment that is only a
      // multiply. Pure red keeps every scrap of its hue and simply gets dark.
      for (final skin in <(String, TiqPalette)>[
        ('night', night),
        ('day', day),
      ]) {
        final multiplyOnly = (255 * skin.$2.plateCeiling.r).round();
        final red = toned(const Color(0xFFFF0000), skin.$2);
        final blue = toned(const Color(0xFF0000FF), skin.$2);
        expect(
          red.r - red.b,
          lessThan(multiplyOnly),
          reason:
              '${skin.$1}: pure red came out as $red — as wide a spread as a '
              'bare multiply by the ceiling would give. The chroma half of '
              'the tone is not being applied.',
        );
        // AND THE CHROMA IS NOT TOTAL EITHER. The owner asked for colour on
        // 29 September 2026 and got 55% of it; a tone that drained the hue
        // completely would pass every bound in this file and be the thing the
        // owner complained about.
        expect(
          red.r - red.b,
          greaterThan(10),
          reason:
              '${skin.$1}: pure red came out neutral ($red). The plate is a '
              'ground, not a greyscale conversion — the owner asked for a bit '
              'of colour.',
        );
        expect(
          blue.b - blue.r,
          greaterThan(10),
          reason: '${skin.$1}: pure blue came out neutral ($blue)',
        );
      }
    });

    test('white lands exactly on the ceiling, in both skins', () {
      final nightWhite = toned(const Color(0xFFFFFFFF), night);
      expect((nightWhite.r, nightWhite.g, nightWhite.b), (0x66, 0x66, 0x66));
      final dayWhite = toned(const Color(0xFFFFFFFF), day);
      expect((dayWhite.r, dayWhite.g, dayWhite.b), (0xE6, 0xE6, 0xE6));
    });

    test('black lands exactly on the lift, in both skins', () {
      // THE HALF THAT IS NEW, AND THE HALF THAT CLOSES THE DAY DEFECT.
      //
      // Night lifts nothing — on a near-black ground the shadows of a
      // photograph ARE the ground — so black stays black and the matrix has
      // exactly the shape it had when it was a ceiling alone.
      final nightBlack = toned(const Color(0xFF000000), night);
      expect((nightBlack.r, nightBlack.g, nightBlack.b), (0, 0, 0));

      // Day lifts to 60%: the darkest pixel a Day plate may paint is #999999,
      // because `ink1` is #1B2632 and a picture darker than the ink is a
      // picture the ink disappears into. That was 2.63:1 before this existed.
      final dayBlack = toned(const Color(0xFF000000), day);
      expect((dayBlack.r, dayBlack.g, dayBlack.b), (0x99, 0x99, 0x99));
    });

    test('NO PIXEL escapes the skin\'s range, either end', () {
      for (final skin in <(String, TiqPalette)>[
        ('night', night),
        ('day', day),
      ]) {
        final ceiling = (skin.$2.plateCeiling.r * 255).round();
        final lift = (skin.$2.plateLift * 255).round();
        // The probes, plus 512 pseudo-random pixels — a photograph is not a
        // colour wheel and the bound has to hold for whatever is in the frame.
        final sources = <Color>[
          ...probes,
          for (var i = 0; i < 512; i++)
            Color.fromARGB(255, (i * 97) % 256, (i * 37) % 256, (i * 211) % 256),
        ];
        for (final source in sources) {
          final out = toned(source, skin.$2);
          expect(
            math.max(out.r, math.max(out.g, out.b)),
            lessThanOrEqualTo(ceiling + 1),
            reason: '${skin.$1}: $source came out ABOVE the ceiling as $out',
          );
          expect(
            math.min(out.r, math.min(out.g, out.b)),
            greaterThanOrEqualTo(lift - 1),
            reason:
                '${skin.$1}: $source came out BELOW the lift as $out. On Day '
                'that is the contrast defect returning: the plate is darker '
                'than the ink that sits on it.',
          );
        }
      }
    });

    test('a neutral stays neutral, and is mapped across the whole range', () {
      for (final skin in <TiqPalette>[night, day]) {
        final grey = toned(const Color(0xFF808080), skin);
        expect(grey.r, grey.g);
        expect(grey.g, grey.b);
        final expected =
            (skin.plateLift * 255 +
                    (skin.plateCeiling.r - skin.plateLift) * 128)
                .round();
        expect(grey.r, closeTo(expected, 1));
      }
    });

    test('lift = 0 is exactly the old ceiling-only matrix', () {
      // The generalisation has to be a provable superset, not a rewrite: with
      // no lift, row i is still `ceiling[i] x (saturation row i)` and the
      // offset column is still zero. Night takes this path.
      final m = plateToneMatrix(
        chroma: 0.12,
        ceiling: const Color(0xFF474747),
        lift: 0,
      );
      expect(m[4], 0);
      expect(m[9], 0);
      expect(m[14], 0);
      const k = 0x47 / 0xFF;
      expect(m[0], closeTo(k * (0.2126 * 0.88 + 0.12), 1e-9));
      expect(m[1], closeTo(k * 0.7152 * 0.88, 1e-9));
      expect(m[6], closeTo(k * (0.7152 * 0.88 + 0.12), 1e-9));
      expect(m[12], closeTo(k * 0.0722 * 0.88, 1e-9));
    });

    test('the offset column is lift x 255, not lift', () {
      // `ColorFilter.matrix` runs on 0..255 values and the fifth column is a
      // constant in that same space. Getting it wrong is silent at lift = 0
      // and a 0.6/255 no-op at lift = 0.6, which is the Day defect unfixed
      // and every other test in this file still green.
      final m = plateToneMatrix(
        ceiling: day.plateCeiling,
        lift: day.plateLift,
      );
      expect(m[4], closeTo(0.60 * 255, 1e-9));
      expect(m[9], closeTo(0.60 * 255, 1e-9));
      expect(m[14], closeTo(0.60 * 255, 1e-9));
      expect(m[19], 0, reason: 'alpha is untouched');
    });

    test('the tokens, and the filter each skin actually hands out', () {
      expect(TiqPlate.chroma, 0.55, reason: 'the owner asked for colour');
      expect(night.plateCeiling, const Color(0xFF666666));
      expect(night.plateLift, 0.0);
      expect(day.plateCeiling, const Color(0xFFE6E6E6));
      expect(day.plateLift, 0.60);
      // AND THE TWO SKINS DO NOT SHARE A TONE. One `static const plateCeiling`
      // for both skins is the assumption that left Day failing at 2.63:1.
      expect(
        TiqPlate.toneFor(night),
        isNot(TiqPlate.toneFor(day)),
        reason: 'the plate is toned the same way on paper as on a console',
      );
      expect(
        TiqPlate.toneFor(night),
        ColorFilter.matrix(
          plateToneMatrix(ceiling: night.plateCeiling, lift: night.plateLift),
        ),
      );
      // The thing that regressed: a treatment that is only the ceiling.
      expect(
        TiqPlate.toneFor(night),
        isNot(ColorFilter.mode(night.plateCeiling, BlendMode.multiply)),
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

      // The band of plate above the strip light's bloom: pure picture, no
      // amber, no scrim, no hero cluster. Measured off the plate's own rect,
      // not off the viewport, because the shell puts the body's top padding
      // above it.
      //
      // PIN MOVED, 28 September 2026: the band is the same band, with the
      // scope control cut out of it. The control is painted on the plate now,
      // with a `surface` fill and an edge — a control, not a photograph, and
      // not subject to the bake. Cutting its rect out is the honest way to
      // keep measuring the picture; narrowing the band to dodge it would have
      // left a few pixels of band and nothing at all on a 360dp phone.
      final spec = PlateSpec.resolve(skin: TiqSkin.night(), viewportHeight: 640);
      final plate = tester.getRect(find.byType(TiqPlate));
      final chip = tester.getRect(
        find.byKey(const ValueKey<String>('floor-scope-chip')),
      );
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
        // Inflated by 2: the chip's own edge is antialiased against the
        // picture, and a blend of two colours is neither of them.
        except: chip.inflate(2),
      );

      // The Floor renders in Night, so these are Night's two ends.
      expect(
        sample.maxChannel,
        lessThanOrEqualTo(0x66 + 2),
        reason:
            'a pixel brighter than the #666666 ceiling: the plate is not a '
            'ground any more. Brightest was ${sample.maxChannel}.',
      );
      // (ceiling - lift) x chroma x 255 = 0.40 x 0.55 x 255 = 56. Wider than
      // the 8.5 the 12% treatment allowed, on purpose and on the owner's
      // instruction — and still a long way under the 71 the multiply-only
      // treatment let through, which is the rainbow this file was written for.
      final bound =
          ((night.plateCeiling.r - night.plateLift) * TiqPlate.chroma * 255)
              .ceil();
      expect(bound, 56);
      expect(
        sample.maxSpread,
        lessThanOrEqualTo(bound + 4),
        reason:
            'a colour cast of ${sample.maxSpread}/255 on the plate, against a '
            'bound of $bound. The multiply-only treatment allowed 71 — this '
            'is the rainbow.',
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

      expect(platedImage(tester)?.colorFilter, TiqPlate.toneFor(night));
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
/// The brightest channel and the widest channel spread in a rectangle of the
/// rendered frame, **skipping** [except].
///
/// The exclusion exists because the plate is no longer only a picture: the
/// scope control is painted on it, with a `surface` fill and an edge, and a
/// control is a control — it is not subject to the photographic bake and its
/// fill legitimately carries more colour than 8.5/255. What this measures is
/// the picture, so it measures the picture.
Future<({int maxChannel, int maxSpread})> _sample(
  WidgetTester tester, {
  required int top,
  required int bottom,
  required int left,
  required int right,
  Rect? except,
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
        if (except != null &&
            except.contains(Offset(x.toDouble(), y.toDouble()))) {
          continue;
        }
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

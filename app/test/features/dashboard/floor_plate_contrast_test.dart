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
import 'package:tradeiq_app/features/dashboard/presentation/floor_ask.dart';

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
/// ## Day was a declared defect here, and this file is where it closed
///
/// This file used to assert, deliberately, that **every** Day figure was
/// **below** 4.5:1, with a note saying that if one ever went above it somebody
/// had fixed the scrim and the test should be deleted. Somebody did — on 29
/// September 2026, via the tone rather than the scrim. The plate is no longer
/// capped at `#474747` in both skins: it is mapped into a per-skin range, and
/// Day's has a **lift** of 0.60, so no plate pixel on paper is darker than
/// `#999999`. Dark ink over a dark picture was the whole defect and a ceiling
/// could never have fixed it, because the ink and the picture were failing on
/// the same side.
///
/// So the inequality is inverted and the test is a pin instead of a confession.
/// It fails if anyone lowers Day's lift, raises either ceiling, or lands a
/// picture these numbers do not survive.
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

  /// Both figures over every committed picture, in one skin.
  ///
  /// The worst pixel is the brightest on a dark ground and the darkest on a
  /// light one — `dark` is which side of that the skin is on.
  Future<Map<String, ({double figure, double meta})>> measure(
    WidgetTester tester,
    TiqSkin skin, {
    required bool dark,
  }) async {
    (hero, health) = await _inkRects(tester);
    final out = <String, ({double figure, double meta})>{};
    for (final code in codes) {
      final image = await _decode(tester, '$places/$code.jpg');
      final plate = await _pumpBarePlate(tester, image, skin);
      final frame = await _grab(tester);
      out[code] = (
        figure: contrastRatio(
          skin.palette.ink1,
          _worstPixel(frame, hero.shift(plate.topLeft), dark: dark),
        ),
        meta: contrastRatio(
          skin.palette.ink2,
          _worstPixel(frame, health.shift(plate.topLeft), dark: dark),
        ),
      );
    }
    return out;
  }

  /// The measurement, printed. The owner asked for the numbers rather than a
  /// green tick, and a table in a test log is the only version of them that
  /// cannot go stale.
  void report(String skin, Map<String, ({double figure, double meta})> m) {
    // ignore: avoid_print
    print('\n  $skin — 390x844, worst pixel in each ink\'s own box');
    // ignore: avoid_print
    print('  ${'code'.padRight(10)}${'hero (ink1)'.padRight(14)}health (ink2)');
    for (final e in m.entries) {
      // ignore: avoid_print
      print(
        '  ${e.key.padRight(10)}'
        '${'${e.value.figure.toStringAsFixed(2)}:1'.padRight(14)}'
        '${e.value.meta.toStringAsFixed(2)}:1',
      );
    }
  }

  void pin(
    String skin,
    Map<String, ({double figure, double meta})> m,
    double floor,
  ) {
    for (final e in m.entries) {
      expect(
        e.value.figure,
        greaterThanOrEqualTo(floor),
        reason:
            '${e.key}: the hero figure measures '
            '${e.value.figure.toStringAsFixed(2)}:1 on the $skin plate, under '
            'the $floor floor. Either the picture is unusable on this skin or '
            'somebody moved the plate tone — check plateLift and plateCeiling '
            'before blaming the photograph.',
      );
      expect(
        e.value.meta,
        greaterThanOrEqualTo(floor),
        reason:
            '${e.key}: the "Territory health" line measures '
            '${e.value.meta.toStringAsFixed(2)}:1 on the $skin plate, under '
            'the $floor floor.',
      );
    }
  }

  /// ── THE CONTROLS ON THE TOP BAND, AND THEY ARE TRANSLUCENT NOW ──────
  ///
  /// The Floor's plate carries two controls up there since 30 September 2026:
  /// the scope chip it always had, and the destinations control that replaced
  /// the nav pill. The question the owner's reviewer asked is whether a glyph
  /// on a photograph is readable, and it is a question with a measured answer
  /// rather than an opinion.
  ///
  /// ## THIS TEST'S SUBJECT CHANGED ON 1 OCTOBER 2026, AND IT GOT HARDER
  ///
  /// Until that day both controls wore an **opaque** `surface` fill, so their
  /// ink landed on a declared colour and the photograph was irrelevant. This
  /// file printed one number per skin — ink-1 on `surface`, 14.16:1 and
  /// 14.34:1 — and that number was true and almost free.
  ///
  /// The owner's weight pass replaced the opaque tier with a **wash of
  /// `ground`**: 72% under the scope chip, 55% under Menu. That is the whole
  /// point of the change — the picture survives under the control — and it is
  /// also the one thing in the change that can collide with the contrast
  /// floor, because 28% and 45% of whatever the photograph happens to contain
  /// is now behind the ink. The owner named it in the brief as the risk, and
  /// the right answer is a measurement over the real pictures rather than an
  /// argument.
  ///
  /// So the single `surface` figure is replaced by **28 measurements per
  /// skin** — two controls over fourteen committed images — and the
  /// composition is done the way the rasteriser does it: the worst plate pixel
  /// inside each control's own box, with the wash alpha-blended over it. The
  /// blend is monotonic in the backdrop, so the worst pixel for the composite
  /// is the worst pixel for the picture, which is why the bare plate can be
  /// rasterised once per image and reused for both controls.
  ///
  /// Three inks are checked, because the two controls do not carry the same
  /// ones: the chip's scope name is `ink1`, its window half and its chevron
  /// are `ink2`, and Menu's glyph is `ink1`. The chevron is why `ink2` is in
  /// here at all — it was `ink3` until this pass and `ink3` over the Day wash
  /// is the one pairing that does not clear 4.5.
  ///
  /// `entry_plate.dart` records the case that makes this worth printing at
  /// all: a bare mark on this band measured **3.60:1** on Night and had to be
  /// given a scrim. The bare figure is still printed beside the washed one, so
  /// what the wash is buying is visible rather than assumed.
  testWidgets('the plate\'s quiet top-band controls clear 4.5:1 over every '
      'committed picture, in both skins', (tester) async {
    final (chipBox, menuBox) = await _controlRects(tester);

    for (final (name, skin, dark) in <(String, TiqSkin, bool)>[
      ('NIGHT', TiqSkin.night(), true),
      ('DAY', TiqSkin.day(), false),
    ]) {
      final p = skin.palette;
      final chipWash = p.ground.withValues(alpha: plateQuietChipAlpha);
      final menuWash = p.ground.withValues(alpha: plateQuietButtonAlpha);

      final rows =
          <String, ({double scope, double window, double menu, double bare})>{};
      for (final code in codes) {
        final image = await _decode(tester, '$places/$code.jpg');
        final plate = await _pumpBarePlate(tester, image, skin);
        final frame = await _grab(tester);

        // THE COMPOSITE, the way Skia makes it: src-over of the wash on the
        // hardest pixel the photograph puts under that control.
        final underChip = _worstPixel(
          frame,
          chipBox.shift(plate.topLeft),
          dark: dark,
        );
        final underMenu = _worstPixel(
          frame,
          menuBox.shift(plate.topLeft),
          dark: dark,
        );
        final onChip = Color.alphaBlend(chipWash, underChip);
        final onMenu = Color.alphaBlend(menuWash, underMenu);

        rows[code] = (
          scope: contrastRatio(p.ink1, onChip),
          window: contrastRatio(p.ink2, onChip),
          menu: contrastRatio(p.ink1, onMenu),
          // What the same ink would have measured with NO wash at all, which
          // is the number the wash exists to move.
          bare: contrastRatio(p.ink1, underChip),
        );
      }

      // ignore: avoid_print
      print(
        '\n  $name — the plate\'s quiet controls, 390x844, worst pixel under '
        'each one\n'
        '  chip wash: ground@${(plateQuietChipAlpha * 100).round()}%   '
        'Menu wash: ground@${(plateQuietButtonAlpha * 100).round()}%\n'
        '  ${'code'.padRight(10)}${'chip/ink1'.padRight(12)}'
        '${'chip/ink2'.padRight(12)}${'Menu/ink1'.padRight(12)}'
        '(no wash)',
      );
      for (final e in rows.entries) {
        // ignore: avoid_print
        print(
          '  ${e.key.padRight(10)}'
          '${'${e.value.scope.toStringAsFixed(2)}:1'.padRight(12)}'
          '${'${e.value.window.toStringAsFixed(2)}:1'.padRight(12)}'
          '${'${e.value.menu.toStringAsFixed(2)}:1'.padRight(12)}'
          '${e.value.bare.toStringAsFixed(2)}:1',
        );
      }
      final worst = rows.entries
          .map(
            (e) => math.min(
              math.min(e.value.scope, e.value.window),
              e.value.menu,
            ),
          )
          .reduce(math.min);
      // ignore: avoid_print
      print(
        '  ${'WORST OF 42'.padRight(12)}${worst.toStringAsFixed(2)}:1'
        '  (3 inks × 14 pictures, floor $floor)',
      );

      for (final e in rows.entries) {
        for (final (what, ratio) in <(String, double)>[
          ('the scope name (ink-1)', e.value.scope),
          ('the window and the chevron (ink-2)', e.value.window),
          ('Menu\'s glyph (ink-1)', e.value.menu),
        ]) {
          expect(
            ratio,
            greaterThanOrEqualTo(floor),
            reason:
                '${e.key}: $what measures ${ratio.toStringAsFixed(2)}:1 on '
                'the $name plate through the quiet wash, under the $floor '
                'floor.\n'
                'THIS IS THE COLLISION THE WEIGHT PASS WAS WARNED ABOUT: a '
                'quieter control over a photograph trades contrast for calm, '
                'and the trade has a floor. Do NOT fix it by darkening the '
                'ink — raise the wash alpha (plateQuietChipAlpha / '
                'plateQuietButtonAlpha) until this passes, and if it cannot '
                'pass at an alpha that still shows the picture then the '
                'mockup and 1.4.3 genuinely disagree and the owner has to '
                'rule on it.',
          );
        }
      }
    }
  });

  /// THE WASH IS WORTH WHAT IT COSTS, and this is the one number that says so.
  ///
  /// A separate test from the floor above because it answers a different
  /// question. That one asks "is the quiet control legible" — a pass/fail
  /// against 4.5. This one asks "did the wash do anything", which is the
  /// question a reviewer actually has about a translucent fill: a wash so thin
  /// it changes nothing is decoration, and a reader would be better served by
  /// the opaque tier it replaced.
  testWidgets('the wash is doing real work: it beats bare ink on every '
      'picture, in both skins', (tester) async {
    final (chipBox, _) = await _controlRects(tester);
    for (final (name, skin, dark) in <(String, TiqSkin, bool)>[
      ('NIGHT', TiqSkin.night(), true),
      ('DAY', TiqSkin.day(), false),
    ]) {
      final wash = skin.palette.ground.withValues(alpha: plateQuietChipAlpha);
      for (final code in codes) {
        final image = await _decode(tester, '$places/$code.jpg');
        final plate = await _pumpBarePlate(tester, image, skin);
        final frame = await _grab(tester);
        final under = _worstPixel(
          frame,
          chipBox.shift(plate.topLeft),
          dark: dark,
        );
        final bare = contrastRatio(skin.palette.ink1, under);
        final washed = contrastRatio(
          skin.palette.ink1,
          Color.alphaBlend(wash, under),
        );
        expect(
          washed,
          greaterThan(bare),
          reason:
              '$name/$code: the wash moves ink-1 from '
              '${bare.toStringAsFixed(2)}:1 to ${washed.toStringAsFixed(2)}:1, '
              'which is not an improvement. A wash that does not improve the '
              'pairing is decoration over a photograph and the control should '
              'go back to an opaque tier.',
        );
      }
    }
  });

  testWidgets('there are committed place images to measure', (tester) async {
    // A guard, not a formality: if the assets folder is ever emptied or moved,
    // every assertion below becomes vacuously green and this file starts
    // proving nothing while still passing.
    expect(codes.length, greaterThanOrEqualTo(14));
  });

  testWidgets('the plate ink clears 4.5:1 on Night over every committed '
      'picture, supplied and generated alike', (tester) async {
    final m = await measure(tester, TiqSkin.night(), dark: true);
    report('NIGHT', m);
    pin('Night', m, floor);

    // Measured 29 September 2026, after the ceiling moved from #474747 to
    // #666666 on the owner's instruction to make the pictures luminous. The
    // margin is narrower than it was and still wide — this exists to catch a
    // future picture that is nothing like these, and to catch a ceiling that
    // creeps up again, not to pin a number to two decimal places across
    // rasterisers.
    final worst = m.values
        .map((v) => math.min(v.figure, v.meta))
        .reduce(math.min);
    expect(
      worst,
      greaterThan(5.0),
      reason:
          'the worst Night pairing is ${worst.toStringAsFixed(2)}:1. Night had '
          'headroom and spent some of it on luminosity; it has not got this '
          'much more to spend.',
    );
  });

  testWidgets('DAY CLEARS 4.5:1 TOO, which is the defect this file used to '
      'assert', (tester) async {
    // THIS TEST USED TO ASSERT THE FAILURE.
    //
    // PR #473 reported that the Day meta line over the plate measured 2.92:1
    // against a 4.5 minimum, and that the plate was under-specified for a
    // light ground: the scrim ramps `ground` from 0% at the top of the text
    // zone to 80% at the foot, so "Territory health" sits at roughly 57% and
    // the hero figure's cap height at about 17%. On a dark ground that is
    // fine — the ink is light and the picture is dark. On a light ground the
    // ink is dark and the picture was ALSO dark, because every plate pixel was
    // capped at #474747 in both skins. The two converged.
    //
    // The repair is not the scrim. It is the tone: Day maps the picture into
    // [#999999, #E6E6E6] instead of [black, #474747], so the photograph is now
    // the PALE half of the pairing, which is what dark ink on paper needs. The
    // assertion below is the old one with the inequality turned round, and it
    // is the thing that stops the lift being quietly dialled back.
    final m = await measure(tester, TiqSkin.day(), dark: false);
    report('DAY', m);
    pin('Day', m, floor);

    // AND THE SUPPLIED PICTURES ARE NOT THE WEAK ONES. `ALL` and `NW` are the
    // two still generated; the supplied set has to sit with them rather than
    // dragging the number down. Kept from the version of this test that
    // asserted the defect, because it answers a different question: not "does
    // the plate work" but "did a new picture make it worse".
    final generated = <double>[m['ALL']!.meta, m['NW']!.meta];
    final supplied = m.entries
        .where((e) => e.key != 'ALL' && e.key != 'NW')
        .map((e) => e.value.meta)
        .toList();
    expect(
      supplied.reduce(math.min),
      greaterThan(generated.reduce(math.min) - 0.4),
      reason:
          'a supplied picture is materially worse for the Day meta line than '
          'the generated ones. The tone holds a floor for every picture, so a '
          'picture that still drags is a picture with a problem of its own '
          'and it belongs to whoever added it.',
    );
  });

  testWidgets('the tone tokens are what the measurement was made at', (
    tester,
  ) async {
    // The numbers above are a measurement, and a measurement is only a pin if
    // the thing it was measured at is pinned too. Lowering Day's lift or
    // raising either ceiling would show up here first, with the reason
    // attached, instead of as fourteen opaque contrast failures.
    expect(TiqSkin.day().palette.plateLift, 0.60);
    expect(TiqSkin.day().palette.plateCeiling, const Color(0xFFE6E6E6));
    expect(TiqSkin.night().palette.plateLift, 0.0);
    expect(TiqSkin.night().palette.plateCeiling, const Color(0xFF666666));
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

/// Where the two quiet controls' **painted boxes** sit, relative to the plate.
///
/// Taken off the real widgets rather than recomputed from
/// [PlateSpec.topSlotInset] and [plateQuietExtent], for the reason
/// [_inkRects] gives about the hero: a measurement that re-derives its own
/// geometry measures a screen the product does not draw. The first version of
/// the test above used a hand-built 44dp band across the whole plate width and
/// so measured the picture under a region neither control occupies.
///
/// It is the **painted** box and not the tap target: the wash is 29dp tall
/// inside a 44dp transparent box, and the 15dp of transparency around it has
/// no wash over it to measure.
Future<(Rect, Rect)> _controlRects(WidgetTester tester) async {
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
                    hero: const SizedBox.shrink(),
                    // The same pair, in the same order, that
                    // `the_floor_screen.dart` builds — chip left, Menu right,
                    // `spaceBetween`.
                    topSlot: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Flexible(
                          child: PlateScopeChip(
                            key: const ValueKey<String>('chip'),
                            scope: 'Gauteng North',
                            window: 'Last 30 days',
                            onTap: () {},
                            semanticsLabel: 'scope',
                          ),
                        ),
                        const SizedBox(width: TiqSpace.s2),
                        FloorDestinationsButton(
                          key: const ValueKey<String>('menu'),
                          onTap: () {},
                        ),
                      ],
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
  Rect painted(String key) => tester
      .getRect(
        find
            .descendant(
              of: find.byKey(ValueKey<String>(key)),
              matching: find.byType(Container),
            )
            .first,
      )
      .shift(-plate.topLeft);
  return (painted('chip'), painted('menu'));
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

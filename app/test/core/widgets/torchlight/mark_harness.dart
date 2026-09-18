import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';

/// THE MARK GOLDEN HARNESS — Night first, then Day, Veld last.
///
/// This repository does not keep `matchesGoldenFile` PNGs, and deliberately:
/// a byte-comparison golden fails on a font hint, passes on a semantic
/// regression, and is re-baselined by whoever is in a hurry. The amber census
/// established the pattern instead — render the frame, then *measure* the
/// thing the design actually claims.
///
/// So the goldens here are measurements:
///
/// * [greyscaleDifference] proves "can't confirm" is a different shape from
///   "in progress" **with the hue removed**, which is the whole of unify §1.5
///   and the test a hatched fourth state would have failed;
/// * `marks_amber_test.dart` uses the amber census to prove no mark emits
///   light;
/// * the per-state widget tests prove the words are on the screen.
///
/// Every one of them fails for a reason a person can read.

/// Render [child] on this skin's ground and return the raw RGBA.
Future<Uint8List> paintMark(
  WidgetTester tester, {
  required TiqSkin skin,
  required Widget child,
  Size size = const Size(64, 64),
  double textScale = 1.0,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        devicePixelRatio: 1.0,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: ThemeData(extensions: <ThemeExtension<dynamic>>[skin]),
          child: RepaintBoundary(
            key: const ValueKey<String>('mark-boundary'),
            child: ColoredBox(
              color: skin.palette.ground,
              child: SizedBox.fromSize(
                size: size,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey<String>('mark-boundary')),
  );
  // `toImage` hands the layer tree to the rasteriser, which lives outside the
  // test binding's fake clock; awaiting it on the fake clock deadlocks.
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (data == null) throw StateError('The boundary produced no pixels.');
    return data.buffer.asUint8List();
  });
  if (bytes == null) throw StateError('The mark harness did not run.');
  return bytes;
}

/// Rec. 709 luminance, 0–255. The same arithmetic the contrast generator uses
/// for its greyscale filter, so "greyscale" means one thing in this codebase.
int luminanceOf(int r, int g, int b) =>
    (0.2126 * r + 0.7152 * g + 0.0722 * b).round();

/// The fraction of pixels whose **luminance** differs by more than [tolerance].
///
/// Luminance and not colour: a hue difference is not a difference here, which
/// is the point. Two marks that are the same shape in two colours score zero,
/// and that is the failure this measures.
double greyscaleDifference(
  Uint8List a,
  Uint8List b, {
  int tolerance = 8,
}) {
  if (a.length != b.length) {
    throw ArgumentError('Two different frame sizes cannot be compared.');
  }
  final pixels = a.length ~/ 4;
  var differing = 0;
  for (var i = 0; i < pixels; i++) {
    final o = i * 4;
    final la = luminanceOf(a[o], a[o + 1], a[o + 2]);
    final lb = luminanceOf(b[o], b[o + 1], b[o + 2]);
    if ((la - lb).abs() > tolerance) differing++;
  }
  return differing / pixels;
}

/// The fraction of pixels that are not the ground — how much of the frame the
/// mark actually covers. A mark that draws nothing scores zero, which is how a
/// silhouette test catches a painter that silently no-ops.
double inkedFraction(Uint8List rgba, Color ground, {int tolerance = 8}) {
  final gl = luminanceOf(
    (ground.r * 255).round(),
    (ground.g * 255).round(),
    (ground.b * 255).round(),
  );
  final pixels = rgba.length ~/ 4;
  var inked = 0;
  for (var i = 0; i < pixels; i++) {
    final o = i * 4;
    if ((luminanceOf(rgba[o], rgba[o + 1], rgba[o + 2]) - gl).abs() >
        tolerance) {
      inked++;
    }
  }
  return inked / pixels;
}

/// The three skins, in the order the design says to build them: Night first,
/// then Day, Veld last.
List<TiqSkin> get allSkins => <TiqSkin>[
  TiqSkin.night(),
  TiqSkin.day(),
  TiqSkin.veld(),
];

/// Wrap [child] in a skin for a plain widget test (no pixels).
Widget skinned(TiqSkin skin, Widget child, {double textScale = 1.0}) =>
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: ThemeData(extensions: <ThemeExtension<dynamic>>[skin]),
          child: ColoredBox(
            color: skin.palette.ground,
            child: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      ),
    );

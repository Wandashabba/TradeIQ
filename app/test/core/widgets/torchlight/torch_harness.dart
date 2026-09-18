import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/motion_budget.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';

/// The Phase 1 harness: pump a component in a skin, at a pinned size and text
/// scale, and read its pixels back.
///
/// It pumps into the **same** repaint-boundary key the amber golden harness
/// uses, so `amberCensus(tester)` works on anything pumped here without a
/// second render.
const Key torchBoundaryKey = ValueKey<String>('amber-golden-boundary');

/// The three skins, in the order the design says to build them: Night first,
/// then Day, and Veld last — after Night and Day have stopped moving.
List<TiqSkin> get torchSkins => <TiqSkin>[
  TiqSkin.night(density: TiqDensity.field),
  TiqSkin.day(),
  TiqSkin.veld(),
];

/// Pump [child] in [skin].
///
/// [claims] and the flags around them build a real [TorchScope] over the
/// component, because a Torchlight emitter that is not inside one renders
/// unlit — which is correct, and which would make every golden here a golden
/// of the denied state.
Future<void> pumpTorch(
  WidgetTester tester, {
  required TiqSkin skin,
  required Widget child,
  Size size = const Size(360, 720),
  double textScale = 1.0,
  List<TorchClaim> claims = const <TorchClaim>[],
  bool navRenders = false,
  bool tabbedRoute = false,
  bool beneathSheet = false,
  bool still = true,
  Locale locale = const Locale('en'),
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
        // The busy dots and the press scale are the only animated things in
        // this folder, and a repeating animation makes `pumpAndSettle` hang
        // forever. Every golden asserts the resting frame, which is also the
        // frame a reduce-motion reader meets.
        disableAnimations: still,
      ),
      child: Localizations(
        locale: locale,
        delegates: const <LocalizationsDelegate<dynamic>>[
          DefaultWidgetsLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
        ],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Theme(
            data: ThemeData(extensions: <ThemeExtension<dynamic>>[skin]),
            child: MotionBudgetScope(
              budget: still ? MotionBudget.frozen : MotionBudget.moving,
              child: RepaintBoundary(
                key: torchBoundaryKey,
                child: ColoredBox(
                  color: skin.palette.ground,
                  child: SizedBox.fromSize(
                    size: size,
                    child: TorchScope(
                      skin: skin,
                      phase: 'golden',
                      navRenders: navRenders,
                      tabbedRoute: tabbedRoute,
                      beneathSheet: beneathSheet,
                      claims: claims,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The frame's pixels, addressable by logical coordinate.
class TorchPixels {
  TorchPixels(this._rgba, {required this.width, required this.height});

  final Uint8List _rgba;
  final int width;
  final int height;

  /// [x] and [y] are logical coordinates and the pixel they land in is the one
  /// that CONTAINS them — `floor`, not `round`. A border occupying `[20, 22)`
  /// is sampled at 20.5, and rounding would have read 21 on a 1px border and
  /// the fill behind it.
  Color at(double x, double y) {
    final px = x.floor().clamp(0, width - 1);
    final py = y.floor().clamp(0, height - 1);
    final o = (py * width + px) * 4;
    return Color.fromARGB(_rgba[o + 3], _rgba[o], _rgba[o + 1], _rgba[o + 2]);
  }

  /// Whether any pixel on the horizontal run is [colour].
  bool rowHas(Color colour, double y, {double from = 0, double? to}) {
    final end = (to ?? width - 1).round();
    for (var x = from.round(); x <= end; x++) {
      if (at(x.toDouble(), y) == colour) return true;
    }
    return false;
  }
}

/// Read back the last pumped frame.
Future<TorchPixels> torchPixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(torchBoundaryKey),
  );
  // `toImage` hands the layer tree to the rasteriser, which lives outside the
  // test binding's fake clock; awaiting it on the fake clock deadlocks.
  final pixels = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = image.width;
    final h = image.height;
    image.dispose();
    if (data == null) throw StateError('The boundary produced no pixels.');
    return TorchPixels(data.buffer.asUint8List(), width: w, height: h);
  });
  if (pixels == null) throw StateError('The pixel read did not run.');
  return pixels;
}

/// The centre of a widget, in logical pixels.
Offset centreOf(WidgetTester tester, Finder finder) =>
    tester.getRect(finder).center;

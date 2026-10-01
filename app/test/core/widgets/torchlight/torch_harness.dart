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
/// then Day — after Night and Day have stopped moving.
List<TiqSkin> get torchSkins => <TiqSkin>[
  TiqSkin.night(density: TiqDensity.field),
  TiqSkin.day(),
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
/// A matcher for a pixel on a lit amber object's own fill ramp.
///
/// IT USED TO BE `equals(skin.palette.flame600)` AT EVERY CALL SITE, and that
/// stopped being expressible on 1 October 2026, when a filled amber object
/// became a gradient from a hot stop to `flame600` rather than a flat swatch of
/// one colour. (The owner: *"the send button on the app and everywhere else for
/// orange is very dull, it need to be lumunous and bright and inviting"*, and
/// `flame600` was already at value 1.00 — see `TiqSkin.amberFillRamp`.) A
/// sampled pixel on a lit nav tab or a granted nav circle now lands *somewhere*
/// on that ramp, and which point depends on where in the object it was sampled.
///
/// What the old assertion was actually guarding is unchanged and is what this
/// guards: that the object is carrying the route's grant and is amber. An
/// *unlit* one samples `lifted`, `well` or Abyssal, none of which is anywhere
/// near this ramp, so the test still fails for the reason it was written for —
/// and it now additionally fails if the gradient silently stops painting, which
/// the exact-equality form could not catch.
///
/// It is deliberately a range over the ramp's own two stops and not a loose
/// "is it orange": the bound is the object's declared ramp, so a pixel from a
/// *different* amber — a flame-500 pressed fill, say — is still a failure.
///
/// The comparison is on 8-bit channels with one level of tolerance, which is
/// not slack — it is the arithmetic. A rasterised pixel comes back as exact
/// eighths-of-a-thousand floats (`n / 255`), a `Color.lerp` of two such colours
/// does not, and the shader quantises once more on its way to the framebuffer.
/// Exact equality between the two would fail on every stop but the endpoints.
Matcher isOnAmberRamp(TiqSkin skin) {
  final ramp = skin.amberFillRamp;
  int r(Color c) => (c.r * 255).round();
  int g(Color c) => (c.g * 255).round();
  int b(Color c) => (c.b * 255).round();
  final hot = ramp.first;
  final cold = ramp.last;

  return predicate<Color>((c) {
    if (c.a != 1.0) return false;
    // Every stop on this ramp holds red at FF, so red cannot locate `t` — the
    // green channel has the longest run and is used instead. If a future ramp
    // moves red, this needs the channel with the widest span rather than a
    // hardcoded one, and the assertion below would catch the mistake.
    final span = g(cold) - g(hot);
    if (span == 0) return false;
    final t = (g(c) - g(hot)) / span;
    if (t < -0.01 || t > 1.01) return false;
    final want = Color.lerp(hot, cold, t.clamp(0.0, 1.0))!;
    return (r(c) - r(want)).abs() <= 1 &&
        (g(c) - g(want)).abs() <= 1 &&
        (b(c) - b(want)).abs() <= 1;
  }, 'a stop on ${skin.mode.name}\'s amber fill ramp (${ramp.first} → ${ramp.last})');
}

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

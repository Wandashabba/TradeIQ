import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';

/// THE AMBER GOLDEN HARNESS.
///
/// [TorchScope] asserts that a route does not *claim* more amber than it may.
/// This counts what actually got *painted*. The two are different failures:
/// a widget can light itself without asking, a decoration can bloom where
/// nobody declared an object, and a shim can hand an old screen a flame token
/// through a mapping table. None of those go through the allocator, and all
/// three have happened in this codebase.
///
/// The method is deliberately dumb, because a dumb check survives a refactor:
/// render the route, walk every pixel, decide whether it is flame-hued, find
/// the connected regions of the ones that are, and count them. If the count is
/// over the skin's budget, fail and print where the regions were.
///
/// ```dart
/// await pumpAmberRoute(tester, skin: TiqSkin.night(), child: DashboardFixture());
/// final census = await amberCensus(tester);
/// expectWithinAmberBudget(census, TiqSkin.night(), route: 'dashboard', phase: 'loaded');
/// ```
///
/// ## What counts as flame-hued
///
/// Hue in **20°–48°**, value ≥ **0.90**, saturation ≥ **0.12**. Those three
/// numbers are not a guess; they are the smallest box that contains every
/// amber the system may paint and excludes every warm neutral it may paint
/// beside it:
///
/// | token | hue | sat | value | counted |
/// |---|---|---|---|---|
/// | `flame500` | 28.2° | 0.73 | 0.97 | yes |
/// | `flame600` | 30.2° | 0.62 | 1.00 | yes |
/// | `flame700` | 30.8° | 0.42 | 1.00 | yes |
/// | `flame900` (bloom core) | 34.5° | 0.13 | 1.00 | yes |
/// | `ink1` Palladian | 40.0° | 0.06 | 0.93 | no |
/// | `ink2` Oatmeal | 40.0° | 0.12 | 0.79 | no |
/// | `chartNeutral` | 39.2° | 0.19 | 0.55 | no |
/// | `comparison` Truffle | 15.7° | 0.50 | 0.88 | no |
/// | `flame300` (amber *text* on a light ground) | 28.0° | 0.87 | 0.54 | no |
///
/// The value floor is what makes this a census of *emitted* light. `flame300`
/// is amber but it is ink, and the faint tail of a bloom composited at 30%
/// over the Night ground lands at value 0.33 — neither is a lit object, and
/// counting a halo as a second light is how a budget check gets switched off
/// for being noisy.
///
/// Oatmeal sitting one hundredth of a saturation point outside the box is not
/// a coincidence. Burning Flame and Oatmeal have identical relative luminance;
/// they are genuinely hard to tell apart, which is the whole reason
/// `chartNeutral` exists. If a palette change ever moves Oatmeal into the box,
/// this harness starts counting text as light and
/// `amber_golden_test.dart`'s token-classification test fails first and says
/// so.
class AmberRegion {
  AmberRegion({required this.bounds, required this.area});

  /// In logical pixels, at the density the route was rendered at.
  final Rect bounds;

  /// How many pixels the region contains. A rim is a long thin region with a
  /// small area; a filled block is a fat one.
  final int area;

  @override
  String toString() =>
      '${area}px at ${bounds.left.toInt()},${bounds.top.toInt()} '
      '${bounds.width.toInt()}x${bounds.height.toInt()}';
}

/// What one render actually painted.
class AmberCensus {
  AmberCensus({
    required this.regions,
    required this.litPixels,
    required this.totalPixels,
  });

  /// The connected regions, largest first.
  final List<AmberRegion> regions;

  final int litPixels;
  final int totalPixels;

  int get objectCount => regions.length;

  /// What fraction of the frame is on fire. Not budgeted — reported, because a
  /// single region covering half the screen is a different bug from four small
  /// ones and the count alone cannot tell them apart.
  double get litFraction => totalPixels == 0 ? 0 : litPixels / totalPixels;

  String describe() {
    final buffer = StringBuffer()
      ..writeln(
        '$objectCount amber object(s), $litPixels lit pixels '
        '(${(litFraction * 100).toStringAsFixed(2)}% of the frame):',
      );
    for (final r in regions) {
      buffer.writeln('  $r');
    }
    return buffer.toString();
  }
}

/// Pump [child] as a route, in [skin], at a fixed size and density.
///
/// The size is pinned because a connected-components count is a function of
/// the layout: a nav pill that wraps at 320dp is two regions and at 360dp is
/// one. Density is pinned to 1.0 so a region's area is in logical pixels and
/// a failure message means something.
Future<void> pumpAmberRoute(
  WidgetTester tester, {
  required TiqSkin skin,
  required Widget child,
  Size size = const Size(360, 720),
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
            key: const ValueKey<String>('amber-golden-boundary'),
            child: ColoredBox(
              color: skin.palette.ground,
              child: SizedBox.fromSize(size: size, child: child),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Count the flame-hued regions in the last pumped frame.
///
/// [minimumArea] discards a region smaller than this. Three pixels of amber at
/// the corner of an anti-aliased rim is not an object, and a harness that
/// reported it as one would be turned off within a week.
Future<AmberCensus> amberCensus(
  WidgetTester tester, {
  int minimumArea = 12,
}) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey<String>('amber-golden-boundary')),
  );
  // `toImage` hands the layer tree to the rasteriser, which lives outside the
  // test binding's fake clock. Awaiting it on the fake clock deadlocks — the
  // test hangs with no output, which is how this was found. `runAsync` is the
  // same escape hatch `matchesGoldenFile` uses for the same reason.
  final census = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final width = image.width;
    final height = image.height;
    image.dispose();
    if (data == null) {
      throw StateError('The render boundary produced no pixels.');
    }
    return censusOfPixels(
      data.buffer.asUint8List(),
      width: width,
      height: height,
      minimumArea: minimumArea,
    );
  });
  if (census == null) {
    throw StateError('The amber census did not run.');
  }
  return census;
}

/// The pixel half of [amberCensus], split out so it can be tested against a
/// buffer built by hand — a harness whose own arithmetic is never checked is
/// a harness that reports whatever it feels like.
AmberCensus censusOfPixels(
  Uint8List rgba, {
  required int width,
  required int height,
  int minimumArea = 12,
}) {
  final total = width * height;
  final mask = List<bool>.filled(total, false);
  var lit = 0;
  for (var i = 0; i < total; i++) {
    final o = i * 4;
    if (isFlameHued(rgba[o], rgba[o + 1], rgba[o + 2])) {
      mask[i] = true;
      lit++;
    }
  }

  // Eight-connected flood fill. Eight and not four, because a 1px amber rim
  // drawn on a diagonal is one rim and a four-connected walk would report it
  // as a staircase of separate lights.
  final seen = List<bool>.filled(total, false);
  final regions = <AmberRegion>[];
  final queue = <int>[];
  for (var start = 0; start < total; start++) {
    if (!mask[start] || seen[start]) continue;
    queue
      ..clear()
      ..add(start);
    seen[start] = true;
    var area = 0;
    var minX = width, maxX = -1, minY = height, maxY = -1;
    while (queue.isNotEmpty) {
      final index = queue.removeLast();
      final x = index % width;
      final y = index ~/ width;
      area++;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = x + dx;
          final ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          final n = ny * width + nx;
          if (mask[n] && !seen[n]) {
            seen[n] = true;
            queue.add(n);
          }
        }
      }
    }
    if (area >= minimumArea) {
      regions.add(
        AmberRegion(
          bounds: Rect.fromLTRB(
            minX.toDouble(),
            minY.toDouble(),
            maxX + 1.0,
            maxY + 1.0,
          ),
          area: area,
        ),
      );
    }
  }
  regions.sort((a, b) => b.area.compareTo(a.area));

  // A LIT OBJECT IS NOT ENCLOSED BY ANOTHER LIT OBJECT.
  //
  // Dark ink on an amber block leaves amber showing through the counter of
  // every `o`, the inside of every outlined glyph, and the middle of the one
  // in "10". Each of those is a separate eight-connected region and none of
  // them is a separate light: they are the block, seen through its own label.
  // Without this step a nav tab whose slot says "Today" counts as four.
  //
  // The test is containment of the BOUNDS, which is deliberately strict:
  // two lights that merely overlap in their bounding boxes — a rim behind a
  // circle, say — still count as two, because neither box contains the other.
  final enclosed = <int>{};
  for (var i = 0; i < regions.length; i++) {
    for (var j = 0; j < i; j++) {
      if (enclosed.contains(j)) continue;
      if (regions[j].bounds.contains(regions[i].bounds.topLeft) &&
          regions[j].bounds.contains(
            regions[i].bounds.bottomRight - const Offset(1, 1),
          )) {
        enclosed.add(i);
        break;
      }
    }
  }
  if (enclosed.isNotEmpty) {
    for (final index in enclosed.toList()..sort((a, b) => b.compareTo(a))) {
      regions.removeAt(index);
    }
  }
  return AmberCensus(regions: regions, litPixels: lit, totalPixels: total);
}

/// Whether one pixel is emitted amber. See the table on [AmberRegion].
bool isFlameHued(int r, int g, int b) {
  final max = r > g ? (r > b ? r : b) : (g > b ? g : b);
  final min = r < g ? (r < b ? r : b) : (g < b ? g : b);
  final value = max / 255.0;
  if (value < 0.90) return false;
  if (max == 0) return false;
  final saturation = (max - min) / max;
  if (saturation < 0.12) return false;
  final delta = (max - min).toDouble();
  if (delta == 0) return false;
  double hue;
  if (max == r) {
    hue = 60 * (((g - b) / delta) % 6);
  } else if (max == g) {
    hue = 60 * ((b - r) / delta + 2);
  } else {
    hue = 60 * ((r - g) / delta + 4);
  }
  if (hue < 0) hue += 360;
  return hue >= 20 && hue <= 48;
}

/// Fail if the frame painted more lit objects than the skin allows.
void expectWithinAmberBudget(
  AmberCensus census,
  TiqSkin skin, {
  required String route,
  required String phase,
}) {
  final budget = TorchScope.budgetFor(skin);
  expect(
    census.objectCount,
    lessThanOrEqualTo(budget),
    reason:
        '$route [${skin.mode.name}/${skin.density.name}, $phase] painted '
        '${census.objectCount} amber objects against a budget of $budget.\n\n'
        '${census.describe()}\n'
        'Burning Flame is a light source, never a label. In Night the nav '
        'pill is object 1 whenever the nav renders; on a light ground there '
        'is exactly one amber block and it is the primary commit action. If '
        'an object here is not on the TorchScope ladder, it should not be '
        'amber at all — not a chip, flag, status, badge, tick, divider, '
        'gridline, axis, toggle, toast, skeleton, sparkline, delta, empty '
        'state, icon tint, section marker or word.',
  );
}

// THE COMPOSER AND THE PHONE'S BOTTOM EDGE.
//
// The owner reported on 2 October 2026 that on the light theme the composer sat
// "low and not aligned like the dark theme, it's touching the end of the phone
// at the bottom". It does not: the two skins are identical to the pixel, and
// `TorchShell` does reserve `MediaQuery.padding.bottom`.
//
// What was true is that NOTHING COULD EVER HAVE CAUGHT IT IF IT WERE WRONG.
// `pumpFloor` built its `MediaQueryData` with a size, a devicePixelRatio, a
// textScaler and `viewInsets` — and no `padding` at all. So `safeBottom` was 0
// in every Floor test and every committed render ever taken, and the gesture
// bar on a real handset was a case the suite could not express. That is the
// same shape as the status-bar inset defect of 29 September, which was invisible
// for the same reason: a browser and a golden both report a zero inset.
//
// So these are the two assertions that were missing, not a transcription of the
// bug report:
//
//   1. the reservation is REAL — a non-zero bottom inset moves the composer up
//      by exactly that much, and
//   2. the two skins are IDENTICAL — a complaint that one theme sits lower than
//      the other is answerable with a number rather than an opinion.
//
// `viewInsets` is the keyboard and is already covered elsewhere; `padding` is
// the gesture bar, and it is this file's subject.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/dashboard/presentation/the_floor_screen.dart';

import 'floor_harness.dart';

void main() {
  /// The composer's trough, measured from the bottom of the window.
  Future<double> gapBelowComposer(
    WidgetTester tester, {
    required TiqSkin skin,
    required Size size,
    required double inset,
    double textScale = 1.0,
  }) async {
    await pumpFloor(
      tester,
      const TheFloorScreen(),
      skin: skin,
      size: size,
      safeBottom: inset,
      textScale: textScale,
      current: kpis(),
    );
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    expect(
      field,
      findsWidgets,
      reason: 'The Floor lands on the composer; without it there is nothing '
          'for this file to measure.',
    );
    return size.height - tester.getRect(field.first).bottom;
  }

  const phone = Size(390, 844);

  testWidgets('a gesture bar moves the composer up by exactly its height', (
    tester,
  ) async {
    final without = await gapBelowComposer(
      tester,
      skin: TiqSkin.night(),
      size: phone,
      inset: 0,
    );
    final with48 = await gapBelowComposer(
      tester,
      skin: TiqSkin.night(),
      size: phone,
      inset: 48,
    );

    expect(
      with48 - without,
      48.0,
      reason:
          'TorchShell reserves MediaQuery.padding.bottom as a SizedBox after '
          'the band. If this is ever 0 the composer is sitting under the '
          "phone's gesture bar, and no golden will show it because a golden "
          'reports a zero inset.',
    );
  });

  testWidgets('the composer sits at the same height in both skins', (
    tester,
  ) async {
    for (final inset in <double>[0, 48]) {
      final night = await gapBelowComposer(
        tester,
        skin: TiqSkin.night(),
        size: phone,
        inset: inset,
      );
      final day = await gapBelowComposer(
        tester,
        skin: TiqSkin.day(),
        size: phone,
        inset: inset,
      );
      expect(
        day,
        night,
        reason:
            'Skins carry colour, never geometry. A report that one theme sits '
            'lower than the other is about paint — on 2 October it was Dawn '
            'warming the dark theme behind the composer and the light theme '
            'having nothing there yet.',
      );
    }
  });

  testWidgets('the gap does not collapse at a larger text scale', (
    tester,
  ) async {
    for (final scale in <double>[1.0, 1.3]) {
      final gap = await gapBelowComposer(
        tester,
        skin: TiqSkin.night(),
        size: phone,
        inset: 48,
        textScale: scale,
      );
      expect(
        gap,
        greaterThanOrEqualTo(48.0),
        reason:
            'Bigger type grows the band upward. If the gap ever falls below '
            'the inset, the trough has been pushed into the gesture bar at '
            '${scale}x.',
      );
    }
  });
}

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/camera/photo_exposure.dart';

/// WAS THE SHELF ACTUALLY LIT?
///
/// The measurement itself, against frames this file draws. Everything here
/// runs inside [WidgetTester.runAsync]: `ui.instantiateImageCodec` resolves on
/// the engine's own thread, which `FakeAsync`'s clock never reaches, so a test
/// that decoded an image on the fake timeline would hang with no output. That
/// is the same trap the drift-`watch()` note in the harness describes, in a
/// different costume, and it is why the capture route reads the exposure
/// through `photoExposureProvider` rather than calling this directly.

/// A solid 8×8 PNG. Small on purpose: [meanLuma] downsamples to 16×16 anyway,
/// and a fixture that is cheap to draw is a fixture nobody replaces with a
/// checked-in binary.
Future<Uint8List> _png(Color colour) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder, const Rect.fromLTWH(0, 0, 8, 8)).drawRect(
    const Rect.fromLTWH(0, 0, 8, 8),
    ui.Paint()..color = colour,
  );
  final image = await recorder.endRecording().toImage(8, 8);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

String _dataUrl(Uint8List bytes) =>
    'data:image/png;base64,${base64Encode(bytes)}';

void main() {
  testWidgets('a black frame measures near zero and reads as underexposed', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final luma = await meanLuma(await _png(const Color(0xFF000000)));
      expect(luma, isNotNull);
      expect(luma, lessThan(0.02));
      expect(isUnderexposed(luma), isTrue);
    });
  });

  testWidgets('a white frame measures near one and is not accused', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final luma = await meanLuma(await _png(const Color(0xFFFFFFFF)));
      expect(luma, greaterThan(0.98));
      expect(isUnderexposed(luma), isFalse);
    });
  });

  testWidgets('the threshold is the metered mid-grey, not a guess', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // 0x20 is 12.5% — a dark aisle. 0x40 is 25% — a dim one that is still
      // readable, and the app does not question it.
      expect(
        isUnderexposed(await meanLuma(await _png(const Color(0xFF202020)))),
        isTrue,
      );
      expect(
        isUnderexposed(await meanLuma(await _png(const Color(0xFF404040)))),
        isFalse,
      );
      expect(kDarkFrameLuma, 0.18);
    });
  });

  testWidgets('luma is weighted the way an eye is, not a channel average', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // Pure green reads far brighter than pure blue at the same numeric
      // value. A flat (r+g+b)/3 would call them identical and would call a
      // blue-lit fridge aisle perfectly exposed.
      final green = await meanLuma(await _png(const Color(0xFF00FF00)));
      final blue = await meanLuma(await _png(const Color(0xFF0000FF)));
      expect(green, greaterThan(0.5));
      expect(blue, lessThan(0.2));
    });
  });

  testWidgets('a frame nobody can decode measures null, and null is not dark', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final luma = await meanLuma(Uint8List.fromList(<int>[1, 2, 3, 4]));
      expect(luma, isNull);
      // The app does not accuse a capture it could not read.
      expect(isUnderexposed(luma), isFalse);
    });
  });

  testWidgets('it reads the data: URL Phase-1 photos actually travel as', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final url = _dataUrl(await _png(const Color(0xFF0A0A0A)));
      expect(isUnderexposed(await meanLumaOfDataUrl(url)), isTrue);
    });
  });

  testWidgets('anything that is not a base64 data: URL measures null', (
    tester,
  ) async {
    await tester.runAsync(() async {
      expect(await meanLumaOfDataUrl('https://example.test/shelf.jpg'), isNull);
      expect(await meanLumaOfDataUrl('data:image/png;base64'), isNull);
      expect(await meanLumaOfDataUrl('data:image/png;base64,not-base64!'),
          isNull);
    });
  });
}

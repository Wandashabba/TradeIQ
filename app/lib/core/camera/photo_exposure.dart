/// WAS THE SHELF ACTUALLY LIT?
///
/// An agent photographing a bay at the back of a spaza with the lights off
/// gets a frame nobody can read. The app has two dishonest answers available
/// to it and takes neither: silently keeping the photo (the evidence is
/// useless and nobody finds out until a manager opens it a week later), or
/// silently dropping it (the agent walks out of the shop believing they
/// captured something).
///
/// So the frame is *measured*, and the review step says what it found. A dark
/// photo is **never auto-rejected** — during Stage 6 load-shedding it may be
/// the only obtainable evidence — it is edged, questioned, and kept if the
/// agent says keep it.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mean luma below which a frame is called dark.
///
/// 18% is the mid-grey a camera meters to. A frame whose *average* is under it
/// is not a dark subject, it is an underexposed one.
const double kDarkFrameLuma = 0.18;

/// The mean luma of [bytes], 0..1, or null when the frame cannot be decoded.
///
/// Null is not "bright": a frame nobody can decode is a frame nobody can judge,
/// and the review step treats an unknown exposure as ordinary rather than
/// accusing the agent of a fault the app invented.
///
/// The image is decoded at **16×16**. A 12 MP shelf photo decoded full-size to
/// average its pixels is an out-of-memory on a 2 GB handset — the same reason
/// the review strip decodes at `cacheWidth`. Sixteen rows of sixteen is 256
/// samples, which is more than enough to separate a lit aisle from a black one
/// and costs nothing.
Future<double?> meanLuma(Uint8List bytes) async {
  ui.Image? image;
  try {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 16,
      targetHeight: 16,
    );
    final frame = await codec.getNextFrame();
    image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    final rgba = data.buffer.asUint8List();
    if (rgba.length < 4) return null;

    var sum = 0.0;
    var counted = 0;
    for (var i = 0; i + 3 < rgba.length; i += 4) {
      final alpha = rgba[i + 3];
      // A fully transparent pixel has no luminance to contribute; counting it
      // as black would call every photo with an alpha border dark.
      if (alpha == 0) continue;
      // Rec. 601 luma, which is what "how bright does this look" means to an
      // eye. sRGB values are left un-linearised on purpose: the threshold is
      // calibrated against the metered mid-grey, which is an encoded value.
      sum += (0.299 * rgba[i] + 0.587 * rgba[i + 1] + 0.114 * rgba[i + 2]) / 255;
      counted++;
    }
    if (counted == 0) return null;
    return sum / counted;
  } catch (error) {
    // A photo that will not decode is a *different* problem, reported by the
    // review step's own decode-failed state. Never a crash on the one screen
    // standing between an agent and their evidence.
    debugPrint('Exposure check could not decode the frame: $error');
    return null;
  } finally {
    image?.dispose();
  }
}

/// [meanLuma] for a `data:` URL, which is how Phase-1 photos travel (ADR 0007).
///
/// Anything that is not a base64 `data:` URL — or does not decode — returns
/// null, exactly as an undecodable frame does.
Future<double?> meanLumaOfDataUrl(String dataUrl) async {
  if (!dataUrl.startsWith('data:')) return null;
  final comma = dataUrl.indexOf(',');
  if (comma == -1) return null;
  Uint8List bytes;
  try {
    bytes = base64Decode(dataUrl.substring(comma + 1));
  } on FormatException {
    return null;
  }
  return meanLuma(bytes);
}

/// Whether a measured [luma] is dark enough to ask about.
///
/// An unmeasured frame (null) is **not** dark. The app does not accuse a
/// capture it could not read.
bool isUnderexposed(double? luma) => luma != null && luma < kDarkFrameLuma;

/// The seam the capture route reads the exposure through.
///
/// It exists for the same reason `ImagePickerGateway` does: the real
/// implementation decodes an image, and **decoding an image inside a widget
/// test does not complete on `FakeAsync`'s clock** — `pumpAndSettle` waits for
/// a Future the engine will resolve on a real thread, and the test hangs with
/// no output. `photo_exposure_test.dart` exercises the real measurement inside
/// `tester.runAsync`, where decoding works; the screen tests override this with
/// a scripted answer, which is also how they script a dark aisle without
/// shipping a photograph of one.
typedef PhotoExposureReader = Future<double?> Function(String dataUrl);

final photoExposureProvider = Provider<PhotoExposureReader>(
  (ref) => meanLumaOfDataUrl,
);

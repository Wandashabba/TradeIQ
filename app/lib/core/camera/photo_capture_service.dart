import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../location/photo_geotagger.dart';
import 'photo_exposure.dart';

/// Where a photo came from. Gallery is not a convenience — an agent standing in
/// a dark aisle with a cracked camera still has to be able to file evidence.
enum PhotoSource { camera, gallery }

/// A captured image, already encoded as the `data:` URL the backend stores
/// (ADR 0007 — base64 in Postgres until object storage lands, #65).
class CapturedPhoto {
  const CapturedPhoto({
    required this.dataUrl,
    required this.byteLength,
    required this.capturedAt,
    this.gpsTag = const <String, dynamic>{},
    this.meanLuma,
  });

  final String dataUrl;
  final int byteLength;

  /// How bright the frame turned out, 0..1, once something has measured it.
  ///
  /// Null means **nobody has looked**, not "bright": the service does not
  /// decode the image (a 12 MP decode on the capture path is an OOM on a 2 GB
  /// handset and the capture is not the moment to spend it), so the review
  /// step measures it with [meanLumaOfDataUrl] and hands the photo on with
  /// this filled in. An unmeasured photo is never called dark.
  final double? meanLuma;

  /// Whether the frame is dark enough for the review step to ask about.
  bool get isUnderexposed => meanLuma != null && meanLuma! < kDarkFrameLuma;

  /// The same photo with its exposure recorded.
  CapturedPhoto withMeanLuma(double? luma) => CapturedPhoto(
    dataUrl: dataUrl,
    byteLength: byteLength,
    capturedAt: capturedAt,
    gpsTag: gpsTag,
    meanLuma: luma,
  );

  /// The device clock when the picker handed the photo back. This, not the
  /// moment the section is saved or the outbox sends, is the photo's
  /// `timestamp` — `capture_timeline_gap` (#246) places the shot by it.
  final DateTime capturedAt;

  /// Where the device was when the photo was taken — `{lat, lng, accuracy?,
  /// fixedAt?}` — or empty when location was refused, unavailable or slow, or
  /// the capture did not ask for it (see [PhotoGeotagger]).
  final Map<String, dynamic> gpsTag;
}

/// Raised when an image survives downscaling and is still too big for
/// `POST /photos`, which rejects anything over 8 MB of base64.
class PhotoTooLargeException implements Exception {
  const PhotoTooLargeException(this.byteLength);

  final int byteLength;

  @override
  String toString() =>
      'Photo is ${(byteLength / (1024 * 1024)).toStringAsFixed(1)} MB after '
      'compression — the server accepts up to 8 MB.';
}

/// The seam over `image_picker`, so tests can capture without a camera.
abstract class ImagePickerGateway {
  Future<XFile?> pick({
    required ImageSource source,
    required double maxWidth,
    required int imageQuality,
  });
}

class ImagePickerGatewayImpl implements ImagePickerGateway {
  ImagePickerGatewayImpl({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<XFile?> pick({
    required ImageSource source,
    required double maxWidth,
    required int imageQuality,
  }) =>
      _picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        imageQuality: imageQuality,
      );
}

/// Captures a shelf/closure photo and encodes it for upload.
///
/// The photos this produces are the point of the whole pipeline: they are the
/// evidence behind a closed task, and they are the corpus the Phase-2 CV and
/// OCR models (#1, #2) will eventually be trained on. Until now the app
/// uploaded a 1×1 transparent placeholder, so nothing real was ever captured.
class PhotoCaptureService {
  PhotoCaptureService({
    required this.gateway,
    this.geotagger,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ImagePickerGateway gateway;

  /// Reads the device location for a geotagged capture. Null means no capture
  /// is ever geotagged.
  final PhotoGeotagger? geotagger;
  final DateTime Function() _clock;

  /// The server cap. Enforced here too, so a 12 MB photo fails on the device
  /// with a sentence a human can act on rather than as a 400 after the upload.
  static const int maxDataUrlBytes = 8 * 1024 * 1024;

  /// Downscale before encoding. A shelf photo does not need to be 4032px wide
  /// to show whether the planogram is right, and base64 inflates bytes by ~33%.
  static const double _maxWidth = 1600;
  static const int _quality = 80;

  /// Returns null when the agent backs out of the picker — a cancel is a
  /// normal outcome, not an error.
  ///
  /// [geotag] records where the device is as the photo comes back (#310). It
  /// is opt-in because only visit evidence (audit sections, and task closures
  /// since #317) needs a place: a message attachment has no business asking
  /// for the sender's location. The wait is bounded by the geotagger's
  /// timeout, and no fix still yields the photo, with an empty tag.
  Future<CapturedPhoto?> capture(
    PhotoSource source, {
    bool geotag = false,
  }) async {
    final file = await gateway.pick(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: _maxWidth,
      imageQuality: _quality,
    );
    if (file == null) return null;
    // Stamped before any location wait, so a slow fix cannot shift it.
    final capturedAt = _clock();

    final bytes = await file.readAsBytes();
    // Trust the picker when it reports a type; fall back to the extension only
    // when it doesn't (the web implementation often doesn't).
    final mime = file.mimeType ?? _mimeFor(file.name);
    final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';

    if (dataUrl.length > maxDataUrlBytes) {
      throw PhotoTooLargeException(dataUrl.length);
    }
    final tagger = geotagger;
    final gpsTag = geotag && tagger != null
        ? await tagger.tag()
        : const <String, dynamic>{};
    return CapturedPhoto(
      dataUrl: dataUrl,
      byteLength: dataUrl.length,
      capturedAt: capturedAt,
      gpsTag: gpsTag,
    );
  }

  static String _mimeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }
}

final photoCaptureServiceProvider = Provider<PhotoCaptureService>(
  (ref) => PhotoCaptureService(
    gateway: ImagePickerGatewayImpl(),
    geotagger: ref.read(photoGeotaggerProvider),
  ),
);

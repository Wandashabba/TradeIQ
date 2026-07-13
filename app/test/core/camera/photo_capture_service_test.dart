import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tradeiq_app/core/camera/photo_capture_service.dart';

class _FakeGateway implements ImagePickerGateway {
  _FakeGateway({this.file, this.throws = false});

  final XFile? file;
  final bool throws;

  ImageSource? requestedSource;
  double? requestedMaxWidth;
  int? requestedQuality;

  @override
  Future<XFile?> pick({
    required ImageSource source,
    required double maxWidth,
    required int imageQuality,
  }) async {
    if (throws) throw Exception('camera denied');
    requestedSource = source;
    requestedMaxWidth = maxWidth;
    requestedQuality = imageQuality;
    return file;
  }
}

/// On the VM, `XFile.fromData` derives `name` from `path` and ignores the `name`
/// argument — so the path has to be set for the extension to be visible, which
/// is also what the real (io) picker does.
XFile _xfile(Uint8List bytes, {String name = 'shelf.jpg', String? mimeType}) =>
    XFile.fromData(bytes, name: name, mimeType: mimeType, path: name);

void main() {
  test('encodes a captured image as a data URL', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final service = PhotoCaptureService(gateway: _FakeGateway(file: _xfile(bytes)));

    final photo = await service.capture(PhotoSource.camera);

    expect(photo, isNotNull);
    expect(photo!.dataUrl, 'data:image/jpeg;base64,${base64Encode(bytes)}');
  });

  test('a cancelled picker is a normal outcome, not an error', () async {
    final service = PhotoCaptureService(gateway: _FakeGateway());

    // Backing out of the camera must not look like a failure — the agent simply
    // did not take a photo.
    expect(await service.capture(PhotoSource.camera), isNull);
  });

  test('downscales before encoding, because base64 inflates by ~33%', () async {
    final gateway = _FakeGateway(file: _xfile(Uint8List.fromList([1])));
    final service = PhotoCaptureService(gateway: gateway);

    await service.capture(PhotoSource.camera);

    expect(gateway.requestedMaxWidth, 1600);
    expect(gateway.requestedQuality, 80);
  });

  test('maps the source through to image_picker', () async {
    final gateway = _FakeGateway(file: _xfile(Uint8List.fromList([1])));
    final service = PhotoCaptureService(gateway: gateway);

    await service.capture(PhotoSource.gallery);
    expect(gateway.requestedSource, ImageSource.gallery);

    await service.capture(PhotoSource.camera);
    expect(gateway.requestedSource, ImageSource.camera);
  });

  test('rejects a photo that is still over the 8MB server cap', () async {
    // The server rejects >8MB of base64 with a 400. Failing here instead means
    // the agent gets a sentence they can act on, not a failed upload.
    final huge = Uint8List(7 * 1024 * 1024); // ~9.3MB once base64-encoded
    final service = PhotoCaptureService(gateway: _FakeGateway(file: _xfile(huge)));

    expect(
      () => service.capture(PhotoSource.camera),
      throwsA(isA<PhotoTooLargeException>()),
    );
  });

  test('trusts the mime type the picker reports', () async {
    final service = PhotoCaptureService(
      gateway: _FakeGateway(
        file: _xfile(Uint8List.fromList([9]), mimeType: 'image/webp'),
      ),
    );

    final photo = await service.capture(PhotoSource.gallery);

    expect(photo!.dataUrl, startsWith('data:image/webp;base64,'));
  });

  test('falls back to the extension when the picker reports no type', () async {
    // image_picker_for_web frequently leaves mimeType null.
    final service = PhotoCaptureService(
      gateway: _FakeGateway(file: _xfile(Uint8List.fromList([9]), name: 'shelf.png')),
    );

    final photo = await service.capture(PhotoSource.gallery);

    expect(photo!.dataUrl, startsWith('data:image/png;base64,'));
  });

  test('a denied permission surfaces as a throw, not a silent null', () async {
    final service = PhotoCaptureService(gateway: _FakeGateway(throws: true));

    // A silent null would be indistinguishable from "user cancelled", and the
    // agent would never learn the camera permission is off.
    expect(() => service.capture(PhotoSource.camera), throwsException);
  });
}

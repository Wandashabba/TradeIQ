import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'file_download.dart';

/// The browser: a blob with the file's **real** media type, and an anchor
/// carrying the filename.
///
/// The media type matters even though the `download` attribute names the file:
/// a browser that opens the blob in a tab instead of saving it renders it as
/// whatever the blob says it is, and a CSV announced as a PDF is a blank
/// viewer. There is no path to report afterwards — the browser decides where
/// downloads live — so [SavedFile.location] is null and the words on screen say
/// "downloaded" rather than naming a folder that may not exist.
class WebFileDownloader implements FileDownloader {
  const WebFileDownloader();

  @override
  Future<SavedFile> save({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final blob = web.Blob(
      <JSUint8Array>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename
      ..style.display = 'none';
    web.document.body?.append(anchor);
    try {
      anchor.click();
    } finally {
      anchor.remove();
      // Revoking frees the blob; the click has already handed the bytes over.
      web.URL.revokeObjectURL(url);
    }
    return SavedFile(filename: filename);
  }
}

FileDownloader createFileDownloader() => const WebFileDownloader();

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'file_download_io.dart'
    if (dart.library.js_interop) 'file_download_web.dart';

/// Where a downloaded file ended up, in words a person can act on.
///
/// Never a raw path on the web, where there is no path to give: the browser
/// took the bytes and put them wherever it puts downloads, and saying
/// "/tmp/report.csv" there would be a sentence nobody could follow.
class SavedFile {
  const SavedFile({required this.filename, this.location});

  final String filename;

  /// The directory the file landed in, or null where the platform does not say.
  final String? location;
}

/// A file failed to save. Carries a sentence, not a stack.
class DownloadRefused implements Exception {
  const DownloadRefused(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Hands bytes the server produced to the platform that will keep them.
///
/// Behind a provider for the same reason `ArtifactExporter` is: writing a file
/// wants a real filesystem and the web branch wants a real DOM, so a widget
/// test that tapped Run would reach for two things a test binding does not
/// have. Tests swap in a recorder and assert what was asked for; production
/// gets a file.
abstract class FileDownloader {
  /// Save [bytes] as [filename]. [mimeType] is what the platform is told the
  /// file is — `text/csv`, never the default of some other library.
  Future<SavedFile> save({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  });
}

/// The platform's own downloader — a real file on a phone or a desktop, a
/// browser download on the web.
final fileDownloaderProvider = Provider<FileDownloader>(
  (ref) => createFileDownloader(),
);

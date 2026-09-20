import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'file_download.dart';

/// Phones, tablets and desktops: a real file, in a directory the person can
/// reach with a file manager.
///
/// `getDownloadsDirectory` is the right answer and only exists on desktop; on
/// Android and iOS the documents directory is the one the OS exposes to the
/// files app. A name that already exists is not overwritten — a manager who
/// runs the same report twice has two runs, not one.
class IoFileDownloader implements FileDownloader {
  const IoFileDownloader();

  @override
  Future<SavedFile> save({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    Directory directory;
    try {
      directory =
          (Platform.isMacOS || Platform.isWindows || Platform.isLinux
              ? await getDownloadsDirectory()
              : null) ??
          await getApplicationDocumentsDirectory();
    } on Object catch (e) {
      throw DownloadRefused('This device would not open a folder to save in. $e');
    }

    final unique = await _freeName(directory, filename);
    final file = File(p.join(directory.path, unique));
    try {
      await file.writeAsBytes(bytes, flush: true);
    } on FileSystemException catch (e) {
      throw DownloadRefused('The file could not be written. ${e.message}');
    }
    return SavedFile(filename: unique, location: directory.path);
  }

  /// `report.csv`, then `report (2).csv`, then `report (3).csv`.
  static Future<String> _freeName(Directory directory, String filename) async {
    final extension = p.extension(filename);
    final stem = p.basenameWithoutExtension(filename);
    var candidate = filename;
    var n = 1;
    while (await File(p.join(directory.path, candidate)).exists()) {
      n++;
      candidate = '$stem ($n)$extension';
    }
    return candidate;
  }
}

FileDownloader createFileDownloader() => const IoFileDownloader();

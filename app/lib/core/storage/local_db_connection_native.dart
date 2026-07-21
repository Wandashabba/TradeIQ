import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'db_key.dart';

/// Opens the local database encrypted with SQLCipher.
///
/// The build links SQLCipher in place of stock SQLite (see the `hooks:` block
/// in pubspec.yaml). That on its own encrypts nothing — SQLCipher reads and
/// writes plaintext databases exactly like SQLite until a key is set — so the
/// `PRAGMA key` below is what actually does the work, and the
/// `PRAGMA cipher_version` check is what proves it.
QueryExecutor openDbConnection({DbKeyStore? keyStore}) {
  final keys = keyStore ?? SecureDbKeyStore();

  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'tradeiq_local.sqlite'));
    final keyHex = await keys.keyHex();

    if (await file.exists() && await _isPlaintext(file)) {
      await _encryptInPlace(file, keyHex);
    }

    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        // Must be the first statement on the connection: SQLCipher decides how
        // to read the file on the strength of it.
        db.execute('PRAGMA key = "x\'$keyHex\'";');

        // Stock SQLite answers this with nothing. If the build ever links the
        // wrong library, every "encrypted" database would be written in
        // plaintext and nothing would look wrong — the failure mode this
        // whole change exists to prevent, arriving silently. Refuse to open
        // instead.
        final version = db.select('PRAGMA cipher_version;');
        if (version.isEmpty || '${version.first.values.first}'.isEmpty) {
          throw StateError(
            'SQLCipher is not the linked SQLite build: the local database '
            'would be stored unencrypted. Check the sqlite3 hooks user_define '
            'in pubspec.yaml.',
          );
        }
      },
    );
  });
}

/// Reads the file header to decide whether this database predates encryption.
Future<bool> _isPlaintext(File file) async {
  final handle = await file.open();
  try {
    return looksLikePlaintextSqlite(await handle.read(16));
  } finally {
    await handle.close();
  }
}

/// Copies a plaintext database into an encrypted one and swaps it in.
///
/// Migrating rather than deleting: an agent may be holding captures that have
/// never reached the server, and a device that encrypts itself by discarding
/// their afternoon is not an improvement. Same reasoning as logout keeping
/// unsynced rows.
///
/// Deliberately throws on failure rather than falling back to a fresh database.
/// A wipe-on-failure path would turn one bad migration into silent data loss
/// that nobody is told about; failing loudly keeps the plaintext file intact
/// and recoverable.
Future<void> _encryptInPlace(File file, String keyHex) async {
  final encrypted = File('${file.path}.encrypting');
  if (await encrypted.exists()) await encrypted.delete();

  final db = sqlite3.open(file.path);
  try {
    // sqlcipher_export copies schema and rows but NOT user_version — which is
    // where drift records its schema version. Losing it would send drift back
    // to migrating from version 0 over tables that already exist.
    final schemaVersion = db.select('PRAGMA user_version;').first.values.first;

    db.execute(
      'ATTACH DATABASE \'${encrypted.path}\' AS encrypted KEY "x\'$keyHex\'";',
    );
    db.execute("SELECT sqlcipher_export('encrypted');");
    db.execute('PRAGMA encrypted.user_version = $schemaVersion;');
    db.execute('DETACH DATABASE encrypted;');
  } catch (_) {
    // Leave the plaintext original exactly as it was.
    if (await encrypted.exists()) await encrypted.delete();
    rethrow;
  } finally {
    db.close();
  }

  // Only now is the encrypted copy known-good. The rename is the commit point:
  // until it happens the original is still the live database.
  await file.delete();
  await encrypted.rename(file.path);
}

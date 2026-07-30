import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'secure_storage.dart';

/// Supplies the 256-bit key the local database is encrypted with.
///
/// The key lives in the platform keychain/keystore — hardware-backed where the
/// device offers it — and never in the database, the app bundle, or anything
/// that travels with a backup. Encrypting a file with a key stored beside it
/// is obfuscation wearing encryption's clothes.
abstract class DbKeyStore {
  /// The existing key, or a freshly generated one persisted on first call.
  ///
  /// Lowercase hex, because that is what SQLCipher's `PRAGMA key = "x'...'"`
  /// form expects. Passing a passphrase instead would make SQLCipher derive a
  /// key by PBKDF2 — slower, and pointless for a value that is already random.
  Future<String> keyHex();
}

class SecureDbKeyStore implements DbKeyStore {
  SecureDbKeyStore({FlutterSecureStorage? storage, Random? random})
      : _storage = storage ?? appSecureStorage,
        _random = random ?? Random.secure();

  final FlutterSecureStorage _storage;
  final Random _random;

  static const _keyName = 'local_db_key';

  /// 32 bytes = 256 bits, matching SQLCipher's default cipher.
  static const _keyBytes = 32;

  @override
  Future<String> keyHex() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null && existing.length == _keyBytes * 2) return existing;

    final bytes = List<int>.generate(_keyBytes, (_) => _random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: _keyName, value: hex);
    return hex;
  }
}

/// A fixed key, for tests.
class FixedDbKeyStore implements DbKeyStore {
  FixedDbKeyStore(this._hex);
  final String _hex;

  @override
  Future<String> keyHex() async => _hex;
}

/// The 16 bytes every unencrypted SQLite file begins with: "SQLite format 3"
/// followed by a NUL.
final _sqliteMagic = <int>[...utf8.encode('SQLite format 3'), 0];

/// Whether [header] is the start of an *unencrypted* SQLite file.
///
/// SQLCipher encrypts the header too, so an encrypted database's first bytes
/// are indistinguishable from random. That difference is how the app tells
/// "this install predates encryption and its data needs migrating" from "this
/// is already encrypted" — without a side flag it would have to trust, and
/// without attempting an open that fails uninformatively either way.
bool looksLikePlaintextSqlite(List<int> header) {
  if (header.length < _sqliteMagic.length) return false;
  for (var i = 0; i < _sqliteMagic.length; i++) {
    if (header[i] != _sqliteMagic[i]) return false;
  }
  return true;
}

final dbKeyStoreProvider = Provider<DbKeyStore>((ref) => SecureDbKeyStore());

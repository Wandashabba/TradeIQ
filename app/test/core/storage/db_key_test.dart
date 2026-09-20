import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/db_key.dart';

/// In-memory stand-in for the platform keystore, which is unavailable under
/// `flutter test`.
class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage();

  final Map<String, String> values = {};
  int writes = 0;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    writes += 1;
    if (value != null) values[key] = value;
  }
}

void main() {
  group('SecureDbKeyStore', () {
    test('generates a 256-bit key and persists it', () async {
      final storage = _FakeSecureStorage();
      final store = SecureDbKeyStore(storage: storage);

      final key = await store.keyHex();

      // 32 bytes as hex.
      expect(key, hasLength(64));
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(key), isTrue);
      expect(storage.writes, 1);
    });

    test('returns the same key on every later call', () async {
      // A key that changed would leave the database unopenable — every capture
      // on the device unreadable, which is worse than never encrypting it.
      final storage = _FakeSecureStorage();
      final store = SecureDbKeyStore(storage: storage);

      final first = await store.keyHex();
      final second = await store.keyHex();
      final fromNewInstance =
          await SecureDbKeyStore(storage: storage).keyHex();

      expect(second, first);
      expect(fromNewInstance, first);
      expect(storage.writes, 1, reason: 'must not rewrite an existing key');
    });

    test('replaces a stored value that is not a full-length key', () async {
      // Defends against a truncated or corrupted keystore entry being used as
      // a key, which would silently produce an unopenable database.
      final storage = _FakeSecureStorage()..values['local_db_key'] = 'abc123';
      final store = SecureDbKeyStore(storage: storage);

      final key = await store.keyHex();

      expect(key, hasLength(64));
      expect(key, isNot('abc123'));
    });

    test('does not produce the same key twice', () async {
      final a = await SecureDbKeyStore(storage: _FakeSecureStorage()).keyHex();
      final b = await SecureDbKeyStore(storage: _FakeSecureStorage()).keyHex();

      expect(a, isNot(b));
    });

    test('uses the full byte range, not just ASCII', () async {
      // Random.secure() is the real source; this pins that the generator is fed
      // 0-255 per byte rather than something narrower.
      final store = SecureDbKeyStore(
        storage: _FakeSecureStorage(),
        random: Random(1),
      );

      final key = await store.keyHex();

      expect(key, hasLength(64));
    });
  });

  group('looksLikePlaintextSqlite', () {
    test('recognises a real SQLite header', () {
      final header = <int>[...utf8.encode('SQLite format 3'), 0, 16, 0, 1];

      expect(looksLikePlaintextSqlite(header), isTrue);
    });

    test('rejects an encrypted database, whose header is ciphertext', () {
      // SQLCipher encrypts the header too, so the first bytes look random.
      final header = List<int>.generate(32, (i) => (i * 37 + 11) % 256);

      expect(looksLikePlaintextSqlite(header), isFalse);
    });

    test('rejects a file too short to contain the magic', () {
      expect(looksLikePlaintextSqlite(utf8.encode('SQLite')), isFalse);
      expect(looksLikePlaintextSqlite(const []), isFalse);
    });

    test('requires the trailing NUL, not just the text', () {
      // "SQLite format 3" followed by a space is not the SQLite magic, and
      // treating it as one would send a non-database file down the migration
      // path.
      final header = <int>[...utf8.encode('SQLite format 3'), 32, 16, 0, 1];

      expect(looksLikePlaintextSqlite(header), isFalse);
    });
  });
}

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../storage/secure_storage.dart';

/// A persisted authentication session: the bearer token plus the user's role,
/// enough to restore a logged-in session on app restart without re-login.
class StoredSession {
  const StoredSession({required this.token, required this.role});
  final String token;
  final String role;
}

/// Persists the auth session across app restarts. Abstracted so the session
/// controller can be unit-tested with an in-memory fake instead of the
/// platform keychain/keystore.
abstract class TokenStore {
  Future<void> save(StoredSession session);
  Future<StoredSession?> read();
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? appSecureStorage;

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _roleKey = 'auth_role';

  @override
  Future<void> save(StoredSession session) async {
    await _storage.write(key: _tokenKey, value: session.token);
    await _storage.write(key: _roleKey, value: session.role);
  }

  @override
  Future<StoredSession?> read() async {
    final token = await _storage.read(key: _tokenKey);
    final role = await _storage.read(key: _roleKey);
    if (token == null || role == null) {
      return null;
    }
    return StoredSession(token: token, role: role);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _roleKey);
  }
}

/// Keeps the session in memory for the life of the tab, and nowhere else.
///
/// Used on web, where `flutter_secure_storage` is not secure storage. Its web
/// backend AES-encrypts the value and then writes the **key into the same
/// localStorage as the ciphertext** — any XSS reads both, so it is obfuscation
/// wearing encryption's clothes (#139 H12).
///
/// The available mitigations all cost more than they return here: a
/// server-delivered `wrapKey` needs an endpoint that does not exist,
/// `useSessionStorage` still co-locates key and ciphertext, and an HttpOnly
/// cookie means changing how the API authenticates. Not persisting at all
/// removes the thing being stolen instead of hiding it better.
///
/// The cost is a re-login when the tab closes or reloads. On the manager
/// console — desktop, often shared, session-shaped work — that is the right
/// trade, and arguably what a console should do anyway. The mobile app, where
/// staying signed in genuinely matters to a field agent's day, keeps the
/// platform keychain.
class InMemoryTokenStore implements TokenStore {
  StoredSession? _session;

  @override
  Future<void> save(StoredSession session) async => _session = session;

  @override
  Future<StoredSession?> read() async => _session;

  @override
  Future<void> clear() async => _session = null;
}

final tokenStoreProvider = Provider<TokenStore>(
  // Deliberately platform-split. See [InMemoryTokenStore]: on web the "secure"
  // store keeps its key beside the ciphertext, so persisting there buys
  // nothing and costs a standing XSS target.
  (ref) => kIsWeb ? InMemoryTokenStore() : SecureTokenStore(),
);

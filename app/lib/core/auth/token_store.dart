import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
      : _storage = storage ?? FlutterSecureStorage();

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

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

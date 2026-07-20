import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import 'auth_repository.dart';
import 'jwt.dart';
import 'token_store.dart';

class SessionState {
  const SessionState({this.role, this.token});
  final String? role;
  final String? token;
}

class SessionController extends AsyncNotifier<SessionState> {
  @override
  Future<SessionState> build() async {
    // Restore a persisted session (if any) so an app restart doesn't force a
    // re-login. Persistence is best-effort: if secure storage is unavailable
    // (e.g. no platform binding under unit tests, or a read failure), fall
    // back to a logged-out session rather than bricking startup.
    // A 401 on any authenticated request means this session is over. The router
    // already sends an empty session to /login, so signing out is the whole
    // fix — nothing here needs to know about navigation.
    onUnauthorized = () {
      if (state.value?.role != null) logout();
    };

    try {
      final stored = await ref.read(tokenStoreProvider).read();
      if (stored != null) {
        // A stored token outlives nothing: the backend issues a 12h JWT and has
        // no refresh endpoint, so a token saved yesterday restores a session
        // that is already dead. Restoring it produces a logged-in shell where
        // every screen errors; refusing it produces a login prompt, which is
        // the truth and is actionable.
        if (isExpired(stored.token)) {
          try {
            await ref.read(tokenStoreProvider).clear();
          } catch (_) {
            // ignore — it will be overwritten on the next login
          }
          return const SessionState();
        }
        currentAuthToken = stored.token;
        return SessionState(role: stored.role, token: stored.token);
      }
    } catch (_) {
      // fall through to the empty session below
    }
    return const SessionState();
  }

  /// Signs in. When [rememberMe] is false the session lives in memory only and
  /// is gone when the app closes — which is what someone borrowing a colleague's
  /// phone is asking for when they untick the box.
  Future<void> login(
    String email,
    String password, {
    bool rememberMe = true,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.login(email, password);
      currentAuthToken = result.token;
      if (rememberMe) {
        // Best-effort persist: a storage failure must not fail an otherwise
        // successful login.
        try {
          await ref.read(tokenStoreProvider).save(
                StoredSession(token: result.token, role: result.role),
              );
        } catch (_) {
          // ignore — the in-memory session is still valid for this run
        }
      } else {
        // Clear any token a previous "remember me" login left behind, or
        // unticking the box would leave the old session persisted and the
        // control would still be lying.
        try {
          await ref.read(tokenStoreProvider).clear();
        } catch (_) {
          // ignore
        }
      }
      return SessionState(role: result.role, token: result.token);
    });
  }

  Future<void> logout() async {
    currentAuthToken = null;
    // Clear in-memory state first so the UI/router react immediately; the
    // persisted copy is cleared best-effort afterwards.
    state = const AsyncData(SessionState());
    try {
      await ref.read(tokenStoreProvider).clear();
    } catch (_) {
      // ignore — worst case the stale token is overwritten on next login
    }
  }
}

final sessionControllerProvider = AsyncNotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

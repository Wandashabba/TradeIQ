import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import 'auth_repository.dart';
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
    try {
      final stored = await ref.read(tokenStoreProvider).read();
      if (stored != null) {
        currentAuthToken = stored.token;
        return SessionState(role: stored.role, token: stored.token);
      }
    } catch (_) {
      // fall through to the empty session below
    }
    return const SessionState();
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.login(email, password);
      currentAuthToken = result.token;
      // Best-effort persist: a storage failure must not fail an otherwise
      // successful login.
      try {
        await ref.read(tokenStoreProvider).save(
              StoredSession(token: result.token, role: result.role),
            );
      } catch (_) {
        // ignore — the in-memory session is still valid for this run
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

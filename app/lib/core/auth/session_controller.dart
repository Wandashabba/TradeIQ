import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drift/drift.dart';

import '../network/api_client.dart';
import '../storage/local_db.dart';
import 'auth_repository.dart';
import 'jwt.dart';
import 'session_ended.dart';
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
    //
    // It does need to know what is still on the phone. A session that ends
    // under an agent holding six captured sections is a **state**, not an
    // error (#380/#392), and the sentence that makes it one — "everything you
    // captured is still here" — has to be counted before the sign-out clears
    // the owner the outbox is keyed by.
    onUnauthorized = () {
      if (state.value?.role != null) logout(expired: true);
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
        currentLocalUserId = jwtUserId(stored.token);
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
      // Everything queued from here belongs to this user, and only they can
      // flush it. Set before any capture is possible, not after.
      currentLocalUserId = jwtUserId(result.token);
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
      // Signed in again: whatever the last ending held is now the sync
      // service's problem, not a line under a form nobody is looking at.
      ref.read(sessionEndedProvider.notifier).clear();
      return SessionState(role: result.role, token: result.token);
    });
  }

  /// Signs out.
  ///
  /// [expired] marks the one ending the person did not ask for: a 401 on an
  /// authenticated request. It is the difference between "I am done" and "the
  /// clock ran out under me", and only the second one owes the person a count
  /// of what is still held on their phone.
  Future<void> logout({bool expired = false}) async {
    final departing = currentLocalUserId;
    if (expired) {
      // Before the owner is cleared — the outbox query is scoped by it.
      // Best-effort: a database that will not answer must never strand
      // somebody in a half-signed-out state.
      try {
        final held = await countHeldWork(ref.read(localDbProvider), departing);
        ref.read(sessionEndedProvider.notifier).record(held);
      } catch (_) {
        // ignore — no proof block, and the plain sign-in screen instead
      }
    } else {
      // A deliberate sign-out answers its own question: nothing is owed and a
      // held line left over from a previous ending would be a lie.
      ref.read(sessionEndedProvider.notifier).clear();
    }
    currentAuthToken = null;
    currentLocalUserId = null;
    // Clear in-memory state first so the UI/router react immediately; the
    // persisted copy is cleared best-effort afterwards.
    state = const AsyncData(SessionState());
    try {
      await ref.read(tokenStoreProvider).clear();
    } catch (_) {
      // ignore — worst case the stale token is overwritten on next login
    }
    await _dropSyncedRows(departing);
  }

  /// Deletes this user's already-sent outbox rows on the way out.
  ///
  /// Only the sent ones. Wiping the whole queue would be the stronger privacy
  /// story and the wrong call: an agent who audits a store with no signal and
  /// then logs out would lose the visit outright, and the offline-first design
  /// promises the opposite. Unsent rows stay, and the userId column means no
  /// one else can see or flush them — the leak is closed by ownership, not by
  /// destroying an agent's afternoon.
  ///
  /// Best-effort throughout: a failure here must never strand someone in a
  /// half-logged-out state.
  Future<void> _dropSyncedRows(String? userId) async {
    if (userId == null) return;
    try {
      final db = ref.read(localDbProvider);
      await (db.delete(db.syncQueueItems)
            ..where((t) => t.synced.equals(true) & t.userId.equals(userId)))
          .go();
    } catch (_) {
      // ignore — these rows are already on the server; they are litter, not data
    }
  }
}

final sessionControllerProvider = AsyncNotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

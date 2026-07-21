import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/auth_repository.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/auth/token_store.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthResult> login(String email, String password) async {
    return const AuthResult(token: 'fake-token', role: 'manager');
  }
}

class FailingAuthRepository implements AuthRepository {
  @override
  Future<AuthResult> login(String email, String password) async {
    throw Exception('invalid credentials');
  }
}

class FakeTokenStore implements TokenStore {
  FakeTokenStore([this._stored]);
  StoredSession? _stored;

  @override
  Future<void> save(StoredSession session) async => _stored = session;

  @override
  Future<StoredSession?> read() async => _stored;

  @override
  Future<void> clear() async => _stored = null;
}

void main() {
  test(
    'login success updates the session state with the returned role',
    () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(sessionControllerProvider.notifier);
      await controller.login('agent@tradeiq.com', 'password123');

      final state = container.read(sessionControllerProvider);
      expect(state.value?.role, 'manager');
    },
  );

  test('login failure surfaces as AsyncError instead of throwing', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FailingAuthRepository()),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(sessionControllerProvider.notifier);
    await controller.login('agent@tradeiq.com', 'wrong-password');

    final state = container.read(sessionControllerProvider);
    expect(state, isA<AsyncError<SessionState>>());
  });

  test('logout clears the session back to an empty state', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(sessionControllerProvider.notifier);
    await controller.login('agent@tradeiq.com', 'password123');
    expect(container.read(sessionControllerProvider).value?.role, 'manager');

    await controller.logout();

    final state = container.read(sessionControllerProvider);
    expect(state.value?.role, isNull);
    expect(state.value?.token, isNull);
  });

  test('login persists the session to the token store', () async {
    final store = FakeTokenStore();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(sessionControllerProvider.notifier)
        .login('agent@tradeiq.com', 'password123');

    final saved = await store.read();
    expect(saved?.token, 'fake-token');
    expect(saved?.role, 'manager');
  });

  test('build() restores a persisted session on startup', () async {
    final store = FakeTokenStore(
      const StoredSession(token: 'persisted-token', role: 'field_agent'),
    );
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(sessionControllerProvider.future);

    expect(state.role, 'field_agent');
    expect(state.token, 'persisted-token');
  });

  test('logout clears the persisted session', () async {
    final store = FakeTokenStore(
      const StoredSession(token: 'persisted-token', role: 'manager'),
    );
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sessionControllerProvider.future);
    await container.read(sessionControllerProvider.notifier).logout();

    expect(await store.read(), isNull);
  });

  test('an expired stored token does not restore a session', () async {
    // The backend issues a 12h JWT and has no refresh endpoint, so this is
    // every user every day, not an edge case. Restoring it would produce a
    // logged-in shell where every screen errors and nothing offers a way out.
    final store = FakeTokenStore(
      StoredSession(token: _jwtExpiringAt(_hoursFromNow(-1)), role: 'manager'),
    );
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    final session = await container.read(sessionControllerProvider.future);

    expect(session.role, isNull);
    expect(session.token, isNull);
    // And the dead token is cleared rather than left to be retried forever.
    expect(await store.read(), isNull);
  });

  test('a stored token still in date restores normally', () async {
    final token = _jwtExpiringAt(_hoursFromNow(6));
    final store = FakeTokenStore(StoredSession(token: token, role: 'manager'));
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    final session = await container.read(sessionControllerProvider.future);

    expect(session.role, 'manager');
    expect(session.token, token);
  });

  test('login without rememberMe keeps the session out of storage', () async {
    final store = FakeTokenStore();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sessionControllerProvider.future);
    await container
        .read(sessionControllerProvider.notifier)
        .login('a@b.com', 'pw', rememberMe: false);

    // Signed in for this run...
    expect(container.read(sessionControllerProvider).value?.role, 'manager');
    // ...but nothing survives the app closing, which is what unticking asks for.
    expect(await store.read(), isNull);
  });

  test(
    'login without rememberMe clears a previously persisted session',
    () async {
      // Otherwise unticking the box on a shared phone leaves the last user's
      // token on disk and the control is still lying.
      final store = FakeTokenStore(
        const StoredSession(token: 'older-token', role: 'field_agent'),
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          tokenStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sessionControllerProvider.future);
      await container
          .read(sessionControllerProvider.notifier)
          .login('a@b.com', 'pw', rememberMe: false);

      expect(await store.read(), isNull);
    },
  );

  test('a 401 on an authenticated request signs the session out', () async {
    final store = FakeTokenStore();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sessionControllerProvider.future);
    await container
        .read(sessionControllerProvider.notifier)
        .login('a@b.com', 'pw');
    expect(container.read(sessionControllerProvider).value?.role, 'manager');

    // What the Dio error interceptor does when the server rejects the token.
    onUnauthorized!();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(sessionControllerProvider).value?.role, isNull);
    expect(await store.read(), isNull);
  });

  group('offline outbox on logout', () {
    test('keeps unsynced work but drops rows already sent', () async {
      // The judgement call this pins. Wiping the queue on logout would be the
      // stronger privacy story and the wrong trade: an agent who audits a shop
      // with no signal and then logs out would lose the visit outright, and
      // offline-first promises the opposite. Ownership closes the leak; it does
      // not need an agent's afternoon destroyed to do it.
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          tokenStoreProvider.overrideWithValue(FakeTokenStore()),
          localDbProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sessionControllerProvider.future);
      currentLocalUserId = 'agent-a';

      await db.enqueue(
        entityType: 'visit',
        entityId: 'unsent',
        payloadJson: '{}',
      );
      await db.enqueue(
        entityType: 'visit',
        entityId: 'sent',
        payloadJson: '{}',
      );
      await (db.update(db.syncQueueItems)
            ..where((t) => t.entityId.equals('sent')))
          .write(const SyncQueueItemsCompanion(synced: Value(true)));

      await container.read(sessionControllerProvider.notifier).logout();

      final left = await db.select(db.syncQueueItems).get();
      expect(left.map((r) => r.entityId), ['unsent']);
      // And nobody is left signed in, so nothing of theirs can flush.
      expect(currentLocalUserId, isNull);
    });
  });
}

DateTime _hoursFromNow(int hours) =>
    DateTime.now().toUtc().add(Duration(hours: hours));

/// A structurally real JWT — only the payload matters, since nothing client
/// side verifies the signature.
String _jwtExpiringAt(DateTime expiry) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  final header = seg({'alg': 'HS256', 'typ': 'JWT'});
  final payload = seg({'exp': expiry.millisecondsSinceEpoch ~/ 1000});
  return '$header.$payload.signature';
}

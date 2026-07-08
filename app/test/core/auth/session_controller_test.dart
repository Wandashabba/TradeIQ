import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/auth_repository.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/auth/token_store.dart';

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
  test('login success updates the session state with the returned role', () async {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository())],
    );
    addTearDown(container.dispose);

    final controller = container.read(sessionControllerProvider.notifier);
    await controller.login('agent@tradeiq.com', 'password123');

    final state = container.read(sessionControllerProvider);
    expect(state.value?.role, 'manager');
  });

  test('login failure surfaces as AsyncError instead of throwing', () async {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(FailingAuthRepository())],
    );
    addTearDown(container.dispose);

    final controller = container.read(sessionControllerProvider.notifier);
    await controller.login('agent@tradeiq.com', 'wrong-password');

    final state = container.read(sessionControllerProvider);
    expect(state, isA<AsyncError<SessionState>>());
  });

  test('logout clears the session back to an empty state', () async {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository())],
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

    await container.read(sessionControllerProvider.notifier).login('agent@tradeiq.com', 'password123');

    final saved = await store.read();
    expect(saved?.token, 'fake-token');
    expect(saved?.role, 'manager');
  });

  test('build() restores a persisted session on startup', () async {
    final store = FakeTokenStore(const StoredSession(token: 'persisted-token', role: 'field_agent'));
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
    final store = FakeTokenStore(const StoredSession(token: 'persisted-token', role: 'manager'));
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
}

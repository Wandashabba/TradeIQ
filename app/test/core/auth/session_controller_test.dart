import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/auth_repository.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';

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

    controller.logout();

    final state = container.read(sessionControllerProvider);
    expect(state.value?.role, isNull);
    expect(state.value?.token, isNull);
  });
}

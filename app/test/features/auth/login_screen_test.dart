import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/auth_repository.dart';
import 'package:tradeiq_app/core/auth/token_store.dart';
import 'package:tradeiq_app/features/auth/presentation/login_screen.dart';

/// In-memory token store so widget tests never touch the real secure-storage
/// platform channel (whose calls hang under the test binding).
class _FakeTokenStore implements TokenStore {
  StoredSession? _session;

  @override
  Future<void> save(StoredSession session) async => _session = session;

  @override
  Future<StoredSession?> read() async => _session;

  @override
  Future<void> clear() async => _session = null;
}

class FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthResult> login(String email, String password) async {
    // A small delay is required so the loading state in the
    // "shows a loading indicator" test is observable: under
    // AutomatedTestWidgetsFlutterBinding's fake-clock zone, a bare
    // `tester.pump()` doesn't advance time, so a Future.delayed only
    // resolves once pumpAndSettle() (or pump(duration)) elapses the clock.
    // A repository that resolved via pure microtasks (no delay) would be
    // fully drained by `await tester.tap(...)` before the loading
    // assertion ever ran.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return const AuthResult(token: 'fake-token', role: 'manager');
  }
}

class Unauthorized401AuthRepository implements AuthRepository {
  @override
  Future<AuthResult> login(String email, String password) async {
    final options = RequestOptions(path: '/auth/login');
    throw DioException(
      requestOptions: options,
      response: Response(requestOptions: options, statusCode: 401),
    );
  }
}

class NetworkErrorAuthRepository implements AuthRepository {
  @override
  Future<AuthResult> login(String email, String password) async {
    throw DioException(
      requestOptions: RequestOptions(path: '/auth/login'),
      type: DioExceptionType.connectionError,
    );
  }
}

Widget _wrap(AuthRepository repository) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      tokenStoreProvider.overrideWithValue(_FakeTokenStore()),
    ],
    child: const MaterialApp(home: LoginScreen()),
  );
}

void main() {
  testWidgets('submitting valid credentials shows a loading indicator', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(FakeAuthRepository()));

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'manager@tradeiq.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('shows validation errors when fields are empty', (tester) async {
    await tester.pumpWidget(_wrap(FakeAuthRepository()));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('shows "Invalid credentials" on a 401 from the backend', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(Unauthorized401AuthRepository()));

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'manager@tradeiq.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong-password');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid credentials'), findsOneWidget);
  });

  testWidgets('shows a connectivity message when the server is unreachable', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(NetworkErrorAuthRepository()));

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'manager@tradeiq.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not reach the server'), findsOneWidget);
    expect(find.text('Invalid credentials'), findsNothing);
  });
}

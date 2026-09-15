import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/auth_repository.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/auth/token_store.dart';
import 'package:tradeiq_app/core/push/push_client.dart';
import 'package:tradeiq_app/core/push/push_config.dart';
import 'package:tradeiq_app/core/push/push_deep_link.dart';
import 'package:tradeiq_app/core/push/push_registration.dart';
import 'package:tradeiq_app/core/push/push_repository.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.token);
  final String token;

  @override
  Future<AuthResult> login(String email, String password) async =>
      AuthResult(token: token, role: 'field_agent');
}

class _FakePushClient implements PushClient {
  _FakePushClient({this.token = 'fcm-token-1'});

  String? token;
  bool deleted = false;
  final refresh = StreamController<String>.broadcast();
  final opened = StreamController<String>.broadcast();

  @override
  bool get isEnabled => true;

  @override
  PushPlatform get platform => PushPlatform.android;

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Stream<String> get onOpenedRoute => opened.stream;

  @override
  Future<void> deleteToken() async => deleted = true;
}

class _RecordingPushRepository implements PushRepository {
  final registered = <(String, PushPlatform)>[];
  final unregistered = <(String, String)>[];

  @override
  Future<void> registerDevice({
    required String token,
    required PushPlatform platform,
  }) async => registered.add((token, platform));

  @override
  Future<void> unregisterDevice(
    String token, {
    required String authToken,
  }) async => unregistered.add((token, authToken));

  @override
  Future<NotificationPreferences> fetchPreferences() async =>
      const NotificationPreferences();

  @override
  Future<NotificationPreferences> updatePreferences(
    Map<NotificationCategory, bool> changes,
  ) async => const NotificationPreferences();
}

/// Lets the registration's fire-and-forget futures run.
Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// #67 — sign-in registers this install's token, sign-out unregisters it with
/// the departing session, and a tap opens the notification's route.
void main() {
  late LocalDb db;
  late _RecordingPushRepository repository;
  late List<String> openedRoutes;

  setUp(() {
    db = LocalDb(NativeDatabase.memory());
    repository = _RecordingPushRepository();
    openedRoutes = [];
  });
  tearDown(() => db.close());

  ProviderContainer container(PushClient client) {
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          _FakeAuthRepository('session-token-1'),
        ),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        localDbProvider.overrideWithValue(db),
        pushClientProvider.overrideWithValue(client),
        pushRepositoryProvider.overrideWithValue(repository),
        pushRouteHandlerProvider.overrideWithValue(openedRoutes.add),
      ],
    );
    addTearDown(c.dispose);
    // As main.dart does: listened for the life of the app.
    c.listen(pushRegistrationProvider, (_, _) {});
    return c;
  }

  test('login registers the token; logout unregisters it with the departing session', () async {
    final client = _FakePushClient();
    final c = container(client);
    await _settle();
    expect(repository.registered, isEmpty, reason: 'nobody is signed in yet');

    await c.read(sessionControllerProvider.notifier).login('a@b.co', 'pw');
    await _settle();
    expect(repository.registered, [('fcm-token-1', PushPlatform.android)]);
    expect(c.read(pushRegistrationProvider).registeredToken, 'fcm-token-1');

    await c.read(sessionControllerProvider.notifier).logout();
    await _settle();
    expect(repository.unregistered, [('fcm-token-1', 'session-token-1')]);
    expect(client.deleted, isTrue);
    expect(c.read(pushRegistrationProvider).registeredToken, isNull);
  });

  test('a refreshed token is registered again for the same session', () async {
    final client = _FakePushClient();
    final c = container(client);
    await c.read(sessionControllerProvider.notifier).login('a@b.co', 'pw');
    await _settle();

    client.refresh.add('fcm-token-2');
    await _settle();

    expect(repository.registered.map((r) => r.$1), [
      'fcm-token-1',
      'fcm-token-2',
    ]);
    await c.read(sessionControllerProvider.notifier).logout();
    await _settle();
    expect(repository.unregistered, [('fcm-token-2', 'session-token-1')]);
  });

  test('tapping a notification opens its route; an unsafe route is ignored', () async {
    final client = _FakePushClient();
    final c = container(client);
    await c.read(sessionControllerProvider.notifier).login('a@b.co', 'pw');
    await _settle();

    client.opened
      ..add('/tasks')
      ..add('https://evil.example');
    await _settle();

    expect(openedRoutes, ['/tasks']);
  });

  test('with no token (permission refused) nothing is registered or unregistered', () async {
    final client = _FakePushClient(token: null);
    final c = container(client);
    await c.read(sessionControllerProvider.notifier).login('a@b.co', 'pw');
    await _settle();
    await c.read(sessionControllerProvider.notifier).logout();
    await _settle();

    expect(repository.registered, isEmpty);
    expect(repository.unregistered, isEmpty);
  });

  test('with the no-op client (push unconfigured) login and logout touch nothing', () async {
    final c = container(const NoopPushClient());
    await c.read(sessionControllerProvider.notifier).login('a@b.co', 'pw');
    await _settle();
    expect(c.read(sessionControllerProvider).value?.role, 'field_agent');
    await c.read(sessionControllerProvider.notifier).logout();
    await _settle();

    expect(repository.registered, isEmpty);
    expect(repository.unregistered, isEmpty);
  });
}

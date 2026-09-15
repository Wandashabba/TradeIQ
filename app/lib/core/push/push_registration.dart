import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_controller.dart';
import 'push_client.dart';
import 'push_deep_link.dart';
import 'push_repository.dart';

class PushRegistrationState {
  const PushRegistrationState({this.registeredToken});

  /// The token the server last accepted for this session; null otherwise.
  final String? registeredToken;
}

/// Ties this install's push token to whoever is signed in (#67).
///
/// - **Sign-in** (or a restored session): gets the token and registers it.
/// - **Token refresh:** registers the new token.
/// - **Sign-out:** unregisters the token with the departing session's bearer
///   token — the app has already dropped it — then forgets the token locally,
///   so a phone handed to someone else never receives the last person's pushes.
/// - **Tap:** opens the notification's route through go_router.
///
/// With the no-op client (push unconfigured) every step is skipped. Network
/// failures are swallowed: push is a convenience and must never get in the
/// way of signing in or out.
class PushRegistrationController extends Notifier<PushRegistrationState> {
  final _subscriptions = <StreamSubscription<String>>[];
  Object _generation = Object();

  /// The token registered, or being registered, for [_bearer].
  String? _deviceToken;

  /// The session the device is registered under.
  String? _bearer;

  @override
  PushRegistrationState build() {
    final session = ref.watch(sessionControllerProvider).value;
    final client = ref.watch(pushClientProvider);
    final repository = ref.watch(pushRepositoryProvider);
    final generation = Object();
    _generation = generation;
    ref.onDispose(_cancelSubscriptions);

    final bearer = session?.role != null ? session?.token : null;
    if (bearer == null) {
      final departingToken = _deviceToken;
      final departingBearer = _bearer;
      _deviceToken = null;
      _bearer = null;
      if (departingToken != null && departingBearer != null) {
        unawaited(
          _unregister(client, repository, departingToken, departingBearer),
        );
      }
      return const PushRegistrationState();
    }
    if (!client.isEnabled) return const PushRegistrationState();

    _listen(client, repository, generation, bearer);
    if (_bearer == bearer && _deviceToken != null) {
      // Rebuilt for another reason within the same session: already done.
      return PushRegistrationState(registeredToken: _deviceToken);
    }
    unawaited(_register(client, repository, generation, bearer));
    return const PushRegistrationState();
  }

  bool _alive(Object generation) => identical(generation, _generation);

  void _cancelSubscriptions() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  void _listen(
    PushClient client,
    PushRepository repository,
    Object generation,
    String bearer,
  ) {
    _subscriptions
      ..add(
        client.onTokenRefresh.listen((token) {
          if (_alive(generation)) {
            unawaited(_send(client, repository, generation, bearer, token));
          }
        }),
      )
      ..add(
        client.onOpenedRoute.listen((route) {
          if (_alive(generation) && isSafePushRoute(route)) {
            ref.read(pushRouteHandlerProvider)(route);
          }
        }),
      );
  }

  Future<void> _register(
    PushClient client,
    PushRepository repository,
    Object generation,
    String bearer,
  ) async {
    String? token;
    try {
      token = await client.getToken();
    } catch (_) {
      token = null;
    }
    if (token == null || !_alive(generation)) return;
    await _send(client, repository, generation, bearer, token);
  }

  Future<void> _send(
    PushClient client,
    PushRepository repository,
    Object generation,
    String bearer,
    String token,
  ) async {
    // Recorded before the call: a registration whose response is lost still
    // reached the server, and sign-out must still remove it.
    _deviceToken = token;
    _bearer = bearer;
    try {
      await repository.registerDevice(token: token, platform: client.platform);
      if (_alive(generation)) {
        state = PushRegistrationState(registeredToken: token);
      }
    } catch (_) {
      // Offline or refused: the next sign-in or token refresh tries again.
    }
  }

  Future<void> _unregister(
    PushClient client,
    PushRepository repository,
    String token,
    String bearer,
  ) async {
    try {
      await repository.unregisterDevice(token, authToken: bearer);
    } catch (_) {
      // Unreachable: FCM reports the token dead once it is deleted below, and
      // the server removes it then.
    }
    await client.deleteToken();
  }
}

final pushRegistrationProvider =
    NotifierProvider<PushRegistrationController, PushRegistrationState>(
      PushRegistrationController.new,
    );

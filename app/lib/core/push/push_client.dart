import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_push_client.dart';
import 'push_config.dart';

/// The device side of push notifications (#67), behind an interface so the
/// rest of the app never imports Firebase — and so a build without a Firebase
/// project gets [NoopPushClient] and nothing else changes.
abstract class PushClient {
  /// False for the no-op client: there is no token to register.
  bool get isEnabled;

  PushPlatform get platform;

  /// Initialises push on first call, asks the user's permission where the
  /// platform requires it, and returns this install's token — or null when
  /// push is off, refused, or unavailable. Never throws.
  Future<String?> getToken();

  /// A new token for this install (FCM rotates them).
  Stream<String> get onTokenRefresh;

  /// The `route` of a notification the user tapped — including the one that
  /// launched the app from cold.
  Stream<String> get onOpenedRoute;

  /// Forgets this install's token locally (sign-out). Never throws.
  Future<void> deleteToken();
}

/// Push while unconfigured: no token, no events, nothing to do.
class NoopPushClient implements PushClient {
  const NoopPushClient({this.platform = PushPlatform.android});

  @override
  final PushPlatform platform;

  @override
  bool get isEnabled => false;

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Stream<String> get onOpenedRoute => const Stream.empty();

  @override
  Future<void> deleteToken() async {}
}

/// The Firebase client when this build carries a complete Firebase config for
/// its platform (see [PushConfig]); the no-op client otherwise.
final pushClientProvider = Provider<PushClient>((ref) {
  final platform = currentPushPlatform();
  final config = PushConfig.fromEnvironment();
  if (platform == null || !config.isConfiguredFor(platform)) {
    return NoopPushClient(platform: platform ?? PushPlatform.android);
  }
  final client = FirebasePushClient(config: config, platform: platform);
  ref.onDispose(client.dispose);
  return client;
});

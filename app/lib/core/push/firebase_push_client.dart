import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_client.dart';
import 'push_config.dart';

/// Push through Firebase Cloud Messaging (#67).
///
/// Only ever constructed by `pushClientProvider` when the build carries a
/// complete [PushConfig], so Firebase is initialised from explicit
/// [FirebaseOptions] — no `google-services.json`, no `GoogleService-Info.plist`,
/// and no Google Services Gradle plugin. Every failure (no Play services, a
/// blocked service worker, a refused permission) degrades to "no token", never
/// to a crash.
class FirebasePushClient implements PushClient {
  FirebasePushClient({required this.config, required this.platform});

  final PushConfig config;

  @override
  final PushPlatform platform;

  final _refresh = StreamController<String>.broadcast();
  final _opened = StreamController<String>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  Future<FirebaseMessaging?>? _ready;

  @override
  bool get isEnabled => true;

  FirebaseOptions get _options => FirebaseOptions(
    apiKey: config.apiKey,
    appId: config.appId,
    messagingSenderId: config.messagingSenderId,
    projectId: config.projectId,
    iosBundleId: config.iosBundleId.isEmpty ? null : config.iosBundleId,
  );

  Future<FirebaseMessaging?> _init() => _ready ??= _initialise();

  Future<FirebaseMessaging?> _initialise() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: _options);
      }
      final messaging = FirebaseMessaging.instance;
      _subscriptions
        ..add(messaging.onTokenRefresh.listen(_refresh.add))
        ..add(FirebaseMessaging.onMessageOpenedApp.listen(_emitRoute));
      if (platform == PushPlatform.ios) {
        // iOS hides a notification that arrives while the app is open unless
        // told otherwise; Android and web show nothing in the foreground.
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      final initial = await messaging.getInitialMessage();
      // After this frame: whoever asked for the token is already listening.
      if (initial != null) scheduleMicrotask(() => _emitRoute(initial));
      return messaging;
    } catch (error) {
      debugPrint('[push] Firebase could not start; push stays off: $error');
      return null;
    }
  }

  void _emitRoute(RemoteMessage message) {
    final route = message.data['route'];
    if (route is String && !_opened.isClosed) _opened.add(route);
  }

  @override
  Future<String?> getToken() async {
    final messaging = await _init();
    if (messaging == null) return null;
    try {
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }
      return await messaging.getToken(
        vapidKey: platform == PushPlatform.web ? config.vapidKey : null,
      );
    } catch (error) {
      debugPrint('[push] no push token: $error');
      return null;
    }
  }

  @override
  Stream<String> get onTokenRefresh => _refresh.stream;

  @override
  Stream<String> get onOpenedRoute => _opened.stream;

  @override
  Future<void> deleteToken() async {
    final ready = _ready;
    if (ready == null) return; // never started: there is no token to forget
    try {
      await (await ready)?.deleteToken();
    } catch (_) {
      // Best-effort: the server copy is already unregistered.
    }
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _refresh.close();
    _opened.close();
  }
}

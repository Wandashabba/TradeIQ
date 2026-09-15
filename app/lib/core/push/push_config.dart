import 'package:flutter/foundation.dart';

/// Push notifications (#67) are built, but switched off until the owner creates
/// a Firebase project. This file is the switch.
///
/// Firebase is configured from `--dart-define` values, never from
/// `google-services.json` or `GoogleService-Info.plist`, so a build with no
/// Firebase project at all compiles, runs and tests exactly as before — push is
/// simply off. See docs/operations/push-notifications.md for the values and
/// where to find them.
///
/// The values are per platform (each platform is its own Firebase app), and a
/// build is for one platform, so one set of names serves all three:
///
/// ```sh
/// flutter build apk --dart-define-from-file=firebase.android.json
/// ```
enum PushPlatform { android, ios, web }

/// The platform this build runs on, or null where push is not offered
/// (desktop).
PushPlatform? currentPushPlatform() {
  if (kIsWeb) return PushPlatform.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => PushPlatform.android,
    TargetPlatform.iOS => PushPlatform.ios,
    _ => null,
  };
}

class PushConfig {
  const PushConfig({
    this.apiKey = '',
    this.appId = '',
    this.messagingSenderId = '',
    this.projectId = '',
    this.iosBundleId = '',
    this.vapidKey = '',
  });

  /// The values this binary was built with. All empty unless the build passed
  /// the dart-defines.
  factory PushConfig.fromEnvironment() => const PushConfig(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
    vapidKey: String.fromEnvironment('FIREBASE_VAPID_KEY'),
  );

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;

  /// iOS only; optional (Firebase falls back to the app's own bundle id).
  final String iosBundleId;

  /// Web only, and required there: the "Web Push certificates" key pair.
  final String vapidKey;

  /// Whether push can be switched on for [platform]. Anything missing means
  /// off — never a half-initialised Firebase.
  bool isConfiguredFor(PushPlatform? platform) {
    if (platform == null) return false;
    final core = [
      apiKey,
      appId,
      messagingSenderId,
      projectId,
    ].every((value) => value.trim().isNotEmpty);
    if (!core) return false;
    return platform != PushPlatform.web || vapidKey.trim().isNotEmpty;
  }
}

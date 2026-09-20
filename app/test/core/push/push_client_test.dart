import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/push/push_client.dart';
import 'package:tradeiq_app/core/push/push_config.dart';
import 'package:tradeiq_app/core/push/push_deep_link.dart';
import 'package:tradeiq_app/core/push/push_repository.dart';

/// #67 — push is built but off until the owner adds a Firebase config. With no
/// dart-defines (as here, and as in every build today) the app must get the
/// no-op client and never touch Firebase.
void main() {
  group('unconfigured', () {
    test('a build without dart-defines carries no Firebase config', () {
      final config = PushConfig.fromEnvironment();
      for (final platform in PushPlatform.values) {
        expect(config.isConfiguredFor(platform), isFalse);
      }
    });

    test(
      'the provider hands out the no-op client, which does nothing',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final client = container.read(pushClientProvider);

        expect(client, isA<NoopPushClient>());
        expect(client.isEnabled, isFalse);
        expect(client.platform, PushPlatform.android);
        expect(await client.getToken(), isNull);
        expect(await client.onTokenRefresh.isEmpty, isTrue);
        expect(await client.onOpenedRoute.isEmpty, isTrue);
        await client.deleteToken(); // completes, and there is nothing to assert
      },
    );
  });

  group('PushConfig', () {
    const complete = PushConfig(
      apiKey: 'key',
      appId: '1:123:android:abc',
      messagingSenderId: '123',
      projectId: 'tradeiq',
    );

    test('needs every core value', () {
      expect(complete.isConfiguredFor(PushPlatform.android), isTrue);
      expect(complete.isConfiguredFor(PushPlatform.ios), isTrue);
      expect(
        const PushConfig(
          apiKey: 'key',
          appId: ' ',
          messagingSenderId: '123',
          projectId: 'tradeiq',
        ).isConfiguredFor(PushPlatform.android),
        isFalse,
      );
      expect(complete.isConfiguredFor(null), isFalse);
    });

    test('web also needs the VAPID key', () {
      expect(complete.isConfiguredFor(PushPlatform.web), isFalse);
      const web = PushConfig(
        apiKey: 'key',
        appId: '1:123:web:abc',
        messagingSenderId: '123',
        projectId: 'tradeiq',
        vapidKey: 'BExample',
      );
      expect(web.isConfiguredFor(PushPlatform.web), isTrue);
    });
  });

  test('only in-app paths are opened from a notification', () {
    expect(isSafePushRoute('/alerts'), isTrue);
    expect(isSafePushRoute('/tasks?status=open'), isTrue);
    for (final unsafe in [
      '',
      'alerts',
      '//evil.example/x',
      'https://evil.example',
      r'/\evil.example',
    ]) {
      expect(isSafePushRoute(unsafe), isFalse, reason: unsafe);
    }
  });

  test('preferences default to on and read back from the server shape', () {
    const defaults = NotificationPreferences();
    for (final category in NotificationCategory.values) {
      expect(defaults[category], isTrue);
    }
    final parsed = NotificationPreferences.fromJson({
      'alerts': true,
      'tasks': false,
      'messages': true,
      'sla': false,
    });
    expect(parsed, const NotificationPreferences(tasks: false, sla: false));
    expect(
      parsed.withValue(NotificationCategory.sla, true),
      const NotificationPreferences(tasks: false),
    );
  });
}

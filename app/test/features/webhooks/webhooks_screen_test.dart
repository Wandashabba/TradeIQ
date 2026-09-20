import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/webhooks/data/webhooks_repository.dart';
import 'package:tradeiq_app/features/webhooks/presentation/webhooks_screen.dart';

import '../../core/theme/tiq_colors_test.dart' show contrastRatio;
import '../../helpers/routed_app.dart';

final _firstWebhook = Webhook(
  id: 'w-first',
  url: 'https://example.com/first',
  event: 'visit.submitted',
  active: true,
  health: WebhookHealth.healthy,
  lastDeliveryStatus: DeliveryStatus.succeeded,
  lastDeliveryAt: DateTime.now().subtract(const Duration(minutes: 5)),
);

final _secondWebhook = Webhook(
  id: 'w-second',
  url: 'https://example.com/second',
  event: 'task.closed',
  active: true,
  health: WebhookHealth.failing,
  lastDeliveryStatus: DeliveryStatus.failedRetrying,
  lastDeliveryAt: DateTime.now().subtract(const Duration(hours: 2)),
);

const _thirdWebhook = Webhook(
  id: 'w-third',
  url: 'https://example.com/third',
  event: 'alert.raised',
  active: true,
  health: WebhookHealth.unhealthy,
  consecutiveFailures: 1,
);

List<WebhookDelivery> _deliveries() {
  final now = DateTime.now();
  return [
    WebhookDelivery(
      id: 'd-ok',
      event: 'visit.submitted',
      status: DeliveryStatus.succeeded,
      attempts: 1,
      lastStatusCode: 200,
      createdAt: now.subtract(const Duration(minutes: 5)),
      deliveredAt: now.subtract(const Duration(minutes: 5)),
    ),
    WebhookDelivery(
      id: 'd-retry',
      event: 'visit.submitted',
      status: DeliveryStatus.failedRetrying,
      attempts: 2,
      lastStatusCode: 503,
      lastError: 'HTTP 503',
      createdAt: now.subtract(const Duration(minutes: 10)),
      nextAttemptAt: now.add(const Duration(minutes: 25, seconds: 30)),
    ),
    WebhookDelivery(
      id: 'd-dead',
      event: 'visit.submitted',
      status: DeliveryStatus.gaveUp,
      attempts: 6,
      lastError: 'connect ECONNREFUSED',
      createdAt: now.subtract(const Duration(days: 1)),
    ),
  ];
}

class _FakeWebhooksRepository implements WebhooksRepository {
  String? deletedId;
  String? createdUrl;
  String? createdEvent;
  String? deliveriesFor;
  String? redeliveredId;

  @override
  Future<PaginatedResponse<Webhook>> listWebhooks() async => PaginatedResponse(
    data: [_firstWebhook, _secondWebhook, _thirdWebhook],
    nextCursor: null,
  );

  @override
  Future<Webhook> createWebhook({
    required String url,
    required String event,
  }) async {
    createdUrl = url;
    createdEvent = event;
    return Webhook(id: 'w-new', url: url, event: event, active: true);
  }

  @override
  Future<void> deleteWebhook(String id) async {
    deletedId = id;
  }

  String? toggledId;
  bool? toggledValue;

  @override
  Future<Webhook> setActive(String id, bool active) async {
    toggledId = id;
    toggledValue = active;
    return _firstWebhook;
  }

  @override
  Future<List<WebhookDelivery>> listDeliveries(
    String webhookId, {
    int limit = 10,
  }) async {
    deliveriesFor = webhookId;
    return _deliveries();
  }

  @override
  Future<WebhookDelivery> redeliver(String deliveryId) async {
    redeliveredId = deliveryId;
    return _deliveries().firstWhere((d) => d.id == deliveryId);
  }
}

class _ThrowingWebhooksRepository implements WebhooksRepository {
  @override
  Future<PaginatedResponse<Webhook>> listWebhooks() async =>
      throw Exception('boom');

  @override
  Future<Webhook> createWebhook({
    required String url,
    required String event,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteWebhook(String id) async => throw UnimplementedError();

  @override
  Future<Webhook> setActive(String id, bool active) async =>
      throw UnimplementedError();

  @override
  Future<List<WebhookDelivery>> listDeliveries(
    String webhookId, {
    int limit = 10,
  }) async =>
      throw UnimplementedError();

  @override
  Future<WebhookDelivery> redeliver(String deliveryId) async =>
      throw UnimplementedError();
}

Widget _app(WebhooksRepository repo, {ThemeData? theme}) => routedApp(
      const WebhooksScreen(),
      theme: theme,
      overrides: [
        webhooksRepositoryProvider.overrideWithValue(repo),
      ],
    );

/// Taps a webhook row's own title. Scoped to the row, because once it is open
/// its delivery tiles repeat the same event name.
Future<void> _expand(
  WidgetTester tester,
  String webhookId,
  String webhookEvent,
) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(ValueKey<String>('webhook-$webhookId')),
      matching: find.text(webhookEvent),
    ),
  );
  await tester.pumpAndSettle();
}

/// The pill's words must clear AA over the tile they sit on: the status tint
/// composited onto the no-blur tile fill, composited onto the theme's plane.
void _expectPillAA(
  WidgetTester tester,
  String word,
  LumenStatus status, {
  required TiqColors colors,
  required LumenPalette lumen,
}) {
  final text = find.text(word.toUpperCase()).first;
  final ink = tester.widget<Text>(text).style!.color!;
  final sw = status.swatchOf(colors);
  expect(ink, sw.ink, reason: '$word must be set in its status ink');

  final pill = tester.widget<Container>(
    find.ancestor(of: text, matching: find.byType(Container)).first,
  );
  final tint = (pill.decoration! as BoxDecoration).color!;
  expect(tint, sw.tint);

  final ground = Color.alphaBlend(
    tint,
    Color.alphaBlend(lumen.solidFill, colors.plane),
  );
  final ratio = contrastRatio(ink, ground);
  expect(
    ratio,
    greaterThanOrEqualTo(4.5),
    reason: '$word is $ratio:1 on its pill — pill words are 8.5px, so AA '
        'demands 4.5:1.',
  );
}

void main() {
  testWidgets('light: endpoints are no-blur glass tiles in a glass panel', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_FakeWebhooksRepository(), theme: AppTheme.light()),
    );
    await tester.pumpAndSettle();

    final panes = tester
        .widgetList<GlassPane>(
          find.ancestor(
            of: find.text('visit.submitted'),
            matching: find.byType(GlassPane),
          ),
        )
        .toList();
    expect(panes.any((p) => p.kind == GlassKind.tile && !p.blur), isTrue);
    expect(panes.any((p) => p.kind == GlassKind.panel), isTrue);
  });

  testWidgets('renders webhook events once loaded', (tester) async {
    await tester.pumpWidget(_app(_FakeWebhooksRepository()));
    await tester.pumpAndSettle();

    expect(find.text('visit.submitted'), findsOneWidget);
    expect(find.text('task.closed'), findsOneWidget);
  });

  for (final (name, theme, colors, lumen) in [
    ('light', AppTheme.light(), TiqColors.light, LumenPalette.light),
    ('dark', AppTheme.dark(), TiqColors.night, LumenPalette.dark),
  ]) {
    testWidgets('$name: each webhook carries its health as a word and the '
        'time of its last delivery', (tester) async {
      await tester.pumpWidget(_app(_FakeWebhooksRepository(), theme: theme));
      await tester.pumpAndSettle();

      expect(find.text('HEALTHY'), findsOneWidget);
      expect(find.text('FAILING'), findsOneWidget);
      expect(find.text('UNHEALTHY'), findsOneWidget);
      expect(find.text('Last delivery 5m ago'), findsOneWidget);
      expect(find.text('Last delivery 2h ago'), findsOneWidget);
      expect(find.text('No deliveries yet'), findsOneWidget);
      expect(find.text('1 unhealthy', findRichText: true), findsNothing);
      expect(find.textContaining('1 unhealthy'), findsOneWidget);

      _expectPillAA(tester, 'Healthy', LumenStatus.good,
          colors: colors, lumen: lumen);
      _expectPillAA(tester, 'Failing', LumenStatus.warn,
          colors: colors, lumen: lumen);
      _expectPillAA(tester, 'Unhealthy', LumenStatus.crit,
          colors: colors, lumen: lumen);
    });

    testWidgets('$name: opening a webhook lists its deliveries as no-blur '
        'tiles with status, code, attempts and timing', (tester) async {
      final repo = _FakeWebhooksRepository();
      await tester.pumpWidget(_app(repo, theme: theme));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('deliveries-w-first')), findsNothing);
      await _expand(tester, 'w-first', 'visit.submitted');

      expect(repo.deliveriesFor, 'w-first');
      expect(find.text('RECENT DELIVERIES'), findsOneWidget);
      expect(find.text('DELIVERED'), findsOneWidget);
      expect(find.text('RETRYING'), findsOneWidget);
      expect(find.text('GAVE UP'), findsOneWidget);
      expect(find.text('HTTP 200'), findsOneWidget);
      expect(find.text('HTTP 503'), findsOneWidget);
      expect(find.text('No response'), findsOneWidget);
      expect(find.text('1 attempt'), findsOneWidget);
      expect(find.text('2 attempts'), findsOneWidget);
      expect(find.text('6 attempts'), findsOneWidget);
      expect(find.text('Delivered 5m ago'), findsOneWidget);
      expect(find.text('Next retry in 25m'), findsOneWidget);
      expect(find.text('No more retries'), findsOneWidget);

      for (final id in ['d-ok', 'd-retry', 'd-dead']) {
        final pane = tester.widget<GlassPane>(
          find.byKey(ValueKey<String>('delivery-$id')),
        );
        expect(pane.kind, GlassKind.tile);
        expect(pane.blur, isFalse);
      }

      _expectPillAA(tester, 'Delivered', LumenStatus.good,
          colors: colors, lumen: lumen);
      _expectPillAA(tester, 'Retrying', LumenStatus.warn,
          colors: colors, lumen: lumen);
      _expectPillAA(tester, 'Gave up', LumenStatus.crit,
          colors: colors, lumen: lumen);

      // Tapping again closes it.
      await _expand(tester, 'w-first', 'visit.submitted');
      expect(find.byKey(const ValueKey('deliveries-w-first')), findsNothing);
    });
  }

  testWidgets('Redeliver is offered on failed rows only, and calls the '
      'repository', (tester) async {
    final repo = _FakeWebhooksRepository();
    await tester.pumpWidget(_app(repo, theme: AppTheme.light()));
    await tester.pumpAndSettle();
    await _expand(tester, 'w-first', 'visit.submitted');

    expect(find.byKey(const ValueKey('redeliver-d-ok')), findsNothing);
    expect(find.byKey(const ValueKey('redeliver-d-retry')), findsOneWidget);
    expect(find.byKey(const ValueKey('redeliver-d-dead')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('redeliver-d-dead')));
    await tester.pumpAndSettle();

    expect(repo.redeliveredId, 'd-dead');
    expect(find.text('Redelivery queued'), findsOneWidget);
  });

  test('relativeTime reads past and future spans', () {
    final now = DateTime(2026, 9, 14, 12);
    expect(relativeTime(now.subtract(const Duration(seconds: 20)), now: now),
        'just now');
    expect(relativeTime(now.subtract(const Duration(minutes: 7)), now: now),
        '7m ago');
    expect(relativeTime(now.subtract(const Duration(hours: 3)), now: now),
        '3h ago');
    expect(relativeTime(now.subtract(const Duration(days: 2)), now: now),
        '2d ago');
    expect(relativeTime(now.add(const Duration(minutes: 5)), now: now),
        'in 5m');
    expect(relativeTime(now.add(const Duration(seconds: 10)), now: now),
        'in under a minute');
  });

  testWidgets('tapping delete records the webhook id', (tester) async {
    final repo = _FakeWebhooksRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('delete-w-first')));
    await tester.pumpAndSettle();

    expect(repo.deletedId, 'w-first');
  });

  testWidgets('creating a webhook records the entered args', (tester) async {
    final repo = _FakeWebhooksRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('new-url')),
      'https://example.com/new',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('new-event')),
      'stock.captured',
    );
    await tester.tap(find.byKey(const ValueKey<String>('create-webhook')));
    await tester.pumpAndSettle();

    expect(repo.createdUrl, 'https://example.com/new');
    expect(repo.createdEvent, 'stock.captured');
  });

  testWidgets('the create form lists the events, report.generated included',
      (tester) async {
    await tester.pumpWidget(_app(_FakeWebhooksRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(webhookEvents, contains('report.generated'));
    expect(
      find.text(
        'One of: visit.submitted, alert.raised, order.created, '
        'report.generated',
      ),
      findsOneWidget,
    );
  });

  testWidgets('toggling active calls setActive', (tester) async {
    final repo = _FakeWebhooksRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // _firstWebhook starts active; toggling turns it off.
    await tester.tap(find.byKey(const ValueKey<String>('toggle-w-first')));
    await tester.pumpAndSettle();

    expect(repo.toggledId, 'w-first');
    expect(repo.toggledValue, false);
  });

  testWidgets('shows an error message when loading fails', (tester) async {
    await tester.pumpWidget(_app(_ThrowingWebhooksRepository()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Failed to load webhooks'),
      findsOneWidget,
    );
  });
}

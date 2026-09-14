import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/webhooks/data/webhooks_repository.dart';
import 'package:tradeiq_app/features/webhooks/presentation/webhooks_screen.dart';

import '../../helpers/routed_app.dart';

const _firstWebhook = Webhook(
  id: 'w-first',
  url: 'https://example.com/first',
  event: 'visit.submitted',
  active: true,
);

const _secondWebhook = Webhook(
  id: 'w-second',
  url: 'https://example.com/second',
  event: 'task.closed',
  active: true,
);

class _FakeWebhooksRepository implements WebhooksRepository {
  String? deletedId;
  String? createdUrl;
  String? createdEvent;

  @override
  Future<PaginatedResponse<Webhook>> listWebhooks() async =>
      const PaginatedResponse(data: [_firstWebhook, _secondWebhook], nextCursor: null);

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
}

Widget _app(WebhooksRepository repo, {ThemeData? theme}) => routedApp(
      const WebhooksScreen(),
      theme: theme,
      overrides: [
        webhooksRepositoryProvider.overrideWithValue(repo),
      ],
    );

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

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/webhooks/data/webhooks_repository.dart';

/// A fake HTTP layer that returns a canned body and records the request,
/// following the pattern in `test/features/agents/agents_repository_test.dart`.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.body);
  final String body;
  RequestOptions? last;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  test('Webhook.fromJson parses all fields', () {
    final webhook = Webhook.fromJson(const {
      'id': 'w1',
      'url': 'https://example.com/hook',
      'event': 'visit.submitted',
      'active': false,
      'health': 'unhealthy',
      'consecutiveFailures': 2,
      'lastDeliveryStatus': 'gave_up',
      'lastDeliveryAt': '2026-09-14T08:00:00.000Z',
    });

    expect(webhook.id, 'w1');
    expect(webhook.url, 'https://example.com/hook');
    expect(webhook.event, 'visit.submitted');
    expect(webhook.active, isFalse);
    expect(webhook.health, WebhookHealth.unhealthy);
    expect(webhook.consecutiveFailures, 2);
    expect(webhook.lastDeliveryStatus, DeliveryStatus.gaveUp);
    expect(webhook.lastDeliveryAt!.toUtc(), DateTime.utc(2026, 9, 14, 8));
  });

  test('Webhook.fromJson defaults active and health when missing', () {
    final webhook = Webhook.fromJson(const {
      'id': 'w2',
      'url': 'https://example.com/hook2',
      'event': 'task.closed',
    });

    expect(webhook.active, isTrue);
    expect(webhook.health, WebhookHealth.healthy);
    expect(webhook.consecutiveFailures, 0);
    expect(webhook.lastDeliveryStatus, isNull);
    expect(webhook.lastDeliveryAt, isNull);
  });

  test('WebhookHealth.parse maps every backend word', () {
    expect(WebhookHealth.parse('healthy'), WebhookHealth.healthy);
    expect(WebhookHealth.parse('failing'), WebhookHealth.failing);
    expect(WebhookHealth.parse('unhealthy'), WebhookHealth.unhealthy);
    expect(WebhookHealth.parse(null), WebhookHealth.healthy);
  });

  test('WebhookDelivery.fromJson parses a retrying delivery', () {
    final d = WebhookDelivery.fromJson(const {
      'id': 'd1',
      'webhookId': 'w1',
      'event': 'order.created',
      'status': 'failed_retrying',
      'attempts': 2,
      'lastStatusCode': 503,
      'lastError': 'HTTP 503',
      'nextAttemptAt': '2026-09-14T08:05:00.000Z',
      'lastAttemptAt': '2026-09-14T08:00:00.000Z',
      'deliveredAt': null,
      'createdAt': '2026-09-14T07:59:00.000Z',
    });

    expect(d.id, 'd1');
    expect(d.event, 'order.created');
    expect(d.status, DeliveryStatus.failedRetrying);
    expect(d.status.redeliverable, isTrue);
    expect(d.attempts, 2);
    expect(d.lastStatusCode, 503);
    expect(d.lastError, 'HTTP 503');
    expect(d.nextAttemptAt!.toUtc(), DateTime.utc(2026, 9, 14, 8, 5));
    expect(d.deliveredAt, isNull);
  });

  test('DeliveryStatus: only failed deliveries are redeliverable', () {
    expect(DeliveryStatus.parse('succeeded')!.redeliverable, isFalse);
    expect(DeliveryStatus.parse('pending')!.redeliverable, isFalse);
    expect(DeliveryStatus.parse('gave_up')!.redeliverable, isTrue);
    expect(DeliveryStatus.parse('nonsense'), isNull);
  });

  group('DioWebhooksRepository', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = dio.httpClientAdapter;
    });

    tearDown(() {
      dio.httpClientAdapter = originalAdapter;
    });

    test('listWebhooks parses the {data, nextCursor} envelope', () async {
      dio.httpClientAdapter = _RecordingAdapter(
        '{"data": [{"id": "w1", "url": "https://example.com/hook", '
        '"event": "visit.submitted", "active": true, "health": "failing"}], '
        '"nextCursor": "cursor-1"}',
      );

      final page = await DioWebhooksRepository().listWebhooks();

      expect(page, isA<PaginatedResponse<Webhook>>());
      expect(page.data, hasLength(1));
      expect(page.data.first.id, 'w1');
      expect(page.data.first.health, WebhookHealth.failing);
      expect(page.nextCursor, 'cursor-1');
    });

    test(
      'listDeliveries GETs the webhook\'s deliveries with a limit',
      () async {
        final adapter = _RecordingAdapter(
          '{"data": [{"id": "d1", "event": "order.created", '
          '"status": "succeeded", "attempts": 1, "lastStatusCode": 200, '
          '"deliveredAt": "2026-09-14T08:00:00.000Z", '
          '"createdAt": "2026-09-14T08:00:00.000Z"}], "nextCursor": null}',
        );
        dio.httpClientAdapter = adapter;

        final list = await DioWebhooksRepository().listDeliveries(
          'w1',
          limit: 5,
        );

        expect(adapter.last!.method, 'GET');
        expect(adapter.last!.path, '/webhooks/w1/deliveries');
        expect(adapter.last!.queryParameters, {'limit': 5});
        expect(list.single.status, DeliveryStatus.succeeded);
        expect(list.single.lastStatusCode, 200);
      },
    );

    test('redeliver POSTs to the delivery and parses the row', () async {
      final adapter = _RecordingAdapter(
        '{"id": "d9", "event": "order.created", "status": "pending", '
        '"attempts": 6, "createdAt": "2026-09-14T08:00:00.000Z"}',
      );
      dio.httpClientAdapter = adapter;

      final d = await DioWebhooksRepository().redeliver('d9');

      expect(adapter.last!.method, 'POST');
      expect(adapter.last!.path, '/webhook-deliveries/d9/redeliver');
      expect(d.id, 'd9');
      expect(d.status, DeliveryStatus.pending);
      expect(d.attempts, 6);
    });
  });
}

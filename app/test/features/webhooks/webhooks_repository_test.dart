import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/webhooks/data/webhooks_repository.dart';

/// A fake HTTP layer that returns a canned body, following the pattern in
/// `test/features/agents/agents_repository_test.dart`.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.body);
  final String body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
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
    });

    expect(webhook.id, 'w1');
    expect(webhook.url, 'https://example.com/hook');
    expect(webhook.event, 'visit.submitted');
    expect(webhook.active, isFalse);
  });

  test('Webhook.fromJson defaults active to true when missing', () {
    final webhook = Webhook.fromJson(const {
      'id': 'w2',
      'url': 'https://example.com/hook2',
      'event': 'task.closed',
    });

    expect(webhook.active, isTrue);
  });

  group('DioWebhooksRepository.listWebhooks', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = dio.httpClientAdapter;
    });

    tearDown(() {
      dio.httpClientAdapter = originalAdapter;
    });

    test('parses the {data, nextCursor} envelope into a PaginatedResponse',
        () async {
      dio.httpClientAdapter = _RecordingAdapter(
        '{"data": [{"id": "w1", "url": "https://example.com/hook", '
        '"event": "visit.submitted", "active": true}], '
        '"nextCursor": "cursor-1"}',
      );

      final page = await DioWebhooksRepository().listWebhooks();

      expect(page, isA<PaginatedResponse<Webhook>>());
      expect(page.data, hasLength(1));
      expect(page.data.first.id, 'w1');
      expect(page.nextCursor, 'cursor-1');
    });
  });
}

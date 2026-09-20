import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/features/orders/data/orders_repository.dart';

/// Reads go over HTTP; writes go through the outbox, so the repository needs a
/// local database even to list. See `order_outbox_test.dart` for the writes.
DioOrdersRepository _repository(LocalDb db) => DioOrdersRepository(
  db: db,
  syncService: SyncService(
    db: db,
    flusher: HttpQueueFlusher(db: db),
  ),
);

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
  test('OrderItem.fromJson parses total as double and lines from _count', () {
    final order = OrderItem.fromJson(const {
      'id': 'ord-123',
      'outletId': 'o1',
      'status': 'submitted',
      'total': 149.5,
      '_count': {'lines': 3},
    });

    expect(order.id, 'ord-123');
    expect(order.outletId, 'o1');
    expect(order.status, 'submitted');
    expect(order.total, 149.5);
    expect(order.total, isA<double>());
    expect(order.lineCount, 3);
  });

  test('OrderItem.fromJson coerces integer total to double', () {
    final order = OrderItem.fromJson(const {
      'id': 'ord-int',
      'outletId': 'o2',
      'status': 'draft',
      'total': 200,
      '_count': {'lines': 1},
    });

    expect(order.total, 200.0);
    expect(order.total, isA<double>());
  });

  test('OrderItem.fromJson defaults lineCount to 0 when _count absent', () {
    final order = OrderItem.fromJson(const {
      'id': 'ord-nocount',
      'outletId': 'o3',
      'status': 'draft',
      'total': 0,
    });

    expect(order.lineCount, 0);
  });

  group('DioOrdersRepository.listOrders', () {
    late HttpClientAdapter originalAdapter;
    late LocalDb db;

    setUp(() {
      originalAdapter = dio.httpClientAdapter;
      db = LocalDb(NativeDatabase.memory());
    });

    tearDown(() async {
      dio.httpClientAdapter = originalAdapter;
      await db.close();
    });

    test(
      'parses the {data, nextCursor} envelope into a PaginatedResponse',
      () async {
        dio.httpClientAdapter = _RecordingAdapter(
          '{"data": [{"id": "ord-1", "outletId": "o1", "status": "submitted", '
          '"total": 25, "_count": {"lines": 2}}], '
          '"nextCursor": "cursor-1"}',
        );

        final page = await _repository(db).listOrders();

        expect(page, isA<PaginatedResponse<OrderItem>>());
        expect(page.data, hasLength(1));
        expect(page.data.first.id, 'ord-1');
        expect(page.nextCursor, 'cursor-1');
      },
    );
  });
}

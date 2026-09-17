import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/features/orders/data/orders_repository.dart';

/// An in-store order taken offline, from the tap to the POST (#338).
///
/// The field this exercises is `capturedAt`: the moment the agent took the
/// order, stamped on the device. It has to survive being written to the outbox
/// and read back out again unchanged, because the whole point is that an order
/// captured at 23:30 on the 30th is still dated the 30th when the phone finally
/// finds signal on the 1st.
class _FakeAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"id":"ord-1","outletId":"ou1","status":"submitted","total":16.0}',
    201,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

SyncQueueItem _item(String payloadJson) => SyncQueueItem(
  id: 1,
  entityType: orderEntity,
  entityId: 'ord-local-1',
  payloadJson: payloadJson,
  queuedAt: DateTime(2026, 1, 1),
  synced: false,
  attempts: 0,
);

void main() {
  late LocalDb db;
  final requests = <RequestOptions>[];
  late Dio dio;

  setUp(() {
    db = LocalDb(NativeDatabase.memory());
    requests.clear();
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
      ..httpClientAdapter = _FakeAdapter()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.next(options);
          },
        ),
      );
    // The outbox only flushes rows it knows the owner of.
    currentLocalUserId = 'agent-1';
  });

  tearDown(() async {
    currentLocalUserId = null;
    await db.close();
  });

  test('queues the order with the device capture time and sends it', () async {
    final before = DateTime.now().toUtc();
    final repo = DioOrdersRepository(
      db: db,
      syncService: SyncService(db: db, flusher: HttpQueueFlusher(db: db, dio: dio)),
    );

    await repo.createOrder(
      outletId: 'ou1',
      lines: const [OrderLine(skuId: 'sku1', quantity: 2, unitPrice: 8)],
    );
    final after = DateTime.now().toUtc();

    // It went out as one POST /orders carrying the lines as captured.
    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(requests.single.path, '/orders');
    final sent = requests.single.data as Map<String, dynamic>;
    expect(sent['outletId'], 'ou1');
    expect(sent['lines'], [
      {'skuId': 'sku1', 'quantity': 2, 'unitPrice': 8.0},
    ]);

    // The capture time is the device's own, stamped when the order was taken.
    final capturedAt = DateTime.parse(sent['capturedAt'] as String);
    expect(capturedAt.isUtc, isTrue);
    expect(capturedAt.isBefore(before.subtract(const Duration(seconds: 1))), isFalse);
    expect(capturedAt.isAfter(after.add(const Duration(seconds: 1))), isFalse);

    // And the row is marked sent, not left for a retry.
    final rows = await db.select(db.syncQueueItems).get();
    expect(rows.single.entityType, orderEntity);
    expect(rows.single.synced, isTrue);
  });

  test('keeps the order queued when it cannot send, capture time intact', () async {
    // No signal: the order is on the phone and the capture time is already
    // stamped, so syncing tomorrow still reports when it was actually taken.
    final failing = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
      ..httpClientAdapter = _ThrowingAdapter();
    final repo = DioOrdersRepository(
      db: db,
      syncService: SyncService(db: db, flusher: HttpQueueFlusher(db: db, dio: failing)),
    );

    await repo.createOrder(
      outletId: 'ou1',
      lines: const [OrderLine(skuId: 'sku1', quantity: 1, unitPrice: 5)],
    );

    final row = (await db.select(db.syncQueueItems).get()).single;
    expect(row.synced, isFalse);
    final payload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    expect(payload['capturedAt'], isA<String>());
    expect(DateTime.parse(payload['capturedAt'] as String).isUtc, isTrue);
  });

  test('flushes a queued order payload to /orders unchanged', () async {
    // The round trip that matters: what the flusher posts is exactly what was
    // written to the outbox. Re-stamping the time here would date every
    // offline order by the moment it found signal.
    final flusher = HttpQueueFlusher(db: db, dio: dio);
    const capturedAt = '2026-09-30T21:30:00.000Z';

    await flusher.flush(
      _item(
        jsonEncode({
          'outletId': 'ou1',
          'lines': [
            {'skuId': 'sku1', 'quantity': 2, 'unitPrice': 8.0},
          ],
          'capturedAt': capturedAt,
        }),
      ),
    );

    expect(requests.single.path, '/orders');
    expect(requests.single.data, {
      'outletId': 'ou1',
      'lines': [
        {'skuId': 'sku1', 'quantity': 2, 'unitPrice': 8.0},
      ],
      'capturedAt': capturedAt,
    });
  });

  test('sends a payload queued by an older build, which carries no capture time', () async {
    // Upgrading the app must not strand orders already in the outbox. The
    // server falls back to the time it receives them.
    final flusher = HttpQueueFlusher(db: db, dio: dio);

    await flusher.flush(
      _item(
        jsonEncode({
          'outletId': 'ou1',
          'lines': [
            {'skuId': 'sku1', 'quantity': 1, 'unitPrice': 5.0},
          ],
        }),
      ),
    );

    expect(requests.single.path, '/orders');
    expect((requests.single.data as Map).containsKey('capturedAt'), isFalse);
  });
}

class _ThrowingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw DioException.connectionError(
    requestOptions: options,
    reason: 'no signal',
  );
}

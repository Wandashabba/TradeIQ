import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';

class NoopFlusher implements QueueFlusher {
  int callCount = 0;

  @override
  Future<void> flush(SyncQueueItem item) async {
    callCount += 1;
  }
}

class _FailFirstFlusher implements QueueFlusher {
  final List<String> attempted = [];

  @override
  Future<void> flush(SyncQueueItem item) async {
    attempted.add(item.entityId);
    if (item.entityId == 'visit-1') {
      throw Exception('network error');
    }
  }
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.statusCode);
  final int statusCode;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{}',
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

SyncQueueItem _visitQueueItem(String payloadJson) => SyncQueueItem(
      id: 1,
      entityType: 'visit',
      entityId: 'visit-1',
      payloadJson: payloadJson,
      queuedAt: DateTime(2026, 1, 1),
      synced: false,
    );

void main() {
  test('flushPending marks queued items as synced', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
      entityType: 'visit',
      entityId: 'visit-1',
      payloadJson: '{}',
    ));

    final flusher = NoopFlusher();
    final service = SyncService(db: db, flusher: flusher);
    await service.flushPending();

    expect(flusher.callCount, 1);
    final rows = await db.select(db.syncQueueItems).get();
    expect(rows.first.synced, isTrue);
  });

  test('flushPending does not let one failing item block the rest of the queue', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
      entityType: 'visit',
      entityId: 'visit-1',
      payloadJson: '{}',
    ));
    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
      entityType: 'visit',
      entityId: 'visit-2',
      payloadJson: '{}',
    ));

    final flusher = _FailFirstFlusher();
    final service = SyncService(db: db, flusher: flusher);
    await service.flushPending();

    expect(flusher.attempted, ['visit-1', 'visit-2']);
    final rows = await db.select(db.syncQueueItems).get();
    final byEntityId = {for (final row in rows) row.entityId: row.synced};
    expect(byEntityId['visit-1'], isFalse);
    expect(byEntityId['visit-2'], isTrue);
  });

  group('HttpQueueFlusher', () {
    test('posts the visit payload to /visits and succeeds on 2xx', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))..httpClientAdapter = _FakeAdapter(201);
      final flusher = HttpQueueFlusher(dio: dio);

      await flusher.flush(_visitQueueItem('{"outletId":"o1","lat":1.0,"lng":2.0}'));
    });

    test('throws when the backend rejects the check-in with 422', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))..httpClientAdapter = _FakeAdapter(422);
      final flusher = HttpQueueFlusher(dio: dio);

      await expectLater(
        flusher.flush(_visitQueueItem('{"outletId":"o1","lat":1.0,"lng":2.0}')),
        throwsA(isA<DioException>()),
      );
    });

    test('throws UnimplementedError for an unhandled entity type', () async {
      final flusher = HttpQueueFlusher(dio: Dio());
      await expectLater(
        flusher.flush(_visitQueueItem('{}').copyWith(entityType: 'stock')),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}

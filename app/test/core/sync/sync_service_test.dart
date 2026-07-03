import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';

class NoopFlusher implements QueueFlusher {
  int callCount = 0;

  @override
  Future<Map<String, dynamic>?> flush(SyncQueueItem item) async {
    callCount += 1;
    return null;
  }
}

class _FailFirstFlusher implements QueueFlusher {
  final List<String> attempted = [];

  @override
  Future<Map<String, dynamic>?> flush(SyncQueueItem item) async {
    attempted.add(item.entityId);
    if (item.entityId == 'visit-1') {
      throw Exception('network error');
    }
    return null;
  }
}

class _RecordingFlusher implements QueueFlusher {
  final List<String> receivedPayloads = [];
  Map<String, dynamic>? Function(SyncQueueItem item)? onFlush;

  @override
  Future<Map<String, dynamic>?> flush(SyncQueueItem item) async {
    receivedPayloads.add(item.payloadJson);
    return onFlush?.call(item);
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

Future<void> _insertVisitDraft(LocalDb db, {required String id, String? remoteId}) async {
  await db.into(db.visitDrafts).insert(VisitDraftsCompanion.insert(
        id: id,
        outletId: 'outlet-1',
        checkinTs: DateTime(2026, 1, 1),
        checkinLat: 0,
        checkinLng: 0,
        geofencePass: true,
      ));
  if (remoteId != null) {
    await (db.update(db.visitDrafts)..where((t) => t.id.equals(id)))
        .write(VisitDraftsCompanion(remoteId: Value(remoteId)));
  }
}

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

  test('writes the response id back to VisitDrafts.remoteId after a successful visit flush', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    await _insertVisitDraft(db, id: 'local-visit-1');
    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
      entityType: 'visit',
      entityId: 'local-visit-1',
      payloadJson: '{"outletId":"outlet-1"}',
    ));

    final flusher = _RecordingFlusher()..onFlush = (_) => {'id': 'remote-visit-1'};
    final service = SyncService(db: db, flusher: flusher);
    await service.flushPending();

    final draft = await (db.select(db.visitDrafts)..where((t) => t.id.equals('local-visit-1'))).getSingle();
    expect(draft.remoteId, 'remote-visit-1');
  });

  test('skips a child item whose parent visit has not synced yet', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    await _insertVisitDraft(db, id: 'local-visit-1');
    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
      entityType: 'stock',
      entityId: 'stock-1',
      payloadJson: '{"visitId":"local-visit-1","skuId":"sku-1"}',
    ));

    final flusher = _RecordingFlusher();
    final service = SyncService(db: db, flusher: flusher);
    await service.flushPending();

    expect(flusher.receivedPayloads, isEmpty);
    final rows = await db.select(db.syncQueueItems).get();
    expect(rows.first.synced, isFalse);
  });

  test("resolves a child item to the parent visit's remote id once it is known", () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    await _insertVisitDraft(db, id: 'local-visit-1', remoteId: 'remote-visit-1');
    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
      entityType: 'stock',
      entityId: 'stock-1',
      payloadJson: '{"visitId":"local-visit-1","skuId":"sku-1"}',
    ));

    final flusher = _RecordingFlusher();
    final service = SyncService(db: db, flusher: flusher);
    await service.flushPending();

    expect(flusher.receivedPayloads, ['{"visitId":"remote-visit-1","skuId":"sku-1"}']);
    final rows = await db.select(db.syncQueueItems).get();
    expect(rows.first.synced, isTrue);
  });

  group('HttpQueueFlusher', () {
    test('posts the visit payload to /visits and returns the decoded response', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
        ..httpClientAdapter = _FakeAdapter(201);
      final flusher = HttpQueueFlusher(dio: dio);

      final response = await flusher.flush(_visitQueueItem('{"outletId":"o1","lat":1.0,"lng":2.0}'));
      expect(response, isA<Map<String, dynamic>>());
    });

    test('posts the stock payload to /stock and succeeds on 2xx', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))..httpClientAdapter = _FakeAdapter(201);
      final flusher = HttpQueueFlusher(dio: dio);

      await flusher.flush(_visitQueueItem('{"visitId":"v1","skuId":"s1"}').copyWith(entityType: 'stock'));
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
        flusher.flush(_visitQueueItem('{}').copyWith(entityType: 'receipt')),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}

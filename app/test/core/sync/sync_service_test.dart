import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
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
  _FakeAdapter(this.statusCode, [this.body = '{"id":"remote-visit-1"}']);
  final int statusCode;
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
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

VisitDraftsCompanion _visitDraft(String id, {String? remoteId}) => VisitDraftsCompanion.insert(
      id: id,
      outletId: 'o1',
      checkinTs: DateTime(2026, 1, 1),
      checkinLat: 0,
      checkinLng: 0,
      geofencePass: true,
      remoteId: Value(remoteId),
    );

SyncQueueItem _queueItem({
  required String entityType,
  required String entityId,
  required String payloadJson,
  int id = 1,
}) =>
    SyncQueueItem(
      id: id,
      entityType: entityType,
      entityId: entityId,
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
    test('posts /visits and records the server id on the visit draft', () async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);
      await db.into(db.visitDrafts).insert(_visitDraft('visit-1'));

      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))..httpClientAdapter = _FakeAdapter(201);
      final flusher = HttpQueueFlusher(db: db, dio: dio);

      await flusher.flush(_queueItem(
        entityType: 'visit',
        entityId: 'visit-1',
        payloadJson: '{"outletId":"o1","lat":1.0,"lng":2.0}',
      ));

      final draft = await (db.select(db.visitDrafts)..where((t) => t.id.equals('visit-1'))).getSingle();
      expect(draft.remoteId, 'remote-visit-1');
    });

    test('throws when the backend rejects the check-in with 422', () async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))..httpClientAdapter = _FakeAdapter(422);
      final flusher = HttpQueueFlusher(db: db, dio: dio);

      await expectLater(
        flusher.flush(_queueItem(
          entityType: 'visit',
          entityId: 'visit-1',
          payloadJson: '{"outletId":"o1","lat":1.0,"lng":2.0}',
        )),
        throwsA(isA<DioException>()),
      );
    });

    test('stock flush resolves the remote visit id and posts to /stock', () async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);
      await db.into(db.visitDrafts).insert(_visitDraft('v1', remoteId: 'remote-v1'));

      final captured = <dynamic>[];
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
        ..httpClientAdapter = _FakeAdapter(201, '{}')
        ..interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
          captured.add(options.data);
          handler.next(options);
        }));
      final flusher = HttpQueueFlusher(db: db, dio: dio);

      await flusher.flush(_queueItem(
        entityType: 'stock',
        entityId: 'batch-1',
        payloadJson: '{"visitDraftId":"v1","items":[{"skuId":"s1"}]}',
      ));

      expect(captured, hasLength(1));
      expect((captured.first as Map)['visitId'], 'remote-v1');
    });

    test('stock flush throws when the visit has not synced yet', () async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);
      await db.into(db.visitDrafts).insert(_visitDraft('v1')); // remoteId null

      final flusher = HttpQueueFlusher(db: db, dio: Dio());
      await expectLater(
        flusher.flush(_queueItem(
          entityType: 'stock',
          entityId: 'batch-1',
          payloadJson: '{"visitDraftId":"v1","items":[]}',
        )),
        throwsA(isA<StateError>()),
      );
    });

    test('visit_submit flush resolves the remote id and posts to /visits/:id/submit', () async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);
      await db.into(db.visitDrafts).insert(_visitDraft('v1', remoteId: 'remote-v1'));

      final paths = <String>[];
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
        ..httpClientAdapter = _FakeAdapter(200, '{}')
        ..interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
          paths.add(options.path);
          handler.next(options);
        }));
      final flusher = HttpQueueFlusher(db: db, dio: dio);

      await flusher.flush(_queueItem(
        entityType: 'visit_submit',
        entityId: 'submit-1',
        payloadJson: '{"visitDraftId":"v1"}',
      ));

      expect(paths.single, '/visits/remote-v1/submit');
    });

    test('visibility flush resolves the remote id and posts to /visibility', () async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);
      await db.into(db.visitDrafts).insert(_visitDraft('v1', remoteId: 'remote-v1'));

      final captured = <dynamic>[];
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
        ..httpClientAdapter = _FakeAdapter(201, '{}')
        ..interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
          captured.add(options.data);
          handler.next(options);
        }));
      final flusher = HttpQueueFlusher(db: db, dio: dio);

      await flusher.flush(_queueItem(
        entityType: 'visibility',
        entityId: 'vis-1',
        payloadJson: '{"visitDraftId":"v1","planogramCompliancePct":80,"highTrafficPass":true}',
      ));

      final body = captured.single as Map;
      expect(body['visitId'], 'remote-v1');
      expect(body['planogramCompliancePct'], 80);
      expect(body.containsKey('visitDraftId'), isFalse);
    });

    test('throws UnimplementedError for an unhandled entity type', () async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);
      final flusher = HttpQueueFlusher(db: db, dio: Dio());
      await expectLater(
        flusher.flush(_queueItem(entityType: 'pricing', entityId: 'p1', payloadJson: '{}')),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}

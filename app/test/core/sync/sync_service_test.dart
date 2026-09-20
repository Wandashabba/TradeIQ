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

/// Records exactly which entities were sent, which is the question the
/// ownership tests ask: not "did it flush" but "whose".
class RecordingFlusher implements QueueFlusher {
  final List<String> sent = [];

  @override
  Future<void> flush(SyncQueueItem item) async => sent.add(item.entityId);
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

VisitDraftsCompanion _visitDraft(String id, {String? remoteId}) =>
    VisitDraftsCompanion.insert(
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
}) => SyncQueueItem(
  id: id,
  entityType: entityType,
  entityId: entityId,
  payloadJson: payloadJson,
  queuedAt: DateTime(2026, 1, 1),
  synced: false,
  attempts: 0,
);

void main() {
  // The outbox is owned: rows are stamped with whoever queued them and only
  // that user's rows flush. Tests therefore need somebody signed in, exactly
  // as the app does.
  setUp(() => currentLocalUserId = 'user-a');
  tearDown(() => currentLocalUserId = null);

  test('flushPending marks queued items as synced', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db.enqueue(
      entityType: 'visit',
      entityId: 'visit-1',
      payloadJson: '{}',
    );

    final flusher = NoopFlusher();
    final service = SyncService(db: db, flusher: flusher);
    await service.flushPending();

    expect(flusher.callCount, 1);
    final rows = await db.select(db.syncQueueItems).get();
    expect(rows.first.synced, isTrue);
  });

  test('onItemSynced hears about items that sent, never ones that failed', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db.enqueue(entityType: 'visit', entityId: 'visit-1', payloadJson: '{}');
    await db.enqueue(
      entityType: 'visit_submit',
      entityId: 'visit-2',
      payloadJson: '{}',
    );

    final heard = <String>[];
    await SyncService(
      db: db,
      flusher: _FailFirstFlusher(),
      onItemSynced: (item) => heard.add(item.entityId),
    ).flushPending();

    expect(heard, ['visit-2']);
  });

  test('a throwing onItemSynced does not stop the queue', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db.enqueue(entityType: 'visit', entityId: 'visit-a', payloadJson: '{}');
    await db.enqueue(entityType: 'visit', entityId: 'visit-b', payloadJson: '{}');

    final flusher = RecordingFlusher();
    await SyncService(
      db: db,
      flusher: flusher,
      onItemSynced: (_) => throw StateError('listener broke'),
    ).flushPending();

    expect(flusher.sent, ['visit-a', 'visit-b']);
    final rows = await db.select(db.syncQueueItems).get();
    expect(rows.every((r) => r.synced), isTrue);
  });

  test(
    'flushPending does not let one failing item block the rest of the queue',
    () async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);
      await db.enqueue(
        entityType: 'visit',
        entityId: 'visit-1',
        payloadJson: '{}',
      );
      await db.enqueue(
        entityType: 'visit',
        entityId: 'visit-2',
        payloadJson: '{}',
      );

      final flusher = _FailFirstFlusher();
      final service = SyncService(db: db, flusher: flusher);
      await service.flushPending();

      expect(flusher.attempted, ['visit-1', 'visit-2']);
      final rows = await db.select(db.syncQueueItems).get();
      final byEntityId = {for (final row in rows) row.entityId: row.synced};
      expect(byEntityId['visit-1'], isFalse);
      expect(byEntityId['visit-2'], isTrue);
    },
  );

  group('HttpQueueFlusher', () {
    test(
      'posts /visits and records the server id on the visit draft',
      () async {
        final db = LocalDb(NativeDatabase.memory());
        addTearDown(db.close);
        await db.into(db.visitDrafts).insert(_visitDraft('visit-1'));

        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
          ..httpClientAdapter = _FakeAdapter(201);
        final flusher = HttpQueueFlusher(db: db, dio: dio);

        await flusher.flush(
          _queueItem(
            entityType: 'visit',
            entityId: 'visit-1',
            payloadJson: '{"outletId":"o1","lat":1.0,"lng":2.0}',
          ),
        );

        final draft = await (db.select(
          db.visitDrafts,
        )..where((t) => t.id.equals('visit-1'))).getSingle();
        expect(draft.remoteId, 'remote-visit-1');
      },
    );

    test('throws when the backend rejects the check-in with 422', () async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
        ..httpClientAdapter = _FakeAdapter(422);
      final flusher = HttpQueueFlusher(db: db, dio: dio);

      await expectLater(
        flusher.flush(
          _queueItem(
            entityType: 'visit',
            entityId: 'visit-1',
            payloadJson: '{"outletId":"o1","lat":1.0,"lng":2.0}',
          ),
        ),
        throwsA(isA<DioException>()),
      );
    });

    test(
      'stock flush resolves the remote visit id and posts to /stock',
      () async {
        final db = LocalDb(NativeDatabase.memory());
        addTearDown(db.close);
        await db
            .into(db.visitDrafts)
            .insert(_visitDraft('v1', remoteId: 'remote-v1'));

        final captured = <dynamic>[];
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
          ..httpClientAdapter = _FakeAdapter(201, '{}')
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                captured.add(options.data);
                handler.next(options);
              },
            ),
          );
        final flusher = HttpQueueFlusher(db: db, dio: dio);

        await flusher.flush(
          _queueItem(
            entityType: 'stock',
            entityId: 'batch-1',
            payloadJson: '{"visitDraftId":"v1","items":[{"skuId":"s1"}]}',
          ),
        );

        expect(captured, hasLength(1));
        expect((captured.first as Map)['visitId'], 'remote-v1');
      },
    );

    test('stock flush throws when the visit has not synced yet', () async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);
      await db.into(db.visitDrafts).insert(_visitDraft('v1')); // remoteId null

      final flusher = HttpQueueFlusher(db: db, dio: Dio());
      await expectLater(
        flusher.flush(
          _queueItem(
            entityType: 'stock',
            entityId: 'batch-1',
            payloadJson: '{"visitDraftId":"v1","items":[]}',
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'photo flush resolves the remote visit id and posts to /photos',
      () async {
        final db = LocalDb(NativeDatabase.memory());
        addTearDown(db.close);
        await db
            .into(db.visitDrafts)
            .insert(_visitDraft('v1', remoteId: 'remote-v1'));

        final captured = <dynamic>[];
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
          ..httpClientAdapter = _FakeAdapter(201, '{"id":"p1","url":"u"}')
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                captured.add(options.data);
                handler.next(options);
              },
            ),
          );
        final flusher = HttpQueueFlusher(db: db, dio: dio);

        await flusher.flush(
          _queueItem(
            entityType: 'photo',
            entityId: 'photo-1',
            payloadJson:
                '{"visitDraftId":"v1","section":"visibility","dataUrl":"data:image/jpeg;base64,AAA",'
                '"gpsTag":{},"timestamp":"2026-07-13T09:00:00.000Z"}',
          ),
        );

        expect(captured, hasLength(1));
        final body = captured.first as Map;
        expect(body['visitId'], 'remote-v1');
        expect(body['section'], 'visibility');
        expect(body['dataUrl'], 'data:image/jpeg;base64,AAA');
        // visitDraftId is a local id — it must never leak to the server.
        expect(body.containsKey('visitDraftId'), isFalse);
      },
    );

    test(
      'photo flush waits for its visit, so an offline capture is not lost',
      () async {
        final db = LocalDb(NativeDatabase.memory());
        addTearDown(db.close);
        await db
            .into(db.visitDrafts)
            .insert(_visitDraft('v1')); // remoteId null

        // A shelf photo taken in a dead aisle stays queued until the visit that
        // owns it exists on the server — it is retried, never dropped.
        final flusher = HttpQueueFlusher(db: db, dio: Dio());
        await expectLater(
          flusher.flush(
            _queueItem(
              entityType: 'photo',
              entityId: 'photo-1',
              payloadJson:
                  '{"visitDraftId":"v1","section":"pricing","dataUrl":"x","gpsTag":{},"timestamp":"t"}',
            ),
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'visit_submit flush resolves the remote id and posts to /visits/:id/submit',
      () async {
        final db = LocalDb(NativeDatabase.memory());
        addTearDown(db.close);
        await db
            .into(db.visitDrafts)
            .insert(_visitDraft('v1', remoteId: 'remote-v1'));

        final paths = <String>[];
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
          ..httpClientAdapter = _FakeAdapter(200, '{}')
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                paths.add(options.path);
                handler.next(options);
              },
            ),
          );
        final flusher = HttpQueueFlusher(db: db, dio: dio);

        await flusher.flush(
          _queueItem(
            entityType: 'visit_submit',
            entityId: 'submit-1',
            payloadJson: '{"visitDraftId":"v1"}',
          ),
        );

        expect(paths.single, '/visits/remote-v1/submit');
      },
    );

    test(
      'visibility flush resolves the remote id and posts to /visibility',
      () async {
        final db = LocalDb(NativeDatabase.memory());
        addTearDown(db.close);
        await db
            .into(db.visitDrafts)
            .insert(_visitDraft('v1', remoteId: 'remote-v1'));

        final captured = <dynamic>[];
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
          ..httpClientAdapter = _FakeAdapter(201, '{}')
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                captured.add(options.data);
                handler.next(options);
              },
            ),
          );
        final flusher = HttpQueueFlusher(db: db, dio: dio);

        await flusher.flush(
          _queueItem(
            entityType: 'visibility',
            entityId: 'vis-1',
            payloadJson:
                '{"visitDraftId":"v1","planogramCompliancePct":80,"highTrafficPass":true}',
          ),
        );

        final body = captured.single as Map;
        expect(body['visitId'], 'remote-v1');
        expect(body['planogramCompliancePct'], 80);
        expect(body.containsKey('visitDraftId'), isFalse);
      },
    );

    test(
      'pricing flush resolves the remote id and posts items to /pricing',
      () async {
        final db = LocalDb(NativeDatabase.memory());
        addTearDown(db.close);
        await db
            .into(db.visitDrafts)
            .insert(_visitDraft('v1', remoteId: 'remote-v1'));

        final captured = <dynamic>[];
        final paths = <String>[];
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
          ..httpClientAdapter = _FakeAdapter(201, '{}')
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                captured.add(options.data);
                paths.add(options.path);
                handler.next(options);
              },
            ),
          );
        final flusher = HttpQueueFlusher(db: db, dio: dio);

        await flusher.flush(
          _queueItem(
            entityType: 'pricing',
            entityId: 'p1',
            payloadJson:
                '{"visitDraftId":"v1","items":[{"skuId":"s1","priceActual":19.99}]}',
          ),
        );

        expect(paths.single, '/pricing');
        final body = captured.single as Map;
        expect(body['visitId'], 'remote-v1');
        expect(body['items'], hasLength(1));
      },
    );

    test('risk flush resolves the remote id and posts risks to /risks', () async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);
      await db
          .into(db.visitDrafts)
          .insert(_visitDraft('v1', remoteId: 'remote-v1'));

      final captured = <dynamic>[];
      final paths = <String>[];
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
        ..httpClientAdapter = _FakeAdapter(201, '{}')
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              captured.add(options.data);
              paths.add(options.path);
              handler.next(options);
            },
          ),
        );
      final flusher = HttpQueueFlusher(db: db, dio: dio);

      await flusher.flush(
        _queueItem(
          entityType: 'risk',
          entityId: 'r1',
          payloadJson:
              '{"visitDraftId":"v1","risks":[{"flagType":"stockout","severity":"high","note":"empty shelf"}]}',
        ),
      );

      expect(paths.single, '/risks');
      final body = captured.single as Map;
      expect(body['visitId'], 'remote-v1');
      expect(body['risks'], hasLength(1));
    });

    test(
      'task flush resolves the remote id and posts the task fields to /tasks',
      () async {
        final db = LocalDb(NativeDatabase.memory());
        addTearDown(db.close);
        await db
            .into(db.visitDrafts)
            .insert(_visitDraft('v1', remoteId: 'remote-v1'));

        final captured = <dynamic>[];
        final paths = <String>[];
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
          ..httpClientAdapter = _FakeAdapter(201, '{}')
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                captured.add(options.data);
                paths.add(options.path);
                handler.next(options);
              },
            ),
          );
        final flusher = HttpQueueFlusher(db: db, dio: dio);

        await flusher.flush(
          _queueItem(
            entityType: 'task',
            entityId: 't1',
            payloadJson:
                '{"visitDraftId":"v1","outletId":"o1","findingType":"damage","requiredFix":"replace strip","priority":"normal"}',
          ),
        );

        expect(paths.single, '/tasks');
        final body = captured.single as Map;
        expect(body['visitId'], 'remote-v1');
        expect(body['outletId'], 'o1');
        expect(body['priority'], 'normal');
        expect(body.containsKey('visitDraftId'), isFalse);
      },
    );

    test(
      'scorecard flush resolves the remote id and posts to /scorecards',
      () async {
        final db = LocalDb(NativeDatabase.memory());
        addTearDown(db.close);
        await db
            .into(db.visitDrafts)
            .insert(_visitDraft('v1', remoteId: 'remote-v1'));

        final captured = <dynamic>[];
        final paths = <String>[];
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
          ..httpClientAdapter = _FakeAdapter(201, '{}')
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                captured.add(options.data);
                paths.add(options.path);
                handler.next(options);
              },
            ),
          );
        final flusher = HttpQueueFlusher(db: db, dio: dio);

        await flusher.flush(
          _queueItem(
            entityType: 'scorecard',
            entityId: 'sc1',
            payloadJson: '{"visitDraftId":"v1"}',
          ),
        );

        expect(paths.single, '/scorecards');
        expect((captured.single as Map)['visitId'], 'remote-v1');
      },
    );

    test('throws UnimplementedError for an unhandled entity type', () async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);
      final flusher = HttpQueueFlusher(db: db, dio: Dio());
      // 'photo' used to stand in for "unhandled" here — it is wired now (#41),
      // so this needs a type the flusher genuinely does not know.
      await expectLater(
        flusher.flush(
          _queueItem(
            entityType: 'sasquatch',
            entityId: 'x1',
            payloadJson: '{}',
          ),
        ),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });

  group('outbox ownership', () {
    test('never flushes another user\'s queued captures', () async {
      // The bug this exists for: field devices are shared. Agent A queues a
      // visit offline, logs out, agent B logs in — and every one of A's
      // captures used to flush under B's token, landing on the server as work
      // B never did. A disclosure and an attribution bug at once.
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);

      currentLocalUserId = 'agent-a';
      await db.enqueue(
        entityType: 'visit',
        entityId: 'a-visit',
        payloadJson: '{}',
      );

      currentLocalUserId = 'agent-b';
      await db.enqueue(
        entityType: 'visit',
        entityId: 'b-visit',
        payloadJson: '{}',
      );

      final flusher = RecordingFlusher();
      await SyncService(db: db, flusher: flusher).flushPending();

      expect(flusher.sent, ['b-visit']);

      // A's row is untouched — still pending, still theirs. Not destroyed:
      // it flushes when A signs back in.
      final rows = await db.select(db.syncQueueItems).get();
      final a = rows.firstWhere((r) => r.entityId == 'a-visit');
      expect(a.synced, isFalse);
      expect(a.userId, 'agent-a');
    });

    test('flushes nothing when nobody is signed in', () async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);

      currentLocalUserId = 'agent-a';
      await db.enqueue(
        entityType: 'visit',
        entityId: 'a-visit',
        payloadJson: '{}',
      );

      currentLocalUserId = null;
      final flusher = RecordingFlusher();
      await SyncService(db: db, flusher: flusher).flushPending();

      expect(flusher.sent, isEmpty);
    });

    test('leaves pre-migration rows with no owner alone', () async {
      // Rows queued before the userId column existed cannot have their owner
      // recovered. Handing them to whoever signs in next is precisely the bug,
      // so they are never sent.
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);

      currentLocalUserId = null;
      await db.enqueue(
        entityType: 'visit',
        entityId: 'orphan',
        payloadJson: '{}',
      );

      currentLocalUserId = 'agent-a';
      final flusher = RecordingFlusher();
      await SyncService(db: db, flusher: flusher).flushPending();

      expect(flusher.sent, isEmpty);
    });
  });

  group('one capture at a time (#376)', () {
    /// Refuses exactly the photo, so a test can see that the rest of the
    /// queue was never touched and that the refused body is left as it was.
    Future<LocalDb> queue() async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);
      await db.enqueue(
        entityType: 'visit',
        entityId: 'draft-1',
        payloadJson: '{"outletId":"o1"}',
      );
      await db.enqueue(
        entityType: 'stock',
        entityId: 'stock-1',
        payloadJson: '{"visitDraftId":"draft-1","items":[]}',
      );
      await db.enqueue(
        entityType: 'photo',
        entityId: 'photo-1',
        payloadJson: '{"visitDraftId":"draft-1","data":"AAAA"}',
      );
      await db.enqueue(
        entityType: 'visit',
        entityId: 'draft-2',
        payloadJson: '{"outletId":"o2"}',
      );
      await db.enqueue(
        entityType: 'stock',
        entityId: 'stock-2',
        payloadJson: '{"visitDraftId":"draft-2","items":[]}',
      );
      return db;
    }

    Future<int> idOf(LocalDb db, String entityId) async =>
        (await (db.select(db.syncQueueItems)
                  ..where((t) => t.entityId.equals(entityId)))
                .getSingle())
            .id;

    test('sendOne sends that row and nothing else', () async {
      final db = await queue();
      final flusher = RecordingFlusher();
      final service = SyncService(db: db, flusher: flusher);

      final sent = await service.sendOne(await idOf(db, 'stock-2'));

      expect(sent, isTrue);
      expect(flusher.sent, ['stock-2']);
      final rows = await db.select(db.syncQueueItems).get();
      expect(
        rows.where((r) => r.synced).map((r) => r.entityId),
        ['stock-2'],
      );
    });

    test('a refused send records the failure and leaves the body alone', () async {
      final db = await queue();
      final id = await idOf(db, 'photo-1');
      final before = (await (db.select(db.syncQueueItems)
                ..where((t) => t.id.equals(id)))
              .getSingle())
          .payloadJson;

      final service = SyncService(db: db, flusher: _RefusingFlusher());
      expect(await service.sendOne(id), isFalse);

      final row = await (db.select(db.syncQueueItems)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(row.synced, isFalse);
      expect(row.attempts, 1);
      expect(row.lastError, 'sync:rejected:422');
      expect(
        row.payloadJson,
        before,
        reason: 'the app never repairs a rejected payload behind the agent',
      );
    });

    test('sendOne cannot reach another agent\'s row, or a sent one', () async {
      final db = await queue();
      final id = await idOf(db, 'stock-2');
      final flusher = RecordingFlusher();
      final service = SyncService(db: db, flusher: flusher);

      currentLocalUserId = 'somebody-else';
      expect(await service.sendOne(id), isFalse);
      currentLocalUserId = null;
      expect(await service.sendOne(id), isFalse);
      currentLocalUserId = 'user-a';
      expect(await service.sendOne(id), isTrue);
      expect(await service.sendOne(id), isFalse, reason: 'already sent');
      expect(flusher.sent, ['stock-2']);
    });

    test('discarding a section removes that row only', () async {
      final db = await queue();
      final service = SyncService(db: db, flusher: NoopFlusher());
      final id = await idOf(db, 'photo-1');

      expect(await service.dependentsOf(id), 0);
      expect(await service.discard(id), 1);

      final left = await db.select(db.syncQueueItems).get();
      expect(
        left.map((r) => r.entityId),
        ['draft-1', 'stock-1', 'draft-2', 'stock-2'],
      );
    });

    test(
      'discarding a visit takes its own captures with it, and no one else\'s',
      () async {
        // Without the cascade the stock count and the photo would wait for a
        // visit that will never arrive — for ever, with no way to clear them.
        final db = await queue();
        final service = SyncService(db: db, flusher: NoopFlusher());
        final id = await idOf(db, 'draft-1');

        expect(await service.dependentsOf(id), 2);
        expect(await service.discard(id), 3);

        final left = await db.select(db.syncQueueItems).get();
        expect(left.map((r) => r.entityId), ['draft-2', 'stock-2']);
      },
    );

    test('a discard cannot reach another agent\'s row, or a sent one', () async {
      final db = await queue();
      final service = SyncService(db: db, flusher: NoopFlusher());
      final id = await idOf(db, 'stock-2');

      currentLocalUserId = 'somebody-else';
      expect(await service.discard(id), 0);
      expect(await service.dependentsOf(id), 0);

      currentLocalUserId = 'user-a';
      await service.sendOne(id);
      expect(
        await service.discard(id),
        0,
        reason: 'a sent row is the receipt and is never thrown away',
      );
      expect((await db.select(db.syncQueueItems).get()).length, 5);
    });
  });
}

/// The server looked at the body and said no.
class _RefusingFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async {
    throw DioException(
      requestOptions: RequestOptions(path: '/photos'),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(path: '/photos'),
        statusCode: 422,
      ),
    );
  }
}

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';

// The client-questions section's outbox item (#122).
class _FakeAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{}',
    201,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

SyncQueueItem _item(Map<String, Object?> payload) => SyncQueueItem(
  id: 1,
  entityType: 'template_response',
  entityId: 'tr-1',
  payloadJson: jsonEncode(payload),
  queuedAt: DateTime(2026, 1, 1),
  synced: false,
  attempts: 0,
);

void main() {
  late LocalDb db;
  final requests = <RequestOptions>[];
  late HttpQueueFlusher flusher;

  setUp(() {
    db = LocalDb(NativeDatabase.memory());
    requests.clear();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
      ..httpClientAdapter = _FakeAdapter()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.next(options);
          },
        ),
      );
    flusher = HttpQueueFlusher(db: db, dio: dio);
  });

  tearDown(() => db.close());

  Future<void> syncedVisit() => db
      .into(db.visitDrafts)
      .insert(
        VisitDraftsCompanion.insert(
          id: 'v1',
          outletId: 'o1',
          checkinTs: DateTime(2026, 1, 1),
          checkinLat: 0,
          checkinLng: 0,
          geofencePass: true,
          remoteId: const Value('remote-v1'),
        ),
      );

  test('posts the answers to /template-responses against the server visit', () async {
    await syncedVisit();

    await flusher.flush(
      _item({
        'visitDraftId': 'v1',
        'templateId': 'tpl-1',
        'templateVersion': 3,
        'answers': {'standUp': true, 'facings': 4},
      }),
    );

    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(requests.single.path, '/template-responses');
    expect(requests.single.data, {
      'visitId': 'remote-v1',
      'templateId': 'tpl-1',
      'templateVersion': 3,
      'answers': {'standUp': true, 'facings': 4},
    });
    // The local draft id never leaks to the server.
    expect((requests.single.data as Map).containsKey('visitDraftId'), isFalse);
  });

  test('omits templateVersion when the item has none', () async {
    await syncedVisit();
    await flusher.flush(
      _item({'visitDraftId': 'v1', 'templateId': 'tpl-1', 'answers': <String, Object?>{}}),
    );
    expect((requests.single.data as Map).containsKey('templateVersion'), isFalse);
  });

  test('waits for its visit to sync, so an offline answer is not lost', () async {
    await db
        .into(db.visitDrafts)
        .insert(
          VisitDraftsCompanion.insert(
            id: 'v1',
            outletId: 'o1',
            checkinTs: DateTime(2026, 1, 1),
            checkinLat: 0,
            checkinLng: 0,
            geofencePass: true,
          ),
        );

    await expectLater(
      flusher.flush(
        _item({'visitDraftId': 'v1', 'templateId': 'tpl-1', 'answers': <String, Object?>{}}),
      ),
      throwsA(isA<StateError>()),
    );
    expect(requests, isEmpty);
  });
}

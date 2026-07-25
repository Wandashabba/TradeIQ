import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';

class _RecordingFlusher implements QueueFlusher {
  final flushed = <SyncQueueItem>[];

  @override
  Future<void> flush(SyncQueueItem item) async => flushed.add(item);
}

void main() {
  test('PhotoUploadResult.fromJson parses id and url', () {
    final result = PhotoUploadResult.fromJson(const {
      'id': 'photo-1',
      'url': 'https://cdn.example.com/photo-1.png',
    });

    expect(result.id, 'photo-1');
    expect(result.url, 'https://cdn.example.com/photo-1.png');
  });

  group('DioPhotosRepository', () {
    Dio client(_ThumbAdapter adapter) =>
        Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
          ..httpClientAdapter = adapter;

    test(
      'listPhotos GETs /photos?visitId and parses the rows in order',
      () async {
        final adapter = _ThumbAdapter();
        final repo = DioPhotosRepository(client: client(adapter));

        final photos = await repo.listPhotos('v1');

        expect(adapter.requests.single.path, '/photos');
        expect(adapter.requests.single.queryParameters, {'visitId': 'v1'});
        // The backend orders newest-first; the repo must not re-sort.
        expect(photos.map((p) => p.id).toList(), ['p-new', 'p-old']);
        expect(photos.first.section, 'shelf');
        expect(photos.first.url, 'data:image/png;base64,AQID');
      },
    );

    test('thumbnailBytes GETs /photos/:id/thumbnail as raw bytes', () async {
      final adapter = _ThumbAdapter();
      final repo = DioPhotosRepository(client: client(adapter));

      final bytes = await repo.thumbnailBytes('p1');

      expect(adapter.requests.single.path, '/photos/p1/thumbnail');
      expect(adapter.requests.single.responseType, ResponseType.bytes);
      expect(bytes, Uint8List.fromList([1, 2, 3, 4]));
    });

    test(
      'thumbnailBytes caches per photoId — one request per photo, ever',
      () async {
        final adapter = _ThumbAdapter();
        final repo = DioPhotosRepository(client: client(adapter));

        await repo.thumbnailBytes('p1');
        await repo.thumbnailBytes('p1');
        expect(adapter.requests, hasLength(1));

        // A different photo is a different cache entry, not a stale hit.
        await repo.thumbnailBytes('p2');
        expect(adapter.requests, hasLength(2));
      },
    );

    test(
      'a failed thumbnail fetch is not cached — the retry really retries',
      () async {
        final adapter = _ThumbAdapter(failFirst: true);
        final repo = DioPhotosRepository(client: client(adapter));

        await expectLater(
          repo.thumbnailBytes('p1'),
          throwsA(isA<DioException>()),
        );
        final bytes = await repo.thumbnailBytes('p1');

        expect(bytes, Uint8List.fromList([1, 2, 3, 4]));
        expect(adapter.requests, hasLength(2));
      },
    );
  });

  group('DriftQueuedPhotosRepository', () {
    test('queues a section photo against the LOCAL visit draft id', () async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);
      final flusher = _RecordingFlusher();
      final repo = DriftQueuedPhotosRepository(
        db: db,
        syncService: SyncService(db: db, flusher: flusher),
      );

      await repo.queuePhoto(
        visitDraftId: 'local-v1',
        section: 'visibility',
        dataUrl: 'data:image/jpeg;base64,AQID',
      );

      final queued = await db.select(db.syncQueueItems).get();
      expect(queued, hasLength(1));
      expect(queued.single.entityType, 'photo');

      final payload =
          jsonDecode(queued.single.payloadJson) as Map<String, dynamic>;
      // The visit may not exist on the server yet — the photo carries the local
      // draft id and the flusher resolves it at send time.
      expect(payload['visitDraftId'], 'local-v1');
      expect(payload['section'], 'visibility');
      expect(payload['dataUrl'], 'data:image/jpeg;base64,AQID');
      expect(payload['timestamp'], isNotEmpty);
    });

    test('a photo taken offline survives a failing flush', () async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);

      // The flush blows up (no network). The capture must still be on disk —
      // an agent who walks out of the store must not lose their evidence.
      final repo = DriftQueuedPhotosRepository(
        db: db,
        syncService: SyncService(db: db, flusher: _ThrowingFlusher()),
      );

      await repo.queuePhoto(
        visitDraftId: 'local-v1',
        section: 'pricing',
        dataUrl: 'data:image/jpeg;base64,AQID',
      );

      final queued = await db.select(db.syncQueueItems).get();
      expect(queued, hasLength(1));
      expect(queued.single.synced, isFalse);
    });
  });
}

class _ThrowingFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async => throw Exception('offline');
}

/// Serves GET /photos (a two-row visit, newest first, as the backend orders
/// it) and GET /photos/:id/thumbnail (4 raw JPEG-stand-in bytes), recording
/// every request so the tests can assert paths, query and count.
class _ThumbAdapter implements HttpClientAdapter {
  _ThumbAdapter({this.failFirst = false});

  final bool failFirst;
  final requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (failFirst && requests.length == 1) {
      return ResponseBody.fromString(
        '{"error":"boom"}',
        500,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.path == '/photos') {
      return ResponseBody.fromString(
        jsonEncode([
          {
            'id': 'p-new',
            'visitId': 'v1',
            'section': 'shelf',
            'url': 'data:image/png;base64,AQID',
            'timestamp': '2026-07-22T10:00:00.000Z',
          },
          {
            'id': 'p-old',
            'visitId': 'v1',
            'section': 'shelf',
            'url': 'data:image/png;base64,BAUG',
            'timestamp': '2026-07-21T10:00:00.000Z',
          },
        ]),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromBytes(
      Uint8List.fromList([1, 2, 3, 4]),
      200,
      headers: {
        Headers.contentTypeHeader: ['image/jpeg'],
      },
    );
  }
}

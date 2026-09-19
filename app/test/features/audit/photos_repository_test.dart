import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/location/location_service.dart';
import 'package:tradeiq_app/core/location/photo_geotagger.dart';
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

    test('uploadMessageAttachment POSTs purpose + dataUrl with no visit and '
        'returns the photo id', () async {
      final adapter = _ThumbAdapter();
      final repo = DioPhotosRepository(client: client(adapter));

      final id = await repo.uploadMessageAttachment(
        'data:image/png;base64,AQID',
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/photos');
      final data = request.data as Map<String, dynamic>;
      expect(data['purpose'], 'message_attachment');
      expect(data['dataUrl'], 'data:image/png;base64,AQID');
      // The attachment shape: no visit, no section — the server rejects a
      // message attachment that names a visit.
      expect(data.containsKey('visitId'), isFalse);
      expect(data.containsKey('section'), isFalse);
      expect(DateTime.tryParse(data['timestamp'] as String), isNotNull);
      expect(id, 'att-1');
    });

    test('imageBytes GETs /photos/:id/image as raw bytes, uncached', () async {
      final adapter = _ThumbAdapter();
      final repo = DioPhotosRepository(client: client(adapter));

      final first = await repo.imageBytes('p1');
      await repo.imageBytes('p1');

      expect(adapter.requests.first.path, '/photos/p1/image');
      expect(adapter.requests.first.responseType, ResponseType.bytes);
      expect(first, Uint8List.fromList([1, 2, 3, 4]));
      // Originals are not held in the thumbnail LRU.
      expect(adapter.requests, hasLength(2));
    });

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

    test('the thumbnail cache is LRU-bounded at 200 — a hit survives eviction, '
        'the least-recent entry does not', () async {
      final adapter = _ThumbAdapter();
      final repo = DioPhotosRepository(client: client(adapter));

      // Fill to the cap, then touch p0 so it is the most recently used.
      for (var i = 0; i < 200; i++) {
        await repo.thumbnailBytes('p$i');
      }
      await repo.thumbnailBytes('p0'); // hit — no request
      expect(adapter.requests, hasLength(200));

      // One past the cap evicts the LEAST recent — p1, not the
      // freshly-touched p0.
      await repo.thumbnailBytes('p200');
      expect(adapter.requests, hasLength(201));

      await repo.thumbnailBytes('p0'); // survived the eviction
      expect(adapter.requests, hasLength(201));

      await repo.thumbnailBytes('p1'); // evicted → a real refetch
      expect(adapter.requests, hasLength(202));
    });
  });

  test('thumbnailBytesProvider is autoDispose — the repo map, not the provider '
      'element, is the survivor cache', () async {
    final repo = _CountingPhotosRepository();
    final container = ProviderContainer(
      overrides: [photosRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final sub = container.listen(thumbnailBytesProvider('p1'), (_, _) {});
    await container.read(thumbnailBytesProvider('p1').future);
    expect(repo.calls, 1);

    sub.close();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    await container.read(thumbnailBytesProvider('p1').future);
    expect(
      repo.calls,
      2,
      reason:
          'a released provider element must not retain bytes — the '
          'repository LRU is the one bounded cache',
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

    group('geotag and capture time (#310)', () {
      final shutter = DateTime.utc(2026, 9, 15, 10, 4, 5);

      Future<(LocalDb, DriftQueuedPhotosRepository)> setUpQueue() async {
        final db = LocalDb(NativeDatabase.memory());
        addTearDown(db.close);
        await db
            .into(db.visitDrafts)
            .insert(
              VisitDraftsCompanion.insert(
                id: 'local-v1',
                outletId: 'o1',
                checkinTs: DateTime(2026, 9, 15),
                checkinLat: 0,
                checkinLng: 0,
                geofencePass: true,
                remoteId: const Value('remote-v1'),
              ),
            );
        final repo = DriftQueuedPhotosRepository(
          db: db,
          syncService: SyncService(db: db, flusher: _RecordingFlusher()),
        );
        return (db, repo);
      }

      /// Sends the one queued row the way the outbox does, hours "later", and
      /// returns the POST /photos body.
      Future<Map<String, dynamic>> sendQueued(LocalDb db) async {
        final row = (await db.select(db.syncQueueItems).get()).single;
        final adapter = _ThumbAdapter();
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
          ..httpClientAdapter = adapter;
        await HttpQueueFlusher(db: db, dio: dio).flush(row);
        expect(adapter.requests.single.path, '/photos');
        return adapter.requests.single.data as Map<String, dynamic>;
      }

      test(
        'the gpsTag and shutter time survive the outbox to POST /photos',
        () async {
          final (db, repo) = await setUpQueue();
          final tag = gpsTagFor(
            LocationGranted(-26.2041, 28.0473, accuracy: 9, fixedAt: shutter),
          );

          await repo.queuePhoto(
            visitDraftId: 'local-v1',
            section: 'stock',
            dataUrl: 'data:image/jpeg;base64,AQID',
            gpsTag: tag,
            // Handed over in the device zone; stored and sent as UTC.
            capturedAt: shutter.toLocal(),
          );

          final body = await sendQueued(db);
          expect(body['visitId'], 'remote-v1');
          expect(body['section'], 'stock');
          // The shape fraud.service.ts readCoords takes: numeric lat/lng.
          expect(body['gpsTag'], {
            'lat': -26.2041,
            'lng': 28.0473,
            'accuracy': 9.0,
            'fixedAt': '2026-09-15T10:04:05.000Z',
          });
          expect(body['timestamp'], '2026-09-15T10:04:05.000Z');
        },
      );

      test('a photo taken with location refused still uploads, with an empty '
          'gpsTag object', () async {
        final (db, repo) = await setUpQueue();

        await repo.queuePhoto(
          visitDraftId: 'local-v1',
          section: 'visibility',
          dataUrl: 'data:image/jpeg;base64,AQID',
          capturedAt: shutter,
        );

        final body = await sendQueued(db);
        // POST /photos requires gpsTag to be an object; empty is "no evidence".
        expect(body['gpsTag'], <String, dynamic>{});
        expect(body['timestamp'], '2026-09-15T10:04:05.000Z');
      });

      test(
        'with no capture time given, the timestamp is still UTC-marked',
        () async {
          final (db, repo) = await setUpQueue();

          await repo.queuePhoto(
            visitDraftId: 'local-v1',
            section: 'pricing',
            dataUrl: 'data:image/jpeg;base64,AQID',
          );

          final body = await sendQueued(db);
          expect(body['timestamp'] as String, endsWith('Z'));
        },
      );
    });
  });
}

class _ThrowingFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async => throw Exception('offline');
}

/// Counts thumbnail fetches — for pinning that the provider element itself
/// holds no second cache.
class _CountingPhotosRepository implements PhotosRepository {
  int calls = 0;

  @override
  Future<Uint8List> thumbnailBytes(String photoId) async {
    calls++;
    return Uint8List.fromList([1]);
  }

  @override
  Future<List<VisitPhoto>> listPhotos(String visitId) async => const [];

  @override
  Future<PhotoUploadResult> uploadPhoto({
    required String visitId,
    required String section,
    required String dataUrl,
    required Map<String, dynamic> gpsTag,
    required String timestamp,
  }) async => throw UnimplementedError();

  @override
  Future<String> uploadMessageAttachment(String dataUrl) async =>
      throw UnimplementedError();

  @override
  Future<Uint8List> imageBytes(String photoId) async =>
      throw UnimplementedError();
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
    if (options.path == '/photos' && options.method == 'POST') {
      // A message-attachment upload answers with metadata and links only.
      return ResponseBody.fromString(
        jsonEncode({
          'id': 'att-1',
          'section': 'message_attachment',
          'thumbnailUrl': '/photos/att-1/thumbnail',
          'imageUrl': '/photos/att-1/image',
        }),
        201,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.path == '/photos') {
      return ResponseBody.fromString(
        // The shared {data, nextCursor} envelope, as GET /photos now answers.
        jsonEncode({
          'data': [
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
          ],
          'nextCursor': null,
        }),
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

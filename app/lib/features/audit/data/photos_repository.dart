import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart' as api;
import '../../../core/network/paginated_response.dart';
import '../../../core/storage/local_db.dart';
import '../../../core/sync/sync_service.dart';

class PhotoUploadResult {
  const PhotoUploadResult({required this.id, required this.url});
  final String id;
  final String url;

  factory PhotoUploadResult.fromJson(Map<String, dynamic> json) =>
      PhotoUploadResult(id: json['id'] as String, url: json['url'] as String);
}

/// One photo row from `GET /photos?visitId` — the backend returns them
/// newest-first, and callers rely on that order (the newest photo is the
/// evidence a manager wants to see).
class VisitPhoto {
  const VisitPhoto({
    required this.id,
    required this.section,
    required this.url,
    required this.timestamp,
  });
  final String id;
  final String section;

  /// Phase-1 stores the photo inline: this is a base64 data URL, not a link.
  final String url;
  final String timestamp;

  factory VisitPhoto.fromJson(Map<String, dynamic> json) => VisitPhoto(
    id: json['id'] as String,
    section: json['section'] as String,
    url: json['url'] as String,
    timestamp: json['timestamp'] as String,
  );
}

/// Direct photo traffic — used where the caller already holds a *server*
/// visit id and is online, i.e. a manager on the console.
abstract class PhotosRepository {
  Future<PhotoUploadResult> uploadPhoto({
    required String visitId,
    required String section,
    required String dataUrl,
    required Map<String, dynamic> gpsTag,
    required String timestamp,
  });

  /// `GET /photos?visitId` — newest first, as the backend orders it.
  Future<List<VisitPhoto>> listPhotos(String visitId);

  /// `GET /photos/:id/thumbnail` — the ≤60KB JPEG, fetched as BYTES through
  /// the authed client. `Image.network` cannot send the Authorization header
  /// on web, so the bytes route is the only honest one.
  Future<Uint8List> thumbnailBytes(String photoId);
}

class DioPhotosRepository implements PhotosRepository {
  /// Injectable for tests; defaults to the app's authed client.
  DioPhotosRepository({Dio? client}) : _client = client ?? api.dio;

  final Dio _client;

  /// Thumbnails by photo id, LRU-bounded. Photos are immutable (never edited
  /// in place — the backend serves them `immutable`), so a cached thumbnail
  /// never goes stale; the bound exists because bytes are ~60KB each and a
  /// session never needs unbounded history. This map is the ONE survivor
  /// cache: it outlives widget rebuilds and the autoDispose provider
  /// elements, so a tasks refresh never re-downloads a visible thumbnail.
  ///
  /// LRU via insertion order (Dart maps are linked): a hit is re-inserted at
  /// the tail, an overflow evicts the head — the same delete+set-on-hit
  /// design as the backend's thumbnail cache (thumbnails.ts).
  final _thumbnailCache = <String, Uint8List>{};

  /// ~12MB worst case at the backend's ≤60KB thumbnail cap.
  static const thumbnailCacheCap = 200;

  @override
  Future<PhotoUploadResult> uploadPhoto({
    required String visitId,
    required String section,
    required String dataUrl,
    required Map<String, dynamic> gpsTag,
    required String timestamp,
  }) async {
    final response = await _client.post(
      '/photos',
      data: {
        'visitId': visitId,
        'section': section,
        'dataUrl': dataUrl,
        'gpsTag': gpsTag,
        'timestamp': timestamp,
      },
    );
    return PhotoUploadResult.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<VisitPhoto>> listPhotos(String visitId) async {
    final response = await _client.get(
      '/photos',
      queryParameters: {'visitId': visitId},
    );
    // The shared `{data, nextCursor}` envelope. Only the first page is read:
    // this backs the evidence dialog, which shows one visit's photos — a
    // handful — and a visit that somehow exceeded a page would be a data
    // problem to investigate, not a list to keep scrolling.
    final page = PaginatedResponse<VisitPhoto>.fromJson(
      response.data as Map<String, dynamic>,
      (json) => VisitPhoto.fromJson(json as Map<String, dynamic>),
    );
    return page.data;
  }

  @override
  Future<Uint8List> thumbnailBytes(String photoId) async {
    final cached = _thumbnailCache.remove(photoId);
    if (cached != null) {
      _thumbnailCache[photoId] = cached; // re-insert = most recently used
      return cached;
    }

    // Only a SUCCESSFUL fetch is cached — a throw propagates uncached, so a
    // retry after a dead-signal moment actually retries.
    final response = await _client.get<List<int>>(
      '/photos/$photoId/thumbnail',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(response.data!);
    _thumbnailCache[photoId] = bytes;
    if (_thumbnailCache.length > thumbnailCacheCap) {
      _thumbnailCache.remove(_thumbnailCache.keys.first);
    }
    return bytes;
  }
}

final photosRepositoryProvider = Provider<PhotosRepository>(
  (ref) => DioPhotosRepository(),
);

/// Thumbnail bytes by photo id, for the worklist thumbs. The family dedupes
/// concurrent listeners per id; autoDispose releases each element with its
/// last listener — the repository's bounded LRU (above) is the one survivor
/// cache, so re-listening after a dispose is a synchronous map hit, not a
/// download. A permanent family element per photo would be a second,
/// UNbounded cache growing for the life of the session.
final thumbnailBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, String>(
      (ref, photoId) =>
          ref.watch(photosRepositoryProvider).thumbnailBytes(photoId),
    );

/// The photos of one visit, newest first. autoDispose: fetched lazily when
/// the evidence dialog opens, released when it closes.
/// Framework auto-retry is OFF here, deliberately: Riverpod 3 holds a
/// failing provider in `AsyncLoading` through its retry backoff, which in a
/// modal dialog means a manager staring at a spinner while the failure is
/// silently re-tried for seconds. A watched dialog gets the truth
/// immediately — the error arm and its Retry button (evidence_thumb.dart)
/// are the recovery path. The thumbnail provider above keeps the default:
/// background chrome can retry quietly.
final visitPhotosProvider = FutureProvider.autoDispose
    .family<List<VisitPhoto>, String>(
      (ref, visitId) => ref.watch(photosRepositoryProvider).listPhotos(visitId),
      retry: (_, _) => null,
    );

/// Offline-first upload — used by the field agent mid-audit.
///
/// A section photo cannot just POST: the visit it belongs to is created offline
/// with a *client* id and may not have synced yet. So the photo joins the same
/// outbox as every other capture, carrying the local `visitDraftId`, and the
/// flusher resolves it to the server visit id at send time (see
/// `core/sync/sync_service.dart`). An agent in a dead aisle still gets to file
/// their evidence.
abstract class QueuedPhotosRepository {
  Future<void> queuePhoto({
    required String visitDraftId,
    required String section,
    required String dataUrl,
    Map<String, dynamic> gpsTag,
  });
}

class DriftQueuedPhotosRepository implements QueuedPhotosRepository {
  DriftQueuedPhotosRepository({required this.db, required this.syncService});

  final LocalDb db;
  final SyncService syncService;
  static const _uuid = Uuid();

  @override
  Future<void> queuePhoto({
    required String visitDraftId,
    required String section,
    required String dataUrl,
    Map<String, dynamic> gpsTag = const {},
  }) async {
    await db.enqueue(
      entityType: 'photo',
      entityId: _uuid.v4(),
      payloadJson: jsonEncode({
        'visitDraftId': visitDraftId,
        'section': section,
        'dataUrl': dataUrl,
        'gpsTag': gpsTag,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );

    try {
      await syncService.flushPending();
    } catch (_) {
      // Best-effort: the photo is queued and retried on the next flush.
    }
  }
}

final queuedPhotosRepositoryProvider = Provider<QueuedPhotosRepository>(
  (ref) => DriftQueuedPhotosRepository(
    db: ref.read(localDbProvider),
    syncService: ref.read(syncServiceProvider),
  ),
);

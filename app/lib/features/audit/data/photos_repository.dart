import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/local_db.dart';
import '../../../core/sync/sync_service.dart';

class PhotoUploadResult {
  const PhotoUploadResult({
    required this.id,
    required this.url,
  });
  final String id;
  final String url;

  factory PhotoUploadResult.fromJson(Map<String, dynamic> json) =>
      PhotoUploadResult(
        id: json['id'] as String,
        url: json['url'] as String,
      );
}

/// Direct upload — used where the caller already holds a *server* visit id and
/// is online, i.e. a manager closing a task from the console.
abstract class PhotosRepository {
  Future<PhotoUploadResult> uploadPhoto({
    required String visitId,
    required String section,
    required String dataUrl,
    required Map<String, dynamic> gpsTag,
    required String timestamp,
  });
}

class DioPhotosRepository implements PhotosRepository {
  @override
  Future<PhotoUploadResult> uploadPhoto({
    required String visitId,
    required String section,
    required String dataUrl,
    required Map<String, dynamic> gpsTag,
    required String timestamp,
  }) async {
    final response = await dio.post('/photos', data: {
      'visitId': visitId,
      'section': section,
      'dataUrl': dataUrl,
      'gpsTag': gpsTag,
      'timestamp': timestamp,
    });
    return PhotoUploadResult.fromJson(response.data as Map<String, dynamic>);
  }
}

final photosRepositoryProvider =
    Provider<PhotosRepository>((ref) => DioPhotosRepository());

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
    await db.into(db.syncQueueItems).insert(
          SyncQueueItemsCompanion.insert(
            entityType: 'photo',
            entityId: _uuid.v4(),
            payloadJson: jsonEncode({
              'visitDraftId': visitDraftId,
              'section': section,
              'dataUrl': dataUrl,
              'gpsTag': gpsTag,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          ),
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

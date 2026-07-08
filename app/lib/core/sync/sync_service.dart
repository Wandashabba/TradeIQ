import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart' as api_client;
import '../storage/local_db.dart';

abstract class QueueFlusher {
  Future<void> flush(SyncQueueItem item);
}

/// Posts queued entities to their matching backend endpoint.
///
/// - `visit` → POST /visits, then records the server-assigned id on the
///   matching [VisitDrafts] row so children can reference the real visit.
/// - `stock` → resolves its local visit-draft id to the server visit id
///   ([VisitDrafts.remoteId]) and POSTs /stock. If the visit hasn't synced
///   yet the item is left queued (throws) and retried on the next flush.
class HttpQueueFlusher implements QueueFlusher {
  HttpQueueFlusher({required LocalDb db, Dio? dio})
      : _db = db,
        _dio = dio ?? api_client.dio;

  final LocalDb _db;
  final Dio _dio;

  @override
  Future<void> flush(SyncQueueItem item) async {
    switch (item.entityType) {
      case 'visit':
        final res = await _dio.post('/visits', data: jsonDecode(item.payloadJson));
        final remoteId = (res.data as Map<String, dynamic>)['id'] as String;
        await (_db.update(_db.visitDrafts)..where((t) => t.id.equals(item.entityId)))
            .write(VisitDraftsCompanion(remoteId: Value(remoteId)));
        return;
      case 'stock':
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final localVisitId = payload['visitDraftId'] as String;
        final draft = await (_db.select(_db.visitDrafts)
              ..where((t) => t.id.equals(localVisitId)))
            .getSingleOrNull();
        final remoteId = draft?.remoteId;
        if (remoteId == null) {
          // Visit not synced yet; leave queued and retry once its flush
          // populates remoteId (visit items sort earlier by id).
          throw StateError('Visit $localVisitId not synced yet');
        }
        await _dio.post('/stock', data: {'visitId': remoteId, 'items': payload['items']});
        return;
      default:
        throw UnimplementedError('HTTP sync for ${item.entityType} not wired yet');
    }
  }
}

class SyncService {
  SyncService({required this.db, required this.flusher});

  final LocalDb db;
  final QueueFlusher flusher;

  Future<void> flushPending() async {
    final pending = await (db.select(db.syncQueueItems)
          ..where((tbl) => tbl.synced.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.id)]))
        .get();

    for (final item in pending) {
      try {
        await flusher.flush(item);
      } catch (_) {
        // One item's failure (network error, terminal rejection, an
        // unimplemented entity type, or a dependency not yet synced) must not
        // block the rest of the queue — it just stays unsynced for next time.
        continue;
      }
      await (db.update(db.syncQueueItems)..where((tbl) => tbl.id.equals(item.id)))
          .write(const SyncQueueItemsCompanion(synced: Value(true)));
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.read(localDbProvider);
  return SyncService(db: db, flusher: HttpQueueFlusher(db: db));
});

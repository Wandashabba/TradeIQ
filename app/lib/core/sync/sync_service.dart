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
/// - Every other entity type belongs to a visit: its payload carries the
///   LOCAL visit-draft id (`visitDraftId`), which is resolved to the server
///   visit id ([VisitDrafts.remoteId]) at flush time. If the visit hasn't
///   synced yet the item is left queued (throws) and retried on the next
///   flush (visit items sort earlier by id).
class HttpQueueFlusher implements QueueFlusher {
  HttpQueueFlusher({required this.db, Dio? dio}) : _dio = dio ?? api_client.dio;

  final LocalDb db;
  final Dio _dio;

  Future<String> _remoteVisitId(String localVisitId) async {
    final draft = await (db.select(db.visitDrafts)
          ..where((t) => t.id.equals(localVisitId)))
        .getSingleOrNull();
    final remoteId = draft?.remoteId;
    if (remoteId == null) {
      throw StateError('Visit $localVisitId not synced yet');
    }
    return remoteId;
  }

  @override
  Future<void> flush(SyncQueueItem item) async {
    switch (item.entityType) {
      case 'visit':
        final res = await _dio.post('/visits', data: jsonDecode(item.payloadJson));
        final remoteId = (res.data as Map<String, dynamic>)['id'] as String;
        await (db.update(db.visitDrafts)..where((t) => t.id.equals(item.entityId)))
            .write(VisitDraftsCompanion(remoteId: Value(remoteId)));
        return;
      case 'stock':
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final remoteId = await _remoteVisitId(payload['visitDraftId'] as String);
        await _dio.post('/stock', data: {'visitId': remoteId, 'items': payload['items']});
        return;
      case 'visit_submit':
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final remoteId = await _remoteVisitId(payload['visitDraftId'] as String);
        // Carry the device's completion time through to the server. Without it
        // the fraud engine has no honest dwell measurement (#101).
        final submittedAtClient = payload['submittedAtClient'];
        await _dio.post(
          '/visits/$remoteId/submit',
          data: submittedAtClient == null
              ? null
              : {'submittedAtClient': submittedAtClient},
        );
        return;
      case 'visibility':
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final remoteId = await _remoteVisitId(payload['visitDraftId'] as String);
        final fields = Map<String, dynamic>.from(payload)..remove('visitDraftId');
        await _dio.post('/visibility', data: {'visitId': remoteId, ...fields});
        return;
      case 'pricing':
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final remoteId = await _remoteVisitId(payload['visitDraftId'] as String);
        await _dio.post('/pricing', data: {'visitId': remoteId, 'items': payload['items']});
        return;
      case 'competitive':
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final remoteId = await _remoteVisitId(payload['visitDraftId'] as String);
        await _dio.post('/competitive', data: {'visitId': remoteId, 'items': payload['items']});
        return;
      case 'capability':
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final remoteId = await _remoteVisitId(payload['visitDraftId'] as String);
        final fields = Map<String, dynamic>.from(payload)..remove('visitDraftId');
        await _dio.post('/capability', data: {'visitId': remoteId, ...fields});
        return;
      case 'risk':
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final remoteId = await _remoteVisitId(payload['visitDraftId'] as String);
        await _dio.post('/risks', data: {'visitId': remoteId, 'risks': payload['risks']});
        return;
      case 'task':
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final remoteId = await _remoteVisitId(payload['visitDraftId'] as String);
        final fields = Map<String, dynamic>.from(payload)..remove('visitDraftId');
        await _dio.post('/tasks', data: {'visitId': remoteId, ...fields});
        return;
      case 'scorecard':
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final remoteId = await _remoteVisitId(payload['visitDraftId'] as String);
        await _dio.post('/scorecards', data: {'visitId': remoteId});
        return;
      case 'photo':
        // A section photo captured mid-audit (#41). Same rule as every other
        // child: it carries the local visit-draft id and waits for the visit to
        // sync before it can name a server visit.
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final remoteId = await _remoteVisitId(payload['visitDraftId'] as String);
        final fields = Map<String, dynamic>.from(payload)..remove('visitDraftId');
        await _dio.post('/photos', data: {'visitId': remoteId, ...fields});
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

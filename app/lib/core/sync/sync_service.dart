import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart' as api_client;
import '../storage/local_db.dart';

abstract class QueueFlusher {
  Future<Map<String, dynamic>?> flush(SyncQueueItem item);
}

/// Posts queued entities to their matching backend endpoint. Only 'visit'
/// and 'stock' are wired so far — other entity types get their own case as
/// their S3-S10 modules land. Returns the decoded response body so callers
/// (see [SyncService.flushPending]) can capture a backend-assigned ID;
/// entity types with no downstream consumer for their response just return
/// null.
class HttpQueueFlusher implements QueueFlusher {
  HttpQueueFlusher({Dio? dio}) : _dio = dio ?? api_client.dio;

  final Dio _dio;

  @override
  Future<Map<String, dynamic>?> flush(SyncQueueItem item) async {
    switch (item.entityType) {
      case 'visit':
        final response = await _dio.post('/visits', data: jsonDecode(item.payloadJson));
        return response.data as Map<String, dynamic>?;
      case 'stock':
        await _dio.post('/stock', data: jsonDecode(item.payloadJson));
        return null;
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
      var payloadJson = item.payloadJson;

      if (item.entityType != 'visit') {
        final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
        final localVisitId = payload['visitId'] as String?;
        if (localVisitId != null) {
          final parent = await (db.select(db.visitDrafts)
                ..where((tbl) => tbl.id.equals(localVisitId)))
              .getSingleOrNull();
          if (parent?.remoteId == null) {
            // Parent visit hasn't synced yet — retry on the next flushPending() call.
            continue;
          }
          payload['visitId'] = parent!.remoteId;
          payloadJson = jsonEncode(payload);
        }
      }

      Map<String, dynamic>? response;
      try {
        response = await flusher.flush(item.copyWith(payloadJson: payloadJson));
      } catch (_) {
        // One item's failure (network error, terminal rejection, or an
        // unimplemented entity type) must not block the rest of the queue
        // from being attempted — it just stays unsynced for next time.
        continue;
      }

      if (item.entityType == 'visit' && response?['id'] is String) {
        await (db.update(db.visitDrafts)..where((tbl) => tbl.id.equals(item.entityId)))
            .write(VisitDraftsCompanion(remoteId: Value(response!['id'] as String)));
      }

      await (db.update(db.syncQueueItems)..where((tbl) => tbl.id.equals(item.id)))
          .write(const SyncQueueItemsCompanion(synced: Value(true)));
    }
  }
}

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(db: ref.read(localDbProvider), flusher: HttpQueueFlusher()),
);

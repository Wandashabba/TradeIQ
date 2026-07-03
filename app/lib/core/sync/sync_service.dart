import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart' as api_client;
import '../storage/local_db.dart';

abstract class QueueFlusher {
  Future<void> flush(SyncQueueItem item);
}

/// Posts queued entities to their matching backend endpoint. Only 'visit'
/// is wired so far (POST /visits) — other entity types get their own case
/// as their S2-S10 modules land.
class HttpQueueFlusher implements QueueFlusher {
  HttpQueueFlusher({Dio? dio}) : _dio = dio ?? api_client.dio;

  final Dio _dio;

  @override
  Future<void> flush(SyncQueueItem item) async {
    switch (item.entityType) {
      case 'visit':
        await _dio.post('/visits', data: jsonDecode(item.payloadJson));
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
          ..where((tbl) => tbl.synced.equals(false)))
        .get();

    for (final item in pending) {
      try {
        await flusher.flush(item);
      } catch (_) {
        // One item's failure (network error, terminal rejection, or an
        // unimplemented entity type) must not block the rest of the queue
        // from being attempted — it just stays unsynced for next time.
        continue;
      }
      await (db.update(db.syncQueueItems)..where((tbl) => tbl.id.equals(item.id)))
          .write(const SyncQueueItemsCompanion(synced: Value(true)));
    }
  }
}

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(db: ref.read(localDbProvider), flusher: HttpQueueFlusher()),
);

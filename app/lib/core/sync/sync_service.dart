import 'package:drift/drift.dart';
import '../storage/local_db.dart';

abstract class QueueFlusher {
  Future<void> flush(SyncQueueItem item);
}

/// Real network flusher wired in once the S1-S10 API endpoints exist.
/// Currently only the /outlets endpoint is implemented backend-side
/// (see backend/src/modules/outlets), so this is not yet used in `main.dart`.
class HttpQueueFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async {
    // Intentionally left for the follow-up S1-S10 implementation plan to
    // route `item.entityType` to the matching backend endpoint.
    throw UnimplementedError('HTTP sync for ${item.entityType} not wired yet');
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
      await flusher.flush(item);
      await (db.update(db.syncQueueItems)..where((tbl) => tbl.id.equals(item.id)))
          .write(const SyncQueueItemsCompanion(synced: Value(true)));
    }
  }
}

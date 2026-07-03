import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';

class NoopFlusher implements QueueFlusher {
  int callCount = 0;

  @override
  Future<void> flush(SyncQueueItem item) async {
    callCount += 1;
  }
}

void main() {
  test('flushPending marks queued items as synced', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
      entityType: 'visit',
      entityId: 'visit-1',
      payloadJson: '{}',
    ));

    final flusher = NoopFlusher();
    final service = SyncService(db: db, flusher: flusher);
    await service.flushPending();

    expect(flusher.callCount, 1);
    final rows = await db.select(db.syncQueueItems).get();
    expect(rows.first.synced, isTrue);
  });
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';

void main() {
  test('enqueues a sync item and reads it back unsynced', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);

    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
          entityType: 'visit',
          entityId: 'visit-1',
          payloadJson: '{"outletId":"outlet-1"}',
        ));

    final rows = await db.select(db.syncQueueItems).get();
    expect(rows, hasLength(1));
    expect(rows.first.synced, isFalse);
  });
}

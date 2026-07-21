import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/features/audit/data/tasks_repository.dart';

class _RecordingFlusher implements QueueFlusher {
  final flushed = <SyncQueueItem>[];

  @override
  Future<void> flush(SyncQueueItem item) async {
    flushed.add(item);
  }
}

void main() {
  // Queued rows are stamped with their owner and only that owner's rows
  // flush, so these tests need somebody signed in — as the app does.
  setUp(() => currentLocalUserId = 'user-a');
  tearDown(() => currentLocalUserId = null);

  test('saveTask enqueues one task item with the fields and flushes', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    final flusher = _RecordingFlusher();
    final repo = DriftTasksRepository(
      db: db,
      syncService: SyncService(db: db, flusher: flusher),
    );

    await repo.saveTask(
      visitDraftId: 'visit-1',
      outletId: 'outlet-1',
      task: const TaskDraft(
        findingType: 'oos',
        requiredFix: 'Restock shelf',
        priority: 'high',
      ),
    );

    final items = await db.select(db.syncQueueItems).get();
    expect(items, hasLength(1));
    expect(items.first.entityType, 'task');

    final payload = jsonDecode(items.first.payloadJson) as Map<String, dynamic>;
    expect(payload['visitDraftId'], 'visit-1');
    expect(payload['outletId'], 'outlet-1');
    expect(payload['findingType'], 'oos');
    expect(payload['requiredFix'], 'Restock shelf');
    expect(payload['priority'], 'high');

    expect(flusher.flushed, hasLength(1));
    expect(flusher.flushed.first.entityType, 'task');
  });
}

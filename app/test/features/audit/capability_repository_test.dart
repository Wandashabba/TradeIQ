import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/features/audit/data/capability_repository.dart';

class _RecordingFlusher implements QueueFlusher {
  final flushed = <SyncQueueItem>[];

  @override
  Future<void> flush(SyncQueueItem item) async => flushed.add(item);
}

void main() {
  test('saveCapability enqueues one capability item with the fields and flushes', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    final flusher = _RecordingFlusher();
    final repo = DriftCapabilityRepository(
      db: db,
      syncService: SyncService(db: db, flusher: flusher),
    );

    await repo.saveCapability(
      visitDraftId: 'visit-1',
      capture: const CapabilityCapture(
        staffHeadcountConfirmed: 5,
        repTrainingStatus: {'productKnowledge': true, 'merchandising': false},
        quizScore: 85,
      ),
    );

    final items = await db.select(db.syncQueueItems).get();
    expect(items, hasLength(1));
    expect(items.first.entityType, 'capability');

    final payload = jsonDecode(items.first.payloadJson) as Map<String, dynamic>;
    expect(payload['visitDraftId'], 'visit-1');
    expect(payload['staffHeadcountConfirmed'], 5);
    expect((payload['repTrainingStatus'] as Map)['productKnowledge'], true);
    expect((payload['repTrainingStatus'] as Map)['merchandising'], false);
    expect(payload['quizScore'], 85);

    expect(flusher.flushed, hasLength(1));
    expect(flusher.flushed.first.entityType, 'capability');
  });
}

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/features/audit/data/risks_repository.dart';

class _RecordingFlusher implements QueueFlusher {
  final flushed = <SyncQueueItem>[];

  @override
  Future<void> flush(SyncQueueItem item) async => flushed.add(item);
}

void main() {
  test('saveRisks enqueues one risk item with the entries and flushes', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    final flusher = _RecordingFlusher();
    final repo = DriftRisksRepository(
      db: db,
      syncService: SyncService(db: db, flusher: flusher),
    );

    await repo.saveRisks(
      visitDraftId: 'visit-1',
      entries: const [
        RiskEntry(flagType: 'expiredStock', severity: 'critical', note: 'Two cases past date'),
        RiskEntry(flagType: 'posmDamaged', severity: 'normal', note: ''),
      ],
    );

    final items = await db.select(db.syncQueueItems).get();
    expect(items, hasLength(1));
    expect(items.first.entityType, 'risk');

    final payload = jsonDecode(items.first.payloadJson) as Map<String, dynamic>;
    expect(payload['visitDraftId'], 'visit-1');
    expect((payload['risks'] as List), hasLength(2));
    final first = (payload['risks'] as List).first as Map<String, dynamic>;
    expect(first['flagType'], 'expiredStock');
    expect(first['severity'], 'critical');
    expect(first['note'], 'Two cases past date');

    expect(flusher.flushed, hasLength(1));
    expect(flusher.flushed.first.entityType, 'risk');
  });
}

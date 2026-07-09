import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/features/audit/data/competitive_repository.dart';

class _RecordingFlusher implements QueueFlusher {
  final flushed = <SyncQueueItem>[];

  @override
  Future<void> flush(SyncQueueItem item) async => flushed.add(item);
}

void main() {
  test('saveCompetitive enqueues one competitive item with the entries and flushes', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    final flusher = _RecordingFlusher();
    final repo = DriftCompetitiveRepository(
      db: db,
      syncService: SyncService(db: db, flusher: flusher),
    );

    await repo.saveCompetitive(
      visitDraftId: 'visit-1',
      entries: const [
        CompetitiveEntry(
          competitorSku: 'Rival Cola 500ml',
          competitorPrice: 12.5,
          competitorPosmType: 'poster',
          competitorPromoterPresent: true,
        ),
      ],
    );

    final items = await db.select(db.syncQueueItems).get();
    expect(items, hasLength(1));
    expect(items.first.entityType, 'competitive');

    final payload = jsonDecode(items.first.payloadJson) as Map<String, dynamic>;
    expect(payload['visitDraftId'], 'visit-1');
    expect((payload['items'] as List), hasLength(1));
    final first = (payload['items'] as List).first as Map<String, dynamic>;
    expect(first['competitorSku'], 'Rival Cola 500ml');
    expect(first['competitorPrice'], 12.5);
    expect(first['competitorPosmType'], 'poster');
    expect(first['competitorPromoterPresent'], true);
    expect(first['geotag'], isEmpty);

    expect(flusher.flushed, hasLength(1));
    expect(flusher.flushed.first.entityType, 'competitive');
  });
}

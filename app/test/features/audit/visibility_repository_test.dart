import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/features/audit/data/visibility_repository.dart';

class _NoopFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async {}
}

void main() {
  test('saveVisibility enqueues one visibility item with the fields', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftVisibilityRepository(
      db: db,
      syncService: SyncService(db: db, flusher: _NoopFlusher()),
    );

    await repo.saveVisibility(
      visitDraftId: 'visit-1',
      capture: const VisibilityCapture(
        brandingElements: {'poster': true},
        planogramCompliancePct: 80.0,
        facingsCount: 12,
        highTrafficPass: true,
        cleanlinessScore: 90,
      ),
    );

    final items = await db.select(db.syncQueueItems).get();
    expect(items, hasLength(1));
    expect(items.first.entityType, 'visibility');

    final payload = jsonDecode(items.first.payloadJson) as Map<String, dynamic>;
    expect(payload['visitDraftId'], 'visit-1');
    expect(payload['planogramCompliancePct'], 80.0);
    expect(payload['facingsCount'], {'total': 12});
    expect(payload['highTrafficPass'], true);
    expect((payload['brandingElements'] as Map)['poster'], true);
  });
}

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/features/audit/data/stock_repository.dart';

class _NoopFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async {}
}

StockEntry _entry() => StockEntry(
      skuId: 'sku-1',
      unitsAvailable: 20,
      lastStockinDate: DateTime.utc(2026, 7, 1),
      daysOutOfStock: 0,
      velocityAvg: 4,
      salesActual: 100,
      salesTarget: 120,
    );

void main() {
  late LocalDb db;

  setUp(() => db = LocalDb(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('saveStock writes stock drafts and enqueues one stock sync item', () async {
    final repository = DriftStockRepository(
      db: db,
      syncService: SyncService(db: db, flusher: _NoopFlusher()),
    );

    await repository.saveStock(visitDraftId: 'visit-1', entries: [_entry(), _entry()]);

    final drafts = await db.select(db.stockDrafts).get();
    expect(drafts, hasLength(2));
    expect(drafts.first.visitDraftId, 'visit-1');

    final queued = await db.select(db.syncQueueItems).get();
    expect(queued, hasLength(1));
    expect(queued.first.entityType, 'stock');

    final payload = jsonDecode(queued.first.payloadJson) as Map<String, dynamic>;
    expect(payload['visitDraftId'], 'visit-1');
    expect((payload['items'] as List), hasLength(2));
    expect((payload['items'] as List).first['skuId'], 'sku-1');
  });
}

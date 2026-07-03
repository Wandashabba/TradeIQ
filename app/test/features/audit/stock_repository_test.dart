import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/features/audit/data/stock_repository.dart';

class _NoopFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async {}
}

class _ThrowingFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async {
    throw Exception('network error');
  }
}

void main() {
  late LocalDb db;

  setUp(() {
    db = LocalDb(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('recording stock writes a StockDraft and enqueues a sync item', () async {
    final repository = DriftStockRepository(db: db, syncService: SyncService(db: db, flusher: _NoopFlusher()));

    await repository.recordStock(
      visitId: 'visit-1',
      skuId: 'sku-1',
      unitsAvailable: 40,
      lastStockinDate: DateTime(2026, 6, 30),
      daysOutOfStock: 0,
      velocityAvg: 10,
      salesActual: 350,
      salesTarget: 400,
    );

    final drafts = await db.select(db.stockDrafts).get();
    expect(drafts, hasLength(1));
    expect(drafts.first.visitId, 'visit-1');
    expect(drafts.first.skuId, 'sku-1');
    expect(drafts.first.unitsAvailable, 40);

    final queued = await db.select(db.syncQueueItems).get();
    expect(queued, hasLength(1));
    expect(queued.first.entityType, 'stock');
  });

  test('a failing sync flush does not throw or block the local write', () async {
    final repository = DriftStockRepository(db: db, syncService: SyncService(db: db, flusher: _ThrowingFlusher()));

    await repository.recordStock(
      visitId: 'visit-1',
      skuId: 'sku-1',
      unitsAvailable: 40,
      lastStockinDate: DateTime(2026, 6, 30),
      daysOutOfStock: 0,
      velocityAvg: 10,
      salesActual: 350,
      salesTarget: 400,
    );

    final queued = await db.select(db.syncQueueItems).get();
    expect(queued.first.synced, isFalse);
  });
}

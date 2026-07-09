import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/features/audit/data/pricing_repository.dart';

class _RecordingFlusher implements QueueFlusher {
  final flushed = <SyncQueueItem>[];

  @override
  Future<void> flush(SyncQueueItem item) async => flushed.add(item);
}

void main() {
  test('savePricing enqueues one pricing item with the entries and flushes', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    final flusher = _RecordingFlusher();
    final repo = DriftPricingRepository(
      db: db,
      syncService: SyncService(db: db, flusher: flusher),
    );

    await repo.savePricing(
      visitDraftId: 'visit-1',
      entries: const [
        PricingEntry(
          skuId: 'sku-1',
          priceActual: 19.99,
          promoActive: true,
          promoMaterialsDetected: {'shelfStrip': true},
          commsRating: 4,
        ),
      ],
    );

    final items = await db.select(db.syncQueueItems).get();
    expect(items, hasLength(1));
    expect(items.first.entityType, 'pricing');

    final payload = jsonDecode(items.first.payloadJson) as Map<String, dynamic>;
    expect(payload['visitDraftId'], 'visit-1');
    expect((payload['items'] as List), hasLength(1));
    final first = (payload['items'] as List).first as Map<String, dynamic>;
    expect(first['skuId'], 'sku-1');
    expect(first['priceActual'], 19.99);
    expect(first['promoActive'], true);
    expect((first['promoMaterialsDetected'] as Map)['shelfStrip'], true);
    expect(first['commsRating'], 4);

    expect(flusher.flushed, hasLength(1));
    expect(flusher.flushed.first.entityType, 'pricing');
  });
}

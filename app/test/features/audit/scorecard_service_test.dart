import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/features/audit/data/scorecard_service.dart';

class _NoopFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async {}
}

Future<void> _enqueue(LocalDb db, String entityType, Map<String, dynamic> payload) {
  return db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
        entityType: entityType,
        entityId: 'e-$entityType-${payload.hashCode}',
        payloadJson: jsonEncode(payload),
      ));
}

void main() {
  late LocalDb db;
  late ScorecardService service;

  setUp(() {
    db = LocalDb(NativeDatabase.memory());
    service = ScorecardService(
      db: db,
      syncService: SyncService(db: db, flusher: _NoopFlusher()),
    );
  });

  tearDown(() => db.close());

  test('computeForVisit scores only this visit\'s queued captures', () async {
    await _enqueue(db, 'stock', {
      'visitDraftId': 'visit-1',
      'items': [
        {'skuId': 'sku-1', 'unitsAvailable': 12},
        {'skuId': 'sku-2', 'unitsAvailable': 0},
      ],
    });
    await _enqueue(db, 'visibility', {
      'visitDraftId': 'visit-1',
      'planogramCompliancePct': 80,
      'cleanlinessScore': 4,
    });
    await _enqueue(db, 'capability', {
      'visitDraftId': 'visit-1',
      'quizScore': 70,
    });
    // A capture for a different visit must be ignored.
    await _enqueue(db, 'visibility', {
      'visitDraftId': 'visit-2',
      'planogramCompliancePct': 10,
      'cleanlinessScore': 1,
    });

    final scorecard = await service.computeForVisit('visit-1');

    expect(scorecard.dimensionScores['availability'], 50);
    expect(scorecard.dimensionScores['visibility'], 80);
    expect(scorecard.dimensionScores['display'], 80);
    expect(scorecard.dimensionScores['pricing'], 0);
    expect(scorecard.dimensionScores['competitive'], 0);
    expect(scorecard.dimensionScores['salesCapability'], 70);
    // (50*.3 + 80*.25 + 80*.15 + 0 + 0 + 70*.1) / 1.0 = 54.0
    expect(scorecard.weightedTotal, 54.0);
    expect(scorecard.ratingBand, 'red');
  });

  test('finalizeScorecard enqueues a scorecard item for the visit', () async {
    await service.finalizeScorecard('visit-1');

    final items = await db.select(db.syncQueueItems).get();
    expect(items, hasLength(1));
    expect(items.first.entityType, 'scorecard');
    final payload = jsonDecode(items.first.payloadJson) as Map<String, dynamic>;
    expect(payload['visitDraftId'], 'visit-1');
  });
}

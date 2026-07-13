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
    expect(scorecard.dimensionScores['salesCapability'], 70);

    // No competitor was captured, so share of shelf is UNMEASURABLE — the
    // dimension is omitted rather than scored 0 (#93).
    expect(scorecard.dimensionScores.containsKey('competitive'), isFalse);

    // The total normalises by the weights actually used (0.9, not 1.0):
    // (50*.3 + 80*.25 + 80*.15 + 0*.1 + 70*.1) / 0.9 = 60.0
    //
    // Scoring the unmeasurable dimension 0 would have dragged this to 54.0 and
    // put the visit in the red band — punishing an agent for a shelf that had
    // no competitor on it.
    expect(scorecard.weightedTotal, 60.0);
    expect(scorecard.ratingBand, 'amber');
  });

  test('competitive is our share of shelf, not "captured anything at all"', () async {
    await _enqueue(db, 'visibility', {
      'visitDraftId': 'visit-1',
      'planogramCompliancePct': 80,
      'cleanlinessScore': 4,
      'facingsCount': {'total': 30},
    });
    await _enqueue(db, 'competitive', {
      'visitDraftId': 'visit-1',
      'items': [
        {'competitorSku': 'Rival', 'facingsCount': 10},
      ],
    });

    final scorecard = await service.computeForVisit('visit-1');

    // 30 of ours against 10 of theirs. The old rule scored a flat 100 for having
    // typed a single row — it measured data entry, not the store.
    expect(scorecard.dimensionScores['competitive'], 75.0);
  });

  test('a competitor with more shelf than us scores us down', () async {
    await _enqueue(db, 'visibility', {
      'visitDraftId': 'visit-1',
      'planogramCompliancePct': 80,
      'cleanlinessScore': 4,
      'facingsCount': {'total': 2},
    });
    await _enqueue(db, 'competitive', {
      'visitDraftId': 'visit-1',
      'items': [
        {'competitorSku': 'Rival', 'facingsCount': 18},
      ],
    });

    final scorecard = await service.computeForVisit('visit-1');

    // 2 of 20 facings — being crushed on shelf used to score identically to
    // dominating it.
    expect(scorecard.dimensionScores['competitive'], 10.0);
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

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

Future<void> _enqueue(
  LocalDb db,
  String entityType,
  Map<String, dynamic> payload,
) {
  return db.enqueue(
    entityType: entityType,
    entityId: 'e-$entityType-${payload.hashCode}',
    payloadJson: jsonEncode(payload),
  );
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
    expect(scorecard.dimensionScores['salesCapability'], 70);

    // No competitor was captured, so share of shelf is UNMEASURABLE — the
    // dimension is omitted rather than scored 0 (#93). Pricing was never
    // captured either, and it is omitted for exactly the same reason: it used
    // to arrive as a measured `0`, which read to the agent as "you scored
    // nothing on pricing" for a section they simply had not reached yet.
    expect(scorecard.dimensionScores.containsKey('competitive'), isFalse);
    expect(scorecard.dimensionScores.containsKey('pricing'), isFalse);

    // The total normalises by the weights actually used (0.8, not 1.0):
    // (50*.3 + 80*.25 + 80*.15 + 70*.1) / 0.8 = 67.5
    //
    // Scoring an unmeasurable dimension 0 would have dragged this to 54.0 and
    // put the visit in the red band — punishing an agent for a shelf that had
    // no competitor on it and a section nobody had opened.
    expect(scorecard.weightedTotal, 67.5);
    expect(scorecard.ratingBand, 'amber');
  });

  // THE VISIT WITH NOTHING ON IT — the state every agent is in when they first
  // open Score. Five of the six dimensions used to arrive here as a measured
  // `0` and the hero stamped a critical "Gap" on a shop nobody had measured.
  test('a visit with nothing captured has no dimensions, no total and no '
      'band — not a zero in the red', () async {
    final scorecard = await service.computeForVisit('visit-1');

    expect(scorecard.dimensionScores, isEmpty);
    for (final key in kScorecardWeights.keys) {
      expect(
        scorecard.dimensionScores[key],
        isNull,
        reason: '$key was never measured, so it is UNKNOWN and not 0',
      );
    }
    expect(scorecard.weightedTotal, isNull);
    expect(scorecard.ratingBand, isNull);
    expect(scorecard.isMeasured, isFalse);
  });

  test('a shelf on which nothing was counted has no availability', () async {
    await _enqueue(db, 'stock', {
      'visitDraftId': 'visit-1',
      'items': [
        {'skuId': 'sku-1', 'unitsAvailable': null},
        {'skuId': 'sku-2', 'unitsAvailable': null},
      ],
    });

    final scorecard = await service.computeForVisit('visit-1');

    // A denominator of zero is UNKNOWN. "0% on shelf" is what the app used to
    // say about a shelf the agent had not walked to.
    expect(scorecard.dimensionScores.containsKey('availability'), isFalse);
    expect(scorecard.weightedTotal, isNull);
  });

  test('a pricing section the agent did save, with nothing in it, is a '
      'measured zero', () async {
    await _enqueue(db, 'pricing', {'visitDraftId': 'visit-1', 'items': []});

    final scorecard = await service.computeForVisit('visit-1');

    // Saved-and-empty is a measurement; never-opened is not. This is the line
    // between the two, and it is the whole point of the change.
    expect(scorecard.dimensionScores['pricing'], 0);
    expect(scorecard.weightedTotal, 0.0);
    expect(scorecard.ratingBand, 'red');
  });

  test('a capability section with no quiz behind it is UNKNOWN', () async {
    await _enqueue(db, 'stock', {
      'visitDraftId': 'visit-1',
      'items': [
        {'skuId': 'sku-1', 'unitsAvailable': 12},
      ],
    });

    final scorecard = await service.computeForVisit('visit-1');

    expect(scorecard.dimensionScores.containsKey('salesCapability'), isFalse);
    expect(scorecard.dimensionScores.containsKey('visibility'), isFalse);
    expect(scorecard.dimensionScores.containsKey('display'), isFalse);
    // The one measured dimension carries the whole total on its own.
    expect(scorecard.weightedTotal, 100.0);
    expect(scorecard.ratingBand, 'green');
  });

  test(
    'competitive is our share of shelf, not "captured anything at all"',
    () async {
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
    },
  );

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

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';
import 'package:tradeiq_app/features/audit/data/visit_review.dart';

class _FakeSkusRepository implements SkusRepository {
  @override
  Future<List<Sku>> listSkus() async => const [
        Sku(
          id: 'sku-1',
          name: 'Fanta Orange 2L',
          category: 'CSD',
          minFacingsStandard: 3,
          rrp: 24.99,
        ),
        Sku(
          id: 'sku-2',
          name: 'Coke Zero 500ml',
          category: 'CSD',
          minFacingsStandard: 2,
          rrp: 12.50,
        ),
      ];
}

Future<void> _queue(
  LocalDb db,
  String type,
  Map<String, dynamic> payload,
) =>
    db.into(db.syncQueueItems).insert(
          SyncQueueItemsCompanion.insert(
            entityType: type,
            entityId: 'e-$type-${payload.hashCode}',
            payloadJson: jsonEncode(payload),
            synced: const Value(false),
          ),
        );

void main() {
  late LocalDb db;
  late ProviderContainer container;

  setUp(() {
    db = LocalDb(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        localDbProvider.overrideWithValue(db),
        skusRepositoryProvider.overrideWithValue(_FakeSkusRepository()),
      ],
    );
    // Auto-dispose: without a listener the provider is torn down before it
    // yields, and `.future` never completes.
    container.listen(visitReviewProvider('v1'), (_, _) {});
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<VisitReview> read() =>
      container.read(visitReviewProvider('v1').future);

  test('a SKU counted at zero is named as the finding it is', () async {
    await _queue(db, 'stock', {
      'visitDraftId': 'v1',
      'items': [
        {'skuId': 'sku-1', 'unitsAvailable': 0},
        {'skuId': 'sku-2', 'unitsAvailable': 14},
      ],
    });

    final review = await read();

    expect(review.skusCounted, 2);
    expect(review.outOfStock, 1);
    // The agent has to be able to check this against the shelf in front of them.
    // A uuid is not checkable; a product name is.
    expect(review.willRaise, hasLength(1));
    expect(review.willRaise.single.title, contains('Fanta Orange 2L'));
    // Mirrors stock.service.ts, which raises stockout tasks at `high`.
    expect(review.willRaise.single.priority, 'high');
  });

  test('a clean store raises nothing — and that is not an empty screen', () async {
    await _queue(db, 'stock', {
      'visitDraftId': 'v1',
      'items': [
        {'skuId': 'sku-1', 'unitsAvailable': 9},
      ],
    });

    final review = await read();

    expect(review.outOfStock, 0);
    expect(review.willRaise, isEmpty);
  });

  test('a risk is raised at its own severity, mirroring the server', () async {
    await _queue(db, 'risk', {
      'visitDraftId': 'v1',
      'risks': [
        {
          'flagType': 'expiry',
          'severity': 'critical',
          'note': 'Six cases past sell-by in the back room',
        },
      ],
    });

    final review = await read();

    expect(review.willRaise, hasLength(1));
    expect(review.willRaise.single.priority, 'critical');
    expect(
      review.willRaise.single.title,
      'Six cases past sell-by in the back room',
    );
  });

  test('the worst thing the agent found is the first thing the gate shows', () async {
    await _queue(db, 'stock', {
      'visitDraftId': 'v1',
      'items': [
        {'skuId': 'sku-1', 'unitsAvailable': 0},
      ],
    });
    await _queue(db, 'task', {
      'visitDraftId': 'v1',
      'requiredFix': 'Ask for a second facing',
      'priority': 'low',
    });
    await _queue(db, 'risk', {
      'visitDraftId': 'v1',
      'flagType': 'safety',
      'severity': 'critical',
      'note': 'Fridge leaking onto the floor',
      'risks': [
        {
          'flagType': 'safety',
          'severity': 'critical',
          'note': 'Fridge leaking onto the floor',
        },
      ],
    });

    final review = await read();

    expect(
      review.willRaise.map((t) => t.priority).toList(),
      ['critical', 'high', 'low'],
    );
  });

  test('another visit’s captures are not counted against this one', () async {
    await _queue(db, 'stock', {
      'visitDraftId': 'someone-elses-visit',
      'items': [
        {'skuId': 'sku-1', 'unitsAvailable': 0},
      ],
    });

    final review = await read();

    expect(review.skusCounted, 0);
    expect(review.willRaise, isEmpty);
  });

  test('the captured line reads as a sentence, not a schema', () async {
    await _queue(db, 'stock', {
      'visitDraftId': 'v1',
      'items': [
        {'skuId': 'sku-1', 'unitsAvailable': 3},
      ],
    });
    await _queue(db, 'competitive', {
      'visitDraftId': 'v1',
      'items': [
        {'competitorName': 'Pepsi', 'facingsCount': 4},
      ],
    });
    await _queue(db, 'photo', {'visitDraftId': 'v1', 'url': 'file://x.jpg'});

    final review = await read();

    expect(review.capturedLine, '1 SKU counted · 1 competitor · 1 photo');
  });
}

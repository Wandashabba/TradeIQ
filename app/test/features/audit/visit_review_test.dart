import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';
import 'package:tradeiq_app/features/audit/data/visit_review.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

class _FakeSkusRepository implements SkusRepository {
  @override
  Future<PaginatedResponse<Sku>> listSkus({
    required String outletId,
    int? limit,
    String? cursor,
  }) async => const PaginatedResponse(
    data: [
      Sku(
        id: 'sku-1',
        name: 'Fanta Orange 2L',
        category: 'CSD',
        minFacingsStandard: 3,
        rrp: 24.99,
        daysOutOfStock: 0,
        velocityAvg: 0,
        effectivePrice: 24.99,
      ),
      Sku(
        id: 'sku-2',
        name: 'Coke Zero 500ml',
        category: 'CSD',
        minFacingsStandard: 2,
        rrp: 12.50,
        daysOutOfStock: 0,
        velocityAvg: 0,
        effectivePrice: 12.50,
      ),
    ],
    nextCursor: null,
  );
}

Future<void> _queue(LocalDb db, String type, Map<String, dynamic> payload) =>
    // `synced: false` is enqueue's only behaviour, so the explicit flag is
    // redundant now that queuing goes through one path.
    db.enqueue(
      entityType: type,
      entityId: 'e-$type-${payload.hashCode}',
      payloadJson: jsonEncode(payload),
    );

const _key = (visitDraftId: 'v1', outletId: 'ou1');

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
    container.listen(visitReviewProvider(_key), (_, _) {});
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<VisitReview> read() =>
      container.read(visitReviewProvider(_key).future);

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

  test(
    'a clean store raises nothing — and that is not an empty screen',
    () async {
      await _queue(db, 'stock', {
        'visitDraftId': 'v1',
        'items': [
          {'skuId': 'sku-1', 'unitsAvailable': 9},
        ],
      });

      final review = await read();

      expect(review.outOfStock, 0);
      expect(review.willRaise, isEmpty);
    },
  );

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

  test(
    'the worst thing the agent found is the first thing the gate shows',
    () async {
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

      expect(review.willRaise.map((t) => t.priority).toList(), [
        'critical',
        'high',
        'low',
      ]);
    },
  );

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

  group('raised-task codes', () {
    final af = lookupAppLocalizations(const Locale('af'));

    test('the provider raises coded tasks, worded per language', () async {
      await _queue(db, 'stock', {
        'visitDraftId': 'v1',
        'items': [
          {'skuId': 'sku-1', 'unitsAvailable': 0},
          {'skuId': 'unknown-sku', 'unitsAvailable': 0},
        ],
      });
      await _queue(db, 'risk', {
        'visitDraftId': 'v1',
        'risks': [
          {'flagType': 'expiry', 'severity': 'normal', 'note': '  '},
        ],
      });

      final review = await read();
      final stockouts = review.willRaise
          .where((t) => t.kind == RaisedTaskKind.stockout)
          .toList();
      final risk = review.willRaise.singleWhere(
        (t) => t.kind == RaisedTaskKind.risk,
      );

      expect(stockouts.map((t) => t.title), [
        'Fanta Orange 2L is out of stock',
        'This SKU is out of stock',
      ]);
      expect(stockouts.map((t) => t.titleIn(af)), [
        'Fanta Orange 2L is uit voorraad',
        'Hierdie SKU is uit voorraad',
      ]);
      expect(stockouts.first.reason, 'You counted zero on shelf');
      expect(stockouts.first.reasonIn(af), 'Jy het nul op die rak getel');

      // A blank note falls back to the flag type — the agent's own words
      // (expiry) are never translated.
      expect(risk.title, 'expiry flagged');
      expect(risk.titleIn(af), 'expiry gemerk');
      expect(risk.reason, 'Risk you raised · expiry');
      expect(risk.reasonIn(af), 'Risiko wat jy gemerk het · expiry');
    });

    test('each code maps to its English and Afrikaans copy', () {
      final untypedRisk = RaisedTask.risk(priority: 'high');
      expect(untypedRisk.title, 'Risk flagged');
      expect(untypedRisk.titleIn(af), 'Risiko gemerk');
      expect(untypedRisk.reason, 'Risk you raised · flagged');
      expect(untypedRisk.reasonIn(af), 'Risiko wat jy gemerk het');

      final noted = RaisedTask.risk(
        note: 'Fridge leaking',
        flagType: 'safety',
        priority: 'critical',
      );
      expect(noted.titleIn(af), 'Fridge leaking');

      final action = RaisedTask.actionPlan(priority: 'low');
      expect(action.title, 'Action you asked for');
      expect(action.titleIn(af), 'Aksie waarvoor jy gevra het');
      expect(action.reason, 'Action plan you wrote');
      expect(action.reasonIn(af), 'Aksieplan wat jy geskryf het');
      expect(
        RaisedTask.actionPlan(
          requiredFix: 'Add a facing',
          priority: 'low',
        ).titleIn(af),
        'Add a facing',
      );

      // An already-worded task is shown as it is, in any language.
      const worded = RaisedTask(title: 'T', reason: 'R', priority: 'low');
      expect(worded.kind, isNull);
      expect(worded.titleIn(af), 'T');
      expect(worded.reasonIn(af), 'R');
    });

    test('the captured line in Afrikaans uses plurals, not suffixes', () {
      const one = VisitReview(
        skusCounted: 1,
        outOfStock: 0,
        skusPriced: 0,
        competitors: 1,
        photos: 1,
        willRaise: [],
      );
      const many = VisitReview(
        skusCounted: 12,
        outOfStock: 0,
        skusPriced: 0,
        competitors: 2,
        photos: 3,
        willRaise: [],
      );
      expect(one.capturedLineIn(af), '1 SKU getel · 1 mededinger · 1 foto');
      expect(
        many.capturedLineIn(af),
        '12 SKU’s getel · 2 mededingers · 3 foto’s',
      );
      expect(many.capturedLine, '12 SKUs counted · 2 competitors · 3 photos');
    });
  });
}

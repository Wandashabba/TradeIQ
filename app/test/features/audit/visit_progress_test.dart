import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';
import 'package:tradeiq_app/features/audit/data/visit_progress.dart';

class _FakeSkusRepository implements SkusRepository {
  _FakeSkusRepository(this.count);

  final int count;

  @override
  Future<List<Sku>> listSkus({required String outletId}) async => [
    for (var i = 0; i < count; i++)
      Sku(
        id: 's$i',
        name: 'SKU $i',
        category: 'c',
        rrp: 10,
        minFacingsStandard: 2,
        daysOutOfStock: 0,
        velocityAvg: 0,
        effectivePrice: 10,
      ),
  ];
}

Future<void> _enqueue(
  LocalDb db,
  String entityType,
  Map<String, dynamic> payload,
) async {
  await db.enqueue(
    entityType: entityType,
    entityId: '$entityType-1',
    payloadJson: jsonEncode(payload),
  );
}

void main() {
  late LocalDb db;
  late ProviderContainer container;

  setUp(() {
    db = LocalDb(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        localDbProvider.overrideWithValue(db),
        skusRepositoryProvider.overrideWithValue(_FakeSkusRepository(4)),
      ],
    );
  });

  tearDown(() async {
    // Dispose the container FIRST. It holds the Drift watch() subscription, and
    // closing the database out from under a live subscription hangs.
    container.dispose();
    await db.close();
  });

  /// Riverpod 3 auto-disposes a provider with nothing listening, so awaiting
  /// `.future` on its own disposes the stream before it can emit. Listen the way
  /// a widget does, and take the first value that arrives.
  Future<VisitProgress> progress() async {
    final skus = container.listen(
      skusListProvider('ou1'),
      (_, _) {},
      fireImmediately: true,
    );
    await container.read(skusListProvider('ou1').future);

    final completer = Completer<VisitProgress>();
    final sub = container.listen<AsyncValue<VisitProgress>>(
      visitProgressProvider((visitDraftId: 'v1', outletId: 'ou1')),
      (_, next) {
        final value = next.value;
        if (value != null && !completer.isCompleted) completer.complete(value);
      },
      fireImmediately: true,
    );
    final value = await completer.future;
    sub.close();
    skus.close();
    return value;
  }

  test('a fresh visit has nothing captured and cannot be submitted', () async {
    final p = await progress();

    // Outlet info is confirmed by the act of checking in — there is nothing to
    // capture, so it is the one section that starts done.
    expect(p.stateOf(AuditSection.outletInfo), SectionState.done);
    expect(p.stateOf(AuditSection.stock), SectionState.notStarted);
    expect(p.canSubmit, isFalse);
  });

  test(
    'submit is blocked on exactly the required sections, and names them',
    () async {
      final p = await progress();

      // These four are what the server's scorecard scores. Without them a visit
      // lands with a dimension at zero and the store is marked down for work the
      // agent never did.
      expect(
        p.blocking,
        containsAll([
          AuditSection.stock,
          AuditSection.visibility,
          AuditSection.pricing,
          AuditSection.capability,
        ]),
      );

      // Competitive is NOT required: an outlet with no competitor on shelf is a
      // real outcome, and the server treats that dimension as unmeasurable
      // rather than zero (#93).
      expect(p.blocking, isNot(contains(AuditSection.competitive)));
      expect(p.blocking, isNot(contains(AuditSection.risks)));
    },
  );

  test(
    'a per-SKU section covering only some SKUs is PARTIAL, not done',
    () async {
      // 2 of 4 SKUs priced. Calling this "done" would let an incomplete visit
      // through the submit gate.
      await _enqueue(db, 'pricing', {
        'visitDraftId': 'v1',
        'items': [
          {'skuId': 's0'},
          {'skuId': 's1'},
        ],
      });

      final p = await progress();

      expect(p.stateOf(AuditSection.pricing), SectionState.partial);
      expect(p.details[AuditSection.pricing], '2 of 4 SKUs');
      expect(p.blocking, contains(AuditSection.pricing));
    },
  );

  test(
    'counting every SKU completes the section and says what was found',
    () async {
      await _enqueue(db, 'stock', {
        'visitDraftId': 'v1',
        'items': [
          {'skuId': 's0', 'unitsAvailable': 12},
          {'skuId': 's1', 'unitsAvailable': 0},
          {'skuId': 's2', 'unitsAvailable': 4},
          {'skuId': 's3', 'unitsAvailable': 0},
        ],
      });

      final p = await progress();

      expect(p.stateOf(AuditSection.stock), SectionState.done);
      // Out-of-stock is the finding, so the hub says so rather than just "done".
      expect(p.details[AuditSection.stock], '4 SKUs · 2 out of stock');
    },
  );

  test('a capture for another visit is ignored', () async {
    await _enqueue(db, 'capability', {'visitDraftId': 'someone-else'});

    final p = await progress();

    expect(p.stateOf(AuditSection.capability), SectionState.notStarted);
  });

  test('finishing every required section unblocks submit', () async {
    await _enqueue(db, 'stock', {
      'visitDraftId': 'v1',
      'items': [
        {'skuId': 's0', 'unitsAvailable': 1},
        {'skuId': 's1', 'unitsAvailable': 1},
        {'skuId': 's2', 'unitsAvailable': 1},
        {'skuId': 's3', 'unitsAvailable': 1},
      ],
    });
    await _enqueue(db, 'pricing', {
      'visitDraftId': 'v1',
      'items': [
        {'skuId': 's0'},
        {'skuId': 's1'},
        {'skuId': 's2'},
        {'skuId': 's3'},
      ],
    });
    await _enqueue(db, 'visibility', {'visitDraftId': 'v1'});
    await _enqueue(db, 'capability', {'visitDraftId': 'v1'});

    final p = await progress();

    expect(p.blocking, isEmpty);
    expect(p.canSubmit, isTrue);
    // Competitive, risks and the action plan are still untouched — optional
    // means optional.
    expect(p.doneCount, 4);
  });
}

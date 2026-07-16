import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';
import 'package:tradeiq_app/features/audit/data/stock_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s2_stock_screen.dart';

class _FakeSkusRepository implements SkusRepository {
  @override
  Future<List<Sku>> listSkus({required String outletId}) async => const [
        Sku(id: 's1', name: 'Test Cola', category: 'Beverages', minFacingsStandard: 4, rrp: 19.99,
            daysOutOfStock: 0, velocityAvg: 4.2),
      ];
}

/// A SKU with exactly one prior in-stock reading: `daysOutOfStock` only needs
/// one history point, `velocityAvg` needs two — so this combination (a rate of
/// zero alongside a nonzero out-of-stock count) is a legitimate state, not a
/// contradiction.
class _FakeSkusRepositoryNoHistory implements SkusRepository {
  @override
  Future<List<Sku>> listSkus({required String outletId}) async => const [
        Sku(id: 's1', name: 'Test Cola', category: 'Beverages', minFacingsStandard: 4, rrp: 19.99,
            daysOutOfStock: 5, velocityAvg: 0),
      ];
}

class _SpyStockRepository implements StockRepository {
  String? visitDraftId;
  List<StockEntry>? entries;

  @override
  Future<void> saveStock({required String visitDraftId, required List<StockEntry> entries}) async {
    this.visitDraftId = visitDraftId;
    this.entries = entries;
  }
}

void main() {
  testWidgets('shows read-only server context and calls saveStock on Save', (tester) async {
    final spy = _SpyStockRepository();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        skusRepositoryProvider.overrideWithValue(_FakeSkusRepository()),
        stockRepositoryProvider.overrideWithValue(spy),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: S2StockScreen(visitDraftId: 'v1', outletId: 'o1')),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Selling ~4.2/day'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('units-s1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('units-input-s1')), '20');
    await tester.tap(find.byKey(const ValueKey('units-confirm-s1')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save stock'));
    await tester.tap(find.text('Save stock'));
    await tester.pumpAndSettle();

    expect(spy.visitDraftId, 'v1');
    expect(spy.entries, hasLength(1));
    expect(spy.entries!.first.skuId, 's1');
    expect(spy.entries!.first.unitsAvailable, 20);
    expect(find.text('Stock saved — queued for sync'), findsOneWidget);
  });

  testWidgets('the +/- stepper adjusts the count without a keyboard', (tester) async {
    final spy = _SpyStockRepository();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        skusRepositoryProvider.overrideWithValue(_FakeSkusRepository()),
        stockRepositoryProvider.overrideWithValue(spy),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: S2StockScreen(visitDraftId: 'v1', outletId: 'o1')),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final plus = find.descendant(of: find.byKey(const ValueKey('units-s1')), matching: find.byIcon(Icons.add));
    await tester.tap(plus);
    await tester.pump();
    await tester.tap(plus);
    await tester.pump();
    await tester.tap(plus);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save stock'));
    await tester.tap(find.text('Save stock'));
    await tester.pumpAndSettle();

    expect(spy.entries!.first.unitsAvailable, 3);
  });

  testWidgets('a zero count is shown as the finding it is', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        skusRepositoryProvider.overrideWithValue(_FakeSkusRepository()),
        stockRepositoryProvider.overrideWithValue(_SpyStockRepository()),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: S2StockScreen(visitDraftId: 'v1', outletId: 'o1')),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('units-s1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('units-input-s1')), '0');
    await tester.tap(find.byKey(const ValueKey('units-confirm-s1')));
    await tester.pumpAndSettle();

    expect(find.text('Out of stock — this raises a task for the manager'), findsOneWidget);
  });

  testWidgets('with no velocity history yet, the context line stands on its own', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        skusRepositoryProvider.overrideWithValue(_FakeSkusRepositoryNoHistory()),
        stockRepositoryProvider.overrideWithValue(_SpyStockRepository()),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: S2StockScreen(visitDraftId: 'v1', outletId: 'o1')),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // A rate of zero does not mean "Selling no sales history yet" — it means
    // there isn't yet a rate to report, and that can still come with a known
    // out-of-stock count from a single prior reading.
    expect(find.text('No sales history yet · out of stock 5d'), findsOneWidget);
  });
}

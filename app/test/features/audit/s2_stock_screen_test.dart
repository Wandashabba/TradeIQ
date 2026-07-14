import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';
import 'package:tradeiq_app/features/audit/data/stock_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s2_stock_screen.dart';

class _FakeSkusRepository implements SkusRepository {
  @override
  Future<List<Sku>> listSkus() async => const [
        Sku(id: 's1', name: 'Test Cola', category: 'Beverages', minFacingsStandard: 4, rrp: 19.99),
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
  testWidgets('captures stock entries and calls saveStock on Save', (tester) async {
    final spy = _SpyStockRepository();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        skusRepositoryProvider.overrideWithValue(_FakeSkusRepository()),
        stockRepositoryProvider.overrideWithValue(spy),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: S2StockScreen(visitDraftId: 'v1'))),
      ),
    ));
    await tester.pumpAndSettle();

    // The shelf count is entered by tapping the number and typing it. A pure
    // +/- stepper is right for facings and wrong for a shelf holding 20 units —
    // nobody taps "+" twenty times.
    await tester.tap(find.byKey(const ValueKey('units-s1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('units-input-s1')), '20');
    await tester.tap(find.byKey(const ValueKey('units-confirm-s1')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('vel-s1')), '4');
    await tester.enterText(find.byKey(const ValueKey('sactual-s1')), '100');
    await tester.enterText(find.byKey(const ValueKey('starget-s1')), '120');

    await tester.ensureVisible(find.text('Save stock'));
    await tester.tap(find.text('Save stock'));
    await tester.pumpAndSettle();

    expect(spy.visitDraftId, 'v1');
    expect(spy.entries, hasLength(1));
    expect(spy.entries!.first.skuId, 's1');
    expect(spy.entries!.first.unitsAvailable, 20);
    expect(spy.entries!.first.velocityAvg, 4);
    expect(spy.entries!.first.salesTarget, 120);
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
        home: Scaffold(body: SingleChildScrollView(child: S2StockScreen(visitDraftId: 'v1'))),
      ),
    ));
    await tester.pumpAndSettle();

    // Counting stock is a two-handed job: one hand on the shelf, one on the
    // phone. Three taps, no keyboard.
    final plus = find.descendant(
      of: find.byKey(const ValueKey('units-s1')),
      matching: find.byIcon(Icons.add),
    );
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
        home: Scaffold(body: SingleChildScrollView(child: S2StockScreen(visitDraftId: 'v1'))),
      ),
    ));
    await tester.pumpAndSettle();

    // An out-of-stock is the most valuable thing an agent can record — it raises
    // the task. It must not look like an empty field.
    await tester.tap(find.byKey(const ValueKey('units-s1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('units-input-s1')), '0');
    await tester.tap(find.byKey(const ValueKey('units-confirm-s1')));
    await tester.pumpAndSettle();

    expect(
      find.text('Out of stock — this raises a task for the manager'),
      findsOneWidget,
    );
  });
}

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

    await tester.enterText(find.byKey(const ValueKey('units-s1')), '20');
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
}

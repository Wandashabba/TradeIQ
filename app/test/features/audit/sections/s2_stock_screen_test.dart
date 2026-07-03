import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/features/audit/data/stock_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s2_stock_screen.dart';
import 'package:tradeiq_app/features/skus/data/skus_repository.dart';

class _FakeSkusRepository implements SkusRepository {
  @override
  Future<List<Sku>> listSkus() async => const [
        Sku(id: 'sku-1', name: 'Demo Brand 500ml', category: 'Beverages'),
      ];
}

class _RecordingStockRepository implements StockRepository {
  final List<String> recordedSkuIds = [];

  @override
  Future<void> recordStock({
    required String visitId,
    required String skuId,
    required int unitsAvailable,
    required DateTime lastStockinDate,
    required int daysOutOfStock,
    required double velocityAvg,
    required double salesActual,
    required double salesTarget,
  }) async {
    recordedSkuIds.add(skuId);
  }
}

Widget _screenWith(StockRepository stockRepository, {LocalDb? db}) {
  return ProviderScope(
    overrides: [
      localDbProvider.overrideWithValue(db ?? LocalDb(NativeDatabase.memory())),
      skusRepositoryProvider.overrideWithValue(_FakeSkusRepository()),
      stockRepositoryProvider.overrideWithValue(stockRepository),
    ],
    child: const MaterialApp(home: Scaffold(body: S2StockScreen(visitId: 'visit-1'))),
  );
}

void main() {
  testWidgets('renders SKUs and opens the stock form on tap', (tester) async {
    await tester.pumpWidget(_screenWith(_RecordingStockRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Demo Brand 500ml'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);

    await tester.tap(find.text('Demo Brand 500ml'));
    await tester.pumpAndSettle();

    expect(find.text('Stock: Demo Brand 500ml'), findsOneWidget);
  });

  testWidgets('submitting the form records stock and shows the SKU as recorded', (tester) async {
    final stockRepository = _RecordingStockRepository();
    await tester.pumpWidget(_screenWith(stockRepository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Demo Brand 500ml'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Units available'), '40');
    await tester.enterText(find.widgetWithText(TextFormField, 'Days out of stock'), '0');
    await tester.enterText(find.widgetWithText(TextFormField, 'Average daily velocity'), '10');
    await tester.enterText(find.widgetWithText(TextFormField, 'Sales actual'), '350');
    await tester.enterText(find.widgetWithText(TextFormField, 'Sales target'), '400');

    await tester.tap(find.text('Last stock-in date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Stock: Demo Brand 500ml'), findsNothing);
    expect(stockRepository.recordedSkuIds, ['sku-1']);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('tapping an already-recorded SKU does nothing', (tester) async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.stockDrafts).insert(StockDraftsCompanion.insert(
          id: 'draft-1',
          visitId: 'visit-1',
          skuId: 'sku-1',
          unitsAvailable: 40,
          lastStockinDate: DateTime(2026, 6, 30),
          daysOutOfStock: 0,
          velocityAvg: 10,
          salesActual: 350,
          salesTarget: 400,
        ));

    await tester.pumpWidget(_screenWith(_RecordingStockRepository(), db: db));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await tester.tap(find.text('Demo Brand 500ml'));
    await tester.pumpAndSettle();

    expect(find.text('Stock: Demo Brand 500ml'), findsNothing);
  });
}

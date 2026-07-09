import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/audit/data/pricing_repository.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s5_pricing_promotions_screen.dart';

class _FakeSkusRepository implements SkusRepository {
  @override
  Future<List<Sku>> listSkus() async => const [
        Sku(id: 's1', name: 'Test Cola', category: 'Beverages', minFacingsStandard: 4, rrp: 19.99),
      ];
}

class _SpyPricingRepository implements PricingRepository {
  String? visitDraftId;
  List<PricingEntry>? entries;

  @override
  Future<void> savePricing({required String visitDraftId, required List<PricingEntry> entries}) async {
    this.visitDraftId = visitDraftId;
    this.entries = entries;
  }
}

void main() {
  testWidgets('captures pricing entries and calls savePricing on Save', (tester) async {
    final spy = _SpyPricingRepository();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        skusRepositoryProvider.overrideWithValue(_FakeSkusRepository()),
        pricingRepositoryProvider.overrideWithValue(spy),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: S5PricingPromotionsScreen(visitDraftId: 'v1')),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('price-s1')), '18.50');
    await tester.ensureVisible(find.byKey(const ValueKey('promo-s1')));
    await tester.tap(find.byKey(const ValueKey('promo-s1')));
    await tester.enterText(find.byKey(const ValueKey('comms-s1')), '4');
    await tester.pump();

    await tester.ensureVisible(find.text('Save pricing'));
    await tester.tap(find.text('Save pricing'));
    await tester.pumpAndSettle();

    expect(spy.visitDraftId, 'v1');
    expect(spy.entries, hasLength(1));
    expect(spy.entries!.first.skuId, 's1');
    expect(spy.entries!.first.priceActual, 18.50);
    expect(spy.entries!.first.promoActive, true);
    expect(spy.entries!.first.promoMaterialsDetected, isEmpty);
    expect(spy.entries!.first.commsRating, 4);
    expect(find.text('Pricing saved — queued for sync'), findsOneWidget);
  });

  testWidgets('skips SKUs without a price on Save', (tester) async {
    final spy = _SpyPricingRepository();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        skusRepositoryProvider.overrideWithValue(_FakeSkusRepository()),
        pricingRepositoryProvider.overrideWithValue(spy),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: S5PricingPromotionsScreen(visitDraftId: 'v1')),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save pricing'));
    await tester.tap(find.text('Save pricing'));
    await tester.pumpAndSettle();

    expect(spy.visitDraftId, 'v1');
    expect(spy.entries, isEmpty);
  });
}

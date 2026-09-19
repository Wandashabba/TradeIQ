import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/camera/photo_capture_service.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';
import 'package:tradeiq_app/features/audit/data/pricing_repository.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s5_pricing_promotions_screen.dart';

import '../agent_harness.dart';
import 'section_harness.dart';

const _skus = <Sku>[
  Sku(
    id: 's1',
    name: 'Test Cola',
    category: 'Beverages',
    minFacingsStandard: 4,
    rrp: 19.99,
    daysOutOfStock: 0,
    velocityAvg: 4.2,
    effectivePrice: 19.99,
  ),
  Sku(
    id: 's2',
    name: 'Salt Crisps 125g',
    category: 'Snacks',
    minFacingsStandard: 2,
    rrp: 12.5,
    daysOutOfStock: 0,
    velocityAvg: 1.5,
    effectivePrice: 12.5,
  ),
];

class _Skus implements SkusRepository {
  _Skus([this.skus = _skus]);

  final List<Sku> skus;

  @override
  Future<PaginatedResponse<Sku>> listSkus({
    required String outletId,
    int? limit,
    String? cursor,
  }) async => PaginatedResponse<Sku>(data: skus, nextCursor: null);
}

class _SpyPricing implements PricingRepository {
  String? visitDraftId;
  List<PricingEntry>? entries;

  @override
  Future<void> savePricing({
    required String visitDraftId,
    required List<PricingEntry> entries,
  }) async {
    this.visitDraftId = visitDraftId;
    this.entries = entries;
  }
}

List<Override> _overrides(
  PricingRepository spy, {
  List<Sku> skus = _skus,
  QueuedPhotosRepository? photos,
}) => <Override>[
  skusRepositoryProvider.overrideWithValue(_Skus(skus)),
  pricingRepositoryProvider.overrideWithValue(spy),
  if (photos != null) queuedPhotosRepositoryProvider.overrideWithValue(photos),
  photoCaptureServiceProvider.overrideWithValue(fakeCapture()),
  scriptedExposure(0.5),
];

const _screen = S5PricingPromotionsScreen(visitDraftId: 'v1', outletId: 'o1');

Finder _key(String k) => find.byKey(ValueKey<String>(k));

void main() {
  testWidgets('captures price, promotion and comms, and saves them', (
    tester,
  ) async {
    final spy = _SpyPricing();
    await pumpSection(tester, _screen, overrides: _overrides(spy));

    await typeInSection(tester, _key('price-s1'), '18.50');
    await tapInSection(tester, _key('promo-s1'));
    await typeInSection(tester, _key('comms-s1'), '4');
    await saveSection(tester);

    expect(spy.visitDraftId, 'v1');
    final e = spy.entries!.single;
    expect(e.skuId, 's1');
    expect(e.priceActual, 18.5);
    expect(e.promoActive, isTrue);
    expect(e.commsRating, 4);
    expect(
      find.textContaining('Pricing saved — queued for sync'),
      findsOneWidget,
    );
    await disposeAgentScreen(tester);
  });

  testWidgets('a SKU with no price typed is not sent — untouched is not zero', (
    tester,
  ) async {
    final spy = _SpyPricing();
    await pumpSection(tester, _screen, overrides: _overrides(spy));
    await typeInSection(tester, _key('price-s2'), '12');
    await saveSection(tester);
    expect(spy.entries!.map((e) => e.skuId), <String>['s2']);
    await disposeAgentScreen(tester);
  });

  testWidgets('an Afrikaans price typed with a comma is the price, not R 0', (
    tester,
  ) async {
    final spy = _SpyPricing();
    await pumpSection(
      tester,
      _screen,
      overrides: _overrides(spy),
      locale: const Locale('af'),
    );
    await typeInSection(tester, _key('price-s1'), '24,99');
    await saveSection(tester);
    expect(spy.entries!.single.priceActual, 24.99);
    await disposeAgentScreen(tester);
  });

  testWidgets('the recommended price is read through the locale formatter', (
    tester,
  ) async {
    await pumpSection(tester, _screen, overrides: _overrides(_SpyPricing()));
    expect(find.text('RRP R 19.99'), findsOneWidget);
    await disposeAgentScreen(tester);
  });

  testWidgets('the shelf-price photo is queued under section: pricing', (
    tester,
  ) async {
    final photos = SpyQueuedPhotos();
    await pumpSection(
      tester,
      _screen,
      overrides: _overrides(_SpyPricing(), photos: photos),
    );
    await takeSectionPhoto(tester);
    await saveSection(tester);
    expect(photos.calls.single['section'], 'pricing');
    await disposeAgentScreen(tester);
  });

  testWidgets("no SKUs is an empty state with no Save, and can't-confirm", (
    tester,
  ) async {
    await pumpSection(
      tester,
      _screen,
      overrides: _overrides(_SpyPricing(), skus: const <Sku>[]),
    );
    expect(find.text('No SKUs configured for this client.'), findsOneWidget);
    expect(sectionSave, findsNothing);
    expect(_key('section-cant-confirm'), findsOneWidget);
    await disposeAgentScreen(tester);
  });

  group('the amber census', () {
    for (final skin in agentSkinModes) {
      testWidgets('untouched is zero, armed is one — ${skin.name}', (
        tester,
      ) async {
        await pumpSection(
          tester,
          _screen,
          overrides: _overrides(_SpyPricing()),
          skin: skin,
        );
        await expectAmber(
          tester,
          skin: skin,
          route: 'pricing',
          phase: 'untouched',
          expected: 0,
        );
        await tapInSection(tester, _key('promo-s1'));
        await scrollAgentTo(tester, sectionSave);
        await expectAmber(
          tester,
          skin: skin,
          route: 'pricing',
          phase: 'dirty',
          expected: 1,
        );
        await disposeAgentScreen(tester);
      });
    }
  });
}

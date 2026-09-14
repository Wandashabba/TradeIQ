import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/agent_kit.dart';
import 'package:tradeiq_app/core/widgets/console.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/widgets/photo_capture_field.dart';
import 'package:tradeiq_app/features/audit/data/pricing_repository.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s5_pricing_promotions_screen.dart';

class _FakeSkusRepository implements SkusRepository {
  @override
  Future<PaginatedResponse<Sku>> listSkus({
    required String outletId,
    int? limit,
    String? cursor,
  }) async => const PaginatedResponse(
    data: [
      Sku(
        id: 's1',
        name: 'Test Cola',
        category: 'Beverages',
        minFacingsStandard: 4,
        rrp: 19.99,
        daysOutOfStock: 0,
        velocityAvg: 0,
        effectivePrice: 19.99,
      ),
    ],
    nextCursor: null,
  );
}

class _SpyPricingRepository implements PricingRepository {
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

const _bothThemes = ['light', 'dark'];

ThemeData _themeFor(String name) =>
    name == 'light' ? AppTheme.light() : AppTheme.dark();

Widget _screen(PricingRepository spy, {ThemeData? theme, Key? key}) =>
    ProviderScope(
      overrides: [
        skusRepositoryProvider.overrideWithValue(_FakeSkusRepository()),
        pricingRepositoryProvider.overrideWithValue(spy),
      ],
      child: MaterialApp(
        theme: theme,
        // A fresh key per theme pass on BOTH the section (so its per-SKU form
        // State never carries) and the scroll view (so its scroll offset resets
        // — otherwise the second pass starts scrolled down and top-of-list taps
        // miss).
        home: Scaffold(
          body: SingleChildScrollView(
            key: key,
            child: S5PricingPromotionsScreen(
              key: key,
              visitDraftId: 'v1',
              outletId: 'ou1',
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets(
    'captures pricing entries and calls savePricing on Save — promo via '
    'AgentToggle',
    (tester) async {
      for (final name in _bothThemes) {
        final spy = _SpyPricingRepository();

        await tester.pumpWidget(
          _screen(spy, theme: _themeFor(name), key: ValueKey(name)),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const ValueKey('price-s1')), '18.50');
        // Promo active is now an AgentToggle — the key is preserved, so tapping
        // the row still flips the value.
        await tester.ensureVisible(find.byKey(const ValueKey('promo-s1')));
        await tester.tap(find.byKey(const ValueKey('promo-s1')));
        await tester.enterText(find.byKey(const ValueKey('comms-s1')), '4');
        await tester.pump();

        await tester.ensureVisible(find.text('Save pricing'));
        await tester.tap(find.text('Save pricing'));
        await tester.pumpAndSettle();

        expect(spy.visitDraftId, 'v1', reason: name);
        expect(spy.entries, hasLength(1), reason: name);
        expect(spy.entries!.first.skuId, 's1', reason: name);
        expect(spy.entries!.first.priceActual, 18.50, reason: name);
        expect(spy.entries!.first.promoActive, true, reason: name);
        expect(
          spy.entries!.first.promoMaterialsDetected,
          isEmpty,
          reason: name,
        );
        expect(spy.entries!.first.commsRating, 4, reason: name);
        expect(
          find.text('Pricing saved — queued for sync'),
          findsOneWidget,
          reason: name,
        );
      }
    },
  );

  testWidgets('skips SKUs without a price on Save', (tester) async {
    final spy = _SpyPricingRepository();

    await tester.pumpWidget(_screen(spy));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save pricing'));
    await tester.tap(find.text('Save pricing'));
    await tester.pumpAndSettle();

    // No price entered → no fabricated entry (never a phantom price).
    expect(spy.visitDraftId, 'v1');
    expect(spy.entries, isEmpty);
  });

  testWidgets(
    'each SKU is a PanelCard, price/comms are AgentFields, promo is an '
    'AgentToggle, save is an AgentButton — no raw '
    'Card/SwitchListTile/ElevatedButton',
    (tester) async {
      for (final name in _bothThemes) {
        await tester.pumpWidget(
          _screen(
            _SpyPricingRepository(),
            theme: _themeFor(name),
            key: ValueKey(name),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Card), findsNothing, reason: '$name no Card');
        expect(
          find.byType(SwitchListTile),
          findsNothing,
          reason: '$name no SwitchListTile',
        );
        expect(
          find.byType(ElevatedButton),
          findsNothing,
          reason: '$name no ElevatedButton',
        );

        // One SKU → one console PanelCard, its two numeric inputs are labelled
        // AgentFields, promo active is an AgentToggle, and the save is the
        // kit's button.
        final glass = tester
            .element(find.byType(S5PricingPromotionsScreen))
            .colors
            .glass;
        if (glass) {
          // Lumen Glass: the SKU is a no-blur glass tile (it repeats down the
          // list) headed by its name — not a console panel.
          expect(
            find.byType(PanelCard),
            findsNothing,
            reason: '$name no panel',
          );
          expect(
            find.ancestor(
              of: find.text('Test Cola'),
              matching: find.byWidgetPredicate(
                (w) => w is GlassPane && w.kind == GlassKind.tile && !w.blur,
              ),
            ),
            findsOneWidget,
            reason: '$name SKU glass tile',
          );
        } else {
          expect(find.byType(PanelCard), findsOneWidget, reason: '$name panel');
        }
        expect(
          find.byType(AgentField),
          findsNWidgets(2),
          reason: '$name two AgentFields',
        );
        expect(
          find.widgetWithText(AgentToggle, 'Promotion active'),
          findsOneWidget,
          reason: '$name promo AgentToggle',
        );
        expect(
          find.widgetWithText(AgentButton, 'Save pricing'),
          findsOneWidget,
          reason: '$name save is AgentButton',
        );
      }
    },
  );

  testWidgets(
    'the shelf-price photo capture field is preserved and renders in both '
    'themes',
    (tester) async {
      for (final name in _bothThemes) {
        await tester.pumpWidget(
          _screen(
            _SpyPricingRepository(),
            theme: _themeFor(name),
            key: ValueKey(name),
          ),
        );
        await tester.pumpAndSettle();

        // The evidence capture — wired to queuePhoto(section: 'pricing') — must
        // survive the console rebuild. (The section string itself is guarded by
        // the source-literal test below; here we prove the field still renders
        // with its label intact.)
        expect(
          find.byType(PhotoCaptureField),
          findsOneWidget,
          reason: '$name photo field present',
        );
        expect(
          tester
              .widget<PhotoCaptureField>(find.byType(PhotoCaptureField))
              .label,
          'Shelf-price photo',
          reason: '$name label',
        );
      }
    },
  );

  test('no non-geometry AppColors. remain in the S5 pricing source', () {
    final src = File(
      'lib/features/audit/presentation/sections/s5_pricing_promotions_screen.dart',
    ).readAsStringSync();
    final offenders = RegExp(
      r'AppColors\.(?!radiusPanel|radiusControl)\w+',
    ).allMatches(src).map((m) => m.group(0)).toSet().toList();
    expect(offenders, isEmpty, reason: 'use context.colors for: $offenders');
  });

  test('the shelf-price photo is queued under section: pricing', () {
    // The section string is the evidence-linkage key that later joins this
    // photo to the pricing section on the manager side. Nothing in the widget
    // tests captures a photo, so queuePhoto(section:) is never exercised at
    // runtime — this source-literal guard is what catches a silent flip to e.g.
    // 'visibility', which would misfile the evidence with the whole suite still
    // green.
    final src = File(
      'lib/features/audit/presentation/sections/s5_pricing_promotions_screen.dart',
    ).readAsStringSync();
    expect(src, contains("section: 'pricing'"));
  });
}

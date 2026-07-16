import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';
import 'package:tradeiq_app/features/orders/data/orders_repository.dart';
import 'package:tradeiq_app/features/orders/presentation/order_form_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

class _RecordingOrdersRepository implements OrdersRepository {
  String? outletId;
  List<OrderLine>? lines;

  @override
  Future<List<OrderItem>> listOrders({String? status, String? outletId}) async =>
      const [];

  @override
  Future<OrderItem> createOrder({
    required String outletId,
    required List<OrderLine> lines,
  }) async {
    this.outletId = outletId;
    this.lines = lines;
    return const OrderItem(
        id: 'o1', outletId: 'ou1', status: 'draft', total: 0, lineCount: 0);
  }
}

class _FakeOutletsRepository implements OutletsRepository {
  @override
  Future<List<Outlet>> listOutlets() async => const [
        Outlet(id: 'ou1', name: 'Shop One', code: 'S1', lat: 0, lng: 0),
        Outlet(id: 'ou2', name: 'Shop Two', code: 'S2', lat: 0, lng: 0),
      ];

  @override
  Future<Outlet> createOutlet({
    required String name,
    required String code,
    required String channelType,
    required double lat,
    required double lng,
    required String territoryId,
  }) async =>
      throw UnimplementedError();
}

class _FakeSkusRepository implements SkusRepository {
  @override
  Future<List<Sku>> listSkus({required String outletId}) async => const [
        Sku(
          id: 'sku1',
          name: 'Cola 500ml',
          category: 'beverage',
          minFacingsStandard: 4,
          rrp: 10.00,
          daysOutOfStock: 0,
          velocityAvg: 0,
          effectivePrice: 8.00,
        ),
        Sku(
          id: 'sku2',
          name: 'Chips 100g',
          category: 'snack',
          minFacingsStandard: 2,
          rrp: 5.00,
          daysOutOfStock: 0,
          velocityAvg: 0,
          effectivePrice: 4.00,
        ),
      ];
}

Widget _app(_RecordingOrdersRepository repo) => ProviderScope(
      overrides: [
        ordersRepositoryProvider.overrideWithValue(repo),
        outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
        skusRepositoryProvider.overrideWithValue(_FakeSkusRepository()),
      ],
      child: const MaterialApp(home: OrderFormScreen()),
    );

void main() {
  testWidgets('shows a placeholder instead of SKUs until an outlet is picked',
      (tester) async {
    final repo = _RecordingOrdersRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // SKUs are outlet-scoped (#112) — there is nothing to show yet.
    expect(
      find.text('Select an outlet to see available SKUs.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('sku-row-sku1')), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('order-outlet-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shop One').last);
    await tester.pumpAndSettle();

    // Once an outlet is picked, the placeholder is gone and SKUs appear.
    expect(
      find.text('Select an outlet to see available SKUs.'),
      findsNothing,
    );
    expect(find.byKey(const ValueKey<String>('sku-row-sku1')), findsOneWidget);

    // The per-line price shown to the agent must be the discounted
    // effectivePrice (8.00), not the plain rrp (10.00) — the agent's mental
    // math for the running total should match what they're actually charged.
    expect(find.text('R 8.00'), findsOneWidget);
    expect(find.text('R 10.00'), findsNothing);
  });

  testWidgets('captures outlet + line quantities and submits', (tester) async {
    final repo = _RecordingOrdersRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('order-outlet-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shop One').last);
    await tester.pumpAndSettle();

    // 2x Cola.
    final inc1 = find.byKey(const ValueKey<String>('sku-inc-sku1'));
    await tester.ensureVisible(inc1);
    await tester.tap(inc1);
    await tester.pump();
    await tester.tap(inc1);
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey<String>('order-total'))).data,
      // 2 x effectivePrice (8.00), not rrp (10.00) — the order form prices
      // lines at the promo-discounted rate (#99).
      'Total: R 16.00',
    );

    final save = find.byKey(const ValueKey<String>('order-save-button'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repo.outletId, 'ou1');
    expect(repo.lines, isNotNull);
    expect(repo.lines!.length, 1);
    expect(repo.lines!.first.skuId, 'sku1');
    expect(repo.lines!.first.quantity, 2);
    expect(repo.lines!.first.unitPrice, 8);
  });

  testWidgets('switching outlets clears previously entered quantities',
      (tester) async {
    final repo = _RecordingOrdersRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('order-outlet-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shop One').last);
    await tester.pumpAndSettle();

    // 2x Cola at Shop One.
    final inc1 = find.byKey(const ValueKey<String>('sku-inc-sku1'));
    await tester.ensureVisible(inc1);
    await tester.tap(inc1);
    await tester.pump();
    await tester.tap(inc1);
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey<String>('order-total'))).data,
      'Total: R 16.00',
    );

    // Switching to a different outlet must not silently carry the quantity
    // over — the agent never entered anything for this outlet (#112: SKUs are
    // now outlet-scoped, so a leftover _qty is no longer guaranteed to be
    // harmless).
    await tester.tap(find.byKey(const ValueKey<String>('order-outlet-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shop Two').last);
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey<String>('sku-qty-sku1'))).data,
      '0',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey<String>('order-total'))).data,
      'Total: R 0.00',
    );
  });

  testWidgets('blocks submit with no line items', (tester) async {
    final repo = _RecordingOrdersRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('order-outlet-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shop One').last);
    await tester.pumpAndSettle();

    final save = find.byKey(const ValueKey<String>('order-save-button'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.textContaining('Add at least one line item'), findsOneWidget);
    expect(repo.lines, isNull);
  });
}

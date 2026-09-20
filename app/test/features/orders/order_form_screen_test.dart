import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';
import 'package:tradeiq_app/features/orders/data/orders_repository.dart';
import 'package:tradeiq_app/features/orders/presentation/order_form_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../../core/design/amber_golden.dart';
import '../operations_harness.dart';

const List<Sku> _skus = <Sku>[
  Sku(
    id: 'sku1',
    name: 'Cola 500ml',
    category: 'beverage',
    minFacingsStandard: 4,
    rrp: 10,
    daysOutOfStock: 0,
    velocityAvg: 0,
    // The promo-discounted rate the agent is actually charged (#99), not the
    // shelf price.
    effectivePrice: 8,
  ),
  Sku(
    id: 'sku2',
    name: 'Chips 100g',
    category: 'snack',
    minFacingsStandard: 2,
    rrp: 5,
    daysOutOfStock: 0,
    velocityAvg: 0,
    effectivePrice: 4,
  ),
];

final List<Outlet> _outlets = <Outlet>[
  opsOutlet('ou1', 'Shop One', code: 'S1'),
  opsOutlet('ou2', 'Shop Two', code: 'S2'),
];

Future<FakeOrdersRepository> _pump(
  WidgetTester tester, {
  List<Sku> skus = _skus,
  Object? skusFailure,
  Object? createFailure,
  Object? outletsFailure,
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
}) async {
  final orders = FakeOrdersRepository(createFailure: createFailure);
  await pumpOperations(
    tester,
    const OrderFormScreen(),
    skin: skin,
    textScale: textScale,
    locale: locale,
    overrides: <Override>[
      ordersRepositoryProvider.overrideWithValue(orders),
      outletsRepositoryProvider.overrideWithValue(
        FakeOpsOutletsRepository(
          outlets: _outlets,
          listFailure: outletsFailure,
        ),
      ),
      skusRepositoryProvider.overrideWithValue(
        FakeSkusRepository(skus: skus, failure: skusFailure),
      ),
    ],
  );
  return orders;
}

/// The stepper's keys, by the label the reader hears.
Finder _stepper(String skuId) => find.byKey(ValueKey<String>('sku-qty-$skuId'));

Finder _step(String skuId, String label) => find.descendant(
  of: _stepper(skuId),
  matching: find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
  ),
);

Future<void> _bump(WidgetTester tester, String skuId, int times) async {
  for (var i = 0; i < times; i++) {
    await scrollOpsTo(tester, _step(skuId, 'One more'));
    await tester.tap(_step(skuId, 'One more'));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _pickStore(WidgetTester tester, String name) =>
    pickOption(tester, const ValueKey<String>('order-outlet-field'), name);

TorchPrimaryButton _submit(WidgetTester tester) =>
    tester.widget<TorchPrimaryButton>(
      find.byKey(const ValueKey<String>('order-save-button')),
    );

void main() {
  group('the store comes first', () {
    testWidgets('until a store is picked there is nothing to order', (
      tester,
    ) async {
      await _pump(tester);

      // SKUs are store-scoped (#112) — there is nothing to show yet.
      expect(
        find.text('Choose a store to see what it stocks.'),
        findsOneWidget,
      );
      expect(_stepper('sku1'), findsNothing);

      await _pickStore(tester, 'Shop One');

      expect(find.text('Choose a store to see what it stocks.'), findsNothing);
      await scrollOpsTo(tester, _stepper('sku1'));
      expect(_stepper('sku1'), findsOneWidget);

      // The per-line price shown to the agent must be the discounted
      // effectivePrice, not the plain rrp — the agent's mental arithmetic for
      // the running total should match what they are actually charged.
      expect(find.text('R 8.00'), findsOneWidget);
      expect(find.text('R 10.00'), findsNothing);
    });

    testWidgets('switching stores clears the quantities', (tester) async {
      await _pump(tester);
      await _pickStore(tester, 'Shop One');
      await _bump(tester, 'sku1', 2);

      await scrollOpsBackTo(
        tester,
        find.byKey(const ValueKey<String>('order-outlet-field')),
      );
      await _pickStore(tester, 'Shop Two');

      // A quantity belongs to a shelf in one shop. Carrying it over would
      // order twelve of something the other store does not stock (#112).
      await scrollOpsTo(tester, _stepper('sku1'));
      expect(
        tester.widget<CountStepper>(_stepper('sku1')).value,
        isNull,
        reason:
            'Not zero: a SKU nobody has touched is NOT on the order, which is '
            'a different thing from a line set to nought.',
      );
    });

    testWidgets('a store list that failed offers a retry', (tester) async {
      await _pump(
        tester,
        outletsFailure: StateError('SocketException: api.tradeiq.co.za'),
      );
      expect(find.text('The store list did not load.'), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
    });
  });

  group('the lines', () {
    testWidgets('captures the store and the quantities, and submits', (
      tester,
    ) async {
      final orders = await _pump(tester);
      await _pickStore(tester, 'Shop One');
      await _bump(tester, 'sku1', 2);

      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('order-total')),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('order-total')),
          // 2 x effectivePrice (8.00), not rrp (10.00): the order form prices
          // lines at the promo-discounted rate (#99).
          matching: find.text('R 16.00'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('order-save-button')));
      await tester.pumpAndSettle();

      expect(orders.createdOutletId, 'ou1');
      expect(orders.createdLines, isNotNull);
      expect(orders.createdLines!.length, 1);
      expect(orders.createdLines!.first.skuId, 'sku1');
      expect(orders.createdLines!.first.quantity, 2);
      expect(orders.createdLines!.first.unitPrice, 8);
    });

    testWidgets('a line explicitly set to nought is not sent', (tester) async {
      final orders = await _pump(tester);
      await _pickStore(tester, 'Shop One');
      await _bump(tester, 'sku1', 2);

      // Down to nought: a decision, not an absence. The stepper says so, and
      // the request leaves it out either way.
      for (var i = 0; i < 2; i++) {
        await scrollOpsTo(tester, _step('sku1', 'One fewer'));
        await tester.tap(_step('sku1', 'One fewer'));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(tester.widget<CountStepper>(_stepper('sku1')).value, 0);
      // Nothing above nought anywhere, so the commit is disarmed.
      expect(_submit(tester).onPressed, isNull);
      expect(orders.createCount, 0);
    });

    testWidgets('no lines keeps the commit disarmed, and says why', (
      tester,
    ) async {
      final orders = await _pump(tester);
      await _pickStore(tester, 'Shop One');

      final button = _submit(tester);
      expect(button.onPressed, isNull);
      expect(
        button.blockedReason,
        'Choose a store and set a quantity on at least one line first.',
      );
      expect(orders.createCount, 0);
    });

    testWidgets('a store with nothing stocked says so', (tester) async {
      await _pump(tester, skus: const <Sku>[]);
      await _pickStore(tester, 'Shop One');
      expect(find.text('Nothing is stocked here.'), findsOneWidget);
      expect(_submit(tester).onPressed, isNull);
    });

    testWidgets("a store's products that failed to load offer a retry", (
      tester,
    ) async {
      await _pump(
        tester,
        skusFailure: StateError('SocketException: api.tradeiq.co.za'),
      );
      await _pickStore(tester, 'Shop One');
      expect(find.text("That store's products did not load."), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
    });
  });

  group('failure', () {
    testWidgets('says nothing was sent, and does not print the exception', (
      tester,
    ) async {
      await _pump(
        tester,
        createFailure: StateError('SocketException: api.tradeiq.co.za'),
      );
      await _pickStore(tester, 'Shop One');
      await _bump(tester, 'sku1', 1);
      await tester.tap(find.byKey(const ValueKey<String>('order-save-button')));
      await tester.pumpAndSettle();

      expect(
        find.text('That order was not created. Nothing was sent.'),
        findsOneWidget,
      );
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      await settleOpsToasts(tester);
    });
  });

  group('Afrikaans and 2.0x', () {
    testWidgets('Afrikaans has no English left on it', (tester) async {
      await _pump(tester, locale: const Locale('af'));
      expect(find.text('Nuwe bestelling'), findsWidgets);
      expect(find.text('Watter winkel'), findsOneWidget);
      expect(find.text('Skep die bestelling'), findsOneWidget);
      expect(find.text('Which store'), findsNothing);
    });

    testWidgets('2.0x does not overflow', (tester) async {
      await _pump(tester, textScale: 2.0);
      await _pickStore(tester, 'Shop One');
      expect(tester.takeException(), isNull);
    });
  });

  group('the amber census, every phase in every skin', () {
    for (final skin in <TiqSkin>[
      TiqSkin.night(),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      testWidgets('${skin.mode.name}, nothing chosen: 0', (tester) async {
        await _pump(tester, skin: skin);
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'order-form',
          phase: 'form',
        );
        expect(census.objectCount, 0, reason: census.describe());
      });

      testWidgets('${skin.mode.name}, a line set: 1', (tester) async {
        await _pump(tester, skin: skin);
        await _pickStore(tester, 'Shop One');
        await _bump(tester, 'sku1', 1);
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'order-form',
          phase: 'ready',
        );
        expect(
          census.objectCount,
          1,
          reason:
              'One object: the commit. The nav is not on this route, so Night '
              'spends its second grant on nothing.\n${census.describe()}',
        );
      });
    }
  });
}

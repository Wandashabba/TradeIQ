import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/orders/data/orders_repository.dart';
import 'package:tradeiq_app/features/orders/presentation/orders_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../../core/design/amber_golden.dart';
import '../operations_harness.dart';

const OrderItem _submitted = OrderItem(
  id: 'ord-aaaaaaaa1',
  outletId: 'o1',
  status: 'submitted',
  total: 149.5,
  lineCount: 3,
);

const OrderItem _confirmed = OrderItem(
  id: 'ord-bbbbbbbb2',
  outletId: 'o2',
  status: 'confirmed',
  total: 42,
  lineCount: 1,
);

const OrderItem _cancelled = OrderItem(
  id: 'ord-cccccccc3',
  outletId: 'o9',
  status: 'cancelled',
  total: 10,
  lineCount: 1,
);

final List<Outlet> _outlets = <Outlet>[
  opsOutlet('o1', 'Kasi Corner Spaza'),
  opsOutlet('o2', 'Shoprite Klipspruit Mall'),
];

Future<FakeOrdersRepository> _pump(
  WidgetTester tester, {
  List<OrderItem> orders = const <OrderItem>[],
  Object? listFailure,
  bool listPending = false,

  /// The STORE list's own two unhappy phases. An order row is titled with the
  /// store's name, and `.value` is null while that list is being walked and
  /// null again when the walk failed — two states the screen used to report
  /// as a third, "Store not on this list".
  Object? outletsFailure,
  bool outletsPending = false,
  String role = 'manager',
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
}) async {
  final repo = FakeOrdersRepository(
    orders: orders,
    listFailure: listFailure,
    listPending: listPending,
  );
  await pumpOperations(
    tester,
    const OrdersScreen(),
    skin: skin,
    textScale: textScale,
    locale: locale,
    settle: !listPending && !outletsPending,
    overrides: <Override>[
      ordersRepositoryProvider.overrideWithValue(repo),
      outletsRepositoryProvider.overrideWithValue(
        FakeOpsOutletsRepository(
          outlets: _outlets,
          listFailure: outletsFailure,
          listPending: outletsPending,
        ),
      ),
      sessionControllerProvider.overrideWith(() => _Session(role)),
    ],
  );
  return repo;
}

class _Session extends SessionController {
  _Session(this.role);

  final String role;

  @override
  Future<SessionState> build() async => SessionState(role: role);
}

void main() {
  group('the rows', () {
    testWidgets('a row names the shop, not the order id', (tester) async {
      await _pump(tester, orders: const <OrderItem>[_submitted, _confirmed]);

      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('order-ord-aaaaaaaa1')),
      );
      expect(row.title, 'Kasi Corner Spaza');
      // The id stays reachable, in the identifier face, where a support
      // ticket can quote it.
      expect(find.text('ord-aaaaaaaa1'), findsOneWidget);
    });

    testWidgets('a store that is not on the list says so in words', (
      tester,
    ) async {
      await _pump(tester, orders: const <OrderItem>[_cancelled]);

      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('order-ord-cccccccc3')),
      );
      expect(row.title, 'Store not on this list');
      // Both ids are then in the meta line, because that is where a machine
      // identifier lives.
      expect(find.textContaining('o9'), findsOneWidget);
    });

    testWidgets('only a submitted order carries a severity, and a word', (
      tester,
    ) async {
      await _pump(
        tester,
        orders: const <OrderItem>[_submitted, _confirmed, _cancelled],
      );

      final open = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('order-ord-aaaaaaaa1')),
      );
      expect(open.severity, SoftRowSeverity.watch);
      expect(open.severityLabel, 'Submitted');

      // Cancelled is a closed fact, not a verdict on anybody. The old screen
      // painted it crimson-critical.
      final closed = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('order-ord-cccccccc3')),
      );
      expect(closed.severity, SoftRowSeverity.none);
    });

    testWidgets('consequence order: waiting first, closed last', (
      tester,
    ) async {
      final ordered = sortedOrders(const <OrderItem>[
        _cancelled,
        _confirmed,
        _submitted,
      ]);
      expect(ordered.first.id, _submitted.id);
      expect(ordered.last.id, _cancelled.id);
    });

    testWidgets('money goes through the one formatter', (tester) async {
      await _pump(tester, orders: const <OrderItem>[_submitted]);
      // Twice: once on the row and once in the value figure, which is a sum
      // of the one order there is.
      expect(find.text('R 149.50'), findsWidgets);
    });
  });

  group('a store list that has not arrived is not a missing store', () {
    // THE FAILURE, WRITTEN DOWN: the row read `.value` off the outlets
    // `AsyncValue`, and `.value` is null both while the list is being walked —
    // every page of GET /outlets, up to fifty of them — and when that walk
    // failed. Every order in the account was then titled "Store not on this
    // list": an unknown stated as a measured fact, and every row wearing the
    // same title. The old screen was uglier and never claimed anything untrue.
    testWidgets('while the store list is loading the row says so', (
      tester,
    ) async {
      await _pump(
        tester,
        orders: const <OrderItem>[_submitted, _confirmed],
        outletsPending: true,
      );
      await tester.pump(const Duration(milliseconds: 700));

      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('order-ord-aaaaaaaa1')),
      );
      expect(row.title, 'Store list still loading');
      expect(row.title, isNot('Store not on this list'));
      expect(row.semanticsLabel, contains('Store list still loading'));
      // The two rows stay apart: the ids are in the meta line.
      expect(find.textContaining('ord-aaaaaaaa1'), findsOneWidget);
      expect(find.textContaining('ord-bbbbbbbb2'), findsOneWidget);
    });

    testWidgets('a store list that failed says that, not that the store is '
        'missing', (tester) async {
      await _pump(
        tester,
        orders: const <OrderItem>[_submitted],
        outletsFailure: StateError('SocketException: api.tradeiq.co.za'),
      );

      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('order-ord-aaaaaaaa1')),
      );
      expect(row.title, 'Store list did not load');
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
    });

    testWidgets('a loaded list with the store genuinely absent still says so', (
      tester,
    ) async {
      // The claim the screen IS allowed to make, kept honest.
      await _pump(tester, orders: const <OrderItem>[_cancelled]);
      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('order-ord-cccccccc3')),
      );
      expect(row.title, 'Store not on this list');
    });
  });

  group('a page is not a history', () {
    testWidgets('an uncut list names no scope and carries no footer', (
      tester,
    ) async {
      await _pump(tester, orders: const <OrderItem>[_submitted, _confirmed]);

      expect(find.byType(PaginationFooter), findsNothing);
      final value = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('orders-value')),
      );
      expect(value.stateLine, isNull);
    });

    testWidgets('a cut list says what was summed, and how much was shown', (
      tester,
    ) async {
      await pumpOperations(
        tester,
        const OrdersScreen(),
        overrides: <Override>[
          ordersRepositoryProvider.overrideWithValue(_CutOrdersRepository()),
          outletsRepositoryProvider.overrideWithValue(
            FakeOpsOutletsRepository(outlets: _outlets),
          ),
        ],
      );

      final value = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('orders-value')),
      );
      expect(
        value.stateLine,
        'Summed over the 2 orders loaded, not the whole history.',
        reason:
            'The old screen printed a sum of one page under the words "Total '
            'value". That number was true of nothing.',
      );

      final awaiting = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('orders-awaiting')),
      );
      expect(awaiting.stateLine, contains('At least this many'));

      await scrollOpsTo(tester, find.byType(PaginationFooter));
      expect(find.text('Showing the 2 newest of 74 orders.'), findsOneWidget);
      expect(find.text('The figures above are of these 2.'), findsOneWidget);
    });

    testWidgets('a measured zero waiting still renders 0', (tester) async {
      await _pump(tester, orders: const <OrderItem>[_confirmed]);
      final tile = find.byKey(const ValueKey<String>('orders-awaiting'));
      expect(find.descendant(of: tile, matching: find.text('0')), findsWidgets);
    });
  });

  group('who may capture an order', () {
    testWidgets('a manager is offered the form', (tester) async {
      await _pump(tester, orders: const <OrderItem>[_submitted]);
      expect(find.byType(SectionRuleAction), findsOneWidget);
    });

    testWidgets('a field agent is offered the form', (tester) async {
      await _pump(
        tester,
        orders: const <OrderItem>[_submitted],
        role: 'field_agent',
      );
      expect(find.byType(SectionRuleAction), findsOneWidget);
    });

    testWidgets('an admin is not, because POST /orders refuses them', (
      tester,
    ) async {
      await _pump(tester, orders: const <OrderItem>[_submitted], role: 'admin');
      // A dishonest affordance is worse than none: the button would 403.
      expect(find.byType(SectionRuleAction), findsNothing);
    });
  });

  group('the states', () {
    testWidgets('loading is a skeleton', (tester) async {
      await _pump(tester, listPending: true);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(Skeleton), findsOneWidget);
    });

    testWidgets('empty offers the one next step', (tester) async {
      await _pump(tester);
      expect(find.text('No orders yet.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('order-create')),
        findsOneWidget,
      );
    });

    testWidgets('error sanitises and retries', (tester) async {
      await _pump(
        tester,
        listFailure: StateError('SocketException: api.tradeiq.co.za'),
      );
      expect(find.text('The order list did not load.'), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('orders-retry')),
        findsOneWidget,
      );
    });
  });

  group('Afrikaans and 2.0x', () {
    testWidgets('Afrikaans has no English left on it', (tester) async {
      await _pump(
        tester,
        orders: const <OrderItem>[_submitted],
        locale: const Locale('af'),
      );
      expect(find.text('Bestellings'), findsWidgets);
      expect(find.textContaining('WAG OP'), findsOneWidget);
      expect(find.textContaining('Ingedien'), findsWidgets);
      expect(find.text('Orders'), findsNothing);
    });

    testWidgets('2.0x does not overflow', (tester) async {
      await _pump(
        tester,
        orders: const <OrderItem>[_submitted, _confirmed],
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Afrikaans at 1.4x does not overflow either', (tester) async {
      await _pump(
        tester,
        orders: const <OrderItem>[_submitted, _confirmed],
        textScale: 1.4,
        locale: const Locale('af'),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('every button is operable by a screen reader', () {
    // The kit shipped a component family that announced itself and did
    // nothing when a screen reader activated it, and `SectionRuleAction` and
    // `PaginationFooter.action` were still shipping that way when this group
    // was migrated. This is the guard, on this screen, per phase — so no
    // local `Semantics(button: true, excludeSemantics: true)` around a bare
    // GestureDetector can bring it back.
    final phases = <String, Future<void> Function(WidgetTester)>{
      'loaded': (t) => _pump(
        t,
        orders: const <OrderItem>[_submitted, _confirmed, _cancelled],
      ),
      'empty': (t) => _pump(t),
      'error': (t) => _pump(t, listFailure: StateError('no route to host')),
    };
    for (final phase in phases.entries) {
      testWidgets(phase.key, (tester) async {
        final handle = tester.ensureSemantics();
        await phase.value(tester);
        expectEveryButtonActivatable(tester);
        handle.dispose();
      });
    }
  });

  group('the amber census, every phase in every skin', () {
    for (final skin in <TiqSkin>[
      TiqSkin.night(),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      final lit = skin.mode == SkinMode.night ? 1 : 0;
      final phases = <String, Future<void> Function(WidgetTester)>{
        'loaded': (t) => _pump(
          t,
          skin: skin,
          orders: const <OrderItem>[_submitted, _confirmed, _cancelled],
        ),
        'empty': (t) => _pump(t, skin: skin),
        'loading': (t) async {
          await _pump(t, skin: skin, listPending: true);
          await t.pump(const Duration(milliseconds: 700));
        },
        'error': (t) => _pump(
          t,
          skin: skin,
          listFailure: StateError('SocketException: api.tradeiq.co.za'),
        ),
      };
      for (final phase in phases.entries) {
        testWidgets('${skin.mode.name}, ${phase.key}: $lit', (tester) async {
          await phase.value(tester);
          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'orders',
            phase: phase.key,
          );
          expect(census.objectCount, lit, reason: census.describe());
        });
      }
    }
  });
}

/// A page with more behind it, and a server that counted the whole list.
class _CutOrdersRepository extends FakeOrdersRepository {
  _CutOrdersRepository()
    : super(orders: const <OrderItem>[_submitted, _confirmed]);

  @override
  Future<PaginatedResponse<OrderItem>> listOrders({
    String? status,
    String? outletId,
  }) async => const PaginatedResponse<OrderItem>(
    data: <OrderItem>[_submitted, _confirmed],
    nextCursor: 'cursor-2',
    total: 74,
  );
}

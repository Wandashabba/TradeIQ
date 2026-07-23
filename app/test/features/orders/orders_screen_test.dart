import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/orders/data/orders_repository.dart';
import 'package:tradeiq_app/features/orders/presentation/orders_screen.dart';

import '../../helpers/routed_app.dart';

const _orderA = OrderItem(
  id: 'ord-aaaaaaaa1',
  outletId: 'o1',
  status: 'submitted',
  total: 149.5,
  lineCount: 3,
);

const _orderB = OrderItem(
  id: 'ord-bbbbbbbb2',
  outletId: 'o2',
  status: 'draft',
  total: 42.0,
  lineCount: 1,
);

class _FakeOrdersRepository implements OrdersRepository {
  @override
  Future<PaginatedResponse<OrderItem>> listOrders({
    String? status,
    String? outletId,
  }) async =>
      const PaginatedResponse(data: [_orderA, _orderB], nextCursor: null);

  @override
  Future<OrderItem> createOrder({
    required String outletId,
    required List<OrderLine> lines,
  }) async =>
      _orderA;
}

class _FailingOrdersRepository implements OrdersRepository {
  @override
  Future<PaginatedResponse<OrderItem>> listOrders({
    String? status,
    String? outletId,
  }) async =>
      throw Exception('boom');

  @override
  Future<OrderItem> createOrder({
    required String outletId,
    required List<OrderLine> lines,
  }) async =>
      throw Exception('boom');
}

Widget _app(OrdersRepository repo) => routedApp(
      const OrdersScreen(),
      overrides: [
        ordersRepositoryProvider.overrideWithValue(repo),
      ],
    );

void main() {
  testWidgets('renders both orders once loaded', (tester) async {
    await tester.pumpWidget(_app(_FakeOrdersRepository()));
    await tester.pumpAndSettle();

    expect(find.text('submitted · 3 lines · total 149.50'), findsOneWidget);
    expect(find.text('draft · 1 lines · total 42.00'), findsOneWidget);
  });

  testWidgets('shows error state when loading fails', (tester) async {
    await tester.pumpWidget(_app(_FailingOrdersRepository()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Failed to load orders'),
      findsOneWidget,
    );
  });
}

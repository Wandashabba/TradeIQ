import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/orders_repository.dart';
import 'order_form_screen.dart';

/// Orders as a worklist: how many are waiting on a decision, then the rows.
/// Same shape as Alerts — triage counts, then one panel of rows.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersListProvider);
    final role = ref.watch(sessionControllerProvider).value?.role;
    // Order capture is a field-agent/manager action (matches POST /orders).
    final canCreate = role == 'field_agent' || role == 'manager';
    return ManagerScaffold(
      title: 'Orders',
      floatingActionButton: canCreate
          ? FloatingActionButton(
              key: const ValueKey<String>('order-create-fab'),
              tooltip: 'New order',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const OrderFormScreen(),
                ),
              ),
              child: const Icon(Icons.add),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Orders captured in the field. Submitted orders await confirmation.',
            style: TextStyle(fontSize: 12, color: context.colors.ink3),
          ),
          const SizedBox(height: 12),
          AsyncSection<List<OrderItem>>(
            value: orders,
            label: 'orders',
            onRetry: () => ref.invalidate(ordersListProvider),
            builder: (list) {
              final total = list.fold<double>(0, (sum, o) => sum + o.total);

              int countOf(String status) =>
                  list.where((o) => o.status == status).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TriageStrip(
                    counts: [
                      (
                        label: 'Submitted',
                        count: countOf('submitted'),
                        level: StatusLevel.warning,
                      ),
                      (
                        label: 'Confirmed',
                        count: countOf('confirmed'),
                        level: StatusLevel.good,
                      ),
                      (
                        label: 'Cancelled',
                        count: countOf('cancelled'),
                        level: StatusLevel.critical,
                      ),
                    ],
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SectionLabel('Total value'),
                        const SizedBox(height: 3),
                        Text(
                          total.toStringAsFixed(2),
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.4,
                            color: context.colors.ink1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _OrderList(orders: _sorted(list)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Consequence order: anything still awaiting a decision first, closed rows
  /// last. Nothing is filtered out — every order stays on the page.
  List<OrderItem> _sorted(List<OrderItem> all) {
    int rank(OrderItem o) => switch (o.status) {
          'submitted' => 0,
          'confirmed' => 2,
          'cancelled' => 3,
          _ => 1,
        };
    final sorted = [...all];
    sorted.sort((a, b) => rank(a).compareTo(rank(b)));
    return sorted;
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders});

  final List<OrderItem> orders;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: '${orders.length} ${orders.length == 1 ? 'order' : 'orders'}',
      subtitle: 'Awaiting confirmation first',
      padded: false,
      child: orders.isEmpty
          ? const EmptyState(
              message: 'No orders yet',
              hint: 'Orders appear here as agents capture them on a visit.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [for (final o in orders) _OrderRow(order: o)],
            ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final OrderItem order;

  /// Backend statuses are submitted | confirmed | cancelled; anything else is
  /// shown neutrally rather than guessed at.
  StatusLevel get _level => switch (order.status) {
        'submitted' => StatusLevel.warning,
        'confirmed' => StatusLevel.good,
        'cancelled' => StatusLevel.critical,
        _ => StatusLevel.neutral,
      };

  String get _statusLabel => order.status.isEmpty
      ? 'Unknown'
      : order.status[0].toUpperCase() + order.status.substring(1);

  @override
  Widget build(BuildContext context) {
    final shortId =
        order.id.substring(0, order.id.length >= 8 ? 8 : order.id.length);

    return WorklistRow(
      key: ValueKey<String>('order-${order.id}'),
      title: 'Order $shortId',
      // The status line is the manager-facing summary; the outlet it was
      // captured against is machine-facing, so it wears the mono token.
      meta: Row(
        children: [
          Flexible(
            flex: 3,
            child: Text(
              '${order.status} · ${order.lineCount} lines · total ${order.total.toStringAsFixed(2)}',
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(flex: 2, child: CodeToken(order.outletId)),
        ],
      ),
      level: _level,
      statusLabel: _statusLabel,
    );
  }
}

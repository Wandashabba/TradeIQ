import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../data/orders_repository.dart';
import 'order_form_screen.dart';

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
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load orders: $err'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(ordersListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) => _OrderCard(order: list[index]),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderItem order;

  @override
  Widget build(BuildContext context) {
    final shortId =
        order.id.substring(0, order.id.length >= 8 ? 8 : order.id.length);
    return Card(
      child: ListTile(
        title: Text('Order $shortId'),
        subtitle: Text(
          '${order.status} · ${order.lineCount} lines · total ${order.total.toStringAsFixed(2)}',
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audit/data/skus_repository.dart';
import '../../outlets/data/outlets_repository.dart';
import '../data/orders_repository.dart';

/// In-store order capture: pick an outlet, set quantities per SKU (unit price
/// defaults to the SKU's RRP), and submit. Posts to `POST /orders`.
class OrderFormScreen extends ConsumerStatefulWidget {
  const OrderFormScreen({super.key});

  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends ConsumerState<OrderFormScreen> {
  String? _outletId;
  final Map<String, int> _qty = <String, int>{};
  bool _submitting = false;

  void _bump(String skuId, int delta) {
    setState(() {
      final next = (_qty[skuId] ?? 0) + delta;
      if (next <= 0) {
        _qty.remove(skuId);
      } else {
        _qty[skuId] = next;
      }
    });
  }

  double _total(List<Sku> skus) {
    var total = 0.0;
    for (final sku in skus) {
      total += (_qty[sku.id] ?? 0) * sku.effectivePrice;
    }
    return total;
  }

  Future<void> _submit(List<Sku> skus) async {
    if (_outletId == null) {
      _snack('Select an outlet.');
      return;
    }
    final lines = <OrderLine>[
      for (final sku in skus)
        if ((_qty[sku.id] ?? 0) > 0)
          OrderLine(skuId: sku.id, quantity: _qty[sku.id]!, unitPrice: sku.effectivePrice),
    ];
    if (lines.isEmpty) {
      _snack('Add at least one line item.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(ordersRepositoryProvider)
          .createOrder(outletId: _outletId!, lines: lines);
      ref.invalidate(ordersListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _snack('Failed to create order: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final outlets = ref.watch(outletsListProvider);
    // SKUs are outlet-scoped now (#112) — there is nothing meaningful to show
    // until an outlet is picked, so the list is only watched once one is.
    final outletId = _outletId;
    final skus = outletId == null
        ? null
        : ref.watch(skusListProvider(outletId));

    return Scaffold(
      appBar: AppBar(title: const Text('New Order')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            outlets.when(
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Failed to load outlets: $err'),
              data: (list) => DropdownButtonFormField<String>(
                key: const ValueKey<String>('order-outlet-field'),
                initialValue: _outletId,
                decoration: const InputDecoration(
                    labelText: 'Outlet', border: OutlineInputBorder()),
                items: [
                  for (final o in list)
                    DropdownMenuItem(value: o.id, child: Text(o.name)),
                ],
                onChanged: (v) => setState(() {
                  _outletId = v;
                  _qty.clear();
                }),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Line items',
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (skus == null)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Select an outlet to see available SKUs.'),
              )
            else
              skus.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => Text('Failed to load SKUs: $err'),
                data: (list) => Column(
                  children: [
                    for (final sku in list)
                      ListTile(
                        key: ValueKey<String>('sku-row-${sku.id}'),
                        dense: true,
                        title: Text(sku.name),
                        subtitle: Text('R ${sku.effectivePrice.toStringAsFixed(2)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: ValueKey<String>('sku-dec-${sku.id}'),
                              icon: const Icon(Icons.remove),
                              onPressed: (_qty[sku.id] ?? 0) > 0
                                  ? () => _bump(sku.id, -1)
                                  : null,
                            ),
                            Text(
                              '${_qty[sku.id] ?? 0}',
                              key: ValueKey<String>('sku-qty-${sku.id}'),
                            ),
                            IconButton(
                              key: ValueKey<String>('sku-inc-${sku.id}'),
                              icon: const Icon(Icons.add),
                              onPressed: () => _bump(sku.id, 1),
                            ),
                          ],
                        ),
                      ),
                    const Divider(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Total: R ${_total(list).toStringAsFixed(2)}',
                        key: const ValueKey<String>('order-total'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const ValueKey<String>('order-save-button'),
                      onPressed: _submitting ? null : () => _submit(list),
                      child: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Create Order'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

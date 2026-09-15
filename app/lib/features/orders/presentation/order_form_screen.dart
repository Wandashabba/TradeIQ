import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/glass_page_scaffold.dart';
import '../../../core/widgets/lumen_kit.dart';
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

    final outletField = outlets.when(
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
    );

    return GlassPageScaffold(
      title: const Text('New Order'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: context.colors.glass
            ? _glassForm(outletField, skus)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  outletField,
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

  /// Glass: the outlet and the lines each get a panel, every line is a tile
  /// with a pill stepper, and the order total is a figure at the panel's foot
  /// — so the number the agent reads back to the store owner is the loudest
  /// thing on the page after the action.
  Widget _glassForm(Widget outletField, AsyncValue<List<Sku>>? skus) {
    final lumen = context.lumen;
    final list = switch (skus) {
      AsyncData(:final value) => value,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GlassSection(label: 'Outlet', children: [outletField]),
        const SizedBox(height: 14),
        _GlassSection(
          label: 'Line items',
          children: [
            if (skus == null)
              Text(
                'Select an outlet to see available SKUs.',
                style: TextStyle(fontSize: 13, color: lumen.inkMuted),
              )
            else
              skus.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => Text('Failed to load SKUs: $err'),
                data: (list) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final sku in list)
                      _GlassSkuRow(
                        key: ValueKey<String>('sku-row-${sku.id}'),
                        sku: sku,
                        qty: _qty[sku.id] ?? 0,
                        onBump: (delta) => _bump(sku.id, delta),
                      ),
                    const SizedBox(height: 4),
                    Divider(height: 1, color: lumen.white(0xB3)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Kicker('Order total'),
                        const Spacer(),
                        Text(
                          'R ${_total(list).toStringAsFixed(2)}',
                          key: const ValueKey<String>('order-total'),
                          style: LumenGlass.figure(size: 20, color: lumen.ink),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (list != null) ...[
          const SizedBox(height: 18),
          GlassPrimaryButton(
            key: const ValueKey<String>('order-save-button'),
            label: 'Create Order',
            busy: _submitting,
            onPressed: () => _submit(list),
          ),
        ],
      ],
    );
  }
}

/// A glass panel with its kicker — one group of the form.
class _GlassSection extends StatelessWidget {
  const _GlassSection({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassPane(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [Kicker(label), const SizedBox(height: 12), ...children],
      ),
    );
  }
}

/// One SKU line in glass: name and unit price, then the quantity as a pill
/// stepper. A no-blur tile — it repeats down the list.
class _GlassSkuRow extends StatelessWidget {
  const _GlassSkuRow({
    super.key,
    required this.sku,
    required this.qty,
    required this.onBump,
  });

  final Sku sku;
  final int qty;
  final ValueChanged<int> onBump;

  @override
  Widget build(BuildContext context) {
    final lumen = context.lumen;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassPane(
        kind: GlassKind.tile,
        blur: false,
        shadow: false,
        radius: LumenGlass.radiusControl,
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sku.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: lumen.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'R ${sku.effectivePrice.toStringAsFixed(2)}',
                    style: LumenGlass.figure(
                      size: 12,
                      color: lumen.inkMuted,
                      weight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GlassPane(
              kind: GlassKind.pill,
              shadow: false,
              radius: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: ValueKey<String>('sku-dec-${sku.id}'),
                    icon: const Icon(Icons.remove, size: 18),
                    color: lumen.accentInk,
                    visualDensity: VisualDensity.compact,
                    onPressed: qty > 0 ? () => onBump(-1) : null,
                  ),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '$qty',
                      key: ValueKey<String>('sku-qty-${sku.id}'),
                      textAlign: TextAlign.center,
                      style: LumenGlass.figure(
                        size: 15,
                        color: qty > 0 ? lumen.ink : lumen.inkMuted,
                      ),
                    ),
                  ),
                  IconButton(
                    key: ValueKey<String>('sku-inc-${sku.id}'),
                    icon: const Icon(Icons.add, size: 18),
                    color: lumen.accentInk,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onBump(1),
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

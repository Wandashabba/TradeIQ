import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/skus_repository.dart';
import '../../data/stock_repository.dart';

/// S2 — Stock & Availability capture. One row per client SKU; on save the
/// entries are persisted locally and queued for sync (POST /stock).
class S2StockScreen extends ConsumerWidget {
  const S2StockScreen({super.key, required this.visitDraftId});

  final String visitDraftId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skus = ref.watch(skusListProvider);
    return skus.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Failed to load SKUs: $err')),
      data: (list) => _StockForm(visitDraftId: visitDraftId, skus: list),
    );
  }
}

class _StockForm extends ConsumerStatefulWidget {
  const _StockForm({required this.visitDraftId, required this.skus});

  final String visitDraftId;
  final List<Sku> skus;

  @override
  ConsumerState<_StockForm> createState() => _StockFormState();
}

class _StockFormState extends ConsumerState<_StockForm> {
  final _units = <String, TextEditingController>{};
  final _oos = <String, TextEditingController>{};
  final _velocity = <String, TextEditingController>{};
  final _salesActual = <String, TextEditingController>{};
  final _salesTarget = <String, TextEditingController>{};
  final _lastStockin = <String, DateTime>{};
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    for (final sku in widget.skus) {
      _units[sku.id] = TextEditingController();
      _oos[sku.id] = TextEditingController(text: '0');
      _velocity[sku.id] = TextEditingController();
      _salesActual[sku.id] = TextEditingController();
      _salesTarget[sku.id] = TextEditingController();
      _lastStockin[sku.id] = DateTime.now();
    }
  }

  @override
  void dispose() {
    for (final c in [..._units.values, ..._oos.values, ..._velocity.values, ..._salesActual.values, ..._salesTarget.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final entries = widget.skus.map((sku) {
      return StockEntry(
        skuId: sku.id,
        unitsAvailable: int.tryParse(_units[sku.id]!.text) ?? 0,
        lastStockinDate: _lastStockin[sku.id]!,
        daysOutOfStock: int.tryParse(_oos[sku.id]!.text) ?? 0,
        velocityAvg: double.tryParse(_velocity[sku.id]!.text) ?? 0.0,
        salesActual: double.tryParse(_salesActual[sku.id]!.text) ?? 0.0,
        salesTarget: double.tryParse(_salesTarget[sku.id]!.text) ?? 0.0,
      );
    }).toList();

    await ref.read(stockRepositoryProvider).saveStock(
          visitDraftId: widget.visitDraftId,
          entries: entries,
        );
    if (mounted) setState(() => _saved = true);
  }

  Widget _numField(String label, Key key, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        key: key,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.skus.isEmpty) {
      return const Center(child: Text('No SKUs configured for this client.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('S2 Stock & Availability'),
        const SizedBox(height: 8),
        for (final sku in widget.skus)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sku.name, style: Theme.of(context).textTheme.titleMedium),
                  _numField('Units available', ValueKey('units-${sku.id}'), _units[sku.id]!),
                  _numField('Days out of stock', ValueKey('oos-${sku.id}'), _oos[sku.id]!),
                  _numField('Avg daily velocity', ValueKey('vel-${sku.id}'), _velocity[sku.id]!),
                  _numField('Sales actual', ValueKey('sactual-${sku.id}'), _salesActual[sku.id]!),
                  _numField('Sales target', ValueKey('starget-${sku.id}'), _salesTarget[sku.id]!),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _save, child: const Text('Save stock')),
        if (_saved)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Stock saved — queued for sync'),
          ),
      ],
    );
  }
}

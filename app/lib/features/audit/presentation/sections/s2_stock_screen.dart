import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/local_db.dart';
import '../../data/stock_repository.dart';
import '../../../skus/data/skus_repository.dart';

class S2StockScreen extends ConsumerStatefulWidget {
  const S2StockScreen({super.key, required this.visitId});

  final String visitId;

  @override
  ConsumerState<S2StockScreen> createState() => _S2StockScreenState();
}

class _S2StockScreenState extends ConsumerState<S2StockScreen> {
  Set<String> _recordedSkuIds = {};
  bool _loadedRecorded = false;

  @override
  void initState() {
    super.initState();
    _loadRecordedSkuIds();
  }

  Future<void> _loadRecordedSkuIds() async {
    final db = ref.read(localDbProvider);
    final rows = await (db.select(db.stockDrafts)..where((t) => t.visitId.equals(widget.visitId))).get();
    if (!mounted) return;
    setState(() {
      _recordedSkuIds = rows.map((r) => r.skuId).toSet();
      _loadedRecorded = true;
    });
  }

  Future<void> _openStockForm(Sku sku) async {
    final result = await showDialog<_StockFormResult>(
      context: context,
      builder: (context) => _StockFormDialog(sku: sku),
    );
    if (result == null) return;

    await ref.read(stockRepositoryProvider).recordStock(
          visitId: widget.visitId,
          skuId: sku.id,
          unitsAvailable: result.unitsAvailable,
          lastStockinDate: result.lastStockinDate,
          daysOutOfStock: result.daysOutOfStock,
          velocityAvg: result.velocityAvg,
          salesActual: result.salesActual,
          salesTarget: result.salesTarget,
        );

    if (!mounted) return;
    setState(() => _recordedSkuIds = {..._recordedSkuIds, sku.id});
  }

  @override
  Widget build(BuildContext context) {
    if (!_loadedRecorded) {
      return const Center(child: CircularProgressIndicator());
    }

    final skusAsync = ref.watch(skusListProvider);

    return skusAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Failed to load SKUs: $err')),
      data: (skus) => ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: skus.length,
        itemBuilder: (context, index) {
          final sku = skus[index];
          final recorded = _recordedSkuIds.contains(sku.id);
          return ListTile(
            title: Text(sku.name),
            subtitle: Text(sku.category),
            trailing: recorded ? const Icon(Icons.check_circle, color: Colors.green) : null,
            onTap: recorded ? null : () => _openStockForm(sku),
          );
        },
      ),
    );
  }
}

class _StockFormResult {
  const _StockFormResult({
    required this.unitsAvailable,
    required this.lastStockinDate,
    required this.daysOutOfStock,
    required this.velocityAvg,
    required this.salesActual,
    required this.salesTarget,
  });

  final int unitsAvailable;
  final DateTime lastStockinDate;
  final int daysOutOfStock;
  final double velocityAvg;
  final double salesActual;
  final double salesTarget;
}

class _StockFormDialog extends StatefulWidget {
  const _StockFormDialog({required this.sku});

  final Sku sku;

  @override
  State<_StockFormDialog> createState() => _StockFormDialogState();
}

class _StockFormDialogState extends State<_StockFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _unitsAvailableController = TextEditingController();
  final _daysOutOfStockController = TextEditingController();
  final _velocityAvgController = TextEditingController();
  final _salesActualController = TextEditingController();
  final _salesTargetController = TextEditingController();
  DateTime? _lastStockinDate;

  @override
  void dispose() {
    _unitsAvailableController.dispose();
    _daysOutOfStockController.dispose();
    _velocityAvgController.dispose();
    _salesActualController.dispose();
    _salesTargetController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastStockinDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (picked != null) setState(() => _lastStockinDate = picked);
  }

  void _submit() {
    final formValid = _formKey.currentState!.validate();
    if (!formValid || _lastStockinDate == null) {
      setState(() {}); // rebuild so a missing-date error becomes visible
      return;
    }

    Navigator.of(context).pop(_StockFormResult(
      unitsAvailable: int.parse(_unitsAvailableController.text),
      lastStockinDate: _lastStockinDate!,
      daysOutOfStock: int.parse(_daysOutOfStockController.text),
      velocityAvg: double.parse(_velocityAvgController.text),
      salesActual: double.parse(_salesActualController.text),
      salesTarget: double.parse(_salesTargetController.text),
    ));
  }

  String? _requiredInt(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    if (int.tryParse(value) == null) return 'Must be a whole number';
    return null;
  }

  String? _requiredDouble(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    if (double.tryParse(value) == null) return 'Must be a number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Stock: ${widget.sku.name}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _unitsAvailableController,
                decoration: const InputDecoration(labelText: 'Units available'),
                keyboardType: TextInputType.number,
                validator: _requiredInt,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_lastStockinDate == null
                    ? 'Last stock-in date'
                    : 'Last stock-in: ${_lastStockinDate!.toIso8601String().split('T').first}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              if (_lastStockinDate == null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Required', style: TextStyle(color: Colors.red)),
                ),
              TextFormField(
                controller: _daysOutOfStockController,
                decoration: const InputDecoration(labelText: 'Days out of stock'),
                keyboardType: TextInputType.number,
                validator: _requiredInt,
              ),
              TextFormField(
                controller: _velocityAvgController,
                decoration: const InputDecoration(labelText: 'Average daily velocity'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _requiredDouble,
              ),
              TextFormField(
                controller: _salesActualController,
                decoration: const InputDecoration(labelText: 'Sales actual'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _requiredDouble,
              ),
              TextFormField(
                controller: _salesTargetController,
                decoration: const InputDecoration(labelText: 'Sales target'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _requiredDouble,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../outlets/data/outlets_repository.dart';
import '../data/reports_repository.dart';

const _reportTypes = <String>['visits', 'scorecards', 'tasks', 'orders'];

/// Manager/admin report builder: name + type + optional date-range and outlet
/// filters. Posts a saved report definition to `POST /reports`.
class ReportFormScreen extends ConsumerStatefulWidget {
  const ReportFormScreen({super.key});

  @override
  ConsumerState<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends ConsumerState<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String _type = _reportTypes.first;
  DateTime? _from;
  DateTime? _to;
  String? _outletId;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? DateTime(2026, 1, 1),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final fromStr = _from == null ? null : _fmt(_from!);
    final toStr = _to == null ? null : _fmt(_to!);
    final filters = <String, dynamic>{
      'from': ?fromStr,
      'to': ?toStr,
      'outletId': ?_outletId,
    };
    try {
      await ref.read(reportsRepositoryProvider).createReport(
            name: _nameCtrl.text.trim(),
            type: _type,
            filters: filters,
          );
      ref.invalidate(reportsListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create report: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outlets = ref.watch(outletsListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('New Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const ValueKey<String>('report-name-field'),
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Name', border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey<String>('report-type-field'),
                initialValue: _type,
                decoration: const InputDecoration(
                    labelText: 'Type', border: OutlineInputBorder()),
                items: [
                  for (final t in _reportTypes)
                    DropdownMenuItem(value: t, child: Text(t)),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 16),
              _DateRow(
                label: 'From',
                value: _from == null ? null : _fmt(_from!),
                buttonKey: 'report-from-date',
                onPressed: () => _pickDate(isFrom: true),
              ),
              const SizedBox(height: 8),
              _DateRow(
                label: 'To',
                value: _to == null ? null : _fmt(_to!),
                buttonKey: 'report-to-date',
                onPressed: () => _pickDate(isFrom: false),
              ),
              const SizedBox(height: 12),
              outlets.when(
                loading: () => const LinearProgressIndicator(),
                error: (err, _) => Text('Failed to load outlets: $err'),
                data: (list) => DropdownButtonFormField<String>(
                  key: const ValueKey<String>('report-outlet-field'),
                  initialValue: _outletId,
                  decoration: const InputDecoration(
                      labelText: 'Outlet (optional)',
                      border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All outlets')),
                    for (final o in list)
                      DropdownMenuItem(value: o.id, child: Text(o.name)),
                  ],
                  onChanged: (v) => setState(() => _outletId = v),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey<String>('report-save-button'),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Create Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.buttonKey,
    required this.onPressed,
  });

  final String label;
  final String? value;
  final String buttonKey;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(value == null ? '$label: any' : '$label: $value')),
        OutlinedButton(
          key: ValueKey<String>(buttonKey),
          onPressed: onPressed,
          child: const Text('Pick'),
        ),
      ],
    );
  }
}

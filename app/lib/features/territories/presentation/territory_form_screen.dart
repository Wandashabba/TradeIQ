import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/glass_page_scaffold.dart';
import '../../../core/widgets/lumen_kit.dart';
import '../data/territories_repository.dart';

/// Manager/admin screen to create a territory (name, code, optional region).
class TerritoryFormScreen extends ConsumerStatefulWidget {
  const TerritoryFormScreen({super.key});

  @override
  ConsumerState<TerritoryFormScreen> createState() =>
      _TerritoryFormScreenState();
}

class _TerritoryFormScreenState extends ConsumerState<TerritoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _regionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final region = _regionCtrl.text.trim();
    try {
      await ref
          .read(territoriesRepositoryProvider)
          .createTerritory(
            name: _nameCtrl.text.trim(),
            code: _codeCtrl.text.trim(),
            region: region.isEmpty ? null : region,
          );
      ref.invalidate(territoriesListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create territory: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      TextFormField(
        key: const ValueKey<String>('territory-name-field'),
        controller: _nameCtrl,
        decoration: const InputDecoration(
          labelText: 'Name',
          border: OutlineInputBorder(),
        ),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        key: const ValueKey<String>('territory-code-field'),
        controller: _codeCtrl,
        decoration: const InputDecoration(
          labelText: 'Code',
          border: OutlineInputBorder(),
        ),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _regionCtrl,
        decoration: const InputDecoration(
          labelText: 'Region (optional)',
          border: OutlineInputBorder(),
        ),
      ),
    ];

    return GlassPageScaffold(
      title: const Text('New Territory'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: context.colors.glass
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassPane(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Kicker('Territory'),
                          const SizedBox(height: 12),
                          ...fields,
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    GlassPrimaryButton(
                      key: const ValueKey<String>('territory-save-button'),
                      label: 'Create Territory',
                      busy: _submitting,
                      onPressed: _submit,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...fields,
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const ValueKey<String>('territory-save-button'),
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Create Territory'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

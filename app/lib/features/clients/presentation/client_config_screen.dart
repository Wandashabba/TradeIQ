import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/manager_scaffold.dart';
import '../data/clients_repository.dart';

class ClientConfigScreen extends ConsumerWidget {
  const ClientConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(clientConfigProvider);
    return ManagerScaffold(
      title: 'Scoring Config',
      body: config.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load config: $err'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(clientConfigProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (cfg) => _ConfigForm(config: cfg),
      ),
    );
  }
}

class _ConfigForm extends ConsumerStatefulWidget {
  const _ConfigForm({required this.config});

  final ClientConfig config;

  @override
  ConsumerState<_ConfigForm> createState() => _ConfigFormState();
}

class _ConfigFormState extends ConsumerState<_ConfigForm> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    widget.config.scorecardWeights.forEach((key, value) {
      _controllers[key] = TextEditingController(text: value.toString());
    });
  }

  Future<void> _submit() async {
    final map = <String, double>{};
    _controllers.forEach((key, controller) {
      map[key] = double.tryParse(controller.text) ?? 0;
    });
    await ref.read(clientsRepositoryProvider).updateWeights(map);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      ref.invalidate(clientConfigProvider);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in _controllers.entries) ...[
            TextField(
              key: ValueKey<String>('weight-${entry.key}'),
              controller: entry.value,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: entry.key,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          ElevatedButton(
            key: const ValueKey<String>('save-config'),
            onPressed: _submit,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

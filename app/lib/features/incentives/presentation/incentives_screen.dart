import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../data/incentives_repository.dart';

class IncentivesScreen extends ConsumerWidget {
  const IncentivesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemes = ref.watch(incentivesListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incentives'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add scheme',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _CreateSchemeDialog(),
        ),
        child: const Icon(Icons.add),
      ),
      body: schemes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load incentives: $err'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(incentivesListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) => _SchemeCard(scheme: list[index]),
        ),
      ),
    );
  }
}

class _SchemeCard extends ConsumerWidget {
  const _SchemeCard({required this.scheme});

  final IncentiveScheme scheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(scheme.name),
        subtitle: Text(
          '${scheme.metric} ≥ ${scheme.threshold.toStringAsFixed(0)} → ${scheme.rewardPoints} pts',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              key: ValueKey<String>('toggle-${scheme.id}'),
              value: scheme.active,
              onChanged: (value) async {
                await ref
                    .read(incentivesRepositoryProvider)
                    .setActive(scheme.id, value);
                ref.invalidate(incentivesListProvider);
              },
            ),
            IconButton(
              key: ValueKey<String>('delete-${scheme.id}'),
              icon: const Icon(Icons.delete),
              onPressed: () async {
                await ref
                    .read(incentivesRepositoryProvider)
                    .deleteScheme(scheme.id);
                ref.invalidate(incentivesListProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateSchemeDialog extends ConsumerStatefulWidget {
  const _CreateSchemeDialog();

  @override
  ConsumerState<_CreateSchemeDialog> createState() => _CreateSchemeDialogState();
}

class _CreateSchemeDialogState extends ConsumerState<_CreateSchemeDialog> {
  final _nameCtrl = TextEditingController();
  final _thresholdCtrl = TextEditingController();
  final _rewardPointsCtrl = TextEditingController();
  String _metric = 'scorecard';
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _thresholdCtrl.dispose();
    _rewardPointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _submitting = true);
    try {
      await ref.read(incentivesRepositoryProvider).createScheme(
            name: _nameCtrl.text.trim(),
            metric: _metric,
            threshold: double.tryParse(_thresholdCtrl.text) ?? 0,
            rewardPoints: int.tryParse(_rewardPointsCtrl.text) ?? 0,
          );
      ref.invalidate(incentivesListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create scheme: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Scheme'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey<String>('new-name'),
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey<String>('new-metric'),
            initialValue: _metric,
            decoration: const InputDecoration(labelText: 'Metric'),
            items: const [
              DropdownMenuItem(value: 'scorecard', child: Text('scorecard')),
              DropdownMenuItem(
                value: 'tasks_closed',
                child: Text('tasks_closed'),
              ),
              DropdownMenuItem(value: 'visits', child: Text('visits')),
            ],
            onChanged: (v) => setState(() => _metric = v ?? 'scorecard'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('new-threshold'),
            controller: _thresholdCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Threshold'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('new-reward-points'),
            controller: _rewardPointsCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Reward points'),
          ),
        ],
      ),
      actions: [
        FilledButton(
          key: const ValueKey<String>('create-scheme'),
          onPressed: _submitting ? null : _create,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/incentives_repository.dart';

/// Incentive schemes as a worklist: the rule that pays out is the row, and
/// whether it is currently paying is a mark *and* a word.
class IncentivesScreen extends ConsumerWidget {
  const IncentivesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemes = ref.watch(incentivesListProvider);

    return ManagerScaffold(
      title: 'Incentives',
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add scheme',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _CreateSchemeDialog(),
        ),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'A scheme awards points when an agent reaches its threshold on the '
            'chosen metric. Paused schemes stop awarding.',
            style: TextStyle(fontSize: 12, color: context.colors.ink3),
          ),
          const SizedBox(height: 12),
          AsyncSection<List<IncentiveScheme>>(
            value: schemes,
            label: 'incentives',
            onRetry: () => ref.invalidate(incentivesListProvider),
            builder: (list) {
              final live = list.where((s) => s.active).length;
              return PanelCard(
                title: '${list.length} '
                    '${list.length == 1 ? 'scheme' : 'schemes'}',
                subtitle: '$live awarding',
                padded: false,
                child: list.isEmpty
                    ? const EmptyState(
                        message: 'No schemes configured',
                        hint: 'Add a scheme to start rewarding agents who clear '
                            'a threshold.',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final s in list) _SchemeRow(scheme: s),
                        ],
                      ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SchemeRow extends ConsumerWidget {
  const _SchemeRow({required this.scheme});

  final IncentiveScheme scheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> setActive(bool value) async {
      await ref.read(incentivesRepositoryProvider).setActive(scheme.id, value);
      ref.invalidate(incentivesListProvider);
    }

    Future<void> delete() async {
      await ref.read(incentivesRepositoryProvider).deleteScheme(scheme.id);
      ref.invalidate(incentivesListProvider);
    }

    return WorklistRow(
      title: scheme.name,
      // The metric is a key the scoring engine knows, so it wears the token;
      // the rule it forms is read as prose beside it.
      meta: Row(
        children: [
          CodeToken(scheme.metric),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '≥ ${scheme.threshold.toStringAsFixed(0)} '
              '· ${scheme.rewardPoints} pts',
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      level: scheme.active ? StatusLevel.good : StatusLevel.neutral,
      statusLabel: scheme.active ? 'Active' : 'Paused',
      resolved: !scheme.active,
      actions: [
        Switch(
          key: ValueKey<String>('toggle-${scheme.id}'),
          value: scheme.active,
          onChanged: (value) => setActive(value),
        ),
        RowAction(
          key: ValueKey<String>('delete-${scheme.id}'),
          label: 'Delete',
          tone: StatusLevel.critical,
          onPressed: delete,
        ),
      ],
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('create-scheme'),
          onPressed: _submitting ? null : _create,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

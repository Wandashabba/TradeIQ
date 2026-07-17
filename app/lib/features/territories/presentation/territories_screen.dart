import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../../users/data/users_repository.dart';
import '../data/territories_repository.dart';
import 'territory_form_screen.dart';
import 'territory_map_screen.dart';

/// Coverage for one territory. Kept per-id and cached by Riverpod so a row
/// that rebuilds does not re-fetch.
final _coverageProvider =
    FutureProvider.family<TerritoryCoverage, String>((ref, id) {
  return ref.read(territoriesRepositoryProvider).getCoverage(id);
});

class TerritoriesScreen extends ConsumerWidget {
  const TerritoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final territories = ref.watch(territoriesListProvider);
    final role = ref.watch(sessionControllerProvider).value?.role;
    // Creating territories and assigning agents are manager/admin actions.
    final canManage = role == 'manager' || role == 'admin';

    return ManagerScaffold(
      title: 'Territories',
      floatingActionButton: canManage
          ? FloatingActionButton(
              key: const ValueKey<String>('territory-create-fab'),
              tooltip: 'New territory',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const TerritoryFormScreen(),
                ),
              ),
              child: const Icon(Icons.add),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'A territory groups outlets and the agents who work them. '
            'Open a row for its full coverage.',
            style: TextStyle(fontSize: 12, color: AppColors.ink3),
          ),
          const SizedBox(height: 12),
          AsyncSection<List<Territory>>(
            value: territories,
            label: 'territories',
            onRetry: () => ref.invalidate(territoriesListProvider),
            builder: (list) => PanelCard(
              title: '${list.length} '
                  '${list.length == 1 ? 'territory' : 'territories'}',
              subtitle: 'Outlet and agent counts, plus coverage rate',
              padded: false,
              child: list.isEmpty
                  ? const EmptyState(
                      message: 'No territories yet',
                      hint: 'Create one to group outlets and assign agents.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final t in list)
                          _TerritoryRow(territory: t, canManage: canManage),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TerritoryRow extends ConsumerWidget {
  const _TerritoryRow({required this.territory, required this.canManage});

  final Territory territory;
  final bool canManage;

  Future<void> _showCoverage(BuildContext context, WidgetRef ref) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(territory.name),
        content: FutureBuilder<TerritoryCoverage>(
          key: ValueKey<String>('coverage-${territory.id}'),
          future:
              ref.read(territoriesRepositoryProvider).getCoverage(territory.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Text('Failed to load coverage: ${snapshot.error}');
            }
            final coverage = snapshot.data!;
            return Text(
              'Outlets: ${coverage.outletCount}   Agents: ${coverage.agentCount}\n'
              'Coverage: ${coverage.coverageRate.round()}%',
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignAgent(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => _AssignAgentDialog(territory: territory),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverage = ref.watch(_coverageProvider(territory.id));

    // A territory nobody is assigned to is the one state worth flagging; the
    // rest is just a count, so it stays neutral.
    final (level, status) = switch (coverage) {
      AsyncData(:final value) when value.agentCount == 0 => (
          StatusLevel.warning,
          'Unassigned',
        ),
      AsyncData() => (StatusLevel.good, 'Assigned'),
      _ => (StatusLevel.neutral, null),
    };

    final figures = switch (coverage) {
      AsyncData(:final value) =>
        '${value.outletCount} outlets · ${value.agentCount} agents · '
            '${value.coverageRate.round()}% covered',
      AsyncError() => 'Coverage unavailable',
      _ => 'Loading coverage…',
    };
    final region = territory.region;

    return WorklistRow(
      key: ValueKey<String>('territory-${territory.id}'),
      title: territory.name,
      // The code is what the back office quotes; the figures beside it are the
      // plain counts the coverage endpoint returns.
      meta: Row(
        children: [
          CodeToken(territory.code),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              region == null ? figures : '$region · $figures',
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      level: level,
      statusLabel: status,
      onTap: () => _showCoverage(context, ref),
      actions: [
        RowAction(
          key: ValueKey<String>('territory-map-${territory.id}'),
          label: 'Map',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => TerritoryMapScreen(territory: territory),
            ),
          ),
        ),
        if (canManage)
          RowAction(
            key: ValueKey<String>('territory-assign-${territory.id}'),
            label: 'Assign',
            onPressed: () => _assignAgent(context),
          ),
      ],
    );
  }
}

/// Dialog that assigns a selected field agent to [territory].
class _AssignAgentDialog extends ConsumerStatefulWidget {
  const _AssignAgentDialog({required this.territory});

  final Territory territory;

  @override
  ConsumerState<_AssignAgentDialog> createState() => _AssignAgentDialogState();
}

class _AssignAgentDialogState extends ConsumerState<_AssignAgentDialog> {
  String? _agentId;
  bool _submitting = false;

  Future<void> _assign() async {
    if (_agentId == null) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(territoriesRepositoryProvider)
          .assignAgent(widget.territory.id, _agentId!);
      if (mounted) {
        // The row's coverage figure is now stale — drop it so it refetches.
        ref.invalidate(_coverageProvider(widget.territory.id));
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agent assigned.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign agent: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final agents = ref.watch(usersListProvider);
    return AlertDialog(
      title: Text('Assign to ${widget.territory.name}'),
      content: agents.when(
        loading: () => const SizedBox(
          height: 48,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Text('Failed to load agents: $err'),
        data: (list) {
          final fieldAgents =
              list.where((u) => u.role == 'field_agent').toList();
          if (fieldAgents.isEmpty) {
            return const Text('No field agents available.');
          }
          return DropdownButtonFormField<String>(
            key: const ValueKey<String>('assign-agent-field'),
            initialValue: _agentId,
            decoration: const InputDecoration(labelText: 'Field agent'),
            items: [
              for (final u in fieldAgents)
                DropdownMenuItem(value: u.id, child: Text(u.email)),
            ],
            onChanged: (v) => setState(() => _agentId = v),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('assign-agent-confirm'),
          onPressed: (_agentId == null || _submitting) ? null : _assign,
          child: const Text('Assign'),
        ),
      ],
    );
  }
}

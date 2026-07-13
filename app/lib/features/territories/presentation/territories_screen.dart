import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../users/data/users_repository.dart';
import '../data/territories_repository.dart';
import 'territory_form_screen.dart';

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
      body: territories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load territories: $err'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(territoriesListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) =>
              _TerritoryCard(territory: list[index], canManage: canManage),
        ),
      ),
    );
  }
}

class _TerritoryCard extends ConsumerWidget {
  const _TerritoryCard({required this.territory, required this.canManage});

  final Territory territory;
  final bool canManage;

  Future<void> _showCoverage(BuildContext context, WidgetRef ref) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(territory.name),
        content: FutureBuilder<TerritoryCoverage>(
          key: ValueKey<String>('coverage-${territory.id}'),
          future: ref.read(territoriesRepositoryProvider).getCoverage(territory.id),
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
              'Outlets: ${coverage.outletCount}   Agents: ${coverage.agentCount}',
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
    return Card(
      child: ListTile(
        key: ValueKey<String>('territory-${territory.id}'),
        title: Text(territory.name),
        subtitle: Text(
          '${territory.code}${territory.region != null ? ' · ${territory.region}' : ''}',
        ),
        trailing: canManage
            ? IconButton(
                key: ValueKey<String>('territory-assign-${territory.id}'),
                icon: const Icon(Icons.person_add),
                tooltip: 'Assign agent',
                onPressed: () => _assignAgent(context),
              )
            : null,
        onTap: () => _showCoverage(context, ref),
      ),
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

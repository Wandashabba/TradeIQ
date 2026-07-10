import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../data/territories_repository.dart';

class TerritoriesScreen extends ConsumerWidget {
  const TerritoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final territories = ref.watch(territoriesListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Territories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
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
              _TerritoryCard(territory: list[index]),
        ),
      ),
    );
  }
}

class _TerritoryCard extends ConsumerWidget {
  const _TerritoryCard({required this.territory});

  final Territory territory;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(territory.name),
        subtitle: Text(
          '${territory.code}${territory.region != null ? ' · ${territory.region}' : ''}',
        ),
        onTap: () => _showCoverage(context, ref),
      ),
    );
  }
}

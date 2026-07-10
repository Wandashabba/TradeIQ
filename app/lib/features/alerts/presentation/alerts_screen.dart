import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../data/alerts_repository.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: alerts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load alerts: $err'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(alertsListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) => _AlertCard(alert: list[index]),
        ),
      ),
    );
  }
}

class _AlertCard extends ConsumerWidget {
  const _AlertCard({required this.alert});

  final AlertItem alert;

  Future<void> _acknowledge(WidgetRef ref) async {
    await ref.read(alertsRepositoryProvider).acknowledge(alert.id);
    ref.invalidate(alertsListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: Icon(
          alert.acknowledged ? Icons.check_circle : Icons.warning,
        ),
        title: Text(alert.message),
        subtitle: Text('${alert.metric} · ${alert.severity}'),
        trailing: alert.acknowledged
            ? null
            : TextButton(
                key: ValueKey<String>('ack-${alert.id}'),
                onPressed: () => _acknowledge(ref),
                child: const Text('Acknowledge'),
              ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../data/fraud_repository.dart';

class FraudScreen extends ConsumerWidget {
  const FraudScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visits = ref.watch(flaggedVisitsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fraud Review'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: visits.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load flagged visits: $err'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(flaggedVisitsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) => _FlaggedVisitCard(visit: list[index]),
        ),
      ),
    );
  }
}

class _FlaggedVisitCard extends StatelessWidget {
  const _FlaggedVisitCard({required this.visit});

  final FlaggedVisit visit;

  @override
  Widget build(BuildContext context) {
    final idLength = visit.visitId.length >= 8 ? 8 : visit.visitId.length;
    return Card(
      child: ListTile(
        title: Text('Visit ${visit.visitId.substring(0, idLength)}'),
        subtitle: Text(
          'Risk ${visit.riskScore.toStringAsFixed(0)} · '
          '${visit.signals.map((s) => s.code).join(', ')}',
        ),
        isThreeLine: true,
        trailing: Icon(
          Icons.flag,
          color: visit.riskScore >= 70 ? Colors.red : Colors.orange,
        ),
      ),
    );
  }
}

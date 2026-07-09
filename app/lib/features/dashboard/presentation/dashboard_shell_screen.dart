import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../data/dashboard_repository.dart';

class DashboardShellScreen extends ConsumerWidget {
  const DashboardShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpis = ref.watch(dashboardKpisProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: kpis.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load KPIs: $err'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(dashboardKpisProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          final tiles = <(String, String)>[
            ('Numeric Distribution', '${data.numericDistribution.toStringAsFixed(1)}%'),
            ('Weighted Distribution', '${data.weightedDistribution.toStringAsFixed(1)}%'),
            ('OSA %', '${data.osaPct.toStringAsFixed(1)}%'),
            // Execution Score is a score, not a rate — no % suffix.
            ('Execution Score', data.executionScore.toStringAsFixed(1)),
            ('Price Compliance %', '${data.priceCompliancePct.toStringAsFixed(1)}%'),
            ('Visibility Compliance %', '${data.visibilityCompliancePct.toStringAsFixed(1)}%'),
            ('Share of Shelf', '${data.shareOfShelf.toStringAsFixed(1)}%'),
            ('Perfect Store Rate', '${data.perfectStoreRate.toStringAsFixed(1)}%'),
          ];
          return SingleChildScrollView(
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final (label, value) in tiles)
                  Card(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(label, textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          Text(
                            value,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

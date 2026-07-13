import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/manager_scaffold.dart';
import '../../territories/data/territories_repository.dart';
import '../data/dashboard_repository.dart';

class DashboardShellScreen extends ConsumerWidget {
  const DashboardShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpis = ref.watch(dashboardKpisProvider);
    return ManagerScaffold(
      title: 'Manager Dashboard',
      body: Column(
        children: [
          const _FilterBar(),
          Expanded(
            child: kpis.when(
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
            ),
          ],
        ),
    );
  }
}

/// Territory + date-range filter bar for the dashboard KPIs. Updates
/// [dashboardFilterProvider], which [dashboardKpisProvider] watches, so the
/// grid re-queries GET /dashboard with the chosen params.
class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(dashboardFilterProvider);
    final territories = ref.watch(territoriesListProvider);

    void update(DashboardFilter next) {
      ref.read(dashboardFilterProvider.notifier).set(next);
    }

    Future<void> pickRange() async {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
      );
      if (range != null) {
        update(DashboardFilter(
          territoryId: filter.territoryId,
          from: range.start.toIso8601String(),
          to: range.end.toIso8601String(),
        ));
      }
    }

    final territoryDropdown = territories.maybeWhen(
      data: (list) => DropdownButton<String?>(
        key: const ValueKey('filter-territory'),
        value: filter.territoryId,
        hint: const Text('All territories'),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('All territories')),
          for (final t in list) DropdownMenuItem<String?>(value: t.id, child: Text(t.name)),
        ],
        onChanged: (v) => update(DashboardFilter(
          territoryId: v,
          from: filter.from,
          to: filter.to,
        )),
      ),
      orElse: () => const SizedBox.shrink(),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Flexible(child: territoryDropdown),
          const SizedBox(width: 12),
          TextButton.icon(
            key: const ValueKey('filter-daterange'),
            icon: const Icon(Icons.date_range),
            label: Text(filter.from != null ? 'Dated' : 'Date range'),
            onPressed: pickRange,
          ),
          if (filter.isActive)
            TextButton(
              key: const ValueKey('filter-clear'),
              onPressed: () => update(const DashboardFilter()),
              child: const Text('Clear'),
            ),
        ],
      ),
    );
  }
}



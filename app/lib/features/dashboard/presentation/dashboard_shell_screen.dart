import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../data/dashboard_repository.dart';

class DashboardShellScreen extends ConsumerWidget {
  const DashboardShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpis = ref.watch(dashboardKpisProvider);
    return Scaffold(
      drawer: const _DashboardDrawer(),
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.checklist),
            tooltip: 'Tasks',
            onPressed: () => context.go('/tasks'),
          ),
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

/// Navigation drawer to the manager/admin destinations backed by the Phase 3
/// modules. Each entry closes the drawer then routes via go_router.
class _DashboardDrawer extends StatelessWidget {
  const _DashboardDrawer();

  static const _destinations = <(String, IconData, String)>[
    ('Dashboard', Icons.dashboard, '/dashboard'),
    ('Tasks', Icons.checklist, '/tasks'),
    ('Campaigns', Icons.campaign, '/campaigns'),
    ('Alerts', Icons.warning_amber, '/alerts'),
    ('Territories', Icons.map, '/territories'),
    ('Orders', Icons.shopping_cart, '/orders'),
    ('Beat plans', Icons.route, '/beatplans'),
    ('Outlets', Icons.store, '/outlets'),
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const DrawerHeader(child: Center(child: Text('TradeIQ'))),
            for (final (label, icon, path) in _destinations)
              ListTile(
                key: ValueKey('nav-$path'),
                leading: Icon(icon),
                title: Text(label),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(path);
                },
              ),
          ],
        ),
      ),
    );
  }
}

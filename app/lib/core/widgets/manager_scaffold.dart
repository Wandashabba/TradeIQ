import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_controller.dart';

/// Wraps every manager screen with the shared drawer, a back arrow on
/// non-dashboard routes, and a logout button.
class ManagerScaffold extends ConsumerWidget {
  const ManagerScaffold({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final isRoot = location == '/dashboard';
    return Scaffold(
      drawer: const _DashboardDrawer(),
      appBar: AppBar(
        title: Text(title),
        leading: isRoot
            ? Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: 'Menu',
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to dashboard',
                onPressed: () => context.go('/dashboard'),
              ),
        actions: [
          if (!isRoot)
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}

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
    ('Leaderboard', Icons.leaderboard, '/leaderboard'),
    ('Fraud review', Icons.gpp_maybe, '/fraud'),
    ('Reports', Icons.assessment, '/reports'),
    ('Trends', Icons.show_chart, '/trends'),
    ('Dispatch', Icons.near_me, '/dispatch'),
    ('Incentives', Icons.card_giftcard, '/incentives'),
    ('Messages', Icons.message, '/messages'),
    ('Users', Icons.group, '/users'),
    ('Audit templates', Icons.description, '/audit-templates'),
    ('Webhooks', Icons.link, '/webhooks'),
    ('Scoring config', Icons.tune, '/client-config'),
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

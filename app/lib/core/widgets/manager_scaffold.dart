import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_controller.dart';
import '../theme/app_colors.dart';
import '../theme/theme_mode_controller.dart';

/// A console destination. Grouped by verb — a manager scanning nineteen flat
/// rows has to *read* the menu; three verbs let them scan it.
typedef NavDestination = ({String label, IconData icon, String path});

const _operate = <NavDestination>[
  (label: 'Dashboard', icon: Icons.dashboard_outlined, path: '/dashboard'),
  (label: 'Tasks', icon: Icons.checklist_outlined, path: '/tasks'),
  (label: 'Alerts', icon: Icons.warning_amber_outlined, path: '/alerts'),
  (label: 'Orders', icon: Icons.shopping_cart_outlined, path: '/orders'),
  (label: 'Beat plans', icon: Icons.route_outlined, path: '/beatplans'),
  (label: 'Dispatch', icon: Icons.near_me_outlined, path: '/dispatch'),
  (label: 'Messages', icon: Icons.message_outlined, path: '/messages'),
  (label: 'Outlets', icon: Icons.store_outlined, path: '/outlets'),
];

const _insight = <NavDestination>[
  (label: 'Reports', icon: Icons.assessment_outlined, path: '/reports'),
  (label: 'Trends', icon: Icons.show_chart_outlined, path: '/trends'),
  (label: 'Leaderboard', icon: Icons.leaderboard_outlined, path: '/leaderboard'),
  (label: 'Fraud review', icon: Icons.gpp_maybe_outlined, path: '/fraud'),
  (label: 'Campaigns', icon: Icons.campaign_outlined, path: '/campaigns'),
];

const _configure = <NavDestination>[
  (label: 'Alert rules', icon: Icons.rule_outlined, path: '/alert-rules'),
  (label: 'Territories', icon: Icons.map_outlined, path: '/territories'),
  (label: 'Users', icon: Icons.group_outlined, path: '/users'),
  (label: 'Audit templates', icon: Icons.description_outlined, path: '/audit-templates'),
  (label: 'Incentives', icon: Icons.card_giftcard_outlined, path: '/incentives'),
  (label: 'Webhooks', icon: Icons.link_outlined, path: '/webhooks'),
  (label: 'Scoring config', icon: Icons.tune_outlined, path: '/client-config'),
];

const _groups = <(String, List<NavDestination>)>[
  ('Operate', _operate),
  ('Insight', _insight),
  ('Configure', _configure),
];

/// Below this width the rail collapses to icons; below [_drawerBreakpoint] it
/// becomes an overlay drawer. The overlay survives only where width genuinely
/// forces it.
const double _railBreakpoint = 1080;
const double _drawerBreakpoint = 760;

/// Wraps every manager screen in the console shell: a persistent navigation
/// rail on desktop (managers are on Flutter web), collapsing to icons and then
/// to a drawer as width runs out.
class ManagerScaffold extends ConsumerWidget {
  const ManagerScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;

  /// Page-level actions rendered in the top bar (e.g. Export, Run rules).
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final width = MediaQuery.sizeOf(context).width;
    final useDrawer = width < _drawerBreakpoint;
    final collapsed = width < _railBreakpoint;

    void logout() => ref.read(sessionControllerProvider.notifier).logout();

    return Scaffold(
      backgroundColor: AppColors.plane,
      // The drawer only exists at phone width — on desktop the rail is always
      // visible, so there is nothing to open.
      drawer: useDrawer
          ? Drawer(
              backgroundColor: AppColors.surface1,
              child: _NavRail(
                location: location,
                collapsed: false,
                onLogout: logout,
                onNavigate: (path) {
                  Navigator.of(context).pop();
                  context.go(path);
                },
              ),
            )
          : null,
      appBar: AppBar(
        automaticallyImplyLeading: useDrawer,
        title: Text(title),
        actions: [
          ...?actions,
          IconButton(
            key: const ValueKey('theme-toggle'),
            icon: Icon(
              ref.watch(themeModeProvider) == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 18,
            ),
            tooltip: ref.watch(themeModeProvider) == ThemeMode.dark
                ? 'Switch to light theme'
                : 'Switch to dark theme',
            onPressed: () =>
                ref.read(themeModeProvider.notifier).toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 18),
            tooltip: 'Log out',
            onPressed: logout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: floatingActionButton,
      body: useDrawer
          ? body
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NavRail(
                  location: location,
                  collapsed: collapsed,
                  onLogout: logout,
                  onNavigate: context.go,
                ),
                const VerticalDivider(width: 1, color: AppColors.line),
                Expanded(child: body),
              ],
            ),
    );
  }
}

class _NavRail extends StatelessWidget {
  const _NavRail({
    required this.location,
    required this.collapsed,
    required this.onNavigate,
    required this.onLogout,
  });

  final String location;
  final bool collapsed;
  final void Function(String path) onNavigate;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: collapsed ? 60 : 232,
      color: AppColors.surface1,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  for (final (heading, destinations) in _groups) ...[
                    if (collapsed)
                      const Divider(
                        height: 17,
                        indent: 16,
                        endIndent: 16,
                        color: AppColors.line,
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 5),
                        child: Text(
                          heading.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.9,
                            color: AppColors.ink3,
                          ),
                        ),
                      ),
                    for (final d in destinations)
                      _NavRow(
                        destination: d,
                        selected: location == d.path ||
                            location.startsWith('${d.path}/'),
                        collapsed: collapsed,
                        onTap: () => onNavigate(d.path),
                      ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            _RailFoot(collapsed: collapsed, onLogout: onLogout),
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.destination,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The active row is a rule plus a weight change — not a filled pill. It
    // reads as position, which is what it means.
    final row = Container(
      decoration: BoxDecoration(
        color: selected ? AppColors.surface2 : null,
        border: Border(
          left: BorderSide(
            color: selected ? AppColors.brand : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(collapsed ? 0 : 10, 7, collapsed ? 0 : 16, 7),
      child: Row(
        mainAxisAlignment:
            collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(
            destination.icon,
            size: 15,
            color: selected ? AppColors.series1 : AppColors.ink3,
          ),
          if (!collapsed) ...[
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                destination.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppColors.ink1 : AppColors.ink2,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return InkWell(
      // Key preserved from the drawer implementation — navigation tests and
      // anything else keyed on a destination keep working.
      key: ValueKey('nav-${destination.path}'),
      onTap: onTap,
      child: collapsed
          ? Tooltip(message: destination.label, child: row)
          : row,
    );
  }
}

class _RailFoot extends ConsumerWidget {
  const _RailFoot({required this.collapsed, required this.onLogout});

  final bool collapsed;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(sessionControllerProvider).value?.role ?? '';
    final avatar = Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface3,
        border: Border.all(color: AppColors.lineStrong),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Icon(
        Icons.person_outline,
        size: 14,
        color: AppColors.ink2,
      ),
    );

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(child: avatar),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              role.isEmpty ? 'Signed in' : _humanRole(role),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ink1,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 15),
            color: AppColors.ink3,
            tooltip: 'Log out',
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }

  static String _humanRole(String role) => switch (role) {
        'field_agent' => 'Field agent',
        'manager' => 'Manager',
        'admin' => 'Administrator',
        _ => role,
      };
}

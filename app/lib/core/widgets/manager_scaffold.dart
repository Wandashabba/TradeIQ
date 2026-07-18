import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_controller.dart';
import '../theme/theme_mode_controller.dart';
import '../theme/tiq_colors.dart';
import 'agent_motion.dart' show reduceMotion;

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

    final colors = context.colors;
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: colors.plane,
      // black54 in dark (Flutter's default, so dark is unchanged); deeper in
      // light, where a pale scrim would not separate the drawer from the page.
      drawerScrimColor: colors.scrim,
      // The drawer only exists at phone width — on desktop the rail is always
      // visible, so there is nothing to open.
      drawer: useDrawer
          ? Drawer(
              backgroundColor: colors.surface1,
              child: _NavRail(
                location: location,
                collapsed: false,
                // The drawer arrives as an event, so its rows are allowed an
                // entrance; the persistent rail is furniture and gets none.
                staggered: true,
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
              mode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 18,
            ),
            tooltip: mode == ThemeMode.dark
                ? 'Switch to light theme'
                : 'Switch to dark theme',
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
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
                  staggered: false,
                  onLogout: logout,
                  onNavigate: context.go,
                ),
                VerticalDivider(width: 1, color: colors.line),
                Expanded(child: body),
              ],
            ),
    );
  }
}

class _NavRail extends StatefulWidget {
  const _NavRail({
    required this.location,
    required this.collapsed,
    required this.staggered,
    required this.onNavigate,
    required this.onLogout,
  });

  final String location;
  final bool collapsed;

  /// True only for the drawer instance: its rows fade-up in a 20ms-per-row
  /// stagger as the drawer opens. The persistent rail never animates.
  final bool staggered;

  final void Function(String path) onNavigate;
  final VoidCallback onLogout;

  @override
  State<_NavRail> createState() => _NavRailState();
}

class _NavRailState extends State<_NavRail>
    with SingleTickerProviderStateMixin {
  /// Every destination across the three groups — the stagger walks them in
  /// visual order, one 20ms step apiece.
  static final int _rowCount =
      _groups.fold(0, (total, group) => total + group.$2.length);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 20 * _rowCount + 150),
    );
    if (widget.staggered) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Wraps a nav row in its slice of the one shared controller: each row fades
  /// in and rises 6% of its own height, starting 20ms after the row above it.
  /// Under reduced motion — or on the persistent rail — the row is returned
  /// untouched, at full opacity, exactly where it belongs.
  Widget _staggeredRow(BuildContext context, int index, Widget row) {
    if (!widget.staggered || reduceMotion(context)) return row;
    final start = (index * 20) / (_rowCount * 20 + 150);
    final anim = CurvedAnimation(
      parent: _controller,
      curve: Interval(start.clamp(0.0, 1.0), 1, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(anim),
        child: row,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final collapsed = widget.collapsed;
    var rowIndex = 0;
    return Container(
      width: collapsed ? 60 : 232,
      color: colors.surface1,
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
                      Divider(
                        height: 17,
                        indent: 16,
                        endIndent: 16,
                        color: colors.line,
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 5),
                        child: Text(
                          heading.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.9,
                            color: colors.ink3,
                          ),
                        ),
                      ),
                    for (final d in destinations)
                      _staggeredRow(
                        context,
                        rowIndex++,
                        _NavRow(
                          destination: d,
                          selected: widget.location == d.path ||
                              widget.location.startsWith('${d.path}/'),
                          collapsed: collapsed,
                          onTap: () => widget.onNavigate(d.path),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            Divider(height: 1, color: colors.line),
            _RailFoot(collapsed: collapsed, onLogout: widget.onLogout),
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
    final colors = context.colors;
    final row = Container(
      decoration: BoxDecoration(
        color: selected ? colors.surface2 : null,
        border: Border(
          left: BorderSide(
            color: selected ? colors.brand : Colors.transparent,
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
            color: selected ? colors.series1 : colors.ink3,
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
                  color: selected ? colors.ink1 : colors.ink2,
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
      // Sits on top of the selected wash: hover/pressed read on both states.
      hoverColor: colors.surface2,
      highlightColor: colors.surface3,
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
    final colors = context.colors;
    final role = ref.watch(sessionControllerProvider).value?.role ?? '';
    final avatar = Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surface3,
        border: Border.all(color: colors.lineStrong),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Icon(
        Icons.person_outline,
        size: 14,
        color: colors.ink2,
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
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.ink1,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 15),
            color: colors.ink3,
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

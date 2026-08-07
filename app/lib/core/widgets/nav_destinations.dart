import 'package:flutter/material.dart';

/// A console destination. Grouped by verb — a manager scanning twenty flat
/// rows has to *read* the menu; three verbs let them scan it.
class NavDestination {
  const NavDestination({
    required this.route,
    required this.label,
    required this.icon,
    required this.group,
  });

  final String route;
  final String label;
  final IconData icon;
  final NavGroup group;
}

enum NavGroup { operate, insight, configure }

extension NavGroupHeading on NavGroup {
  /// The group header as the UI renders it (rail and menu sheet).
  String get heading => switch (this) {
        NavGroup.operate => 'OPERATE',
        NavGroup.insight => 'INSIGHT',
        NavGroup.configure => 'CONFIGURE',
      };
}

/// Single source of manager navigation. The sidebar, the floating bottom
/// bar's Menu sheet, and the router guard all read THIS list — a destination
/// added here appears everywhere at once.
const managerDestinations = <NavDestination>[
  // Operate
  NavDestination(
    route: '/dashboard',
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    group: NavGroup.operate,
  ),
  NavDestination(
    route: '/tasks',
    label: 'Tasks',
    icon: Icons.checklist_outlined,
    group: NavGroup.operate,
  ),
  NavDestination(
    route: '/alerts',
    label: 'Alerts',
    icon: Icons.warning_amber_outlined,
    group: NavGroup.operate,
  ),
  NavDestination(
    route: '/orders',
    label: 'Orders',
    icon: Icons.shopping_cart_outlined,
    group: NavGroup.operate,
  ),
  NavDestination(
    route: '/beatplans',
    label: 'Beat plans',
    icon: Icons.route_outlined,
    group: NavGroup.operate,
  ),
  NavDestination(
    route: '/dispatch',
    label: 'Dispatch',
    icon: Icons.near_me_outlined,
    group: NavGroup.operate,
  ),
  NavDestination(
    route: '/messages',
    label: 'Messages',
    icon: Icons.message_outlined,
    group: NavGroup.operate,
  ),
  NavDestination(
    route: '/outlets',
    label: 'Outlets',
    icon: Icons.store_outlined,
    group: NavGroup.operate,
  ),
  // Insight
  //
  // First in the group deliberately. The whole bet is that a manager asks a
  // question instead of hunting for the screen that answers it, and a
  // destination buried under five others is one nobody reaches for first.
  //
  // Not conditional on the rollout flag. This is a `const` list, so it cannot
  // depend on runtime tenant state without becoming a provider — and the flag
  // is decided by a network call the menu would then have to wait on. The
  // gate screen (`AssistantGate`) resolves it in place instead, so a tenant
  // outside the rollout sees the item and gets a sentence explaining it. That
  // is a better answer than an item that silently is not there, which reads as
  // the feature having been removed.
  NavDestination(
    route: '/assistant',
    label: 'Ask TradeIQ',
    icon: Icons.auto_awesome_outlined,
    group: NavGroup.insight,
  ),
  NavDestination(
    route: '/reports',
    label: 'Reports',
    icon: Icons.assessment_outlined,
    group: NavGroup.insight,
  ),
  NavDestination(
    route: '/trends',
    label: 'Trends',
    icon: Icons.show_chart_outlined,
    group: NavGroup.insight,
  ),
  NavDestination(
    route: '/leaderboard',
    label: 'Leaderboard',
    icon: Icons.leaderboard_outlined,
    group: NavGroup.insight,
  ),
  NavDestination(
    route: '/fraud',
    label: 'Fraud review',
    icon: Icons.gpp_maybe_outlined,
    group: NavGroup.insight,
  ),
  NavDestination(
    route: '/campaigns',
    label: 'Campaigns',
    icon: Icons.campaign_outlined,
    group: NavGroup.insight,
  ),
  // Configure
  NavDestination(
    route: '/alert-rules',
    label: 'Alert rules',
    icon: Icons.rule_outlined,
    group: NavGroup.configure,
  ),
  NavDestination(
    route: '/territories',
    label: 'Territories',
    icon: Icons.map_outlined,
    group: NavGroup.configure,
  ),
  NavDestination(
    route: '/users',
    label: 'Users',
    icon: Icons.group_outlined,
    group: NavGroup.configure,
  ),
  NavDestination(
    route: '/audit-templates',
    label: 'Audit templates',
    icon: Icons.description_outlined,
    group: NavGroup.configure,
  ),
  NavDestination(
    route: '/incentives',
    label: 'Incentives',
    icon: Icons.card_giftcard_outlined,
    group: NavGroup.configure,
  ),
  NavDestination(
    route: '/webhooks',
    label: 'Webhooks',
    icon: Icons.link_outlined,
    group: NavGroup.configure,
  ),
  NavDestination(
    route: '/client-config',
    label: 'Scoring config',
    icon: Icons.tune_outlined,
    group: NavGroup.configure,
  ),
];

/// The destinations of one group, in declaration order.
List<NavDestination> destinationsIn(NavGroup group) =>
    [for (final d in managerDestinations) if (d.group == group) d];

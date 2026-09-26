import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

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

  /// The English name, and the key [labelIn] switches on. Never rendered
  /// directly — see [labelIn]; a hardcoded English string on a screen that has
  /// an Afrikaans translation is a defect, and this list feeds the rail, the
  /// menu sheet and the router guard alike.
  final String label;

  final IconData icon;
  final NavGroup group;

  /// The destination's name in [l10n]'s language.
  ///
  /// Switched on [route] rather than carried in the const list, because a
  /// `const` entry cannot hold a lookup against localisations that do not
  /// exist until a `BuildContext` does. A route with no key falls back to
  /// [label] — a new destination reads in English until somebody translates
  /// it, which is visibly worse than reading nothing.
  String labelIn(AppLocalizations l10n) => switch (route) {
    '/dashboard' => l10n.navTheFloor,
    '/dashboard/overview' => l10n.navExecutionOverview,
    '/tasks' => l10n.navTasks,
    '/alerts' => l10n.navAlerts,
    '/orders' => l10n.navOrders,
    '/beatplans' => l10n.navBeatPlans,
    '/dispatch' => l10n.navDispatch,
    '/messages' => l10n.navMessages,
    '/outlets' => l10n.navOutlets,
    '/assistant' => l10n.navAskTradeIq,
    '/reports' => l10n.navReports,
    '/trends' => l10n.navTrends,
    '/sales-targets' => l10n.navSalesTargets,
    '/leaderboard' => l10n.navLeaderboard,
    '/contests' => l10n.navContests,
    '/fraud' => l10n.navFraudReview,
    '/campaigns' => l10n.navCampaigns,
    '/alert-rules' => l10n.navAlertRules,
    '/territories' => l10n.navTerritories,
    '/users' => l10n.navUsers,
    '/audit-templates' => l10n.navAuditTemplates,
    '/incentives' => l10n.navIncentives,
    '/webhooks' => l10n.navWebhooks,
    '/client-config' => l10n.navScoringConfig,
    _ => label,
  };
}

enum NavGroup { operate, insight, configure }

/// The group's name in [l10n]'s language, sentence case.
///
/// Sentence case **in the data**, which is the half of this that never
/// changed: "OPERATE" shouted into a string is a word a screen reader spells
/// out letter by letter, and it reaches the search index and the PDF exporter
/// too. [SectionRule] uppercases for display only and hands this string to
/// anything that reads — so the menu's groups print as kickers and are still
/// announced as words.
String navGroupName(AppLocalizations l10n, NavGroup group) => switch (group) {
  NavGroup.operate => l10n.navGroupOperate,
  NavGroup.insight => l10n.navGroupInsight,
  NavGroup.configure => l10n.navGroupConfigure,
};

/// Single source of manager navigation. The sidebar, the floating bottom
/// bar's Menu sheet, and the router guard all read THIS list — a destination
/// added here appears everywhere at once.
const managerDestinations = <NavDestination>[
  // Operate
  NavDestination(
    route: '/dashboard',
    label: 'The Floor',
    icon: Icons.dashboard_outlined,
    group: NavGroup.operate,
  ),
  NavDestination(
    route: '/dashboard/overview',
    label: 'Execution overview',
    icon: Icons.insights_outlined,
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
    route: '/sales-targets',
    label: 'Sales targets',
    icon: Icons.flag_outlined,
    group: NavGroup.insight,
  ),
  NavDestination(
    route: '/leaderboard',
    label: 'Leaderboard',
    icon: Icons.leaderboard_outlined,
    group: NavGroup.insight,
  ),
  NavDestination(
    route: '/contests',
    label: 'Contests',
    icon: Icons.emoji_events_outlined,
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
List<NavDestination> destinationsIn(NavGroup group) => [
  for (final d in managerDestinations)
    if (d.group == group) d,
];

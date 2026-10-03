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
  /// an Afrikaans translation is a defect, and this list feeds the menu sheet
  /// — see [managerDestinations] for what it does not feed.
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

/// The three groups, by identifier.
///
/// **The identifiers are not the labels, and deliberately so.** As of
/// 3 October 2026 these print as *Execution*, *Performance* and *Setup* — the
/// trade-marketing words the data layer has always used — while the enum
/// stays `operate`/`insight`/`configure`. Renaming the identifiers would
/// rewrite `ValueKey('menu-fold-operate')` in the fold, the golden names and
/// every test that reaches for a group by key, for no reader-visible gain:
/// nobody sees an enum. [navGroupName] is the single place the two meet.
enum NavGroup { operate, insight, configure }

/// The group's name in [l10n]'s language, sentence case.
///
/// Sentence case **in the data**, which is the half of this that never
/// changed: "EXECUTION" shouted into a string is a word a screen reader
/// spells out letter by letter, and it reaches the search index and the PDF
/// exporter too. [SectionRule] uppercases for display only and hands this string to
/// anything that reads — so the menu's groups print as kickers and are still
/// announced as words.
String navGroupName(AppLocalizations l10n, NavGroup group) => switch (group) {
  NavGroup.operate => l10n.navGroupOperate,
  NavGroup.insight => l10n.navGroupInsight,
  NavGroup.configure => l10n.navGroupConfigure,
};

/// The manager's destinations. **Read by the Menu sheet, and by nothing else**
/// — corrected 2 October 2026.
///
/// This said "the sidebar, the floating bottom bar's Menu sheet, and the router
/// guard all read THIS list — a destination added here appears everywhere at
/// once". One third of that was true and the other two thirds sent a reader
/// looking for code that is not there, so here is what is actually the case:
///
/// * **The Menu sheet reads it.** `menu_sheet.dart`, via [destinationsIn] —
///   still true, and still the reason this list is one list.
/// * **There is no sidebar.** `ManagerScaffold`'s `_NavRail` did read it, and
///   was deleted in `9985dd6b` ("retire eight dead widget files",
///   25 September 2026). What draws manager nav now is `consoleNavSlots` in
///   `console_frame.dart`: four slots with hardcoded English labels and
///   hardcoded routes, which is its own problem and not this list's.
/// * **The router guard has never read it.** `app_router.dart` holds a `const
///   managerOnly` set of 19 routes against this list's 24; `git log -S
///   managerDestinations` on that file is empty, so this was not drift, it was
///   never so. Seven destinations here are outside that set — `/assistant`,
///   `/beatplans`, `/dashboard/overview`, `/leaderboard`, `/messages`,
///   `/orders`, `/outlets` — of which three are deliberately shared with field
///   agents per that file's own comment and four are unexplained.
///
/// **Adding a destination here therefore adds it to the menu and to nothing
/// else.** If it is manager-only, add it to `managerOnly` in `app_router.dart`
/// too, by hand, until somebody makes that guard read this list.
const managerDestinations = <NavDestination>[
  // operate — prints as "Execution"
  NavDestination(
    route: '/dashboard',
    label: 'The Floor',
    icon: Icons.dashboard_outlined,
    group: NavGroup.operate,
  ),
  NavDestination(
    route: '/dashboard/overview',
    label: 'Perfect Store',
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
    label: 'Exceptions',
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
  // insight — prints as "Performance"
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
    label: 'Visit verification',
    icon: Icons.gpp_maybe_outlined,
    group: NavGroup.insight,
  ),
  NavDestination(
    route: '/campaigns',
    label: 'Activations',
    icon: Icons.campaign_outlined,
    group: NavGroup.insight,
  ),
  // configure — prints as "Setup"
  NavDestination(
    route: '/alert-rules',
    label: 'Exception rules',
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
    label: 'Field force',
    icon: Icons.group_outlined,
    group: NavGroup.configure,
  ),
  NavDestination(
    route: '/audit-templates',
    label: 'Survey templates',
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
    label: 'Perfect Store scorecard',
    icon: Icons.tune_outlined,
    group: NavGroup.configure,
  ),
];

/// The destinations of one group, in declaration order.
List<NavDestination> destinationsIn(NavGroup group) => [
  for (final d in managerDestinations)
    if (d.group == group) d,
];

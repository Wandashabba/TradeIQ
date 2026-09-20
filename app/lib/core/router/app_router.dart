import 'package:flutter/material.dart' show FadeTransition, MaterialPage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/agent_map/presentation/agent_map_screen.dart';
import '../../features/agents/presentation/agent_trail_screen.dart';
import '../../features/audit/presentation/audit_shell_screen.dart';
import '../../features/audit/presentation/my_work_screen.dart';
import '../../features/audit/presentation/visit_outcome_screen.dart';
import '../../features/audit/presentation/visit_outlet_picker_screen.dart';
import '../../features/beatplans/presentation/today_screen.dart';
import '../../features/me/presentation/my_record_screen.dart';
import '../../features/auth/presentation/landing_screen.dart';
import '../../features/auth/presentation/change_password_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/update_required_screen.dart';
import '../../features/dashboard/presentation/dashboard_shell_screen.dart';
import '../../features/dashboard/presentation/the_floor_screen.dart';
import '../../features/outlets/presentation/create_outlet_screen.dart';
import '../../features/outlets/presentation/outlet_detail_screen.dart';
import '../../features/outlets/presentation/outlets_list_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import '../../features/campaigns/presentation/campaigns_screen.dart';
import '../../features/contests/presentation/contest_standings_screen.dart';
import '../../features/contests/presentation/contests_screen.dart';
import '../../features/contests/presentation/my_contests_screen.dart';
import '../../features/alerts/presentation/alert_rules_screen.dart';
import '../../features/alerts/presentation/alerts_screen.dart';
import '../../features/territories/presentation/territories_screen.dart';
import '../../features/territories/presentation/territory_form_screen.dart';
import '../../features/territories/presentation/territory_map_gate.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/beatplans/presentation/beatplans_screen.dart';
import '../../features/gamification/presentation/agent_points_screen.dart';
import '../../features/gamification/presentation/leaderboard_screen.dart';
import '../../features/fraud/presentation/fraud_screen.dart';
import '../../features/reports/presentation/report_schedules_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/collaboration/presentation/messages_screen.dart';
import '../../features/users/data/users_repository.dart';
import '../../features/users/presentation/user_password_screen.dart';
import '../../features/users/presentation/users_screen.dart';
import '../../features/incentives/presentation/incentives_screen.dart';
import '../../features/webhooks/presentation/webhooks_screen.dart';
import '../../features/clients/presentation/client_config_screen.dart';
import '../../features/templates/presentation/template_form_screen.dart';
import '../../features/templates/presentation/templates_screen.dart';
import '../../features/dispatch/presentation/dispatch_screen.dart';
import '../../features/trends/presentation/trends_screen.dart';
import '../../features/sales_targets/presentation/sales_targets_screen.dart';
import '../../features/visits/presentation/visit_detail_screen.dart';
import '../../features/assistant/presentation/artifact_screen.dart';
import '../../features/assistant/presentation/assistant_gate.dart';
import '../../features/notifications/presentation/notification_preferences_screen.dart';
import '../auth/session_controller.dart';
import '../network/app_version.dart';
import 'manager_page.dart';
import 'session_refresh_listenable.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: ref.read(sessionRefreshListenableProvider),
    redirect: (context, state) {
      final location = state.matchedLocation;
      // The server has refused this build (#400). Before everything, the
      // splash included: nothing else in the app can talk to the server, and a
      // screen that errors on every request would be the wrong story. Set only
      // by a 426 carrying `code: app_update_required`; cleared by the screen's
      // "Try again".
      if (appUpdateRequired.value != null) {
        return location == '/update-required' ? null : '/update-required';
      }
      if (location == '/update-required') return '/';

      // The splash ('/') owns its own navigation: it holds for max(5s,
      // session-restore) as a deliberate brand moment (premium-ui spec) and
      // then routes by role itself. Redirecting here would cut the hold short.
      if (location == '/') return null;

      final session = ref.read(sessionControllerProvider).value;
      final isLoggedIn = session?.role != null;
      // /forgot-password is public because the whole point is that its
      // person cannot sign in (#400).
      final isPublicRoute =
          location == '/' ||
          location == '/login' ||
          location == '/forgot-password';

      if (!isLoggedIn) {
        return isPublicRoute ? null : '/login';
      }
      if (isPublicRoute) {
        // An agent's day starts with "where am I going", not "pick one of 400
        // outlets" — so they land on their route, not on the picker.
        return session!.role == 'field_agent' ? '/today' : '/dashboard';
      }

      // Per-route role guard: field agents live in the audit/visit flow;
      // managers/admins live in the dashboard/ops screens. Bounce a role that
      // navigates (e.g. by URL) to the other side's screens. Shared screens
      // (/outlets, /beatplans, /orders) are intentionally omitted from both
      // sets — a field agent captures in-store orders (#36), so /orders is not
      // manager-only.
      final role = session!.role;
      final loc = location;
      const managerOnly = {
        '/dashboard',
        '/tasks',
        '/campaigns',
        '/contests',
        '/alerts',
        '/alert-rules',
        '/territories',
        '/agents/activity',
        '/fraud',
        '/reports',
        '/reports/schedules',
        '/users',
        '/incentives',
        '/webhooks',
        '/client-config',
        '/audit-templates',
        '/dispatch',
        '/trends',
        '/sales-targets',
      };
      final isAuditRoute = loc == '/audit' || loc.startsWith('/audit/');
      // The agent's own screens, and theirs alone — a manager has a dashboard
      // for the day's walking order and a territory map for the stores, and
      // no use for one agent's version of either.
      final isAgentOnly = loc == '/today' || loc == '/map';
      // Template subroutes (e.g. /audit-templates/:id/preview) are manager
      // territory too — the exact-match set above only covers the list screen.
      final isTemplatesSubroute = loc.startsWith('/audit-templates/');
      // Everything under /territories is manager territory too — the create
      // form and one territory's map are both reached from a list an agent
      // cannot see, and the exact-match set above only covers that list.
      final isTerritoriesSubroute = loc.startsWith('/territories/');
      // A visit under review (/visits/:id) is supervisory: its API is
      // manager/admin-only, so an agent would only ever land on a 403.
      final isVisitReview = loc.startsWith('/visits/');
      // An agent's points history (/leaderboard/:agentId) is supervisory too:
      // its API is manager/admin-only. /leaderboard itself stays shared — the
      // standings endpoint is open to every signed-in user.
      // The one exception is /leaderboard/contests (#124): the agent's
      // Contests view, whose API (GET /contests/current) is open to every
      // signed-in user like the standings themselves.
      final isLeaderboardContests = loc == '/leaderboard/contests';
      final isAgentPointsHistory =
          loc.startsWith('/leaderboard/') && !isLeaderboardContests;
      // Managing contests and their full standings (/contests/:id) is
      // supervisory: every /contests API but /contests/current is manager-only.
      final isContestsSubroute = loc.startsWith('/contests/');
      // Resetting someone else's password (/users/:id/password) is staff
      // work, like /users itself (#400).
      final isUsersSubroute = loc.startsWith('/users/');
      if (role == 'field_agent' &&
          (managerOnly.contains(loc) ||
              isUsersSubroute ||
              isTemplatesSubroute ||
              isTerritoriesSubroute ||
              isVisitReview ||
              isAgentPointsHistory ||
              isContestsSubroute)) {
        return '/today';
      }
      if (role != 'field_agent' && (isAuditRoute || isAgentOnly)) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LandingScreen()),
      GoRoute(
        path: '/login',
        // Splash → sign-in is the spec's crossfade: the splash's dimmed world
        // dissolves into the sign-in card rather than snapping.
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      // The manager's home, migrated to Torchlight (#412/#413 + The Floor).
      GoRoute(
        path: '/dashboard',
        pageBuilder: (context, state) => managerPage(const TheFloorScreen()),
      ),
      // The old multi-panel console. The Floor replaces its KPI header and its
      // needs-attention counters; it does NOT replace the trend, benchmark,
      // agent-activity and sales-attainment panels, which are separate spec
      // items and not yet migrated. Deleting it here would delete those, so it
      // keeps a route and a nav destination until they land.
      GoRoute(
        path: '/dashboard/overview',
        pageBuilder: (context, state) =>
            managerPage(const DashboardShellScreen()),
      ),
      // The field agent's home: their route for the day.
      GoRoute(path: '/today', builder: (context, state) => const TodayScreen()),
      // Where their stores are. The nav's third slot, and the reason it exists
      // again (#383's sibling): a tab with no destination was cut at
      // migration rather than faked.
      GoRoute(path: '/map', builder: (context, state) => const AgentMapScreen()),
      // The field agent's own record: their visits, their points, and the
      // honest story about a score that changed (#383/#384). Self-scoped on
      // the server, so it is not in `managerOnly` and not guarded here — a
      // manager who opens it sees their own (empty) record, which is true.
      GoRoute(path: '/me', builder: (context, state) => const MyRecordScreen()),
      GoRoute(
        path: '/audit',
        builder: (context, state) => const VisitOutletPickerScreen(),
      ),
      // The agent's sync queue. Shared with managers deliberately: a manager
      // asked "did the agent's visit actually reach us?" should be able to look.
      GoRoute(
        path: '/my-work',
        builder: (context, state) => const MyWorkScreen(),
      ),
      GoRoute(
        path: '/audit/:outletId',
        builder: (context, state) =>
            AuditShellScreen(outletId: state.pathParameters['outletId']!),
      ),
      // Where a visit ends: its score. Reached with `go`, never `push` — there
      // is no way back into a visit that has been submitted.
      GoRoute(
        path: '/audit/:outletId/done',
        builder: (context, state) => VisitOutcomeScreen(
          outletId: state.pathParameters['outletId']!,
          visitDraftId: state.uri.queryParameters['draft'] ?? '',
          outletName: state.uri.queryParameters['name'] ?? 'This store',
        ),
      ),
      GoRoute(
        path: '/outlets',
        pageBuilder: (context, state) => managerPage(const OutletsListScreen()),
      ),
      GoRoute(
        path: '/outlets/create',
        pageBuilder: (context, state) =>
            managerPage(const CreateOutletScreen()),
      ),
      // One outlet, where a wrongly pinned store gets fixed (#386). Registered
      // AFTER /outlets/create, or "create" is read as an outlet id and the
      // create form becomes unreachable.
      GoRoute(
        path: '/outlets/:id',
        pageBuilder: (context, state) => managerPage(
          OutletDetailScreen(outletId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/tasks',
        pageBuilder: (context, state) => managerPage(const TasksScreen()),
      ),
      GoRoute(
        path: '/campaigns',
        pageBuilder: (context, state) => managerPage(const CampaignsScreen()),
      ),
      GoRoute(
        path: '/contests',
        pageBuilder: (context, state) => managerPage(const ContestsScreen()),
      ),
      // One contest's full standings. A sibling route, not a menu destination:
      // the rail keeps Contests selected under /contests/.
      GoRoute(
        path: '/contests/:id',
        pageBuilder: (context, state) => managerPage(
          ContestStandingsScreen(contestId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/alerts',
        pageBuilder: (context, state) => managerPage(const AlertsScreen()),
      ),
      GoRoute(
        path: '/alert-rules',
        pageBuilder: (context, state) => managerPage(const AlertRulesScreen()),
      ),
      GoRoute(
        path: '/territories',
        pageBuilder: (context, state) => managerPage(const TerritoriesScreen()),
      ),
      // The create form. Registered BEFORE /territories/:id/map so `new` is
      // never read as a territory id — the same ordering rule /outlets/create
      // documents two screens up.
      GoRoute(
        path: '/territories/new',
        pageBuilder: (context, state) =>
            managerPage(const TerritoryFormScreen()),
      ),
      // One territory as ground: every outlet in it, whether anyone has been,
      // and the list that replaces the map in Veld and with no tiles.
      //
      // It reads the same coverage endpoint the list does, which has no role
      // restriction, so it is not in `managerOnly` — every role that can see
      // the territories list can open one.
      GoRoute(
        path: '/territories/:territoryId/map',
        pageBuilder: (context, state) => managerPage(
          TerritoryMapGate(territoryId: state.pathParameters['territoryId']!),
        ),
      ),
      GoRoute(
        path: '/agents/activity',
        pageBuilder: (context, state) => managerPage(const AgentTrailScreen()),
      ),
      GoRoute(
        path: '/orders',
        pageBuilder: (context, state) => managerPage(const OrdersScreen()),
      ),
      GoRoute(
        path: '/beatplans',
        pageBuilder: (context, state) => managerPage(const BeatPlansScreen()),
      ),
      GoRoute(
        path: '/leaderboard',
        pageBuilder: (context, state) => managerPage(const LeaderboardScreen()),
      ),
      // The agent's Contests view, reached from the leaderboard (#124).
      // Declared before /leaderboard/:agentId so `contests` is never read as
      // an agent id. An agent screen, so a plain builder like /today.
      GoRoute(
        path: '/leaderboard/contests',
        builder: (context, state) => const MyContestsScreen(),
      ),
      // Drill-down from a leaderboard row (#124). A sibling route, not a menu
      // destination: the rail keeps Leaderboard selected under /leaderboard/.
      GoRoute(
        path: '/leaderboard/:agentId',
        pageBuilder: (context, state) => managerPage(
          AgentPointsScreen(agentId: state.pathParameters['agentId']!),
        ),
      ),
      GoRoute(
        path: '/fraud',
        pageBuilder: (context, state) => managerPage(const FraudScreen()),
      ),
      // The rollout flag is checked inside AssistantGate rather than here.
      // A router redirect would have to await `/clients/me` before it could
      // decide, which blocks navigation on a network call — so a manager taps
      // the item and nothing happens until it returns. The gate renders
      // immediately and resolves in place.
      GoRoute(
        path: '/assistant',
        pageBuilder: (context, state) => managerPage(const AssistantGate()),
      ),
      // Expanded mode for one artifact. A real route, so the browser back
      // button, deep links and sharing all work without bespoke state
      // machinery — and so an artifact survives being reopened tomorrow: the
      // row stores what to re-run, and the tool runs again through the roster
      // of whoever follows the link.
      GoRoute(
        path: '/artifact/:id',
        pageBuilder: (context, state) => managerPage(
          ArtifactScreen(artifactId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/reports',
        pageBuilder: (context, state) => managerPage(const ReportsScreen()),
      ),
      // Reached from the Reports top bar. A sibling route, not a menu
      // destination: the rail keeps Reports selected under /reports/.
      GoRoute(
        path: '/reports/schedules',
        pageBuilder: (context, state) =>
            managerPage(const ReportSchedulesScreen()),
      ),
      GoRoute(
        path: '/messages',
        pageBuilder: (context, state) => managerPage(const MessagesScreen()),
      ),
      GoRoute(
        path: '/users',
        pageBuilder: (context, state) => managerPage(const UsersScreen()),
      ),
      // A manager resets someone's password (#400). The user rides along as
      // `extra` from the list; on a cold start the screen looks them up.
      GoRoute(
        path: '/users/:id/password',
        builder: (context, state) => UserPasswordScreen(
          userId: state.pathParameters['id']!,
          user: state.extra is AppUser ? state.extra! as AppUser : null,
        ),
      ),
      // The account screens (#400): redeem a manager's code while signed out,
      // change your own password while signed in, and the one screen a build
      // the server has refused can show.
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => ForgotPasswordScreen(
          initialEmail: state.extra is String ? state.extra! as String : null,
        ),
      ),
      GoRoute(
        path: '/account/password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/update-required',
        builder: (context, state) => const UpdateRequiredScreen(),
      ),
      GoRoute(
        path: '/incentives',
        pageBuilder: (context, state) => managerPage(const IncentivesScreen()),
      ),
      GoRoute(
        path: '/webhooks',
        pageBuilder: (context, state) => managerPage(const WebhooksScreen()),
      ),
      GoRoute(
        path: '/client-config',
        pageBuilder: (context, state) =>
            managerPage(const ClientConfigScreen()),
      ),
      GoRoute(
        path: '/audit-templates',
        pageBuilder: (context, state) => managerPage(const TemplatesScreen()),
      ),
      GoRoute(
        path: '/audit-templates/:templateId/preview',
        pageBuilder: (context, state) => managerPage(
          TemplateFormScreen(templateId: state.pathParameters['templateId']!),
        ),
      ),
      GoRoute(
        path: '/dispatch',
        pageBuilder: (context, state) => managerPage(const DispatchScreen()),
      ),
      GoRoute(
        path: '/trends',
        pageBuilder: (context, state) => managerPage(const TrendsScreen()),
      ),
      // Monthly sell-in targets per SKU (#119). Manager/admin only: its API
      // refuses field agents outright.
      GoRoute(
        path: '/sales-targets',
        pageBuilder: (context, state) =>
            managerPage(const SalesTargetsScreen()),
      ),
      // One visit, for review (#208). Pushed from alerts, the fraud review and
      // the agent trail, so the back chip returns to the list it came from.
      GoRoute(
        path: '/visits/:id',
        pageBuilder: (context, state) => managerPage(
          VisitDetailScreen(visitId: state.pathParameters['id']!),
          key: state.pageKey,
        ),
      ),
      // Push notification settings (#67). Shared by every role, so it sits in
      // neither guard set: an agent's page is pushed over their day like their
      // other screens, a manager's is a console page.
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) =>
            ref.read(sessionControllerProvider).value?.role == 'field_agent'
            ? MaterialPage<void>(
                key: state.pageKey,
                child: const NotificationPreferencesScreen(),
              )
            : managerPage(
                const NotificationPreferencesScreen(),
                key: state.pageKey,
              ),
      ),
    ],
  );
});

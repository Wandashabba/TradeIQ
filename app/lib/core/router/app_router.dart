import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/agents/presentation/agent_trail_screen.dart';
import '../../features/audit/presentation/audit_shell_screen.dart';
import '../../features/audit/presentation/my_work_screen.dart';
import '../../features/audit/presentation/visit_outcome_screen.dart';
import '../../features/audit/presentation/visit_outlet_picker_screen.dart';
import '../../features/beatplans/presentation/today_screen.dart';
import '../../features/auth/presentation/landing_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_shell_screen.dart';
import '../../features/outlets/presentation/create_outlet_screen.dart';
import '../../features/outlets/presentation/outlets_list_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import '../../features/campaigns/presentation/campaigns_screen.dart';
import '../../features/alerts/presentation/alert_rules_screen.dart';
import '../../features/alerts/presentation/alerts_screen.dart';
import '../../features/territories/presentation/territories_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/beatplans/presentation/beatplans_screen.dart';
import '../../features/gamification/presentation/leaderboard_screen.dart';
import '../../features/fraud/presentation/fraud_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/collaboration/presentation/messages_screen.dart';
import '../../features/users/presentation/users_screen.dart';
import '../../features/incentives/presentation/incentives_screen.dart';
import '../../features/webhooks/presentation/webhooks_screen.dart';
import '../../features/clients/presentation/client_config_screen.dart';
import '../../features/templates/presentation/template_form_screen.dart';
import '../../features/templates/presentation/templates_screen.dart';
import '../../features/dispatch/presentation/dispatch_screen.dart';
import '../../features/trends/presentation/trends_screen.dart';
import '../auth/session_controller.dart';
import 'manager_page.dart';
import 'session_refresh_listenable.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: ref.read(sessionRefreshListenableProvider),
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider).value;
      final isLoggedIn = session?.role != null;
      final location = state.matchedLocation;
      final isPublicRoute = location == '/' || location == '/login';

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
        '/alerts',
        '/alert-rules',
        '/territories',
        '/agents/activity',
        '/fraud',
        '/reports',
        '/users',
        '/incentives',
        '/webhooks',
        '/client-config',
        '/audit-templates',
        '/dispatch',
        '/trends',
      };
      final isAuditRoute = loc == '/audit' || loc.startsWith('/audit/');
      // The agent's route for the day. Their home, and theirs alone — a manager
      // has a dashboard for this and no use for one agent's walking order.
      final isAgentOnly = loc == '/today';
      // Template subroutes (e.g. /audit-templates/:id/preview) are manager
      // territory too — the exact-match set above only covers the list screen.
      final isTemplatesSubroute = loc.startsWith('/audit-templates/');
      if (role == 'field_agent' &&
          (managerOnly.contains(loc) || isTemplatesSubroute)) {
        return '/today';
      }
      if (role != 'field_agent' && (isAuditRoute || isAgentOnly)) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LandingScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/dashboard',
        pageBuilder: (context, state) => managerPage(const DashboardShellScreen()),
      ),
      // The field agent's home: their route for the day.
      GoRoute(path: '/today', builder: (context, state) => const TodayScreen()),
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
        pageBuilder: (context, state) => managerPage(const CreateOutletScreen()),
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
      GoRoute(
        path: '/fraud',
        pageBuilder: (context, state) => managerPage(const FraudScreen()),
      ),
      GoRoute(
        path: '/reports',
        pageBuilder: (context, state) => managerPage(const ReportsScreen()),
      ),
      GoRoute(
        path: '/messages',
        pageBuilder: (context, state) => managerPage(const MessagesScreen()),
      ),
      GoRoute(
        path: '/users',
        pageBuilder: (context, state) => managerPage(const UsersScreen()),
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
        pageBuilder: (context, state) => managerPage(const ClientConfigScreen()),
      ),
      GoRoute(
        path: '/audit-templates',
        pageBuilder: (context, state) => managerPage(const TemplatesScreen()),
      ),
      GoRoute(
        path: '/audit-templates/:templateId/preview',
        pageBuilder: (context, state) => managerPage(
          TemplateFormScreen(
            templateId: state.pathParameters['templateId']!,
          ),
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
    ],
  );
});

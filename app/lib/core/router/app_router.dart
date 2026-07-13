import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/audit/presentation/audit_shell_screen.dart';
import '../../features/audit/presentation/visit_outlet_picker_screen.dart';
import '../../features/auth/presentation/landing_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_shell_screen.dart';
import '../../features/outlets/presentation/create_outlet_screen.dart';
import '../../features/outlets/presentation/outlets_list_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import '../../features/campaigns/presentation/campaigns_screen.dart';
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
        return session!.role == 'field_agent' ? '/audit' : '/dashboard';
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
        '/territories',
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
      // Template subroutes (e.g. /audit-templates/:id/preview) are manager
      // territory too — the exact-match set above only covers the list screen.
      final isTemplatesSubroute = loc.startsWith('/audit-templates/');
      if (role == 'field_agent' &&
          (managerOnly.contains(loc) || isTemplatesSubroute)) {
        return '/audit';
      }
      if (role != 'field_agent' && isAuditRoute) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LandingScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardShellScreen(),
      ),
      GoRoute(
        path: '/audit',
        builder: (context, state) => const VisitOutletPickerScreen(),
      ),
      GoRoute(
        path: '/audit/:outletId',
        builder: (context, state) =>
            AuditShellScreen(outletId: state.pathParameters['outletId']!),
      ),
      GoRoute(
        path: '/outlets',
        builder: (context, state) => const OutletsListScreen(),
      ),
      GoRoute(
        path: '/outlets/create',
        builder: (context, state) => const CreateOutletScreen(),
      ),
      GoRoute(path: '/tasks', builder: (context, state) => const TasksScreen()),
      GoRoute(
        path: '/campaigns',
        builder: (context, state) => const CampaignsScreen(),
      ),
      GoRoute(
        path: '/alerts',
        builder: (context, state) => const AlertsScreen(),
      ),
      GoRoute(
        path: '/territories',
        builder: (context, state) => const TerritoriesScreen(),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const OrdersScreen(),
      ),
      GoRoute(
        path: '/beatplans',
        builder: (context, state) => const BeatPlansScreen(),
      ),
      GoRoute(
        path: '/leaderboard',
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(path: '/fraud', builder: (context, state) => const FraudScreen()),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/messages',
        builder: (context, state) => const MessagesScreen(),
      ),
      GoRoute(path: '/users', builder: (context, state) => const UsersScreen()),
      GoRoute(
        path: '/incentives',
        builder: (context, state) => const IncentivesScreen(),
      ),
      GoRoute(
        path: '/webhooks',
        builder: (context, state) => const WebhooksScreen(),
      ),
      GoRoute(
        path: '/client-config',
        builder: (context, state) => const ClientConfigScreen(),
      ),
      GoRoute(
        path: '/audit-templates',
        builder: (context, state) => const TemplatesScreen(),
      ),
      GoRoute(
        path: '/audit-templates/:templateId/preview',
        builder: (context, state) => TemplateFormScreen(
          templateId: state.pathParameters['templateId']!,
        ),
      ),
      GoRoute(
        path: '/dispatch',
        builder: (context, state) => const DispatchScreen(),
      ),
      GoRoute(
        path: '/trends',
        builder: (context, state) => const TrendsScreen(),
      ),
    ],
  );
});

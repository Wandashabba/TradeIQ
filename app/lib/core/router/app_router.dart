import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/audit/presentation/audit_shell_screen.dart';
import '../../features/audit/presentation/visit_outlet_picker_screen.dart';
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
import '../auth/session_controller.dart';
import 'session_refresh_listenable.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: ref.read(sessionRefreshListenableProvider),
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider).value;
      final isLoggedIn = session?.role != null;
      final isOnLoginScreen = state.matchedLocation == '/login';

      if (!isLoggedIn) {
        return isOnLoginScreen ? null : '/login';
      }
      if (isOnLoginScreen) {
        return session!.role == 'field_agent' ? '/audit' : '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardShellScreen()),
      GoRoute(path: '/audit', builder: (context, state) => const VisitOutletPickerScreen()),
      GoRoute(
        path: '/audit/:outletId',
        builder: (context, state) => AuditShellScreen(outletId: state.pathParameters['outletId']!),
      ),
      GoRoute(path: '/outlets', builder: (context, state) => const OutletsListScreen()),
      GoRoute(path: '/outlets/create', builder: (context, state) => const CreateOutletScreen()),
      GoRoute(path: '/tasks', builder: (context, state) => const TasksScreen()),
      GoRoute(path: '/campaigns', builder: (context, state) => const CampaignsScreen()),
      GoRoute(path: '/alerts', builder: (context, state) => const AlertsScreen()),
      GoRoute(path: '/territories', builder: (context, state) => const TerritoriesScreen()),
      GoRoute(path: '/orders', builder: (context, state) => const OrdersScreen()),
      GoRoute(path: '/beatplans', builder: (context, state) => const BeatPlansScreen()),
    ],
  );
});

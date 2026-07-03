import 'package:go_router/go_router.dart';

import '../../features/audit/presentation/audit_shell_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_shell_screen.dart';
import '../../features/outlets/presentation/outlets_list_screen.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardShellScreen()),
      GoRoute(path: '/audit', builder: (context, state) => const AuditShellScreen()),
      GoRoute(path: '/outlets', builder: (context, state) => const OutletsListScreen()),
    ],
  );
}

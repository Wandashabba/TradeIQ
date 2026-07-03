import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/audit/presentation/audit_shell_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_shell_screen.dart';
import '../../features/outlets/presentation/outlets_list_screen.dart';
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
      GoRoute(path: '/audit', builder: (context, state) => const AuditShellScreen()),
      GoRoute(path: '/outlets', builder: (context, state) => const OutletsListScreen()),
    ],
  );
});

# Login Form + Router Auth-Redirect Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the static Flutter login placeholder with a real login form, add role-based router redirects that guard `/dashboard`, `/audit`, and `/outlets` behind authentication, and add a logout action — closing [issue #5](https://github.com/Wandashabba/TradeIQ/issues/5).

**Architecture:** Move `GoRouter` construction into a Riverpod `Provider` with a `redirect` callback that reads `sessionControllerProvider`, driven by a `SessionRefreshListenable` (`ChangeNotifier`) that bridges Riverpod state changes into GoRouter's `refreshListenable`. The login screen becomes a real form calling `SessionController.login()`; navigation after login/logout happens automatically via the redirect logic reacting to state changes, not manual `context.go()` calls.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod` ^3.3.2), go_router (^17.3.0).

**Spec:** `docs/superpowers/specs/2026-07-03-login-auth-redirect-design.md`

---

### Task 1: `SessionController.logout()`

**Files:**
- Modify: `app/lib/core/auth/session_controller.dart`
- Test: `app/test/core/auth/session_controller_test.dart`

Current content of `session_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import 'auth_repository.dart';

class SessionState {
  const SessionState({this.role, this.token});
  final String? role;
  final String? token;
}

class SessionController extends AsyncNotifier<SessionState> {
  @override
  Future<SessionState> build() async => const SessionState();

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.login(email, password);
      currentAuthToken = result.token;
      return SessionState(role: result.role, token: result.token);
    });
  }
}

final sessionControllerProvider = AsyncNotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
```

- [ ] **Step 1: Write the failing test**

Append to `app/test/core/auth/session_controller_test.dart` (inside the existing `main()`, after the two existing `test(...)` blocks):

```dart
  test('logout clears the session back to an empty state', () async {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository())],
    );
    addTearDown(container.dispose);

    final controller = container.read(sessionControllerProvider.notifier);
    await controller.login('agent@tradeiq.com', 'password123');
    expect(container.read(sessionControllerProvider).value?.role, 'manager');

    controller.logout();

    final state = container.read(sessionControllerProvider);
    expect(state.value?.role, isNull);
    expect(state.value?.token, isNull);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/auth/session_controller_test.dart`
Expected: FAIL — `The method 'logout' isn't defined for the type 'SessionController'`

- [ ] **Step 3: Implement `logout()`**

Add this method inside the `SessionController` class in `app/lib/core/auth/session_controller.dart`, after `login`:

```dart
  void logout() {
    currentAuthToken = null;
    state = const AsyncData(SessionState());
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/core/auth/session_controller_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/auth/session_controller.dart app/test/core/auth/session_controller_test.dart
git commit -m "feat(app): add SessionController.logout()"
```

---

### Task 2: `SessionRefreshListenable`

**Files:**
- Create: `app/lib/core/router/session_refresh_listenable.dart`
- Test: `app/test/core/router/session_refresh_listenable_test.dart`

This bridges Riverpod session-state changes into a `Listenable` GoRouter can watch via `refreshListenable`, so `redirect` re-evaluates immediately after login/logout, not just on navigation.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/core/router/session_refresh_listenable_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/auth_repository.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/router/session_refresh_listenable.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthResult> login(String email, String password) async {
    return const AuthResult(token: 'fake-token', role: 'manager');
  }
}

void main() {
  test('notifies listeners when session state changes', () async {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository())],
    );
    addTearDown(container.dispose);

    final listenable = container.read(sessionRefreshListenableProvider);
    var notifyCount = 0;
    listenable.addListener(() => notifyCount += 1);

    final controller = container.read(sessionControllerProvider.notifier);
    await controller.login('agent@tradeiq.com', 'password123');

    expect(notifyCount, greaterThan(0));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/router/session_refresh_listenable_test.dart`
Expected: FAIL — cannot find `package:tradeiq_app/core/router/session_refresh_listenable.dart`

- [ ] **Step 3: Implement**

```dart
// app/lib/core/router/session_refresh_listenable.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_controller.dart';

/// Bridges Riverpod session-state changes into a [Listenable] that
/// GoRouter's `refreshListenable` can watch, so `redirect` re-runs whenever
/// [sessionControllerProvider] changes (e.g. after login/logout), not just
/// on navigation.
class SessionRefreshListenable extends ChangeNotifier {
  SessionRefreshListenable(Ref ref) {
    ref.listen(sessionControllerProvider, (_, __) => notifyListeners());
  }
}

final sessionRefreshListenableProvider = Provider<SessionRefreshListenable>((ref) {
  return SessionRefreshListenable(ref);
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/core/router/session_refresh_listenable_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/router/session_refresh_listenable.dart app/test/core/router/session_refresh_listenable_test.dart
git commit -m "feat(app): add SessionRefreshListenable bridging session state to GoRouter"
```

---

### Task 3: Router redirect logic + wire into `main.dart`

**Files:**
- Modify: `app/lib/core/router/app_router.dart`
- Modify: `app/lib/main.dart`
- Modify: `app/test/core/router/app_router_test.dart`

Current content of `app_router.dart`:

```dart
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
```

Current content of `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: TradeIqApp()));
}

class TradeIqApp extends StatelessWidget {
  const TradeIqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TradeIQ',
      theme: AppTheme.dark(),
      routerConfig: buildRouter(),
    );
  }
}
```

Both `buildRouter()` (a free function) and `TradeIqApp` (a `StatelessWidget`) change shape in this task — they're tightly coupled (the app won't compile with only one updated), so this task updates both together rather than leaving an intermediate broken state.

- [ ] **Step 1: Replace `app_router_test.dart` wholesale with the failing test**

```dart
// app/test/core/router/app_router_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/router/app_router.dart';

class _FixedSessionController extends SessionController {
  _FixedSessionController(this._initial);
  final SessionState _initial;

  @override
  Future<SessionState> build() async => _initial;
}

Widget _appWithOverrides(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: Consumer(
      builder: (context, ref, _) => MaterialApp.router(routerConfig: ref.watch(routerProvider)),
    ),
  );
}

void main() {
  testWidgets('unauthenticated root route shows the login screen', (tester) async {
    await tester.pumpWidget(_appWithOverrides([]));
    await tester.pumpAndSettle();
    expect(find.text('TradeIQ Login'), findsOneWidget);
  });

  testWidgets('unauthenticated request for /dashboard redirects to login', (tester) async {
    await tester.pumpWidget(_appWithOverrides([]));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    container.read(routerProvider).go('/dashboard');
    await tester.pumpAndSettle();

    expect(find.text('TradeIQ Login'), findsOneWidget);
  });

  testWidgets('authenticated field_agent starting at /login lands on /audit', (tester) async {
    await tester.pumpWidget(_appWithOverrides([
      sessionControllerProvider.overrideWith(
        () => _FixedSessionController(const SessionState(role: 'field_agent')),
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('S1 Outlet Information'), findsOneWidget);
  });

  testWidgets('authenticated manager starting at /login lands on /dashboard', (tester) async {
    await tester.pumpWidget(_appWithOverrides([
      sessionControllerProvider.overrideWith(
        () => _FixedSessionController(const SessionState(role: 'manager')),
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Numeric Distribution'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/router/app_router_test.dart`
Expected: FAIL — `Undefined name 'routerProvider'` (and the old `buildRouter()` symbol is gone from this file, so nothing references it anymore)

- [ ] **Step 3: Implement the redirect-aware router provider**

```dart
// app/lib/core/router/app_router.dart
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
      final session = ref.read(sessionControllerProvider).valueOrNull;
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
```

`ref.read` (not `ref.watch`) is used for `sessionRefreshListenableProvider` here deliberately: `routerProvider` itself must stay a single stable instance for the app's lifetime (recreating the `GoRouter` would reset navigation state). Re-evaluation of `redirect` happens via the listenable calling `notifyListeners()`, which is independent of whether `routerProvider` itself rebuilds.

- [ ] **Step 4: Wire `routerProvider` into `main.dart`**

```dart
// app/lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: TradeIqApp()));
}

class TradeIqApp extends ConsumerWidget {
  const TradeIqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'TradeIQ',
      theme: AppTheme.dark(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/core/router/app_router_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 6: Run the full test suite and analyzer to confirm no regressions**

Run: `cd app && flutter test && flutter analyze`
Expected: all tests pass (some other test files will still fail at this point if their subject widgets haven't been updated to run under a `ProviderScope` yet — Tasks 5 and 6 handle `DashboardShellScreen`/`AuditShellScreen`. If `dashboard_shell_screen_test.dart` or `audit_shell_screen_test.dart` fail here because those screens don't yet need a `ProviderScope`, that's expected and will be fixed in Tasks 5/6 — do not fix them in this task.)

- [ ] **Step 7: Commit**

```bash
git add app/lib/core/router/app_router.dart app/lib/main.dart app/test/core/router/app_router_test.dart
git commit -m "feat(app): add redirect-aware router provider guarding authenticated routes"
```

---

### Task 4: Real login form

**Files:**
- Modify: `app/lib/features/auth/presentation/login_screen.dart`
- Test: `app/test/features/auth/login_screen_test.dart`

Current content of `login_screen.dart`:

```dart
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('TradeIQ Login')),
    );
  }
}
```

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/auth/login_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/auth_repository.dart';
import 'package:tradeiq_app/features/auth/presentation/login_screen.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthResult> login(String email, String password) async {
    return const AuthResult(token: 'fake-token', role: 'manager');
  }
}

class FailingAuthRepository implements AuthRepository {
  @override
  Future<AuthResult> login(String email, String password) async {
    throw Exception('invalid credentials');
  }
}

Widget _wrap(AuthRepository repository) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: LoginScreen()),
  );
}

void main() {
  testWidgets('submitting valid credentials shows a loading indicator', (tester) async {
    await tester.pumpWidget(_wrap(FakeAuthRepository()));

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'manager@tradeiq.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('shows validation errors when fields are empty', (tester) async {
    await tester.pumpWidget(_wrap(FakeAuthRepository()));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('shows an error message when login fails', (tester) async {
    await tester.pumpWidget(_wrap(FailingAuthRepository()));

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'manager@tradeiq.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'wrong-password');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid credentials'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/auth/login_screen_test.dart`
Expected: FAIL — no `TextFormField`/`ElevatedButton` widgets exist yet on the placeholder screen

- [ ] **Step 3: Implement the login form**

```dart
// app/lib/features/auth/presentation/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      ref.read(sessionControllerProvider.notifier).login(
            _emailController.text,
            _passwordController.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final isLoading = session.isLoading;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('TradeIQ Login'),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) =>
                        (value == null || value.isEmpty) ? 'Email is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) =>
                        (value == null || value.isEmpty) ? 'Password is required' : null,
                  ),
                  const SizedBox(height: 24),
                  if (session.hasError)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Invalid credentials',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Log in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

The `'TradeIQ Login'` text is kept as the form's title so the existing router test
(Task 3, `'unauthenticated root route shows the login screen'`) keeps passing
unchanged.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/auth/login_screen_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/auth/presentation/login_screen.dart app/test/features/auth/login_screen_test.dart
git commit -m "feat(app): add real login form calling SessionController.login()"
```

---

### Task 5: Logout button on `DashboardShellScreen`

**Files:**
- Modify: `app/lib/features/dashboard/presentation/dashboard_shell_screen.dart`
- Modify: `app/test/features/dashboard/dashboard_shell_screen_test.dart`

Current content of `dashboard_shell_screen.dart`:

```dart
import 'package:flutter/material.dart';

const _kpiLabels = [
  'Numeric Distribution',
  'Weighted Distribution',
  'OSA %',
  'Execution Score',
  'Price Compliance %',
  'Visibility Compliance %',
  'Share of Shelf',
  'Perfect Store Rate',
];

class DashboardShellScreen extends StatelessWidget {
  const DashboardShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manager Dashboard')),
      body: SingleChildScrollView(
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: _kpiLabels
              .map((label) => Card(
                    child: Center(
                      child: Text(label, textAlign: TextAlign.center),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
```

- [ ] **Step 1: Replace the test file with the failing test**

```dart
// app/test/features/dashboard/dashboard_shell_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/features/dashboard/presentation/dashboard_shell_screen.dart';

void main() {
  testWidgets('renders all 8 KPI tile labels', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DashboardShellScreen()),
      ),
    );
    const labels = [
      'Numeric Distribution',
      'Weighted Distribution',
      'OSA %',
      'Execution Score',
      'Price Compliance %',
      'Visibility Compliance %',
      'Share of Shelf',
      'Perfect Store Rate',
    ];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('tapping logout clears the session', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DashboardShellScreen()),
      ),
    );

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pump();

    final context = tester.element(find.byType(DashboardShellScreen));
    final container = ProviderScope.containerOf(context);
    expect(container.read(sessionControllerProvider).value?.role, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/dashboard/dashboard_shell_screen_test.dart`
Expected: FAIL — no `Icons.logout` widget exists yet on the screen

- [ ] **Step 3: Add the logout action**

```dart
// app/lib/features/dashboard/presentation/dashboard_shell_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';

const _kpiLabels = [
  'Numeric Distribution',
  'Weighted Distribution',
  'OSA %',
  'Execution Score',
  'Price Compliance %',
  'Visibility Compliance %',
  'Share of Shelf',
  'Perfect Store Rate',
];

class DashboardShellScreen extends ConsumerWidget {
  const DashboardShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: _kpiLabels
              .map((label) => Card(
                    child: Center(
                      child: Text(label, textAlign: TextAlign.center),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/dashboard/dashboard_shell_screen_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/dashboard/presentation/dashboard_shell_screen.dart app/test/features/dashboard/dashboard_shell_screen_test.dart
git commit -m "feat(app): add logout action to the dashboard app bar"
```

---

### Task 6: Logout button on `AuditShellScreen`

**Files:**
- Modify: `app/lib/features/audit/presentation/audit_shell_screen.dart`
- Modify: `app/test/features/audit/audit_shell_screen_test.dart`

Current content of `audit_shell_screen.dart`:

```dart
import 'package:flutter/material.dart';

import 'sections/s1_outlet_info_screen.dart';
import 'sections/s2_stock_screen.dart';
import 'sections/s3_4_visibility_display_screen.dart';
import 'sections/s5_pricing_promotions_screen.dart';
import 'sections/s6_competitive_screen.dart';
import 'sections/s7_capability_screen.dart';
import 'sections/s8_risks_screen.dart';
import 'sections/s9_action_plan_screen.dart';
import 'sections/s10_scorecard_screen.dart';

class AuditShellScreen extends StatefulWidget {
  const AuditShellScreen({super.key});

  @override
  State<AuditShellScreen> createState() => _AuditShellScreenState();
}

class _AuditShellScreenState extends State<AuditShellScreen> {
  int _step = 0;

  static const List<Widget> _sections = [
    S1OutletInfoScreen(),
    S2StockScreen(),
    S3S4VisibilityDisplayScreen(),
    S5PricingPromotionsScreen(),
    S6CompetitiveScreen(),
    S7CapabilityScreen(),
    S8RisksScreen(),
    S9ActionPlanScreen(),
    S10ScorecardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Visit')),
      body: SingleChildScrollView(
        child: Stepper(
          physics: const NeverScrollableScrollPhysics(),
          currentStep: _step,
          onStepContinue: () {
            if (_step < _sections.length - 1) setState(() => _step += 1);
          },
          onStepTapped: (index) => setState(() => _step = index),
          steps: _sections
              .map(
                (screen) =>
                    Step(title: const SizedBox.shrink(), content: screen),
              )
              .toList(),
        ),
      ),
    );
  }
}
```

- [ ] **Step 1: Replace the test file with the failing test**

```dart
// app/test/features/audit/audit_shell_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/features/audit/presentation/audit_shell_screen.dart';

void main() {
  testWidgets('shows a stepper with all 10 audit sections', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuditShellScreen()),
      ),
    );
    expect(find.text('S1 Outlet Information'), findsOneWidget);
    expect(find.text('S10 Execution Scorecard'), findsOneWidget);
  });

  testWidgets('tapping logout clears the session', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuditShellScreen()),
      ),
    );

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pump();

    final context = tester.element(find.byType(AuditShellScreen));
    final container = ProviderScope.containerOf(context);
    expect(container.read(sessionControllerProvider).value?.role, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/audit/audit_shell_screen_test.dart`
Expected: FAIL — no `Icons.logout` widget exists yet on the screen

- [ ] **Step 3: Add the logout action**

```dart
// app/lib/features/audit/presentation/audit_shell_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import 'sections/s1_outlet_info_screen.dart';
import 'sections/s2_stock_screen.dart';
import 'sections/s3_4_visibility_display_screen.dart';
import 'sections/s5_pricing_promotions_screen.dart';
import 'sections/s6_competitive_screen.dart';
import 'sections/s7_capability_screen.dart';
import 'sections/s8_risks_screen.dart';
import 'sections/s9_action_plan_screen.dart';
import 'sections/s10_scorecard_screen.dart';

class AuditShellScreen extends ConsumerStatefulWidget {
  const AuditShellScreen({super.key});

  @override
  ConsumerState<AuditShellScreen> createState() => _AuditShellScreenState();
}

class _AuditShellScreenState extends ConsumerState<AuditShellScreen> {
  int _step = 0;

  static const List<Widget> _sections = [
    S1OutletInfoScreen(),
    S2StockScreen(),
    S3S4VisibilityDisplayScreen(),
    S5PricingPromotionsScreen(),
    S6CompetitiveScreen(),
    S7CapabilityScreen(),
    S8RisksScreen(),
    S9ActionPlanScreen(),
    S10ScorecardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Visit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Stepper(
          physics: const NeverScrollableScrollPhysics(),
          currentStep: _step,
          onStepContinue: () {
            if (_step < _sections.length - 1) setState(() => _step += 1);
          },
          onStepTapped: (index) => setState(() => _step = index),
          steps: _sections
              .map(
                (screen) =>
                    Step(title: const SizedBox.shrink(), content: screen),
              )
              .toList(),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/audit/audit_shell_screen_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/audit/presentation/audit_shell_screen.dart app/test/features/audit/audit_shell_screen_test.dart
git commit -m "feat(app): add logout action to the audit flow app bar"
```

---

### Task 7: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `cd app && flutter test`
Expected: all test files pass, no regressions (session_controller, session_refresh_listenable, app_router, login_screen, dashboard_shell_screen, audit_shell_screen, outlets_list_screen, app_theme, widget_test)

- [ ] **Step 2: Run the analyzer**

Run: `cd app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Manual end-to-end verification against the real backend**

With Postgres and the backend running (`make dev` from the repo root, in a separate terminal, after `make setup` has been run at least once):

```bash
cd app && flutter run -d chrome
```

In the browser:
1. Confirm you land on the login form (not the old static placeholder).
2. Submit with empty fields — confirm "Email is required" / "Password is required" appear.
3. Submit with a wrong password (`manager@demo-fmcg.tradeiq.com` / `wrong-password`) — confirm "Invalid credentials" appears and the form is still on `/login`.
4. Submit with the real seeded credentials (`manager@demo-fmcg.tradeiq.com` / `demo-password-123`) — confirm you land on `/dashboard` automatically (no manual navigation).
5. Tap the logout icon in the dashboard app bar — confirm you're returned to `/login`.
6. Repeat steps 3–5 with `agent@demo-fmcg.tradeiq.com` / `demo-password-123` (role `field_agent`) — confirm this lands on `/audit` instead of `/dashboard`.
7. While logged out, manually navigate the browser to `http://localhost:<port>/#/dashboard` — confirm you're bounced back to `/login` rather than seeing the dashboard.

- [ ] **Step 4: No commit for this task** — it's verification only; if any step fails, return to the relevant task above and fix it there (with its own commit), don't fix it here.

---

## Plan self-review notes

- **Spec coverage:** §3 (redirect architecture) → Task 3; §4 (login form) → Task 4; §5 (logout) → Tasks 1, 5, 6; §6 (testing) → every task's TDD steps plus Task 7's full-suite + manual pass; §7 (explicitly out of scope: session persistence, `/outlets` role restrictions) — no task touches `flutter_secure_storage`, `api_client.dart`'s persistence, or adds `requireRole`-equivalent restrictions to `/outlets`, consistent with the spec's exclusions.
- **Placeholder scan:** no TBD/TODO; the one forward-looking note (Task 3, Step 6) about other tests failing until Tasks 5/6 land is an explicit, intentional sequencing note, not an unresolved placeholder.
- **Type consistency:** `SessionState(role:, token:)` fields match across Tasks 1, 3, 4; `sessionControllerProvider` / `SessionController.logout()` / `routerProvider` / `sessionRefreshListenableProvider` names are used identically everywhere they're referenced across tasks.

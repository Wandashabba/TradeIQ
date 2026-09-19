import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/features/dashboard/presentation/the_floor_screen.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/push/push_config.dart';
import 'package:tradeiq_app/core/push/push_repository.dart';
import 'package:tradeiq_app/core/router/app_router.dart';
import 'package:tradeiq_app/core/network/app_version.dart';
import 'package:tradeiq_app/features/auth/presentation/change_password_screen.dart';
import 'package:tradeiq_app/features/auth/presentation/forgot_password_screen.dart';
import 'package:tradeiq_app/features/auth/presentation/update_required_screen.dart';
import 'package:tradeiq_app/features/users/presentation/user_password_screen.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/features/agents/data/agents_repository.dart';
import 'package:tradeiq_app/features/audit/data/visit_progress.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/contests/data/contests_repository.dart';
import 'package:tradeiq_app/features/audit/data/visits_repository.dart';
import 'package:tradeiq_app/features/orders/data/orders_repository.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/reports/data/report_schedules_repository.dart';
import 'package:tradeiq_app/features/sales_targets/data/sales_targets_repository.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/features/beatplans/presentation/today_screen.dart';
import 'package:tradeiq_app/features/sales_targets/presentation/sales_targets_screen.dart';
import 'package:tradeiq_app/features/templates/data/templates_repository.dart';

import '../../features/contests/contests_fakes.dart';

class _FixedSessionController extends SessionController {
  _FixedSessionController(this._initial);
  final SessionState _initial;

  @override
  Future<SessionState> build() async => _initial;
}

class _FakeOutletsRepository implements OutletsRepository {
  @override
  Future<PaginatedResponse<Outlet>> listOutlets({
    bool mine = false,
    int? limit,
    String? cursor,
  }) async => const PaginatedResponse(
    data: [
      Outlet(
        id: 'o1',
        name: 'Test Outlet',
        code: 'TO-001',
        lat: -26.2041,
        lng: 28.0473,
      ),
    ],
    nextCursor: null,
  );

  @override
  Future<Outlet> createOutlet({
    required String name,
    required String code,
    required String channelType,
    required double lat,
    required double lng,
    required String territoryId,
  }) => throw UnimplementedError();
}

class _FakeOrdersRepository implements OrdersRepository {
  @override
  Future<PaginatedResponse<OrderItem>> listOrders({
    String? status,
    String? outletId,
  }) async => const PaginatedResponse(data: [], nextCursor: null);

  @override
  Future<void> createOrder({
    required String outletId,
    required List<OrderLine> lines,
  }) => throw UnimplementedError();
}

class _FakeTemplatesRepository implements TemplatesRepository {
  @override
  Future<PaginatedResponse<AuditTemplate>> listTemplates() async =>
      const PaginatedResponse(data: [], nextCursor: null);

  @override
  Future<AuditTemplateDetail?> fetchSelected() async => null;

  @override
  Future<AuditTemplateDetail?> selectForAudits(String? templateId) async =>
      null;

  @override
  Future<AuditTemplateDetail> fetchTemplate(String id) async =>
      const AuditTemplateDetail(
        template: AuditTemplate(
          id: 'tpl-1',
          name: 'Grocery Audit',
          version: 1,
          active: true,
        ),
        schema: {
          'sections': [
            {
              'id': 's1',
              'title': 'Availability',
              'fields': [
                {'id': 'onShelf', 'label': 'On shelf?', 'type': 'boolean'},
              ],
            },
          ],
        },
      );
}

// Only needed so an unguarded /agents/activity would build without hitting
// the network before the fix lands, not because the passing (post-fix) case
// ever reaches AgentTrailScreen — the redirect happens first.
class _FakeAgentsRepository implements AgentsRepository {
  @override
  Future<AgentActivityPage> listActivity({
    required DateTime from,
    required DateTime to,
    String? territoryId,
  }) async => const AgentActivityPage(agents: [], truncated: false);
}

class _FakeSucceedingVisitsRepository implements VisitsRepository {
  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async => CheckInSucceeded('visit-1');

  @override
  Future<void> submitVisit(String visitDraftId) async {}
}

Widget _appWithOverrides(List<Override> overrides) {
  return ProviderScope(
    overrides: [
      // Agent screens carry the sync chip, which watches the outbox over a Drift
      // stream. Drift's watch() reschedules a zero-duration timer on every tick,
      // so pumpAndSettle never settles against a real one — stub the provider.
      syncStatusProvider.overrideWith((ref) => Stream.value(SyncStatus.empty)),
      visitProgressProvider.overrideWith(
        (ref, arg) =>
            Stream.value(const VisitProgress(states: {}, details: {})),
      ),
      ...overrides,
    ],
    child: Consumer(
      builder: (context, ref, _) =>
          MaterialApp.router(routerConfig: ref.watch(routerProvider)),
    ),
  );
}

class _FakeSalesTargetsRepository implements SalesTargetsRepository {
  @override
  Future<SalesAttainmentReport> attainment(String? month) async =>
      const SalesAttainmentReport(
        month: '2026-09',
        timeZone: 'Africa/Johannesburg',
        skus: [],
      );

  @override
  Future<void> upsert({
    required String skuId,
    required String month,
    required int targetUnits,
    String? territoryId,
    String? outletId,
  }) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<SalesTargetImportResult> importCsv(
    String csv, {
    required bool dryRun,
  }) async => throw UnimplementedError();
}

void main() {
  testWidgets('root route shows the splash and holds (no instant redirect)', (
    tester,
  ) async {
    // 2026-07-24 premium-ui redesign: '/' is the splash — the wordmark, no
    // Continue button — and the router deliberately does NOT redirect it; the
    // splash routes itself at max(5s, restore) (see splash_flow_test.dart).
    await tester.pumpWidget(_appWithOverrides([]));
    await tester.pumpAndSettle();
    expect(find.text('TRADEIQ'), findsOneWidget);
    expect(find.text('Forgot password?'), findsNothing);
  });

  testWidgets('unauthenticated request for /dashboard redirects to login', (
    tester,
  ) async {
    await tester.pumpWidget(_appWithOverrides([]));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.read(routerProvider).go('/dashboard');
    await tester.pumpAndSettle();

    // The login screen's stable unique marker after the c71f37b redesign
    // ('Sign in' appears twice: headline + submit button).
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets(
    'authenticated field_agent starting at /login lands on their route for the day',
    (tester) async {
      await tester.pumpWidget(
        _appWithOverrides([
          sessionControllerProvider.overrideWith(
            () => _FixedSessionController(
              const SessionState(role: 'field_agent'),
            ),
          ),
          outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
          // The route screen reads the agent's beat plan over the network; the
          // routing question here is only *where they land*.
          todayRouteProvider.overrideWith((ref) async => null),
        ]),
      );
      await tester.pumpAndSettle();

      // '/' no longer redirects (the splash holds; see splash_flow_test.dart),
      // so exercise what this test is named for: an authed agent hitting
      // /login — a stale link — is still bounced to their home.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container.read(routerProvider).go('/login');
      await tester.pumpAndSettle();

      // The first question of an agent's day is "where am I going", not "which
      // of these 400 outlets would you like to audit".
      expect(find.byType(TodayScreen), findsOneWidget);
    },
  );

  testWidgets('/audit/:outletId renders the audit shell for that outlet', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appWithOverrides([
        sessionControllerProvider.overrideWith(
          () =>
              _FixedSessionController(const SessionState(role: 'field_agent')),
        ),
        outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
        visitsRepositoryProvider.overrideWithValue(
          _FakeSucceedingVisitsRepository(),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.read(routerProvider).go('/audit/o1');
    await tester.pumpAndSettle();

    // The visit is titled by the store the agent is standing in, and the audit
    // is a named checklist — not a Stepper with blank steps.
    expect(find.text('Test Outlet'), findsOneWidget);
    expect(find.text('Outlet info'), findsOneWidget);
    expect(find.text('Stock & availability'), findsOneWidget);
  });

  testWidgets('authenticated manager starting at /login lands on /dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appWithOverrides([
        sessionControllerProvider.overrideWith(
          () => _FixedSessionController(const SessionState(role: 'manager')),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    // '/' no longer redirects (the splash holds; see splash_flow_test.dart),
    // so exercise what this test is named for: an authed manager hitting
    // /login is still bounced to the dashboard.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.read(routerProvider).go('/login');
    await tester.pumpAndSettle();

    // The Floor loads from GET /dashboard (unstubbed here, so it renders its
    // error region); the screen's own type is the routing signal, because it
    // carries no app header to read a title off — the plate is the header.
    // (was: the KPI grid's title)
    // so it settles into the error state); the AppBar title is the stable
    // signal that routing landed on the dashboard.
    expect(find.byType(TheFloorScreen), findsOneWidget);
  });

  testWidgets('logging out from a protected route redirects back to login', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appWithOverrides([
        sessionControllerProvider.overrideWith(
          () => _FixedSessionController(const SessionState(role: 'manager')),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    // '/' no longer redirects (the splash holds; see splash_flow_test.dart) —
    // put the manager on the protected route explicitly first.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.read(routerProvider).go('/dashboard');
    await tester.pumpAndSettle();
    expect(find.byType(TheFloorScreen), findsOneWidget);

    container.read(sessionControllerProvider.notifier).logout();
    await tester.pumpAndSettle();

    // The login screen's stable unique marker after the c71f37b redesign
    // ('Sign in' appears twice: headline + submit button).
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets(
    'a field_agent navigating to a manager route is bounced to their route',
    (tester) async {
      await tester.pumpWidget(
        _appWithOverrides([
          sessionControllerProvider.overrideWith(
            () => _FixedSessionController(
              const SessionState(role: 'field_agent'),
            ),
          ),
          outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
          todayRouteProvider.overrideWith((ref) async => null),
        ]),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container.read(routerProvider).go('/dashboard');
      await tester.pumpAndSettle();

      // Guarded away from the manager dashboard, back to the audit outlet picker.
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.byType(TheFloorScreen), findsNothing);
    },
  );

  testWidgets('a field_agent can reach /orders for in-store capture', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appWithOverrides([
        sessionControllerProvider.overrideWith(
          () =>
              _FixedSessionController(const SessionState(role: 'field_agent')),
        ),
        outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
        ordersRepositoryProvider.overrideWithValue(_FakeOrdersRepository()),
      ]),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.read(routerProvider).go('/orders');
    await tester.pumpAndSettle();

    // /orders is a shared route: the field agent is NOT bounced back to /audit.
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Select an Outlet'), findsNothing);
  });

  testWidgets(
    'a field_agent navigating to a template preview is bounced to their route',
    (tester) async {
      await tester.pumpWidget(
        _appWithOverrides([
          sessionControllerProvider.overrideWith(
            () => _FixedSessionController(
              const SessionState(role: 'field_agent'),
            ),
          ),
          outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
          todayRouteProvider.overrideWith((ref) async => null),
          templatesRepositoryProvider.overrideWithValue(
            _FakeTemplatesRepository(),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container.read(routerProvider).go('/audit-templates/tpl-1/preview');
      await tester.pumpAndSettle();

      // The preview subroute is manager territory, like /audit-templates.
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.text('Grocery Audit'), findsNothing);
    },
  );

  testWidgets(
    'a field_agent navigating to a visit review is bounced to their route',
    (tester) async {
      await tester.pumpWidget(
        _appWithOverrides([
          sessionControllerProvider.overrideWith(
            () => _FixedSessionController(
              const SessionState(role: 'field_agent'),
            ),
          ),
          outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
          todayRouteProvider.overrideWith((ref) async => null),
        ]),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container.read(routerProvider).go('/visits/v1');
      await tester.pumpAndSettle();

      // /visits/:id is supervisory (#208): its API is manager/admin-only.
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.text('Visit review'), findsNothing);
    },
  );

  testWidgets(
    'a field_agent navigating to an agent\'s points history is bounced to their route',
    (tester) async {
      await tester.pumpWidget(
        _appWithOverrides([
          sessionControllerProvider.overrideWith(
            () => _FixedSessionController(
              const SessionState(role: 'field_agent'),
            ),
          ),
          outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
          todayRouteProvider.overrideWith((ref) async => null),
        ]),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container.read(routerProvider).go('/leaderboard/a1');
      await tester.pumpAndSettle();

      // /leaderboard/:agentId is supervisory (#124): its API is
      // manager/admin-only, so an agent would only ever land on a 403.
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.text('Points history'), findsNothing);
    },
  );

  testWidgets(
    'a field_agent navigating to report schedules is bounced to their route',
    (tester) async {
      await tester.pumpWidget(
        _appWithOverrides([
          sessionControllerProvider.overrideWith(
            () => _FixedSessionController(
              const SessionState(role: 'field_agent'),
            ),
          ),
          outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
          todayRouteProvider.overrideWith((ref) async => null),
          reportSchedulesListProvider.overrideWith((ref) async => const []),
        ]),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container.read(routerProvider).go('/reports/schedules');
      await tester.pumpAndSettle();

      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.text('Report schedules'), findsNothing);
    },
  );

  testWidgets(
    'a field_agent navigating to sales targets is bounced to their route',
    (tester) async {
      await tester.pumpWidget(
        _appWithOverrides([
          sessionControllerProvider.overrideWith(
            () => _FixedSessionController(
              const SessionState(role: 'field_agent'),
            ),
          ),
          outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
          todayRouteProvider.overrideWith((ref) async => null),
          salesTargetsRepositoryProvider.overrideWithValue(
            _FakeSalesTargetsRepository(),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container.read(routerProvider).go('/sales-targets');
      await tester.pumpAndSettle();

      // Sales targets are manager/admin (#119): the API refuses agents.
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.byType(SalesTargetsScreen), findsNothing);
    },
  );

  testWidgets('a manager can open sales targets', (tester) async {
    await tester.pumpWidget(
      _appWithOverrides([
        sessionControllerProvider.overrideWith(
          () => _FixedSessionController(const SessionState(role: 'manager')),
        ),
        salesTargetsRepositoryProvider.overrideWithValue(
          _FakeSalesTargetsRepository(),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.read(routerProvider).go('/sales-targets');
    await tester.pumpAndSettle();

    expect(find.byType(SalesTargetsScreen), findsOneWidget);
  });

  testWidgets('a manager can open report schedules', (tester) async {
    await tester.pumpWidget(
      _appWithOverrides([
        sessionControllerProvider.overrideWith(
          () => _FixedSessionController(const SessionState(role: 'manager')),
        ),
        reportSchedulesListProvider.overrideWith((ref) async => const []),
      ]),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.read(routerProvider).go('/reports/schedules');
    await tester.pumpAndSettle();

    expect(find.text('Report schedules'), findsOneWidget);
    expect(find.text('No report schedules'), findsOneWidget);
  });

  testWidgets('a manager can open a template preview and see its form', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appWithOverrides([
        sessionControllerProvider.overrideWith(
          () => _FixedSessionController(const SessionState(role: 'manager')),
        ),
        templatesRepositoryProvider.overrideWithValue(
          _FakeTemplatesRepository(),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.read(routerProvider).go('/audit-templates/tpl-1/preview');
    await tester.pumpAndSettle();

    expect(find.text('Grocery Audit'), findsOneWidget);
    expect(find.text('On shelf?'), findsOneWidget);
  });

  testWidgets(
    'a field_agent navigating to /alert-rules is bounced to their route',
    (tester) async {
      await tester.pumpWidget(
        _appWithOverrides([
          sessionControllerProvider.overrideWith(
            () => _FixedSessionController(
              const SessionState(role: 'field_agent'),
            ),
          ),
          outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
          todayRouteProvider.overrideWith((ref) async => null),
        ]),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container.read(routerProvider).go('/alert-rules');
      await tester.pumpAndSettle();

      // Only managers/admins may write rules (requireRole on the backend), so
      // the screen is manager-only — an agent lands back on the outlet picker.
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.text('Alert rules'), findsNothing);
    },
  );

  testWidgets(
    'a field_agent navigating to /agents/activity is bounced to their route',
    (tester) async {
      await tester.pumpWidget(
        _appWithOverrides([
          sessionControllerProvider.overrideWith(
            () => _FixedSessionController(
              const SessionState(role: 'field_agent'),
            ),
          ),
          outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
          todayRouteProvider.overrideWith((ref) async => null),
          agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository()),
        ]),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container.read(routerProvider).go('/agents/activity');
      await tester.pumpAndSettle();

      // The trail map is manager/admin territory (requireRole on the
      // backend), so the screen is manager-only — an agent lands back on
      // their route for the day.
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.text('Agent trail'), findsNothing);
    },
  );

  testWidgets(
    'a manager navigating to the audit flow is bounced to /dashboard',
    (tester) async {
      await tester.pumpWidget(
        _appWithOverrides([
          sessionControllerProvider.overrideWith(
            () => _FixedSessionController(const SessionState(role: 'manager')),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container.read(routerProvider).go('/audit/o1');
      await tester.pumpAndSettle();

      expect(find.byType(TheFloorScreen), findsOneWidget);
    },
  );

  group('the account routes (#400)', () {
    tearDown(() => appUpdateRequired.value = null);

    GoRouter routerOf(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(routerProvider);

    List<Override> asRole(String role) => [
      sessionControllerProvider.overrideWith(
        () => _FixedSessionController(SessionState(role: role)),
      ),
      outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
      todayRouteProvider.overrideWith((ref) async => null),
    ];

    testWidgets('/forgot-password is open to someone signed out', (
      tester,
    ) async {
      await tester.pumpWidget(_appWithOverrides([]));
      await tester.pumpAndSettle();
      routerOf(tester).go('/forgot-password');
      await tester.pumpAndSettle();
      // The whole point is that this person cannot sign in.
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    });

    testWidgets('"Forgot password?" on the sign-in screen goes there', (
      tester,
    ) async {
      await tester.pumpWidget(_appWithOverrides([]));
      await tester.pumpAndSettle();
      routerOf(tester).go('/login');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    });

    testWidgets('/account/password needs a session', (tester) async {
      await tester.pumpWidget(_appWithOverrides([]));
      await tester.pumpAndSettle();
      routerOf(tester).go('/account/password');
      await tester.pumpAndSettle();
      expect(find.byType(ChangePasswordScreen), findsNothing);
      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('an agent can change their own password', (tester) async {
      await tester.pumpWidget(_appWithOverrides(asRole('field_agent')));
      await tester.pumpAndSettle();
      routerOf(tester).go('/account/password');
      await tester.pumpAndSettle();
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
    });

    testWidgets('an agent cannot reach anyone else\'s reset', (tester) async {
      await tester.pumpWidget(_appWithOverrides(asRole('field_agent')));
      await tester.pumpAndSettle();
      routerOf(tester).go('/users/u-1/password');
      await tester.pumpAndSettle();
      expect(find.byType(UserPasswordScreen), findsNothing);
      expect(find.byType(TodayScreen), findsOneWidget);
    });

    testWidgets('a 426 sends every route to the update screen, and back', (
      tester,
    ) async {
      await tester.pumpWidget(_appWithOverrides(asRole('field_agent')));
      await tester.pumpAndSettle();
      routerOf(tester).go('/today');
      await tester.pumpAndSettle();
      expect(find.byType(TodayScreen), findsOneWidget);

      // What the API client does on a 426 carrying app_update_required.
      appUpdateRequired.value = const AppUpdateRequired(
        minimumVersion: '9.0.0',
      );
      await tester.pumpAndSettle();
      expect(find.byType(UpdateRequiredScreen), findsOneWidget);

      // Nowhere else is reachable while the build is refused.
      routerOf(tester).go('/orders');
      await tester.pumpAndSettle();
      expect(find.byType(UpdateRequiredScreen), findsOneWidget);

      // "Try again" clears it; the agent is still signed in and lands home.
      await tester.tap(find.byKey(const ValueKey<String>('update-try-again')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(appUpdateRequired.value, isNull);
      expect(find.byType(UpdateRequiredScreen), findsNothing);
    });
  });

  group('contests (#124)', () {
    Future<void> goAs(
      WidgetTester tester,
      String role,
      String location, {
      List<CurrentContest> current = const [],
    }) async {
      await tester.pumpWidget(
        _appWithOverrides([
          sessionControllerProvider.overrideWith(
            () => _FixedSessionController(SessionState(role: role)),
          ),
          outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
          todayRouteProvider.overrideWith((ref) async => null),
          contestsRepositoryProvider.overrideWithValue(
            FakeContestsRepository(
              current: current,
              standingsById: const {
                'c-active': ContestStandings(
                  contest: activeContest,
                  participantCount: 1,
                  standings: [aisha],
                ),
              },
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container.read(routerProvider).go(location);
      await tester.pumpAndSettle();
    }

    for (final location in ['/contests', '/contests/c-active']) {
      testWidgets('a field_agent navigating to $location is bounced to their '
          'route', (tester) async {
        await goAs(tester, 'field_agent', location);

        // Running contests and their full standings are manager/admin APIs.
        expect(find.byType(TodayScreen), findsOneWidget);
        expect(find.text('Contest standings'), findsNothing);
      });
    }

    for (final role in ['field_agent', 'manager']) {
      testWidgets('a $role can open /leaderboard/contests — the one shared '
          '/leaderboard/ subroute', (tester) async {
        await goAs(tester, role, '/leaderboard/contests');

        expect(find.text('No contests right now'), findsOneWidget);
        expect(find.text('Points history'), findsNothing);
      });
    }

    testWidgets('a field_agent reaches Contests from Today\'s nav, and comes '
        'back to Today', (tester) async {
      await goAs(
        tester,
        'field_agent',
        '/today',
        current: const [
          CurrentContest(
            contest: activeContest,
            participantCount: 1,
            standings: [aisha],
          ),
        ],
      );

      // Contests moved from the Today app bar into the agent's nav pill: the
      // Torchlight header allows exactly one trailing icon button and on a tab
      // root that one is the skin cycle (unify §1.2). The capability is
      // unchanged — reach the standings, see how many are running, come back —
      // so this asserts the capability, not the widget it used to be.
      final action = find.descendant(
        of: find.byType(TorchNavPill),
        matching: find.text('Contests'),
      );
      expect(action, findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TorchNavPill),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );

      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('October Sprint'), findsOneWidget);
      expect(find.text('1 contest running'), findsNothing);

      // A nav slot `go`es, so the Contests screen has nothing to pop — its
      // back has to take an agent home rather than to the leaderboard they
      // never came from.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.text('October Sprint'), findsNothing);
    });

    testWidgets('a manager has no Contests action: /today is not theirs', (
      tester,
    ) async {
      await goAs(tester, 'manager', '/today');

      expect(find.byType(TheFloorScreen), findsOneWidget);
      // Not "the trophy button is absent" — that key no longer exists and the
      // assertion would pass on a blank screen. The fact is that a manager
      // never gets the agent's frame at all, and the agent's way into
      // Contests lives in that frame.
      expect(find.byType(TodayScreen), findsNothing);
      expect(
        find.descendant(
          of: find.byType(TorchNavPill),
          matching: find.text('Contests'),
        ),
        findsNothing,
      );
    });

    testWidgets('a manager can open a contest\'s standings', (tester) async {
      await goAs(tester, 'manager', '/contests/c-active');

      expect(find.text('Contest standings'), findsOneWidget);
      expect(find.text('Aisha Patel'), findsOneWidget);
    });
  });

  // Push notification settings (#67) are shared: neither role is bounced.
  for (final (role, title) in [
    ('field_agent', 'Notifications'),
    ('manager', 'Notifications'),
  ]) {
    testWidgets('a $role can open /notifications', (tester) async {
      await tester.pumpWidget(
        _appWithOverrides([
          sessionControllerProvider.overrideWith(
            () => _FixedSessionController(SessionState(role: role)),
          ),
          outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
          todayRouteProvider.overrideWith((ref) async => null),
          pushRepositoryProvider.overrideWithValue(_FakePushRepository()),
        ]),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container.read(routerProvider).go('/notifications');
      await tester.pumpAndSettle();

      expect(find.text(title), findsOneWidget);
      expect(find.text('Overdue tasks'), findsOneWidget);
      expect(find.byType(TodayScreen), findsNothing);
      expect(find.byType(TheFloorScreen), findsNothing);
    });
  }
}

class _FakePushRepository implements PushRepository {
  @override
  Future<NotificationPreferences> fetchPreferences() async =>
      const NotificationPreferences();

  @override
  Future<NotificationPreferences> updatePreferences(
    Map<NotificationCategory, bool> changes,
  ) async => const NotificationPreferences();

  @override
  Future<void> registerDevice({
    required String token,
    required PushPlatform platform,
  }) async {}

  @override
  Future<void> unregisterDevice(
    String token, {
    required String authToken,
  }) async {}
}

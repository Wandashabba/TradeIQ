import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/router/app_router.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/features/agents/data/agents_repository.dart';
import 'package:tradeiq_app/features/audit/data/visit_progress.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/contests/data/contests_repository.dart';
import 'package:tradeiq_app/features/audit/data/visits_repository.dart';
import 'package:tradeiq_app/features/orders/data/orders_repository.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/reports/data/report_schedules_repository.dart';
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
  Future<OrderItem> createOrder({
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
      expect(find.text('Today'), findsOneWidget);
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

    // The dashboard's KPI grid now loads from GET /dashboard (unstubbed here,
    // so it settles into the error state); the AppBar title is the stable
    // signal that routing landed on the dashboard.
    expect(find.text('Execution overview'), findsOneWidget);
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
    expect(find.text('Execution overview'), findsOneWidget);

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
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Execution overview'), findsNothing);
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
      expect(find.text('Today'), findsOneWidget);
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
      expect(find.text('Today'), findsOneWidget);
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
      expect(find.text('Today'), findsOneWidget);
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

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Report schedules'), findsNothing);
    },
  );

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
      expect(find.text('Today'), findsOneWidget);
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
      expect(find.text('Today'), findsOneWidget);
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

      expect(find.text('Execution overview'), findsOneWidget);
    },
  );

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
        expect(find.text('Today'), findsOneWidget);
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

    testWidgets('a field_agent reaches Contests from the Today app bar, and '
        'back returns to Today', (tester) async {
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

      final action = find.byKey(const ValueKey('today-contests'));
      expect(action, findsOneWidget);
      expect(
        find.descendant(of: action, matching: find.text('1')),
        findsOneWidget,
      );

      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('October Sprint'), findsOneWidget);
      expect(find.text('1 contest running'), findsNothing);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('October Sprint'), findsNothing);
    });

    testWidgets('a manager has no Contests action: /today is not theirs', (
      tester,
    ) async {
      await goAs(tester, 'manager', '/today');

      expect(find.text('Execution overview'), findsOneWidget);
      expect(find.byKey(const ValueKey('today-contests')), findsNothing);
    });

    testWidgets('a manager can open a contest\'s standings', (tester) async {
      await goAs(tester, 'manager', '/contests/c-active');

      expect(find.text('Contest standings'), findsOneWidget);
      expect(find.text('Aisha Patel'), findsOneWidget);
    });
  });
}

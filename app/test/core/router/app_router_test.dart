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
import 'package:tradeiq_app/features/audit/data/visits_repository.dart';
import 'package:tradeiq_app/features/orders/data/orders_repository.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/templates/data/templates_repository.dart';

class _FixedSessionController extends SessionController {
  _FixedSessionController(this._initial);
  final SessionState _initial;

  @override
  Future<SessionState> build() async => _initial;
}

class _FakeOutletsRepository implements OutletsRepository {
  @override
  Future<List<Outlet>> listOutlets({bool mine = false}) async => const [
    Outlet(
      id: 'o1',
      name: 'Test Outlet',
      code: 'TO-001',
      lat: -26.2041,
      lng: 28.0473,
    ),
  ];

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
        (ref, arg) => Stream.value(
          const VisitProgress(states: {}, details: {}),
        ),
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
  testWidgets('unauthenticated root route shows the landing screen', (
    tester,
  ) async {
    await tester.pumpWidget(_appWithOverrides([]));
    await tester.pumpAndSettle();
    expect(find.text('TradeIQ'), findsOneWidget);
    expect(find.text('Field Execution, In Focus'), findsOneWidget);
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
    expect(find.text('Execution overview'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
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
}

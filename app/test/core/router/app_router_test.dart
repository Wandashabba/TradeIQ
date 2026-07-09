import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/router/app_router.dart';
import 'package:tradeiq_app/features/audit/data/visits_repository.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

class _FixedSessionController extends SessionController {
  _FixedSessionController(this._initial);
  final SessionState _initial;

  @override
  Future<SessionState> build() async => _initial;
}

class _FakeOutletsRepository implements OutletsRepository {
  @override
  Future<List<Outlet>> listOutlets() async => const [
        Outlet(id: 'o1', name: 'Test Outlet', code: 'TO-001', lat: -26.2041, lng: 28.0473),
      ];

  @override
  Future<Outlet> createOutlet({
    required String name,
    required String code,
    required String channelType,
    required double lat,
    required double lng,
    required String territoryId,
  }) =>
      throw UnimplementedError();
}

class _FakeSucceedingVisitsRepository implements VisitsRepository {
  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async =>
      CheckInSucceeded('visit-1');

  @override
  Future<void> submitVisit(String visitDraftId) async {}
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

  testWidgets('authenticated field_agent starting at /login lands on the outlet picker', (tester) async {
    await tester.pumpWidget(_appWithOverrides([
      sessionControllerProvider.overrideWith(
        () => _FixedSessionController(const SessionState(role: 'field_agent')),
      ),
      outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Select an Outlet'), findsOneWidget);
  });

  testWidgets('/audit/:outletId renders the audit shell for that outlet', (tester) async {
    await tester.pumpWidget(_appWithOverrides([
      sessionControllerProvider.overrideWith(
        () => _FixedSessionController(const SessionState(role: 'field_agent')),
      ),
      outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
      visitsRepositoryProvider.overrideWithValue(_FakeSucceedingVisitsRepository()),
    ]));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    container.read(routerProvider).go('/audit/o1');
    await tester.pumpAndSettle();

    expect(find.text('Audit Visit'), findsOneWidget);
    expect(find.text('S1 Outlet Information'), findsOneWidget);
  });

  testWidgets('authenticated manager starting at /login lands on /dashboard', (tester) async {
    await tester.pumpWidget(_appWithOverrides([
      sessionControllerProvider.overrideWith(
        () => _FixedSessionController(const SessionState(role: 'manager')),
      ),
    ]));
    await tester.pumpAndSettle();

    // The dashboard's KPI grid now loads from GET /dashboard (unstubbed here,
    // so it settles into the error state); the AppBar title is the stable
    // signal that routing landed on the dashboard.
    expect(find.text('Manager Dashboard'), findsOneWidget);
  });

  testWidgets('logging out from a protected route redirects back to login', (tester) async {
    await tester.pumpWidget(_appWithOverrides([
      sessionControllerProvider.overrideWith(
        () => _FixedSessionController(const SessionState(role: 'manager')),
      ),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Manager Dashboard'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    container.read(sessionControllerProvider.notifier).logout();
    await tester.pumpAndSettle();

    expect(find.text('TradeIQ Login'), findsOneWidget);
  });
}

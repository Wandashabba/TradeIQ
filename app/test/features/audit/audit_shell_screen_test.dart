import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';
import 'package:tradeiq_app/features/audit/data/visits_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/audit_shell_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

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

class _FakeSkusRepository implements SkusRepository {
  @override
  Future<List<Sku>> listSkus() async => const [];
}

class _SucceedingVisitsRepository implements VisitsRepository {
  String? submittedId;

  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async =>
      CheckInSucceeded('visit-1');

  @override
  Future<void> submitVisit(String visitDraftId) async => submittedId = visitDraftId;
}

class _GeofenceFailingVisitsRepository implements VisitsRepository {
  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async =>
      CheckInGeofenceFailed(650);

  @override
  Future<void> submitVisit(String visitDraftId) async {}
}

class _LocationUnavailableVisitsRepository implements VisitsRepository {
  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async =>
      CheckInLocationUnavailable('Location permission denied');

  @override
  Future<void> submitVisit(String visitDraftId) async {}
}

// The S10 scorecard section computes from the local DB on build, so the
// shell tests need a real (in-memory) LocalDb behind the provider.
List<Override> _overrides(VisitsRepository visitsRepository, LocalDb db) => [
      outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
      visitsRepositoryProvider.overrideWithValue(visitsRepository),
      skusRepositoryProvider.overrideWithValue(_FakeSkusRepository()),
      localDbProvider.overrideWithValue(db),
    ];

Widget _appWith(VisitsRepository visitsRepository, LocalDb db) {
  return ProviderScope(
    overrides: _overrides(visitsRepository, db),
    child: const MaterialApp(home: AuditShellScreen(outletId: 'o1')),
  );
}

LocalDb _testDb() {
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

void main() {
  testWidgets('shows a stepper with all 10 audit sections after a successful check-in', (tester) async {
    await tester.pumpWidget(_appWith(_SucceedingVisitsRepository(), _testDb()));
    await tester.pumpAndSettle();

    expect(find.text('S1 Outlet Information'), findsOneWidget);
    expect(find.text('S10 Scorecard'), findsOneWidget);
  });

  testWidgets('shows a blocking error when the check-in fails the geofence', (tester) async {
    await tester.pumpWidget(_appWith(_GeofenceFailingVisitsRepository(), _testDb()));
    await tester.pumpAndSettle();

    expect(find.textContaining('650'), findsOneWidget);
    expect(find.text('S1 Outlet Information'), findsNothing);
  });

  testWidgets('shows a retry action when location is unavailable', (tester) async {
    await tester.pumpWidget(_appWith(_LocationUnavailableVisitsRepository(), _testDb()));
    await tester.pumpAndSettle();

    expect(find.text('Location permission denied'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('tapping logout clears the session', (tester) async {
    await tester.pumpWidget(_appWith(_SucceedingVisitsRepository(), _testDb()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pump();

    final context = tester.element(find.byType(AuditShellScreen));
    final container = ProviderScope.containerOf(context);
    expect(container.read(sessionControllerProvider).value?.role, isNull);
  });

  testWidgets('submitting the visit records the submit and returns to the picker', (tester) async {
    final repo = _SucceedingVisitsRepository();
    final router = GoRouter(
      initialLocation: '/audit/o1',
      routes: [
        GoRoute(path: '/audit', builder: (context, state) => const Text('Outlet Picker')),
        GoRoute(
          path: '/audit/:outletId',
          builder: (context, state) => const AuditShellScreen(outletId: 'o1'),
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(repo, _testDb()),
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Submit visit'));
    await tester.tap(find.text('Submit visit'));
    await tester.pumpAndSettle();

    expect(repo.submittedId, 'visit-1');
    expect(find.text('Outlet Picker'), findsOneWidget);
  });

  testWidgets('the check-in confirmation timestamp stays fixed across step navigation', (tester) async {
    await tester.pumpWidget(_appWith(_SucceedingVisitsRepository(), _testDb()));
    await tester.pumpAndSettle();

    // The Stepper is vertical, so every step's content (and its "Continue"
    // control) exists in the widget tree at once — only the current step's
    // body is visually expanded. All "Continue" buttons share the same
    // onStepContinue callback, so tapping any of them advances _step and
    // triggers the setState-driven rebuild we want to exercise here.
    final firstTimestampFinder = find.textContaining('Checked in at').first;
    final firstText = tester.widget<Text>(firstTimestampFinder).data;

    await tester.tap(find.text('Continue').first);
    await tester.pumpAndSettle();

    // Tap step 1's index number ("1") to jump back via onStepTapped, which
    // also calls setState and rebuilds the stepper (and _sections()).
    await tester.tap(find.text('1').first);
    await tester.pumpAndSettle();

    final secondTimestampFinder = find.textContaining('Checked in at').first;
    final secondText = tester.widget<Text>(secondTimestampFinder).data;

    expect(secondText, firstText);
  });
}

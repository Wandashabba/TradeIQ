import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/features/audit/data/stock_repository.dart';
import 'package:tradeiq_app/features/audit/data/visits_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/audit_shell_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/skus/data/skus_repository.dart';

class _FakeOutletsRepository implements OutletsRepository {
  @override
  Future<List<Outlet>> listOutlets() async => const [
        Outlet(id: 'o1', name: 'Test Outlet', code: 'TO-001', lat: -26.2041, lng: 28.0473),
      ];
}

class _FakeSkusRepository implements SkusRepository {
  @override
  Future<List<Sku>> listSkus() async => const [
        Sku(id: 'sku-1', name: 'Demo Brand 500ml', category: 'Beverages'),
      ];
}

class _NoopStockRepository implements StockRepository {
  @override
  Future<void> recordStock({
    required String visitId,
    required String skuId,
    required int unitsAvailable,
    required DateTime lastStockinDate,
    required int daysOutOfStock,
    required double velocityAvg,
    required double salesActual,
    required double salesTarget,
  }) async {}
}

class _SucceedingVisitsRepository implements VisitsRepository {
  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async =>
      CheckInSucceeded('visit-1');
}

class _GeofenceFailingVisitsRepository implements VisitsRepository {
  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async =>
      CheckInGeofenceFailed(650);
}

class _LocationUnavailableVisitsRepository implements VisitsRepository {
  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async =>
      CheckInLocationUnavailable('Location permission denied');
}

Widget _appWith(VisitsRepository visitsRepository, {LocalDb? db}) {
  return ProviderScope(
    overrides: [
      outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
      visitsRepositoryProvider.overrideWithValue(visitsRepository),
      localDbProvider.overrideWithValue(db ?? LocalDb(NativeDatabase.memory())),
      skusRepositoryProvider.overrideWithValue(_FakeSkusRepository()),
      stockRepositoryProvider.overrideWithValue(_NoopStockRepository()),
    ],
    child: const MaterialApp(home: AuditShellScreen(outletId: 'o1')),
  );
}

void main() {
  testWidgets('shows a stepper with all 10 audit sections after a successful check-in', (tester) async {
    await tester.pumpWidget(_appWith(_SucceedingVisitsRepository()));
    await tester.pumpAndSettle();

    expect(find.text('S1 Outlet Information'), findsOneWidget);
    expect(find.text('S10 Execution Scorecard'), findsOneWidget);
  });

  testWidgets('passes the real visitId from a successful check-in to S2StockScreen', (tester) async {
    // _SucceedingVisitsRepository always returns CheckInSucceeded('visit-1'),
    // so pre-seeding a stock draft under that exact visitId lets us prove
    // S2StockScreen was built with 'visit-1' specifically (not '' or any
    // other placeholder): S2's recorded-SKU query is keyed on the visitId it
    // was constructed with, so the SKU only renders as "recorded" (checkmark)
    // if that query matched 'visit-1' exactly.
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.stockDrafts).insert(StockDraftsCompanion.insert(
          id: 'draft-1',
          visitId: 'visit-1',
          skuId: 'sku-1',
          unitsAvailable: 40,
          lastStockinDate: DateTime(2026, 6, 30),
          daysOutOfStock: 0,
          velocityAvg: 10,
          salesActual: 350,
          salesTarget: 400,
        ));

    await tester.pumpWidget(_appWith(_SucceedingVisitsRepository(), db: db));
    await tester.pumpAndSettle();

    // S2 (step index 1) isn't the current step yet, so the vertical
    // Stepper's AnimatedCrossFade wraps it in a disabled TickerMode —
    // flutter_riverpod deliberately pauses provider-driven rebuilds for
    // paused/invisible consumers, so S2's skusListProvider watch won't
    // apply its loaded data until the step becomes current. Advance to
    // it, exactly like a real user would via "Continue".
    await tester.tap(find.text('Continue').first);
    await tester.pumpAndSettle();

    // S2's SKU list rendering (rather than a stuck spinner) proves
    // S2StockScreen built with a real, non-null visitId — its local Drift
    // query is keyed on visitId and its FutureBuilder-driven load would
    // never resolve into the list view otherwise.
    expect(find.text('Demo Brand 500ml'), findsOneWidget);

    // The checkmark only appears if S2's StockDrafts query, keyed on the
    // visitId it received, matched our seeded 'visit-1' row — a stray ''
    // fallback would find no rows and leave the SKU unrecorded.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('shows a blocking error when the check-in fails the geofence', (tester) async {
    await tester.pumpWidget(_appWith(_GeofenceFailingVisitsRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('650'), findsOneWidget);
    expect(find.text('S1 Outlet Information'), findsNothing);
  });

  testWidgets('shows a retry action when location is unavailable', (tester) async {
    await tester.pumpWidget(_appWith(_LocationUnavailableVisitsRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Location permission denied'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('tapping logout clears the session', (tester) async {
    await tester.pumpWidget(_appWith(_SucceedingVisitsRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pump();

    final context = tester.element(find.byType(AuditShellScreen));
    final container = ProviderScope.containerOf(context);
    expect(container.read(sessionControllerProvider).value?.role, isNull);
  });

  testWidgets('the check-in confirmation timestamp stays fixed across step navigation', (tester) async {
    await tester.pumpWidget(_appWith(_SucceedingVisitsRepository()));
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

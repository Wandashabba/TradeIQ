import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/features/audit/presentation/visit_outlet_picker_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

class FakeOutletsRepository implements OutletsRepository {
  @override
  Future<List<Outlet>> listOutlets() async => const [
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

void main() {
  testWidgets('renders outlets and navigates to the audit shell on Start Visit', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/audit',
      routes: [
        GoRoute(
          path: '/audit',
          builder: (context, state) => const VisitOutletPickerScreen(),
        ),
        GoRoute(
          path: '/audit/:outletId',
          builder: (context, state) =>
              Text('Visit ${state.pathParameters['outletId']}'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          outletsRepositoryProvider.overrideWithValue(FakeOutletsRepository()),
          // Agent screens carry the sync chip, which watches the outbox over a
          // Drift stream. Drift's watch() reschedules a zero-duration timer on
          // every tick, so pumpAndSettle never settles against a real one — a
          // widget test stubs the provider rather than the database.
          syncStatusProvider.overrideWith(
            (ref) => Stream.value(SyncStatus.empty),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Outlet'), findsOneWidget);

    await tester.tap(find.text('Start Visit'));
    await tester.pumpAndSettle();

    expect(find.text('Visit o1'), findsOneWidget);
  });
}

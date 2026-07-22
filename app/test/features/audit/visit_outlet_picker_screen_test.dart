import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/features/audit/presentation/visit_outlet_picker_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

/// Returns a shorter list when narrowed, so a test can tell the two apart —
/// a fake that ignored `mine` would make the scope switch untestable.
class ScopeAwareOutletsRepository implements OutletsRepository {
  final List<bool> calls = [];

  @override
  Future<List<Outlet>> listOutlets({bool mine = false}) async {
    calls.add(mine);
    return mine
        ? const [
            Outlet(id: 'o1', name: 'My Store', code: 'MS-1', lat: -26.1, lng: 28.0),
          ]
        : const [
            Outlet(id: 'o1', name: 'My Store', code: 'MS-1', lat: -26.1, lng: 28.0),
            Outlet(id: 'o2', name: 'Other Store', code: 'OS-1', lat: -26.2, lng: 28.1),
          ];
  }

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

class FakeOutletsRepository implements OutletsRepository {
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

  testWidgets('defaults to the agent\'s own territories', (tester) async {
    final repo = ScopeAwareOutletsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          outletsRepositoryProvider.overrideWithValue(repo),
          syncStatusProvider.overrideWith((ref) => Stream.value(SyncStatus.empty)),
        ],
        child: const MaterialApp(home: VisitOutletPickerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // A shorter list of the right shops is the point of having territories.
    expect(repo.calls.first, isTrue);
    expect(find.text('My Store'), findsOneWidget);
    expect(find.text('Other Store'), findsNothing);
    // And it must SAY it is filtered — a narrowed list that looks complete is
    // how somebody concludes a store is missing from the system.
    expect(find.text('My territories'), findsOneWidget);
  });

  testWidgets('the agent can always reach every store', (tester) async {
    // The reason this is a filter and not a permission. Territory data is
    // imperfect and field work is not: an agent covering a colleague's patch,
    // or at a shop filed under the wrong territory, must be able to check in
    // without finding an administrator first.
    final repo = ScopeAwareOutletsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          outletsRepositoryProvider.overrideWithValue(repo),
          syncStatusProvider.overrideWith((ref) => Stream.value(SyncStatus.empty)),
        ],
        child: const MaterialApp(home: VisitOutletPickerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('only-my-territories')));
    await tester.pumpAndSettle();

    expect(repo.calls.last, isFalse);
    expect(find.text('Other Store'), findsOneWidget);
    expect(find.text('All stores'), findsOneWidget);
  });
}

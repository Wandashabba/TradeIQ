import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/outlets/presentation/outlets_list_screen.dart';

import '../../helpers/routed_app.dart';

class FakeOutletsRepository implements OutletsRepository {
  @override
  Future<List<Outlet>> listOutlets({bool mine = false}) async => const [
        Outlet(
          id: 'o1',
          name: 'Test Hypermarket',
          code: 'TH-001',
          lat: -26.2041,
          lng: 28.0473,
        ),
        // An outlet at 0,0 has no usable coordinates — it cannot be geofenced,
        // so a visit to it cannot be verified. The list has to say so.
        Outlet(id: 'o2', name: 'Unplaced Spaza', code: 'US-002', lat: 0, lng: 0),
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

/// OutletsListScreen now uses ManagerScaffold, which reads GoRouterState — a
/// bare MaterialApp(home:) throws, so it must be pumped under a real route.
Widget _app() => routedApp(
      const OutletsListScreen(),
      overrides: [
        outletsRepositoryProvider.overrideWithValue(FakeOutletsRepository()),
      ],
    );

void main() {
  testWidgets('renders outlet names once loaded', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Test Hypermarket'), findsOneWidget);
  });

  testWidgets('wears the console shell, so the nav rail is reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Previously this screen was a bare Scaffold — a manager who landed here
    // lost navigation entirely.
    expect(find.byKey(const ValueKey('nav-/dashboard')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-/alerts')), findsOneWidget);
  });

  testWidgets('flags an outlet that cannot be geofenced', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Unplaced Spaza'), findsOneWidget);
    expect(find.byKey(const ValueKey('outlet-o2')), findsOneWidget);
  });
}

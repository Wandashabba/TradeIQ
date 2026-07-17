import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/features/territories/presentation/territory_map_screen.dart';

import '../../helpers/routed_app.dart';

const _territory = Territory(id: 'ter-1', name: 'Gauteng North', code: 'GP-N');

const _visited = Outlet(
  id: 'o1',
  name: 'Sandton Spar',
  code: 'OUT-1',
  lat: -26.10,
  lng: 28.05,
  visited: true,
);
const _unvisited = Outlet(
  id: 'o2',
  name: 'Rosebank Pick n Pay',
  code: 'OUT-2',
  lat: -26.14,
  lng: 28.04,
  visited: false,
);

class _FakeTerritoriesRepository implements TerritoriesRepository {
  const _FakeTerritoriesRepository(this.coverage);
  final TerritoryCoverage coverage;

  @override
  Future<List<Territory>> listTerritories() async => const [_territory];

  @override
  Future<TerritoryCoverage> getCoverage(String id) async => coverage;

  @override
  Future<Territory> createTerritory({
    required String name,
    required String code,
    String? region,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> assignAgent(String territoryId, String userId) async =>
      throw UnimplementedError();
}

Widget _app(TerritoryCoverage coverage) => routedApp(
      const TerritoryMapScreen(territory: _territory),
      overrides: [
        territoriesRepositoryProvider
            .overrideWithValue(_FakeTerritoriesRepository(coverage)),
      ],
    );

void main() {
  testWidgets('renders a green pin for visited and red for unvisited outlets',
      (tester) async {
    const coverage = TerritoryCoverage(
      outletCount: 2,
      agentCount: 0,
      outlets: [_visited, _unvisited],
      outletsVisited: 1,
      outletsTotal: 2,
      coverageRate: 50,
    );
    await tester.pumpWidget(_app(coverage));
    await tester.pump();
    await tester.pump();

    final visitedPin = tester.widget<Icon>(
      find.byKey(const ValueKey<String>('outlet-pin-icon-o1')),
    );
    final unvisitedPin = tester.widget<Icon>(
      find.byKey(const ValueKey<String>('outlet-pin-icon-o2')),
    );
    expect(visitedPin.color, Colors.green);
    expect(unvisitedPin.color, Colors.red);
  });

  testWidgets('tapping a pin shows the outlet info sheet', (tester) async {
    const coverage = TerritoryCoverage(
      outletCount: 1,
      agentCount: 0,
      outlets: [_visited],
      outletsVisited: 1,
      outletsTotal: 1,
      coverageRate: 100,
    );
    await tester.pumpWidget(_app(coverage));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('outlet-pin-icon-o1')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sandton Spar'), findsOneWidget);
    expect(find.text('Visited'), findsOneWidget);
  });

  testWidgets('shows an empty state when the territory has no outlets',
      (tester) async {
    const coverage = TerritoryCoverage(outletCount: 0, agentCount: 0);
    await tester.pumpWidget(_app(coverage));
    await tester.pump();
    await tester.pump();

    expect(find.text('No outlets in this territory yet.'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });
}

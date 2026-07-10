import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/features/territories/presentation/territories_screen.dart';

const _north = Territory(
  id: 'ter-1',
  name: 'Gauteng North',
  code: 'GP-N',
  region: 'Gauteng',
);

const _south = Territory(
  id: 'ter-2',
  name: 'Western Cape',
  code: 'WC',
);

class _FakeTerritoriesRepository implements TerritoriesRepository {
  @override
  Future<List<Territory>> listTerritories() async => const [_north, _south];

  @override
  Future<TerritoryCoverage> getCoverage(String id) async =>
      const TerritoryCoverage(outletCount: 3, agentCount: 2);
}

class _FailingTerritoriesRepository implements TerritoriesRepository {
  @override
  Future<List<Territory>> listTerritories() async =>
      throw Exception('boom');

  @override
  Future<TerritoryCoverage> getCoverage(String id) async =>
      throw Exception('boom');
}

Widget _app(TerritoriesRepository repo) => ProviderScope(
      overrides: [
        territoriesRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: TerritoriesScreen()),
    );

void main() {
  testWidgets('renders territory names once loaded', (tester) async {
    await tester.pumpWidget(_app(_FakeTerritoriesRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Gauteng North'), findsOneWidget);
    expect(find.text('Western Cape'), findsOneWidget);
  });

  testWidgets('shows an error state when loading fails', (tester) async {
    await tester.pumpWidget(_app(_FailingTerritoriesRepository()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Failed to load territories'),
      findsOneWidget,
    );
  });
}

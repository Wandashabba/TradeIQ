import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/features/territories/presentation/territory_form_screen.dart';

class _RecordingTerritoriesRepository implements TerritoriesRepository {
  Map<String, dynamic>? createdArgs;

  @override
  Future<List<Territory>> listTerritories() async => const [];

  @override
  Future<TerritoryCoverage> getCoverage(String id) async =>
      throw UnimplementedError();

  @override
  Future<Territory> createTerritory({
    required String name,
    required String code,
    String? region,
  }) async {
    createdArgs = {'name': name, 'code': code, 'region': region};
    return Territory(id: 't1', name: name, code: code, region: region);
  }

  @override
  Future<void> assignAgent(String territoryId, String userId) async =>
      throw UnimplementedError();
}

Widget _app(_RecordingTerritoriesRepository repo) => ProviderScope(
      overrides: [
        territoriesRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: TerritoryFormScreen()),
    );

void main() {
  testWidgets('submits name, code and region', (tester) async {
    final repo = _RecordingTerritoriesRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey<String>('territory-name-field')), 'KZN Coast');
    await tester.enterText(
        find.byKey(const ValueKey<String>('territory-code-field')), 'KZN-C');

    await tester.tap(find.byKey(const ValueKey<String>('territory-save-button')));
    await tester.pumpAndSettle();

    expect(repo.createdArgs, isNotNull);
    expect(repo.createdArgs!['name'], 'KZN Coast');
    expect(repo.createdArgs!['code'], 'KZN-C');
  });

  testWidgets('blocks submit when name or code is empty', (tester) async {
    final repo = _RecordingTerritoriesRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('territory-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsWidgets);
    expect(repo.createdArgs, isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';

void main() {
  test('Territory.fromJson parses all fields including region', () {
    final territory = Territory.fromJson(const {
      'id': 't1',
      'name': 'Gauteng North',
      'code': 'GP-N',
      'region': 'Gauteng',
    });

    expect(territory.id, 't1');
    expect(territory.name, 'Gauteng North');
    expect(territory.code, 'GP-N');
    expect(territory.region, 'Gauteng');
  });

  test('Territory.fromJson allows a null region', () {
    final territory = Territory.fromJson(const {
      'id': 't2',
      'name': 'Western Cape',
      'code': 'WC',
    });

    expect(territory.region, isNull);
  });

  test('TerritoryCoverage.fromJson counts outlets and agents from list lengths',
      () {
    final coverage = TerritoryCoverage.fromJson(const {
      'territory': {'id': 't1'},
      'outlets': [
        {'id': 'o1'},
        {'id': 'o2'},
        {'id': 'o3'},
      ],
      'agents': [
        {'id': 'a1'},
        {'id': 'a2'},
      ],
    });

    expect(coverage.outletCount, 3);
    expect(coverage.agentCount, 2);
  });

  test('TerritoryCoverage.fromJson defaults missing lists to zero', () {
    final coverage = TerritoryCoverage.fromJson(const {
      'territory': {'id': 't1'},
    });

    expect(coverage.outletCount, 0);
    expect(coverage.agentCount, 0);
  });
}

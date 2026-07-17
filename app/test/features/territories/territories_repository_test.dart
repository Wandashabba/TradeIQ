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

  test(
      'TerritoryCoverage.fromJson counts outlets and agents, and parses each outlet',
      () {
    final coverage = TerritoryCoverage.fromJson(const {
      'territory': {'id': 't1'},
      'outlets': [
        {'id': 'o1', 'name': 'Outlet One', 'code': 'OUT-1', 'lat': -26.1, 'lng': 28.0, 'visited': true},
        {'id': 'o2', 'name': 'Outlet Two', 'code': 'OUT-2', 'lat': -26.2, 'lng': 28.1, 'visited': false},
        {'id': 'o3', 'name': 'Outlet Three', 'code': 'OUT-3', 'lat': -26.3, 'lng': 28.2, 'visited': false},
      ],
      'agents': [
        {'id': 'a1'},
        {'id': 'a2'},
      ],
      'coverage': {'outletsVisited': 1, 'outletsTotal': 3, 'coverageRate': 33.33},
    });

    expect(coverage.outletCount, 3);
    expect(coverage.agentCount, 2);
    expect(coverage.outlets.length, 3);
    expect(coverage.outlets.first.visited, true);
    expect(coverage.outlets[1].visited, false);
    expect(coverage.outletsVisited, 1);
    expect(coverage.outletsTotal, 3);
    expect(coverage.coverageRate, 33.33);
  });

  test('TerritoryCoverage.fromJson defaults missing lists and coverage to zero',
      () {
    final coverage = TerritoryCoverage.fromJson(const {
      'territory': {'id': 't1'},
    });

    expect(coverage.outletCount, 0);
    expect(coverage.agentCount, 0);
    expect(coverage.outlets, isEmpty);
    expect(coverage.outletsVisited, 0);
    expect(coverage.outletsTotal, 0);
    expect(coverage.coverageRate, 0);
  });
}

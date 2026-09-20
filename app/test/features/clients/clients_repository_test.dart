import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/clients/data/clients_repository.dart';

void main() {
  test('ClientConfig.fromJson parses weights and thresholds maps to doubles',
      () {
    final config = ClientConfig.fromJson(const {
      'id': 'c1',
      'name': 'Acme Beverages',
      'industry': 'fmcg',
      'scorecardWeights': {
        'availability': 0.3,
        'visibility': 0.2,
        'display': 1,
        'pricing': 0.15,
        'competitive': 0.1,
        'salesCapability': 0.05,
      },
      'kpiThresholds': {
        'green': 80,
        'amber': 60.5,
      },
    });

    expect(config.name, 'Acme Beverages');
    expect(config.scorecardWeights['availability'], 0.3);
    expect(config.scorecardWeights['display'], 1.0);
    expect(config.scorecardWeights['display'], isA<double>());
    expect(config.kpiThresholds['green'], 80.0);
    expect(config.kpiThresholds['amber'], 60.5);
    expect(config.kpiThresholds['green'], isA<double>());
  });

  test('ClientConfig.fromJson defaults missing maps to empty', () {
    final config = ClientConfig.fromJson(const {
      'id': 'c2',
      'name': 'Empty Co',
    });

    expect(config.scorecardWeights, isEmpty);
    expect(config.kpiThresholds, isEmpty);
  });

  test('ClientConfig.fromJson reads the client timezone (#309)', () {
    final config = ClientConfig.fromJson(const {
      'id': 'c3',
      'name': 'NY Co',
      'timezone': 'America/New_York',
    });

    expect(config.timezone, 'America/New_York');
  });

  test('ClientConfig.fromJson assumes Johannesburg from a server that sends no '
      'timezone', () {
    final config = ClientConfig.fromJson(const {'id': 'c4', 'name': 'Old Co'});

    expect(config.timezone, 'Africa/Johannesburg');
    expect(config.timezone, defaultClientTimeZone);
  });
}

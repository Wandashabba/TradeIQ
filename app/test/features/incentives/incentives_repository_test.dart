import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/incentives/data/incentives_repository.dart';

void main() {
  test('IncentiveScheme.fromJson parses all fields', () {
    final scheme = IncentiveScheme.fromJson(const {
      'id': 's1',
      'name': 'Top Scorecard',
      'metric': 'scorecard',
      'threshold': 80,
      'rewardPoints': 100,
      'rewardDetail': 'Voucher',
      'active': true,
    });

    expect(scheme.id, 's1');
    expect(scheme.name, 'Top Scorecard');
    expect(scheme.metric, 'scorecard');
    expect(scheme.threshold, 80.0);
    expect(scheme.rewardPoints, 100);
    expect(scheme.active, isTrue);
  });

  test('IncentiveScheme.fromJson defaults active to false when missing', () {
    final scheme = IncentiveScheme.fromJson(const {
      'id': 's2',
      'name': 'Visits Drive',
      'metric': 'visits',
      'threshold': 20.5,
      'rewardPoints': 50,
    });

    expect(scheme.threshold, 20.5);
    expect(scheme.active, isFalse);
  });

  test('EarnedIncentive.fromJson parses all fields', () {
    final earned = EarnedIncentive.fromJson(const {
      'schemeId': 's1',
      'schemeName': 'Top Scorecard',
      'metric': 'scorecard',
      'agentId': 'a1',
      'email': 'agent@example.com',
      'metricValue': 90,
      'rewardPoints': 100,
    });

    expect(earned.schemeName, 'Top Scorecard');
    expect(earned.email, 'agent@example.com');
    expect(earned.rewardPoints, 100);
  });
}

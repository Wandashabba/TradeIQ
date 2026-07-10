import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/fraud/data/fraud_repository.dart';

void main() {
  test('FlaggedVisit.fromJson parses fields and nested signals', () {
    final visit = FlaggedVisit.fromJson({
      'visitId': 'v-12345678',
      'outletId': 'o1',
      'agentId': 'a1',
      'riskScore': 82,
      'signals': [
        {'code': 'gps_mismatch', 'detail': '500m from outlet', 'weight': 40},
        {'code': 'fast_visit', 'detail': 'Under 2 minutes', 'weight': 42},
      ],
    });

    expect(visit.visitId, 'v-12345678');
    expect(visit.outletId, 'o1');
    expect(visit.agentId, 'a1');
    expect(visit.riskScore, 82.0);
    expect(visit.signals, hasLength(2));
    expect(visit.signals.first.code, 'gps_mismatch');
    expect(visit.signals.first.detail, '500m from outlet');
    expect(visit.signals.last.code, 'fast_visit');
  });

  test('FlaggedVisit.fromJson defaults signals to empty when absent', () {
    final visit = FlaggedVisit.fromJson({
      'visitId': 'v2',
      'outletId': 'o2',
      'agentId': 'a2',
      'riskScore': 30,
    });

    expect(visit.signals, isEmpty);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';

void main() {
  test('AlertItem.fromJson parses a full payload', () {
    final alert = AlertItem.fromJson(const {
      'id': 'a1',
      'metric': 'stock',
      'message': 'SKU 42 out of stock',
      'severity': 'critical',
      'acknowledged': true,
      'visitId': 'v1',
      'outletId': 'o1',
    });

    expect(alert.id, 'a1');
    expect(alert.metric, 'stock');
    expect(alert.message, 'SKU 42 out of stock');
    expect(alert.severity, 'critical');
    expect(alert.acknowledged, true);
    expect(alert.visitId, 'v1');
    expect(alert.outletId, 'o1');
  });

  test('AlertItem.fromJson defaults acknowledged to false when missing', () {
    final alert = AlertItem.fromJson(const {
      'id': 'a2',
      'metric': 'price',
      'message': 'Shelf price mismatch',
      'severity': 'warning',
    });

    expect(alert.acknowledged, false);
    expect(alert.visitId, isNull);
    expect(alert.outletId, isNull);
  });
}

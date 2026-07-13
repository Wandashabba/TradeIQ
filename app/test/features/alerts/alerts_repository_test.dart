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

  test('AlertRule.fromJson parses a full payload', () {
    final rule = AlertRule.fromJson(const {
      'id': 'r1',
      'clientId': 'c1',
      'name': 'Price deviation',
      'metric': 'price_deviation',
      'threshold': 12.5,
      'severity': 'critical',
      'active': false,
      'createdAt': '2026-07-13T00:00:00.000Z',
    });

    expect(rule.id, 'r1');
    expect(rule.name, 'Price deviation');
    expect(rule.metric, 'price_deviation');
    expect(rule.threshold, 12.5);
    expect(rule.severity, 'critical');
    expect(rule.active, false);
  });

  test('AlertRule.fromJson keeps a null threshold null', () {
    // The backend applies its own default when a rule has no threshold, so null
    // must not collapse to 0 — that would be a rule that fires on everything.
    final rule = AlertRule.fromJson(const {
      'id': 'r2',
      'name': 'Out of stock',
      'metric': 'out_of_stock',
      'threshold': null,
      'severity': 'normal',
      'active': true,
    });

    expect(rule.threshold, isNull);
  });

  test('AlertRule.fromJson widens an integer threshold to double', () {
    // JSON has one number type; Prisma Float columns serialise 60.0 as 60.
    final rule = AlertRule.fromJson(const {
      'id': 'r3',
      'name': 'Low scorecard',
      'metric': 'low_scorecard',
      'threshold': 60,
      'severity': 'warning',
      'active': true,
    });

    expect(rule.threshold, 60.0);
  });

  test('AlertRule.fromJson falls back to the column defaults', () {
    final rule = AlertRule.fromJson(const {
      'id': 'r4',
      'name': 'Bare rule',
      'metric': 'out_of_stock',
    });

    expect(rule.severity, 'normal');
    expect(rule.active, true);
    expect(rule.threshold, isNull);
  });

  test('alertRuleMetrics mirrors the backend allow-list exactly', () {
    // POST /alerts/rules 400s on anything outside this set (ALERT_METRICS in
    // alerts.service.ts), so the UI must never offer a metric that is not here.
    expect(alertRuleMetrics, ['out_of_stock', 'price_deviation', 'low_scorecard']);
  });
}

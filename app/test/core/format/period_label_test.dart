import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/format/period_label.dart';

void main() {
  group('formatPeriodLabel', () {
    test('full ISO with time and millis renders as a short date', () {
      expect(formatPeriodLabel('2026-07-06T00:00:00.000Z'), '6 Jul');
    });

    test('full ISO with time renders as a short date', () {
      expect(formatPeriodLabel('2026-07-06T12:34:56Z'), '6 Jul');
    });

    test('bare ISO date renders as a short date', () {
      expect(formatPeriodLabel('2026-07-06'), '6 Jul');
    });

    test('ISO week keeps just the week token', () {
      expect(formatPeriodLabel('2026-W26'), 'W26');
    });

    test('a non-date label passes through unchanged', () {
      expect(formatPeriodLabel('All'), 'All');
    });

    test('an empty string passes through unchanged', () {
      expect(formatPeriodLabel(''), '');
    });
  });
}

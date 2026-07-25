import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/format/period_label.dart';

void main() {
  group('shortPeriodLabel', () {
    test('week period drops the year', () {
      expect(shortPeriodLabel('2026-W26'), 'W26');
    });

    test('date-only period becomes MM-DD', () {
      expect(shortPeriodLabel('2026-07-06'), '07-06');
    });

    test('full ISO datetime strips time and year', () {
      expect(shortPeriodLabel('2026-07-06T00:00:00.000Z'), '07-06');
    });

    test('unrecognised string passes through unchanged', () {
      expect(shortPeriodLabel('Q3 2026'), 'Q3 2026');
    });
  });
}

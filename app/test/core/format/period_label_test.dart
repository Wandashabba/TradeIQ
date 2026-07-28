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

    // The headline guarantee: a regex-valid but impossible date must render
    // as-is — neither thrown nor silently mangled into some other day. Dart's
    // DateTime normalises overflow (month 13 → next Jan, day 30 of Feb → Mar),
    // so this pins the round-trip check that rejects such values.
    test('an out-of-range month passes through unchanged', () {
      expect(formatPeriodLabel('2026-13-45'), '2026-13-45');
    });

    test('an out-of-range day passes through unchanged', () {
      expect(formatPeriodLabel('2026-02-30'), '2026-02-30');
    });
  });
}

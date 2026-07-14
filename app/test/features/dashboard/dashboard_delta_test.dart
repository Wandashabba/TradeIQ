import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';

void main() {
  final now = DateTime(2026, 7, 14, 9);

  group('DashboardRange', () {
    test('a 30-day window compares against the 30 days immediately before', () {
      const range = DashboardRange.last30;

      final (from, to) = range.window(now);
      expect(from, DateTime(2026, 6, 14, 9));
      expect(to, now);

      final previous = range.previousWindow(now)!;
      // Equal length, immediately prior — so "up 0.8" means something.
      expect(previous.$2, from);
      expect(previous.$2.difference(previous.$1), to.difference(from!));
    });

    test('YTD compares against the equally-long stretch before the year began', () {
      final previous = DashboardRange.ytd.previousWindow(now)!;
      final (from, to) = DashboardRange.ytd.window(now);

      expect(from, DateTime(2026));
      expect(previous.$2, from);
      expect(previous.$2.difference(previous.$1), to.difference(from!));
    });

    test('all-time has NO previous window — and we will not invent one', () {
      // There is no "before all time". A delta here would be a fabrication, so
      // the range refuses to produce one and the tiles show no arrow.
      expect(DashboardRange.allTime.previousWindow(now), isNull);
      expect(DashboardRange.allTime.window(now).$1, isNull);
    });
  });

  group('KpiDelta', () {
    test('change is in percentage POINTS, not a percentage of a percentage', () {
      const d = KpiDelta(current: 92.1, previous: 91.3);

      // 91.3% became 92.1%: that is +0.8 points. Reporting it as a ~0.9% change
      // would be a different — and wrong — number.
      expect(d.change, closeTo(0.8, 0.001));
      expect(d.hasDelta, isTrue);
    });

    test('a fall is negative, so the arrow points down', () {
      const d = KpiDelta(current: 61.4, previous: 62.6);

      expect(d.change, closeTo(-1.2, 0.001));
      expect(d.hasDelta, isTrue);
    });

    test('no previous window means no delta at all', () {
      const d = KpiDelta(current: 92.1);

      expect(d.change, isNull);
      expect(d.hasDelta, isFalse);
    });

    test('a change too small to matter is not dressed up as movement', () {
      // A 0.01-point wobble is noise. Showing a green arrow for it would be
      // telling a manager something happened when nothing did.
      const d = KpiDelta(current: 92.10, previous: 92.09);

      expect(d.hasDelta, isFalse);
    });
  });
}

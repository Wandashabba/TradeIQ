import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';

void main() {
  final now = DateTime(2026, 7, 14, 9);

  group('DashboardRange — like for like, complete days (#365)', () {
    test(
      'a 30-day window is the last 30 complete days, against the 30 before',
      () {
        const range = DashboardRange.last30;

        final (from, to) = range.window(now);
        // Today (14 Jul, still in progress) is out: it ends at local midnight.
        expect(from, DateTime(2026, 6, 14));
        expect(to, DateTime(2026, 7, 14));

        final previous = range.previousWindow(now)!;
        expect(previous.$1, DateTime(2026, 5, 15));
        expect(previous.$2, from);
      },
    );

    test('YTD compares the same calendar days of last year', () {
      final (from, to) = DashboardRange.ytd.window(now);
      expect(from, DateTime(2026));
      expect(to, DateTime(2026, 7, 14));

      // Not the stretch before 1 January — that would set summer against
      // last year's December.
      final previous = DashboardRange.ytd.previousWindow(now)!;
      expect(previous.$1, DateTime(2025));
      expect(previous.$2, DateTime(2025, 7, 14));
    });

    test('YTD on a leap day meets all of last January and February', () {
      final leap = DateTime(2028, 2, 29, 12);
      expect(DashboardRange.ytd.window(leap).$2, DateTime(2028, 2, 29));
      // 29 Feb 2027 does not exist; like the server, it rolls to 1 Mar.
      expect(DashboardRange.ytd.previousWindow(leap)!.$2, DateTime(2027, 3, 1));
    });

    test('on 1 January YTD shows today so far, with no arrow', () {
      // No complete days yet: an empty window would be a fake −100%.
      final newYear = DateTime(2027, 1, 1, 10);
      expect(DashboardRange.ytd.window(newYear), (DateTime(2027), newYear));
      expect(DashboardRange.ytd.previousWindow(newYear), isNull);
    });

    test('all-time has NO previous window — and we will not invent one', () {
      // There is no "before all time". A delta here would be a fabrication, so
      // the range refuses to produce one and the tiles show no arrow.
      expect(DashboardRange.allTime.previousWindow(now), isNull);
      expect(DashboardRange.allTime.window(now), (null, now));
    });

    test(
      'query bounds go out in UTC, with the inclusive end a millisecond early',
      () {
        final midnight = DateTime(2026, 7, 14);
        expect(
          dashboardQueryFrom(midnight),
          midnight.toUtc().toIso8601String(),
        );
        expect(dashboardQueryFrom(midnight), endsWith('Z'));
        expect(
          DateTime.parse(dashboardQueryTo(midnight)).isAtSameMomentAs(
            midnight.subtract(const Duration(milliseconds: 1)),
          ),
          isTrue,
        );
      },
    );
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

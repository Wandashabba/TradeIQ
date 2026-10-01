import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/dashboard/data/floor_repository.dart';

/// AN AGE RENDERS IN THE LARGEST UNIT THAT KEEPS IT LEGIBLE.
///
/// The defect this file exists for was on the owner's own screenshot: the
/// briefing's worst-outlet line printed `17 207h` and the decision row eleven
/// lines under it printed `17 206,8h`. Both are the same measurement, both are
/// arithmetically correct, and it is 717 days — which is not a thing anybody
/// reads off a screen.
///
/// Two things were wrong and only one of them was the unit. The other was that
/// there were **two** of them: each site typed its own `TiqUnit.worded('h')`,
/// so "the column means one thing on every row" was being enforced by two
/// copies of a literal. [FloorAge] is the one place that choice is made now,
/// and these are its boundaries.
///
/// The rounding order is the half of this that is easy to get wrong and
/// impossible to see: pick the unit off the raw value and round for display,
/// and 47,6 hours prints `48h` — the one hour-reading the ladder says may not
/// exist, sitting one second away from `2d`. So the rounded figure is what
/// decides, and the sequence below walks straight through that seam.
void main() {
  /// [hours] before a fixed clock, as the screen would print it.
  String at(double hours) {
    final now = DateTime.utc(2026, 10, 1, 12);
    final age = FloorAge.since(
      now.subtract(Duration(minutes: (hours * 60).round())),
      now,
    );
    return age == null ? '—' : '${age.value}${age.suffix}';
  }

  group('hours, up to two days', () {
    test('an hour is an hour', () {
      expect(at(1), '1h');
      expect(at(6), '6h');
      expect(at(23), '23h');
      expect(at(47), '47h');
    });

    test('the last hour reading is 47h, never 48h', () {
      // 47,4 rounds to 47 and stays an hour reading. 47,6 rounds to 48, and
      // 48 is the boundary — so it steps to days in the same breath rather
      // than printing the one figure this ladder forbids.
      expect(at(47.4), '47h');
      expect(at(47.6), '2d');
      expect(at(48), '2d');
      expect(FloorAge.hoursUntilDays, 48);
    });
  });

  group('days, up to a fortnight', () {
    test('the mockup’s own figure', () {
      // `6d`, which the mockup draws and the screen used to print as `144h`.
      expect(at(24 * 6), '6d');
    });

    test('a day is a day until the fortnight', () {
      expect(at(24 * 3), '3d');
      expect(at(24 * 13), '13d');
      expect(FloorAge.daysUntilWeeks, 14);
    });

    test('the last day reading is 13d, never 14d', () {
      // Same seam, one rung up: 13d23h rounds to 14 days, and 14 days is the
      // boundary, so it is two weeks rather than a fortnight printed in days.
      expect(at(24 * 13 + 11), '13d');
      expect(at(24 * 13 + 23), '2w');
      expect(at(24 * 14), '2w');
    });
  });

  group('weeks, for everything older', () {
    test('the owner’s 17 207 hours is 102 weeks', () {
      expect(at(17206.8), '102w');
    });

    test('and a year is not printed in days either', () {
      expect(at(24 * 365), '52w');
    });
  });

  group('the readings are monotone across both seams', () {
    test('an older finding never prints a smaller span', () {
      // THE PROPERTY THE BOUNDARIES ARE INSTANCES OF. A ladder that steps on
      // the raw value and rounds afterwards passes every boundary test above
      // and still goes backwards somewhere in between — `48h` is "later" than
      // `2d` to a reader comparing two rows.
      Duration spanOf(String printed) {
        final value = int.parse(printed.substring(0, printed.length - 1));
        return switch (printed[printed.length - 1]) {
          'h' => Duration(hours: value),
          'd' => Duration(days: value),
          _ => Duration(days: value * 7),
        };
      }

      var previous = Duration.zero;
      for (var hours = 1; hours <= 24 * 400; hours += 1) {
        final span = spanOf(at(hours.toDouble()));
        expect(
          span,
          greaterThanOrEqualTo(previous),
          reason:
              '${hours}h printed ${at(hours.toDouble())}, which reads as less '
              'than the reading one hour younger',
        );
        previous = span;
      }
    });
  });

  group('an absence is not a zero', () {
    test('nothing timestamped is null, not 0h', () {
      expect(FloorAge.since(null, DateTime.utc(2026, 10, 1)), isNull);
    });
  });

  group('the spoken unit is the printed one, as a word', () {
    test('a screen reader and the screen name the same span', () {
      final now = DateTime.utc(2026, 10, 1, 12);
      FloorAge spoken(double hours) => FloorAge.since(
        now.subtract(Duration(minutes: (hours * 60).round())),
        now,
      )!;

      expect(spoken(1).spoken, 'Open for 1 hour');
      expect(spoken(6).spoken, 'Open for 6 hours');
      expect(spoken(24 * 6).spoken, 'Open for 6 days');
      expect(spoken(24 * 7).spoken, 'Open for 7 days');
      expect(spoken(24 * 14).spoken, 'Open for 2 weeks');
      expect(spoken(17206.8).spoken, 'Open for 102 weeks');
    });
  });
}

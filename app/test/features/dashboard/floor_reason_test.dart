import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/dashboard/data/floor_repository.dart';

/// THE REASON GETS ONE LINE, AND THE COMMON CASES FIT IT.
///
/// The owner read `Planogram compliance under 50…` off the running screen. The
/// arithmetic is not arguable: after the card's gutter, its padding, the
/// severity lane, the gap and the age figure, a 390dp phone leaves about 230dp
/// of Onest 14 — some 34 characters — and the server's messages run to 55. A
/// 379dp sentence does not fit a 390dp phone by any arrangement of the row, so
/// the sentence is what gives.
///
/// What gives is the **trailing qualifier**, at a clause boundary, never inside
/// a word. That is strictly more than a mid-word ellipsis leaves: the reader
/// gets a whole clause instead of a fragment, and cannot mistake "under 50…"
/// for a number that might have been 500.
void main() {
  String reason(String message, [String outlet = '']) =>
      FloorDecision.reasonWithout(message, outlet);

  group('the reason loses what the row already says', () {
    test('the outlet name, which is the title one line above', () {
      expect(
        reason(
          'Kalahari Cola 2L out of stock at SaveMor Glenwood (6 days)',
          'SaveMor Glenwood',
        ),
        'Kalahari Cola 2L out of stock',
      );
    });

    test('the age, which is the trailing figure', () {
      expect(
        reason('Shelf talker missing (14 hours)'),
        'Shelf talker missing',
      );
    });

    test('a parenthetical that is not a duration stays', () {
      expect(
        reason('Facings halved (SKU 4412)'),
        'Facings halved (SKU 4412)',
      );
    });
  });

  group('the common cases fit the line', () {
    test('a locative qualifier goes, at the clause boundary', () {
      expect(
        reason('Planogram compliance under 50 percent on the main aisle'),
        'Planogram compliance under 50%',
      );
    });

    test('a recurrence qualifier goes', () {
      expect(
        reason('Price above the published band for the third week running'),
        'Price above the published band',
      );
    });

    test('the server’s own longest message fits', () {
      // `alerts.service.ts` writes exactly this.
      expect(
        reason('SKU 4412 price deviates 18% (threshold 10%)').length,
        lessThanOrEqualTo(FloorDecision.reasonBudget),
      );
    });

    test('the fixture set the owner looked at fits', () {
      const messages = <String>[
        'Planogram compliance under 50 percent on the main aisle',
        'Price above the published band for the third week running',
        'Competitor facings doubled since the last visit',
        'Shelf talker missing on the promotional end cap',
      ];
      for (final m in messages) {
        final out = reason(m);
        expect(
          out.length,
          lessThanOrEqualTo(FloorDecision.reasonBudget),
          reason: '"$m" trimmed to "$out"',
        );
      }
    });

    test('a message with no clause to cut keeps all of it', () {
      // `Scorecard 71.4 is below threshold 80` is 36 characters and every
      // joiner in it sits inside the finding: cutting at "below" leaves
      // "Scorecard 71.4 is". Two characters over the budget and whole beats
      // on the budget and meaningless — the rule shortens the common cases
      // and says so, it does not promise to shorten every case.
      expect(
        reason('Scorecard 71.4 is below threshold 80'),
        'Scorecard 71.4 is below threshold 80',
      );
    });
  });

  group('and it never leaves something that is not a finding', () {
    test('a short message is untouched', () {
      expect(reason('SKU 4412 is out of stock'), 'SKU 4412 is out of stock');
    });

    test('one long clause keeps all of it rather than losing its verb', () {
      // No joiner sits past the head floor, so there is nothing to cut and
      // the row ellipsises as it always did. This shortens the common cases;
      // it does not promise to shorten every case.
      const wall = 'Refrigeration unit temperature excursion unacknowledged';
      expect(reason(wall), wall);
    });

    test('a head under the floor is not a cut worth making', () {
      // "Price above" is not a reason. The joiner is at index 11.
      expect(
        reason('Price above the band and the shelf is empty as well'),
        isNot('Price above'),
      );
    });

    test('an empty result falls back to the message it was given', () {
      expect(reason('Kasi Corner Spaza', 'Kasi Corner Spaza'),
          'Kasi Corner Spaza');
    });
  });
}

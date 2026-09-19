import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/gamification/data/gamification_repository.dart';
import 'package:tradeiq_app/features/me/data/my_record_repository.dart';

/// THE WIRE, AND WHAT THE SCREEN IS ALLOWED TO CONCLUDE FROM IT.
///
/// Two rules live here rather than in the widget, because both are about the
/// *shape of a response* and neither should need a pumped frame to be true:
/// a null is never read as a zero, and the bar never invents a denominator.

void main() {
  group('a visit off the wire', () {
    test('carries the agent\'s own pin report', () {
      final visit = MyVisit.fromJson(<String, dynamic>{
        'id': 'v2',
        'checkinTs': '2026-09-17T09:00:00.000Z',
        'geofencePass': false,
        'checkinDistanceM': 140,
        'pinReported': true,
      });
      expect(visit.pinReported, isTrue);
      expect(visit.geofencePass, isFalse);
    });

    test('keeps an unmeasured distance and an unknown dwell as null', () {
      final visit = MyVisit.fromJson(<String, dynamic>{
        'id': 'v1',
        'outletId': 'o1',
        'outletName': 'Kasi Corner Spaza',
        'outletCode': 'KC-0412',
        'checkinTs': '2026-09-17T09:00:00.000Z',
        'checkinDistanceM': null,
        'geofencePass': true,
        'status': 'in_progress',
        'dwellMinutes': null,
        'sectionsCaptured': 0,
        'sectionsTotal': 7,
        'photos': 0,
        'tasksRaised': 0,
        'score': null,
        'reviewedVerdict': null,
      });

      expect(visit.checkinDistanceM, isNull);
      expect(visit.dwellMinutes, isNull);
      // An older server that does not send the field has no pin report.
      expect(visit.pinReported, isFalse);
      expect(visit.score, isNull);
      expect(visit.submitted, isFalse);
      // A measured zero is a zero and stays one.
      expect(visit.sectionsCaptured, 0);
      expect(visit.photos, 0);
    });

    test('keeps the device\'s score apart from the server\'s', () {
      final visit = MyVisit.fromJson(<String, dynamic>{
        'id': 'v1',
        'checkinTs': '2026-09-17T09:00:00.000Z',
        'geofencePass': true,
        'status': 'submitted',
        'score': <String, dynamic>{
          'weightedTotal': 71,
          'ratingBand': 'amber',
          'scoredAt': '2026-09-17T12:00:00.000Z',
          'seen': <String, dynamic>{
            'weightedTotal': 84,
            'ratingBand': 'green',
            'seenAt': '2026-09-17T09:41:00.000Z',
          },
        },
      });

      expect(visit.score!.weightedTotal, 71);
      expect(visit.score!.seen!.weightedTotal, 84);
      expect(visit.score!.changedSinceSeen, isTrue);
    });

    test('a difference that rounds away is not a change worth announcing', () {
      final visit = MyVisit.fromJson(<String, dynamic>{
        'id': 'v1',
        'checkinTs': '2026-09-17T09:00:00.000Z',
        'geofencePass': true,
        'status': 'submitted',
        'score': <String, dynamic>{
          'weightedTotal': 71.2,
          'ratingBand': 'amber',
          'scoredAt': '2026-09-17T12:00:00.000Z',
          'seen': <String, dynamic>{
            'weightedTotal': 70.8,
            'ratingBand': 'amber',
            'seenAt': '2026-09-17T09:41:00.000Z',
          },
        },
      });

      // The screen prints whole points. "71 became 71" is noise dressed as
      // honesty, and it would teach an agent to stop reading the line that
      // matters.
      expect(visit.score!.changedSinceSeen, isFalse);
    });

    test(
      'a scorecard with no recorded device figure has nothing to reconcile',
      () {
        final visit = MyVisit.fromJson(<String, dynamic>{
          'id': 'v1',
          'checkinTs': '2026-09-17T09:00:00.000Z',
          'geofencePass': true,
          'status': 'submitted',
          'score': <String, dynamic>{
            'weightedTotal': 71,
            'ratingBand': 'amber',
            'scoredAt': '2026-09-17T12:00:00.000Z',
            'seen': null,
          },
        });

        expect(visit.score!.seen, isNull);
        expect(visit.score!.changedSinceSeen, isFalse);
      },
    );
  });

  group('which scheme the bar shows', () {
    MyEarnings earnings({
      int visits = 14,
      int tasks = 3,
      double avg = 78,
      List<IncentiveScheme> schemes = const <IncentiveScheme>[],
    }) => MyEarnings(
      entry: LeaderboardEntry(
        agentId: 'a1',
        email: 'a@example.com',
        visitsSubmitted: visits,
        tasksClosed: tasks,
        rank: 4,
        avgScorecard: avg,
        points: 1840,
      ),
      ledger: const <PointsEntry>[],
      schemes: schemes,
    );

    test('no scheme means no bar, rather than a bar at zero', () {
      expect(earnings().focusScheme, isNull);
    });

    test('the nearest unreached threshold wins', () {
      final near = earnings(
        schemes: const <IncentiveScheme>[
          IncentiveScheme(
            id: 'far',
            name: 'Fifty stores',
            metric: 'visits',
            threshold: 50,
            rewardPoints: 1000,
          ),
          IncentiveScheme(
            id: 'near',
            name: 'Twenty stores',
            metric: 'visits',
            threshold: 20,
            rewardPoints: 250,
          ),
        ],
      ).focusScheme;

      expect(near!.id, 'near');
    });

    test('everything cleared shows the one that was reached, not nothing', () {
      final scheme = earnings(
        visits: 40,
        schemes: const <IncentiveScheme>[
          IncentiveScheme(
            id: 'twenty',
            name: 'Twenty stores',
            metric: 'visits',
            threshold: 20,
            rewardPoints: 250,
          ),
        ],
      ).focusScheme;

      // Disappearing at the moment of the win is the one thing the bar must
      // not do — the reward is the sentence, and the sentence needs a bar to
      // sit under.
      expect(scheme!.id, 'twenty');
    });

    test('a metric this response cannot measure is skipped, not guessed', () {
      final scheme = earnings(
        schemes: const <IncentiveScheme>[
          IncentiveScheme(
            id: 'mystery',
            name: 'Something else',
            metric: 'orders_placed',
            threshold: 10,
            rewardPoints: 50,
          ),
        ],
      ).focusScheme;

      expect(scheme, isNull);
    });

    test('a zero threshold is not a scheme', () {
      final scheme = earnings(
        schemes: const <IncentiveScheme>[
          IncentiveScheme(
            id: 'broken',
            name: 'Misconfigured',
            metric: 'visits',
            threshold: 0,
            rewardPoints: 10,
          ),
        ],
      ).focusScheme;

      expect(scheme, isNull);
    });

    test('each metric reads its own figure', () {
      final e = earnings(visits: 14, tasks: 3, avg: 78);
      const visitsScheme = IncentiveScheme(
        id: 'v',
        name: 'v',
        metric: 'visits',
        threshold: 20,
        rewardPoints: 1,
      );
      const tasksScheme = IncentiveScheme(
        id: 't',
        name: 't',
        metric: 'tasks_closed',
        threshold: 20,
        rewardPoints: 1,
      );
      const scoreScheme = IncentiveScheme(
        id: 's',
        name: 's',
        metric: 'scorecard',
        threshold: 90,
        rewardPoints: 1,
      );

      expect(e.progressFor(visitsScheme), 14);
      expect(e.progressFor(tasksScheme), 3);
      expect(e.progressFor(scoreScheme), 78);
    });
  });
}

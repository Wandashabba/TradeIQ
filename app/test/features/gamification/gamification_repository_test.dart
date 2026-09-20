import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/gamification/data/gamification_repository.dart';

void main() {
  test('LeaderboardEntry.fromJson parses all fields', () {
    final entry = LeaderboardEntry.fromJson(const {
      'agentId': 'a-1',
      'email': 'agent@example.com',
      'visitsSubmitted': 12,
      'tasksClosed': 5,
      'avgScorecard': 87.5,
      'points': 240.0,
      'rank': 1,
    });

    expect(entry.agentId, 'a-1');
    expect(entry.email, 'agent@example.com');
    expect(entry.visitsSubmitted, 12);
    expect(entry.tasksClosed, 5);
    expect(entry.avgScorecard, 87.5);
    expect(entry.points, 240.0);
    expect(entry.rank, 1);
    expect(entry.scorecardsCounted, 0);
  });

  test('LeaderboardEntry.fromJson defaults missing counts to zero — but not '
      'the place (#398)', () {
    final entry = LeaderboardEntry.fromJson(const {
      'agentId': 'a-2',
      'email': 'other@example.com',
    });

    expect(entry.visitsSubmitted, 0);
    expect(entry.tasksClosed, 0);
    expect(entry.avgScorecard, 0);
    expect(entry.scorecardsCounted, 0);
    expect(entry.points, 0);
    expect(entry.displayName, isNull);
    expect(entry.label, 'other@example.com');
    // A `?? 0` here would turn every unmeasured agent into rank zero, which
    // is a place — and a worse invention than the last place it replaced.
    expect(entry.rank, isNull);
  });

  test('a null rank on the wire stays null', () {
    final entry = LeaderboardEntry.fromJson(const {
      'agentId': 'a-3',
      'email': 'unmeasured@example.com',
      'rank': null,
      'avgScorecard': 0,
      'scorecardsCounted': 0,
      'points': 0,
    });

    expect(entry.rank, isNull);
  });

  test('scorecardsCounted tells a scored nought from an unscored agent', () {
    // `mean([])` is 0 on the wire, so the sample size is the only thing that
    // separates a finding from an absence.
    final scoredZero = LeaderboardEntry.fromJson(const {
      'agentId': 'a-4',
      'email': 'a@example.com',
      'avgScorecard': 0,
      'scorecardsCounted': 7,
    });
    final neverScored = LeaderboardEntry.fromJson(const {
      'agentId': 'a-5',
      'email': 'b@example.com',
      'avgScorecard': 0,
      'scorecardsCounted': 0,
    });

    expect(scoredZero.avgScorecard, neverScored.avgScorecard);
    expect(scoredZero.scorecardsCounted, 7);
    expect(neverScored.scorecardsCounted, 0);
  });

  test('AgentPointsHistory.fromJson parses the agent and its entries', () {
    final history = AgentPointsHistory.fromJson(const {
      'agent': {
        'agentId': 'a-1',
        'email': 'agent@example.com',
        'displayName': null,
      },
      'data': [
        {
          'id': 'e-1',
          'points': 5,
          'reason': 'task_closed',
          'sourceType': 'task',
          'sourceId': 't-1',
          'score': null,
          'occurredAt': '2026-07-06T09:00:00.000Z',
          'outletName': 'Spar Rosebank',
        },
        {
          'id': 'e-2',
          'points': 0,
          'reason': 'scorecard',
          'sourceType': 'scorecard',
          'sourceId': 's-1',
          'score': 85,
          'occurredAt': '2026-07-05T09:00:00.000Z',
          'outletName': null,
        },
      ],
      'nextCursor': 'e-2',
    });

    expect(history.agentId, 'a-1');
    expect(history.label, 'agent@example.com');
    expect(history.nextCursor, 'e-2');
    expect(history.entries, hasLength(2));

    final task = history.entries[0];
    expect(task.points, 5);
    expect(task.reasonLabel, 'Task closed');
    expect(task.sourceId, 't-1');
    expect(task.score, isNull);
    expect(task.outletName, 'Spar Rosebank');
    expect(task.occurredAt, DateTime.utc(2026, 7, 6, 9));

    final scorecard = history.entries[1];
    expect(scorecard.score, 85.0);
    expect(scorecard.reasonLabel, 'Scorecard');
    expect(scorecard.outletName, isNull);
  });

  test('PointsEntry words cover every reason', () {
    PointsEntry entry(String reason, int points, [double? score]) =>
        PointsEntry(
          id: 'e',
          points: points,
          reason: reason,
          sourceType: 'x',
          sourceId: 'x',
          score: score,
          occurredAt: DateTime.utc(2026),
        );

    expect(entry('visit_submitted', 2).reasonLabel, 'Visit submitted');
    // A reason the app does not know yet (e.g. a manual adjustment) still reads.
    expect(entry('manual_adjustment', -3).reasonLabel, 'Manual adjustment');
    expect(entry('', 0).reasonLabel, 'Points');
  });

  test(
    'LeaderboardEntry.fromJson parses displayName, and label prefers it',
    () {
      final entry = LeaderboardEntry.fromJson(const {
        'agentId': 'a-3',
        'email': 'agent3@example.com',
        'displayName': 'Chantal Adams',
      });

      expect(entry.displayName, 'Chantal Adams');
      expect(entry.label, 'Chantal Adams');
    },
  );
}

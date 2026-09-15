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
  });

  test('LeaderboardEntry.fromJson defaults missing numeric fields to zero', () {
    final entry = LeaderboardEntry.fromJson(const {
      'agentId': 'a-2',
      'email': 'other@example.com',
    });

    expect(entry.visitsSubmitted, 0);
    expect(entry.tasksClosed, 0);
    expect(entry.rank, 0);
    expect(entry.avgScorecard, 0);
    expect(entry.points, 0);
    expect(entry.displayName, isNull);
    expect(entry.label, 'other@example.com');
  });

  test('LeaderboardEntry.fromJson parses displayName, and label prefers it', () {
    final entry = LeaderboardEntry.fromJson(const {
      'agentId': 'a-3',
      'email': 'agent3@example.com',
      'displayName': 'Chantal Adams',
    });

    expect(entry.displayName, 'Chantal Adams');
    expect(entry.label, 'Chantal Adams');
  });
}

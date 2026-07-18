import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/features/gamification/data/gamification_repository.dart';
import 'package:tradeiq_app/features/gamification/presentation/leaderboard_screen.dart';

import '../../helpers/routed_app.dart';

const _entries = [
  LeaderboardEntry(
    agentId: 'a-1',
    email: 'alice@example.com',
    visitsSubmitted: 12,
    tasksClosed: 5,
    rank: 1,
    avgScorecard: 91,
    points: 240,
  ),
  LeaderboardEntry(
    agentId: 'a-2',
    email: 'bob@example.com',
    visitsSubmitted: 8,
    tasksClosed: 3,
    rank: 2,
    avgScorecard: 80,
    points: 160,
  ),
];

class _FakeGamificationRepository implements GamificationRepository {
  @override
  Future<List<LeaderboardEntry>> leaderboard() async => _entries;
}

class _FailingGamificationRepository implements GamificationRepository {
  @override
  Future<List<LeaderboardEntry>> leaderboard() async =>
      throw Exception('boom');
}

Widget _app(GamificationRepository repo, {ThemeData? theme}) => routedApp(
      const LeaderboardScreen(),
      theme: theme,
      overrides: [
        gamificationRepositoryProvider.overrideWithValue(repo),
      ],
    );

void main() {
  testWidgets('renders under the light theme', (tester) async {
    await tester.pumpWidget(_app(_FakeGamificationRepository(), theme: AppTheme.light()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(LeaderboardScreen), findsOneWidget);
  });

  testWidgets('renders leaderboard entry emails once loaded', (tester) async {
    await tester.pumpWidget(_app(_FakeGamificationRepository()));
    await tester.pumpAndSettle();

    expect(find.text('alice@example.com'), findsOneWidget);
    expect(find.text('bob@example.com'), findsOneWidget);
  });

  testWidgets('shows an error message when loading fails', (tester) async {
    await tester.pumpWidget(_app(_FailingGamificationRepository()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Failed to load leaderboard'),
      findsOneWidget,
    );
  });
}

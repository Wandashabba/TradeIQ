import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
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

const _aliceLine = '240 pts · 12 visits · 5 tasks closed';

void main() {
  testWidgets('dark: the points line keeps the row meta style', (tester) async {
    await tester.pumpWidget(_app(_FakeGamificationRepository()));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.text(_aliceLine)).style, isNull);
  });

  testWidgets('light: rows are glass tiles; the points line is mono', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_FakeGamificationRepository(), theme: AppTheme.light()),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.text(_aliceLine)).style!.fontFamily,
      LumenGlass.mono,
    );
    final panes = tester.widgetList<GlassPane>(
      find.ancestor(
        of: find.text('alice@example.com'),
        matching: find.byType(GlassPane),
      ),
    );
    expect(panes.any((p) => p.kind == GlassKind.tile && !p.blur), isTrue);
    expect(find.text('RANK 1'), findsOneWidget);
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

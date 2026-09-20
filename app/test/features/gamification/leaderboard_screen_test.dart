import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/gamification/data/gamification_repository.dart';
import 'package:tradeiq_app/features/gamification/presentation/agent_points_screen.dart';
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

final _history = AgentPointsHistory(
  agentId: 'a-1',
  email: 'alice@example.com',
  entries: [
    PointsEntry(
      id: 'e-1',
      points: 5,
      reason: 'task_closed',
      sourceType: 'task',
      sourceId: 't-1',
      occurredAt: DateTime.now().subtract(const Duration(hours: 3)),
      outletName: 'Spar Rosebank',
    ),
  ],
);

/// History lookups default to [_history]; the leaderboard only reads it after
/// a row is tapped.
mixin _History implements GamificationRepository {
  @override
  Future<AgentPointsHistory> agentPoints(String agentId) async => _history;
}

class _FakeGamificationRepository with _History {
  @override
  Future<List<LeaderboardEntry>> leaderboard() async => _entries;
}

class _NamedGamificationRepository with _History {
  @override
  Future<List<LeaderboardEntry>> leaderboard() async => [
    LeaderboardEntry(
      agentId: _entries[0].agentId,
      email: _entries[0].email,
      visitsSubmitted: _entries[0].visitsSubmitted,
      tasksClosed: _entries[0].tasksClosed,
      rank: _entries[0].rank,
      avgScorecard: _entries[0].avgScorecard,
      points: _entries[0].points,
      displayName: 'Thandi Mokoena',
    ),
    _entries[1],
  ];
}

class _FailingGamificationRepository with _History {
  @override
  Future<List<LeaderboardEntry>> leaderboard() async => throw Exception('boom');
}

/// The leaderboard and its drill-down under real routes, as in app_router.
Widget _routedBoard({ThemeData? theme}) => ProviderScope(
  overrides: [
    gamificationRepositoryProvider.overrideWithValue(
      _FakeGamificationRepository(),
    ),
  ],
  child: MaterialApp.router(
    theme: theme,
    routerConfig: GoRouter(
      initialLocation: '/leaderboard',
      routes: [
        GoRoute(
          path: '/leaderboard',
          builder: (context, state) => const LeaderboardScreen(),
        ),
        GoRoute(
          path: '/leaderboard/:agentId',
          builder: (context, state) =>
              AgentPointsScreen(agentId: state.pathParameters['agentId']!),
        ),
      ],
    ),
  ),
);

Widget _app(GamificationRepository repo, {ThemeData? theme}) => routedApp(
  const LeaderboardScreen(),
  theme: theme,
  overrides: [gamificationRepositoryProvider.overrideWithValue(repo)],
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

  for (final theme in [AppTheme.light(), null]) {
    final label = theme == null ? 'dark' : 'light';
    testWidgets('$label: a named agent is ranked by name, others by email', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_NamedGamificationRepository(), theme: theme),
      );
      await tester.pumpAndSettle();

      final row = find.byKey(const ValueKey('leaderboard-a-1'));
      expect(
        find.descendant(of: row, matching: find.text('Thandi Mokoena')),
        findsOneWidget,
      );
      expect(find.text('alice@example.com'), findsNothing);
      expect(find.text('bob@example.com'), findsOneWidget);
    });
  }

  for (final (label, theme) in [
    ('light', AppTheme.light()),
    ('night', AppTheme.dark()),
  ]) {
    testWidgets('$label: tapping a row opens that agent points history, '
        'and Leaderboard returns', (tester) async {
      await tester.pumpWidget(_routedBoard(theme: theme));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('leaderboard-a-1')));
      await tester.pumpAndSettle();

      expect(find.text('Points history'), findsOneWidget);
      expect(find.text('Task closed'), findsOneWidget);
      expect(find.text('+5 pts · Spar Rosebank'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('points-back-to-leaderboard')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Points history'), findsNothing);
      expect(find.byKey(const ValueKey('leaderboard-a-1')), findsOneWidget);
    });
  }

  testWidgets('shows an error message when loading fails', (tester) async {
    await tester.pumpWidget(_app(_FailingGamificationRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load leaderboard'), findsOneWidget);
  });
}

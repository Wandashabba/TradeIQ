import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/widgets/agent_kit.dart' show formatAgo;
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/gamification/data/gamification_repository.dart';
import 'package:tradeiq_app/features/gamification/presentation/agent_points_screen.dart';

import '../../helpers/routed_app.dart';

final _now = DateTime.now();

final _history = AgentPointsHistory(
  agentId: 'a-1',
  email: 'thandi@example.com',
  displayName: 'Thandi Mokoena',
  entries: [
    PointsEntry(
      id: 'e-1',
      points: 5,
      reason: 'task_closed',
      sourceType: 'task',
      sourceId: 'task-0001-abcdef',
      occurredAt: _now.subtract(const Duration(hours: 2)),
      outletName: 'Spar Rosebank',
    ),
    PointsEntry(
      id: 'e-2',
      points: 0,
      reason: 'scorecard',
      sourceType: 'scorecard',
      sourceId: 'sc-0002',
      score: 78.5,
      occurredAt: _now.subtract(const Duration(days: 1)),
      outletName: 'Spar Rosebank',
    ),
    PointsEntry(
      id: 'e-3',
      points: 2,
      reason: 'visit_submitted',
      sourceType: 'visit',
      sourceId: 'visit-0003',
      occurredAt: _now.subtract(const Duration(days: 1)),
    ),
  ],
);

class _FakeRepo implements GamificationRepository {
  _FakeRepo(this.history);

  final AgentPointsHistory history;
  final requested = <String>[];

  @override
  Future<List<LeaderboardEntry>> leaderboard() async => const [];

  @override
  Future<AgentPointsHistory> agentPoints(String agentId) async {
    requested.add(agentId);
    return history;
  }
}

class _FailingRepo implements GamificationRepository {
  @override
  Future<List<LeaderboardEntry>> leaderboard() async => const [];

  @override
  Future<AgentPointsHistory> agentPoints(String agentId) async =>
      throw Exception('boom');
}

Widget _app(GamificationRepository repo, {ThemeData? theme}) => routedApp(
  const AgentPointsScreen(agentId: 'a-1'),
  theme: theme,
  overrides: [gamificationRepositoryProvider.overrideWithValue(repo)],
);

void main() {
  for (final (label, theme) in [
    ('light', AppTheme.light()),
    ('night', AppTheme.dark()),
  ]) {
    testWidgets('$label: each entry shows reason, figure, source and when, '
        'as mono figures on glass tiles', (tester) async {
      final repo = _FakeRepo(_history);
      await tester.pumpWidget(_app(repo, theme: theme));
      await tester.pumpAndSettle();

      expect(repo.requested, ['a-1']);
      expect(find.text('Points history'), findsOneWidget);
      expect(find.text('Thandi Mokoena'), findsOneWidget);
      expect(find.text('Latest 3 entries, newest first'), findsOneWidget);

      final task = find.byKey(const ValueKey('points-entry-e-1'));
      Finder inTask(Finder f) => find.descendant(of: task, matching: f);
      expect(inTask(find.text('Task closed')), findsOneWidget);
      expect(inTask(find.text('+5 pts · Spar Rosebank')), findsOneWidget);
      // The source id, shortened, to quote in a dispute.
      expect(inTask(find.text('task-000')), findsOneWidget);
      expect(
        inTask(find.text(formatAgo(_history.entries[0].occurredAt))),
        findsOneWidget,
      );

      // A scorecard feeds the average: its score, not a points amount.
      expect(find.text('Scorecard'), findsOneWidget);
      expect(find.text('score 78.5 · Spar Rosebank'), findsOneWidget);
      // No resolvable outlet: the figure alone.
      expect(find.text('Visit submitted'), findsOneWidget);
      expect(find.text('+2 pts'), findsOneWidget);

      final figure = tester.widget<Text>(find.text('+5 pts · Spar Rosebank'));
      expect(figure.style!.fontFamily, LumenGlass.mono);
      final panes = tester.widgetList<GlassPane>(
        find.ancestor(
          of: find.text('Task closed'),
          matching: find.byType(GlassPane),
        ),
      );
      expect(panes.any((p) => p.kind == GlassKind.tile && !p.blur), isTrue);
    });

    testWidgets('$label: an agent with no entries gets an empty state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _FakeRepo(
            const AgentPointsHistory(
              agentId: 'a-1',
              email: 'new@example.com',
              entries: [],
            ),
          ),
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('new@example.com'), findsOneWidget);
      expect(find.text('No points yet'), findsOneWidget);
    });
  }

  testWidgets('flat palette: the figure line keeps the row meta style', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeRepo(_history)));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.text('+5 pts · Spar Rosebank')).style,
      isNull,
    );
  });

  testWidgets('shows an error message when loading fails', (tester) async {
    await tester.pumpWidget(_app(_FailingRepo()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Failed to load points history'),
      findsOneWidget,
    );
  });
}

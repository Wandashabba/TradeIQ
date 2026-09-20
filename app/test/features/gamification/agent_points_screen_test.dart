import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/gamification/data/gamification_repository.dart';
import 'package:tradeiq_app/features/gamification/presentation/agent_points_screen.dart';

import '../../core/design/amber_golden.dart';
import '../worklist_harness.dart';

const String _agentId = 'a-1';

LeaderboardEntry _standing({
  double avgScorecard = 85,
  int scorecardsCounted = 6,
  double points = 94,
  int? rank = 2,
}) => LeaderboardEntry(
  agentId: _agentId,
  email: 'thandi@acme.test',
  displayName: 'Thandi Mokoena',
  visitsSubmitted: 12,
  tasksClosed: 5,
  rank: rank,
  avgScorecard: avgScorecard,
  scorecardsCounted: scorecardsCounted,
  points: points,
);

PointsEntry _entry({
  String id = 'e-1',
  int points = 5,
  String reason = 'task_closed',
  double? score,
  String? outletName = 'Kasi Corner Spaza',
}) => PointsEntry(
  id: id,
  points: points,
  reason: reason,
  sourceType: 'task',
  sourceId: 't-1',
  score: score,
  occurredAt: DateTime.now().subtract(const Duration(hours: 3)),
  outletName: outletName,
);

AgentPointsHistory _history({
  List<PointsEntry>? entries,
  String? nextCursor,
  String? displayName = 'Thandi Mokoena',
}) => AgentPointsHistory(
  agentId: _agentId,
  email: 'thandi@acme.test',
  displayName: displayName,
  entries: entries ?? <PointsEntry>[_entry()],
  nextCursor: nextCursor,
);

class _FakeGamification implements GamificationRepository {
  _FakeGamification({
    this.history,
    this.board = const <LeaderboardEntry>[],
    this.failure,
    this.pending = false,
    this.boardFails = false,
  });

  final AgentPointsHistory? history;
  final List<LeaderboardEntry> board;
  final Object? failure;
  final bool pending;
  final bool boardFails;

  @override
  Future<List<LeaderboardEntry>> leaderboard() async {
    if (boardFails) throw StateError('board is down');
    return board;
  }

  @override
  Future<AgentPointsHistory> agentPoints(String agentId) async {
    if (failure != null) throw failure!;
    if (pending) return Completer<AgentPointsHistory>().future;
    return history ?? _history();
  }
}

Future<void> _pump(
  WidgetTester tester, {
  AgentPointsHistory? history,
  List<LeaderboardEntry>? board,
  Object? failure,
  bool pending = false,
  bool boardFails = false,
  TiqSkin? skin,
  double textScale = 1.0,
  Size size = const Size(360, 720),
  Locale? locale,
}) => pumpWorklist(
  tester,
  const AgentPointsScreen(agentId: _agentId),
  skin: skin,
  size: size,
  textScale: textScale,
  locale: locale,
  path: '/leaderboard/$_agentId',
  settle: !pending,
  overrides: <Override>[
    gamificationRepositoryProvider.overrideWithValue(
      _FakeGamification(
        history: history,
        board: board ?? <LeaderboardEntry>[_standing()],
        failure: failure,
        pending: pending,
        boardFails: boardFails,
      ),
    ),
  ],
);

void main() {
  group('whose record this is', () {
    testWidgets('the person is the title, never the agent id', (tester) async {
      await _pump(tester);

      expect(find.text('Thandi Mokoena'), findsOneWidget);
      expect(find.textContaining(_agentId), findsNothing);
    });

    testWidgets('the standing is a fact in the header, not a badge', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.textContaining('Rank 2'), findsOneWidget);
    });

    testWidgets('an unranked agent is said to be unranked, not placed', (
      tester,
    ) async {
      await _pump(
        tester,
        board: <LeaderboardEntry>[
          _standing(rank: null, scorecardsCounted: 0, avgScorecard: 0),
        ],
      );

      expect(find.textContaining('Not ranked yet'), findsOneWidget);
      expect(find.textContaining(RegExp(r'Rank \d')), findsNothing);
    });
  });

  group('unknown versus zero on the average', () {
    testWidgets('no scorecards renders an em dash and a sentence, not a 0', (
      tester,
    ) async {
      await _pump(
        tester,
        board: <LeaderboardEntry>[
          _standing(avgScorecard: 0, scorecardsCounted: 0),
        ],
      );

      final tile = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('points-average')),
      );
      expect(tile.value, isNull);
      expect(tile.figureState, FigureState.missing);
      expect(tile.noDataReason, 'No scored visit in this window.');
      expect(find.textContaining('No scored visit'), findsOneWidget);
    });

    testWidgets('a real zero average is a measured zero and keeps its place', (
      tester,
    ) async {
      await _pump(
        tester,
        board: <LeaderboardEntry>[
          _standing(avgScorecard: 0, scorecardsCounted: 7),
        ],
      );

      final tile = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('points-average')),
      );
      expect(tile.value, 0);
      expect(tile.figureState, FigureState.measured);
      expect(tile.noDataReason, isNull);
    });

    testWidgets('a thin window greys the average and says how thin', (
      tester,
    ) async {
      await _pump(
        tester,
        board: <LeaderboardEntry>[
          _standing(avgScorecard: 91, scorecardsCounted: 2),
        ],
      );

      final tile = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('points-average')),
      );
      // An average needs n >= 3 before it is a comparison rather than an
      // anecdote, and the threshold belongs to the metric, not to this screen.
      expect(tile.figureState, FigureState.lowSample);
    });

    testWidgets('exactly at the threshold is the normal treatment', (
      tester,
    ) async {
      await _pump(
        tester,
        board: <LeaderboardEntry>[
          _standing(avgScorecard: 91, scorecardsCounted: 3),
        ],
      );

      final tile = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('points-average')),
      );
      expect(tile.figureState, FigureState.measured);
    });
  });

  group('the payout and the average are not peers', () {
    testWidgets('the payout carries no 0-100 meter and the average does', (
      tester,
    ) async {
      await _pump(tester);

      final payout = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('points-total')),
      );
      final average = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('points-average')),
      );
      expect(payout.meter, isNull);
      expect(average.meter, isNotNull);
      // And the payout says what it is made of, so 94 beside 85 is never read
      // as a fraction.
      expect(find.textContaining('plus 5 a closed task'), findsOneWidget);
    });
  });

  group('the ledger', () {
    testWidgets('a scorecard entry shows the score it feeds, not +0 pts', (
      tester,
    ) async {
      await _pump(
        tester,
        history: _history(
          entries: <PointsEntry>[
            _entry(id: 'sc', points: 0, reason: 'scorecard', score: 78.5),
          ],
        ),
      );

      expect(find.text('Scorecard'), findsOneWidget);
      // The score, not a payout: a scorecard entry earns no points of its own
      // — the board averages the score — so "+0 pts" would be a nought that
      // means nothing.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('points-entry-sc')),
          matching: find.textContaining('pts'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('points-entry-sc')),
          matching: find.textContaining('78.5'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a ledger row speaks its figure and its age', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);

      // A SoftRow excludes everything beneath it, so a figure in the trailing
      // and an age in the meta are painted and never spoken unless the row
      // spells them.
      expect(
        find.bySemanticsLabel(
          RegExp(r'Task closed.*\+5 points.*Kasi Corner Spaza'),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a cut page owns up to being cut', (tester) async {
      await _pump(tester, history: _history(nextCursor: 'c2'));

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('points-footer')),
      );
      expect(find.byType(PaginationFooter), findsOneWidget);
    });

    testWidgets('a whole page is not claimed to be cut', (tester) async {
      await _pump(tester);
      expect(find.byType(PaginationFooter), findsNothing);
    });
  });

  group('the states', () {
    testWidgets('loading is a skeleton', (tester) async {
      await _pump(tester, pending: true);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(Skeleton), findsOneWidget);
    });

    testWidgets('an empty ledger says what would fill it', (tester) async {
      await _pump(tester, history: _history(entries: const <PointsEntry>[]));

      expect(
        find.byKey(const ValueKey<String>('points-empty')),
        findsOneWidget,
      );
    });

    testWidgets('an error is sanitised and carries one retry', (tester) async {
      await _pump(
        tester,
        failure: StateError('SocketException: api.tradeiq.co.za'),
      );

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('points-retry')),
        findsOneWidget,
      );
    });

    testWidgets('a board that will not load does not take the ledger down', (
      tester,
    ) async {
      await _pump(tester, boardFails: true);

      // The standing is a base layer. Its absence removes the figures rather
      // than standing a zero in for a number nobody fetched.
      expect(find.byType(StatTile), findsNothing);
      expect(find.byType(SoftRow), findsWidgets);
      expect(find.text('Task closed'), findsOneWidget);
    });

    testWidgets('the back action leaves for the board', (tester) async {
      await _pump(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('points-back-to-leaderboard')),
      );
      await tester.pumpAndSettle();

      expect(find.text('stub:/leaderboard'), findsOneWidget);
    });
  });

  // ── Every button a reader announces, a reader can press ───────────────
  //
  // The kit once shipped a whole button family that announced itself and did
  // nothing when a screen reader activated it, and `SectionRuleAction` and
  // `PaginationFooter.action` were still shipping it when this group started.
  // This is that law on this screen, in every phase, so no local
  // `Semantics(button: true, ..., excludeSemantics: true)` around a bare
  // gesture detector can bring it back here.
  group('every button a screen reader announces can be activated', () {
    final phases = <String, Future<void> Function(WidgetTester)>{
      'loaded': (t) => _pump(t),
      'empty': (t) => _pump(t, history: _history(entries: const [])),
      'error': (t) =>
          _pump(t, failure: StateError('SocketException: api.tradeiq.co.za')),
      'no-standing': (t) => _pump(t, boardFails: true),
    };
    for (final phase in phases.entries) {
      testWidgets(phase.key, (tester) async {
        final handle = tester.ensureSemantics();
        await phase.value(tester);
        expectEveryButtonActivatable(tester);
        handle.dispose();
      });
    }
  });

  group('the amber census, every phase in every skin', () {
    for (final skin in <TiqSkin>[
      TiqSkin.night(),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      final lit = skin.mode == SkinMode.night ? 1 : 0;
      final phases = <String, Future<void> Function(WidgetTester)>{
        'loaded': (t) => _pump(t, skin: skin),
        'empty': (t) => _pump(
          t,
          skin: skin,
          history: _history(entries: const []),
        ),
        'loading': (t) async {
          await _pump(t, skin: skin, pending: true);
          await t.pump(const Duration(milliseconds: 700));
        },
        'error': (t) => _pump(
          t,
          skin: skin,
          failure: StateError('SocketException: api.tradeiq.co.za'),
        ),
        'no-standing': (t) => _pump(t, skin: skin, boardFails: true),
      };
      for (final phase in phases.entries) {
        testWidgets('${skin.mode.name}, ${phase.key}: $lit', (tester) async {
          await phase.value(tester);
          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'agent-points',
            phase: phase.key,
          );
          expect(census.objectCount, lit, reason: census.describe());
        });
      }
    }
  });

  group('2.0x text and Afrikaans', () {
    testWidgets('nothing overflows at 2.0x', (tester) async {
      await _pump(tester, textScale: 2.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nothing overflows at 320dp in Afrikaans', (tester) async {
      await _pump(
        tester,
        size: const Size(320, 640),
        locale: const Locale('af'),
      );
      expect(tester.takeException(), isNull);
    });
  });
}

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
import 'package:tradeiq_app/l10n/l10n.dart';

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

/// Painted text, ignoring case.
///
/// The kit uppercases eyebrows and field labels for display while the ARB
/// holds sentence case, so a case-sensitive `textContaining` would pass on an
/// English eyebrow simply by failing to see it. Ignoring case makes the
/// absence assertions below stricter, not looser.
Finder paintedIgnoringCase(String text) {
  final needle = text.toUpperCase();
  return find.byWidgetPredicate(
    (Widget w) => w is Text && (w.data ?? '').toUpperCase().contains(needle),
    description: 'text containing "$text", ignoring case',
  );
}

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

  group('unknown versus zero on the payout', () {
    testWidgets(
      'the agent the board will not place has no payout to print either',
      (tester) async {
        // The exact row the leaderboard renders as "Not ranked yet": the
        // window holds no ledger entry at all, so `points` is 0 only because
        // `mean([]) + 0` is 0. Printing "0 pts" at full commitment here is
        // the same absence rendered as an absence one tap back and as a
        // measured nought here — and it is what puts a person into a
        // performance conversation as the agent on zero.
        await _pump(
          tester,
          board: <LeaderboardEntry>[
            _standing(
              rank: null,
              points: 0,
              avgScorecard: 0,
              scorecardsCounted: 0,
            ),
          ],
        );

        final payout = tester.widget<StatTile>(
          find.byKey(const ValueKey<String>('points-total')),
        );
        expect(payout.value, isNull);
        expect(payout.figureState, FigureState.missing);
        expect(payout.noDataReason, isNotNull);
        expect(
          find.textContaining('Nothing recorded for this agent'),
          findsOneWidget,
        );
        // No figure, so no unit and no recipe sentence beside nothing.
        expect(find.textContaining('0 pts'), findsNothing);
        expect(find.textContaining('plus 5 a closed task'), findsNothing);
        // And the header still says the absence in words.
        expect(find.textContaining('Not ranked yet'), findsOneWidget);
      },
    );

    testWidgets('a ranked agent on nought points still prints the nought', (
      tester,
    ) async {
      // A scored agent whose scorecards average 0 and who closed nothing IS
      // measured: the server gave them a place. This is the over-correction
      // guard — suppressing here would invent an absence out of a real zero.
      await _pump(
        tester,
        board: <LeaderboardEntry>[
          _standing(
            rank: 3,
            points: 0,
            avgScorecard: 0,
            scorecardsCounted: 4,
          ),
        ],
      );

      final payout = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('points-total')),
      );
      expect(payout.value, 0);
      expect(payout.figureState, FigureState.measured);
      expect(payout.noDataReason, isNull);
      expect(find.textContaining('plus 5 a closed task'), findsOneWidget);
    });

    test('the two screens read one decision, not two', () {
      // The board's rule and this screen's rule are the same getter. A screen
      // that made its own copy is how the mismatch got in.
      final unmeasured = _standing(rank: null, points: 0);
      final ranked = _standing(rank: 2, points: 94);

      expect(unmeasured.payoutIsMeasured, isFalse);
      expect(unmeasured.measuredPoints, isNull);
      expect(ranked.payoutIsMeasured, isTrue);
      expect(ranked.measuredPoints, 94);
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

  // The ledger an Afrikaans manager opens from the board. The board one tap
  // back is now Afrikaans; a ledger that stays English is the console's
  // boundary drawn through one manager's two taps.
  group('an Afrikaans manager opens the ledger', () {
    testWidgets('no English is painted, and the Afrikaans is', (tester) async {
      final af = lookupAppLocalizations(const Locale('af'));
      await _pump(
        tester,
        locale: const Locale('af'),
        size: const Size(360, 1600),
      );

      for (final english in <String>[
        'Points earned',
        'Average scorecard',
        'Back to the leaderboard',
        'Ledger',
        'Field agent',
        'visits submitted',
        'tasks closed',
      ]) {
        expect(paintedIgnoringCase(english), findsNothing, reason: english);
      }

      expect(paintedIgnoringCase(af.pointsEarnedEyebrow), findsWidgets);
      expect(paintedIgnoringCase(af.pointsAverageEyebrow), findsWidgets);
      expect(paintedIgnoringCase(af.pointsBackToLeaderboard), findsWidgets);
      expect(paintedIgnoringCase(af.pointsLedgerHeading), findsWidgets);
    });

    testWidgets('a ledger entry names its reason in Afrikaans', (
      tester,
    ) async {
      final af = lookupAppLocalizations(const Locale('af'));
      await _pump(
        tester,
        locale: const Locale('af'),
        size: const Size(360, 1600),
      );

      // `PointsEntry.reasonLabel` is the English fallback of last resort and
      // nothing a reader sees may come from it. The agent's own record has
      // read these three through the ARB since it shipped; the console read
      // the raw switch, so one event had two spellings.
      expect(paintedIgnoringCase(af.meReasonTaskClosed), findsWidgets);
      expect(paintedIgnoringCase('Task closed'), findsNothing);
    });

    testWidgets('an unranked agent is unmeasured in Afrikaans, not nought', (
      tester,
    ) async {
      final af = lookupAppLocalizations(const Locale('af'));
      await _pump(
        tester,
        board: <LeaderboardEntry>[
          _standing(rank: null, scorecardsCounted: 0, avgScorecard: 0),
        ],
        locale: const Locale('af'),
        size: const Size(360, 1600),
      );

      // The two fixes meeting: the payout is an absence (#464), and the
      // sentence saying so is in the reader's language.
      expect(paintedIgnoringCase(af.pointsPayoutAbsent), findsOneWidget);
      expect(
        paintedIgnoringCase('Nothing recorded for this agent'),
        findsNothing,
      );
    });
  });
}

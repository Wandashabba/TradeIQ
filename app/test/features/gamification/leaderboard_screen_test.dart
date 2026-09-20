import 'dart:async';

import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/gamification/data/gamification_repository.dart';
import 'package:tradeiq_app/features/gamification/data/leaderboard_view.dart';
import 'package:tradeiq_app/features/gamification/presentation/leaderboard_screen.dart';

import '../../core/design/amber_golden.dart';
import '../worklist_harness.dart';

LeaderboardEntry _entry({
  String agentId = 'a-1',
  String email = 'thandi@acme.test',
  String? displayName = 'Thandi Mokoena',
  int? rank = 1,
  int visitsSubmitted = 12,
  int tasksClosed = 5,
  double avgScorecard = 85,
  int scorecardsCounted = 6,
  double points = 94,
}) => LeaderboardEntry(
  agentId: agentId,
  email: email,
  displayName: displayName,
  visitsSubmitted: visitsSubmitted,
  tasksClosed: tasksClosed,
  rank: rank,
  avgScorecard: avgScorecard,
  scorecardsCounted: scorecardsCounted,
  points: points,
);

final List<LeaderboardEntry> _board = <LeaderboardEntry>[
  _entry(),
  _entry(
    agentId: 'a-2',
    email: 'busi@acme.test',
    displayName: 'Busi Dlamini',
    rank: 2,
    visitsSubmitted: 8,
    tasksClosed: 1,
    avgScorecard: 60,
    scorecardsCounted: 4,
    points: 62,
  ),
];

/// An agent the window holds nothing for. `points` is 0 because there is no
/// ledger entry at all, which is an absence and not a measured nought.
final LeaderboardEntry _unmeasured = _entry(
  agentId: 'a-9',
  email: 'sipho@acme.test',
  displayName: 'Sipho Ndlovu',
  rank: null,
  visitsSubmitted: 0,
  tasksClosed: 0,
  avgScorecard: 0,
  scorecardsCounted: 0,
  points: 0,
);

class _FakeGamification implements GamificationRepository {
  _FakeGamification({
    this.entries = const <LeaderboardEntry>[],
    this.failure,
    this.pending = false,
  });

  final List<LeaderboardEntry> entries;
  final Object? failure;
  final bool pending;

  @override
  Future<List<LeaderboardEntry>> leaderboard() async {
    if (failure != null) throw failure!;
    if (pending) return Completer<List<LeaderboardEntry>>().future;
    return entries;
  }

  @override
  Future<AgentPointsHistory> agentPoints(String agentId) async =>
      throw UnimplementedError();
}

Future<void> _pump(
  WidgetTester tester, {
  List<LeaderboardEntry> entries = const <LeaderboardEntry>[],
  Object? failure,
  bool pending = false,
  TiqSkin? skin,
  double textScale = 1.0,
  Size size = const Size(360, 720),
  Locale? locale,
}) => pumpWorklist(
  tester,
  const LeaderboardScreen(),
  skin: skin,
  size: size,
  textScale: textScale,
  locale: locale,
  path: '/leaderboard',
  settle: !pending,
  overrides: <Override>[
    gamificationRepositoryProvider.overrideWithValue(
      _FakeGamification(entries: entries, failure: failure, pending: pending),
    ),
  ],
);

void main() {
  group('the view model', () {
    test('splits ranked from unranked and never reorders a place', () {
      final view = LeaderboardView.of(<LeaderboardEntry>[
        _unmeasured,
        _board[1],
        _board[0],
      ]);

      expect(view.ranked.map((e) => e.rank), <int>[1, 2]);
      expect(view.unranked.single.agentId, 'a-9');
      expect(view.total, 3);
    });

    test('an unranked agent sorts by name, not by the zero they were given', () {
      final view = LeaderboardView.of(<LeaderboardEntry>[
        _entry(agentId: 'z', displayName: 'Zanele Khumalo', rank: null),
        _entry(agentId: 'a', displayName: 'Ayanda Nkosi', rank: null),
      ]);

      expect(
        view.unranked.map((e) => e.label),
        <String>['Ayanda Nkosi', 'Zanele Khumalo'],
      );
      expect(view.ranked, isEmpty);
    });

    test('an empty board is empty, not a board of nobody', () {
      expect(LeaderboardView.of(const <LeaderboardEntry>[]).isEmpty, isTrue);
    });
  });

  group('a row names a person', () {
    testWidgets('the name is the title and no id is anywhere on the row', (
      tester,
    ) async {
      await _pump(tester, entries: _board);

      expect(find.text('Thandi Mokoena'), findsOneWidget);
      expect(find.text('Busi Dlamini'), findsOneWidget);
      expect(find.byType(PersonRow), findsNWidgets(2));
      // Not the agent id, and not the email either where a name exists.
      expect(find.textContaining('a-1'), findsNothing);
      expect(find.textContaining('thandi@acme.test'), findsNothing);
    });

    testWidgets('an agent never given a name falls back to their email', (
      tester,
    ) async {
      await _pump(
        tester,
        entries: <LeaderboardEntry>[_entry(displayName: null)],
      );

      expect(find.text('thandi@acme.test'), findsOneWidget);
    });

    testWidgets('the figures in the trailing are spoken, not only painted', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, entries: _board);

      // The defect this guards: a SoftRow is one semantics node that excludes
      // everything beneath it, so "94 pts" painted in the trailing reaches a
      // screen reader only if the row spells it.
      expect(
        find.bySemanticsLabel(RegExp(r'Thandi Mokoena.*Rank 1.*94 points')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a row is tappable by a screen reader, not only by a thumb', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, entries: _board);

      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('Thandi Mokoena')),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets('tapping a row opens that agent ledger', (tester) async {
      await _pump(tester, entries: _board);

      await tester.tap(find.text('Busi Dlamini'));
      await tester.pumpAndSettle();

      expect(find.text('stub:/leaderboard/a-2'), findsOneWidget);
    });
  });

  group('unranked is not last (#398)', () {
    testWidgets('an unmeasured agent sits in their own section, with a word', (
      tester,
    ) async {
      await _pump(
        tester,
        entries: <LeaderboardEntry>[..._board, _unmeasured],
      );

      expect(find.text('Not ranked yet'), findsWidgets);
      expect(find.byKey(const ValueKey<String>('leaderboard-unranked-note')),
          findsOneWidget);
      expect(
        find.textContaining('They are not last'),
        findsOneWidget,
      );
      // And they are listed: an agent missing from the board reads as an
      // agent who left. Past the fold on a 360dp phone, which is the point of
      // a lazy list and not a reason to pump a viewport nobody holds.
      await scrollWorklistTo(tester, find.text('Sipho Ndlovu'));
      expect(find.text('Sipho Ndlovu'), findsOneWidget);
    });

    testWidgets('an unmeasured agent is never given a place or a payout', (
      tester,
    ) async {
      await _pump(tester, entries: <LeaderboardEntry>[_unmeasured]);

      // "Ranked" is the first section rule's own name, so the assertion is
      // about a place on a ROW and not about the substring.
      expect(find.textContaining(RegExp(r'Rank \d')), findsNothing);
      // `points` is 0 on the wire because there is no ledger entry at all.
      // Printing "0 pts" would be a measured zero, and nothing was measured.
      expect(find.textContaining('pts'), findsNothing);
    });

    testWidgets('a board of nobody measured still names its two sections', (
      tester,
    ) async {
      await _pump(tester, entries: <LeaderboardEntry>[_unmeasured]);

      expect(find.byType(SectionRule), findsNWidgets(2));
      expect(find.textContaining('Nobody has a place'), findsOneWidget);
    });
  });

  group('the 0-100 average is not on the board', () {
    testWidgets('a payout and a mean are never printed as a pair', (
      tester,
    ) async {
      await _pump(tester, entries: _board);

      // 94 pts is `mean(scorecard) + 5 x tasks + 2 x visits`; 85 is the mean
      // on its own. Side by side they read as a fraction of something.
      expect(find.textContaining('85'), findsNothing);
      expect(find.textContaining('60'), findsNothing);
    });
  });

  group('the states', () {
    testWidgets('loading is a skeleton, not a spinner', (tester) async {
      await _pump(tester, pending: true);
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byType(Skeleton), findsOneWidget);
    });

    testWidgets('an empty board says what would fill it', (tester) async {
      await _pump(tester);

      expect(
        find.byKey(const ValueKey<String>('leaderboard-empty')),
        findsOneWidget,
      );
      expect(find.byType(PersonRow), findsNothing);
    });

    testWidgets('an error is sanitised and carries one retry', (tester) async {
      await _pump(
        tester,
        failure: StateError('SocketException: api.tradeiq.co.za'),
      );

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('leaderboard-retry')),
        findsOneWidget,
      );
    });
  });

  group('the amber census, every phase in every skin', () {
    // A ranking has nothing armed: no commit action, no chart focus, no
    // plate. Night paints the nav's active tab and nothing else; Day and Veld
    // paint nothing, because their one rung is the primary commit block.
    for (final skin in <TiqSkin>[
      TiqSkin.night(),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      final lit = skin.mode == SkinMode.night ? 1 : 0;
      final phases = <String, Future<void> Function(WidgetTester)>{
        'loaded': (t) => _pump(t, skin: skin, entries: _board),
        'nobody-measured': (t) =>
            _pump(t, skin: skin, entries: <LeaderboardEntry>[_unmeasured]),
        'empty': (t) => _pump(t, skin: skin),
        'loading': (t) async {
          await _pump(t, skin: skin, pending: true);
          await t.pump(const Duration(milliseconds: 700));
        },
        'error': (t) => _pump(
          t,
          skin: skin,
          failure: StateError('SocketException: api.tradeiq.co.za'),
        ),
      };
      for (final phase in phases.entries) {
        testWidgets('${skin.mode.name}, ${phase.key}: $lit', (tester) async {
          await phase.value(tester);
          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'leaderboard',
            phase: phase.key,
          );
          expect(census.objectCount, lit, reason: census.describe());
        });
      }
    }
  });

  group('2.0x text and Afrikaans', () {
    testWidgets('nothing overflows at 2.0x', (tester) async {
      await _pump(
        tester,
        textScale: 2.0,
        entries: <LeaderboardEntry>[..._board, _unmeasured],
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Thandi Mokoena'), findsOneWidget);
    });

    testWidgets('nothing overflows at 320dp in Afrikaans', (tester) async {
      await _pump(
        tester,
        size: const Size(320, 640),
        locale: const Locale('af'),
        entries: <LeaderboardEntry>[..._board, _unmeasured],
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('Veld is built, and it still names the person', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, skin: TiqSkin.veld(), entries: _board);

      expect(find.byType(PersonRow), findsNWidgets(2));
      // Veld sets body at 17 with a 24dp gutter, so a two-word name
      // middle-truncates on a 360dp row — which is the ruling, and the reason
      // the FULL name is what a screen reader is handed whatever is painted.
      expect(
        find.bySemanticsLabel(RegExp('Thandi Mokoena')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      handle.dispose();
    });
  });
}

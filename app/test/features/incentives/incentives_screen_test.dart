import 'dart:async';

import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/gamification/data/gamification_repository.dart';
import 'package:tradeiq_app/features/incentives/data/incentives_repository.dart';
import 'package:tradeiq_app/features/incentives/data/incentives_view.dart';
import 'package:tradeiq_app/features/incentives/presentation/incentives_screen.dart';

import '../../core/design/amber_golden.dart';
import '../worklist_harness.dart';

IncentiveScheme _scheme({
  String id = 's-1',
  String name = 'Twenty visits',
  String metric = 'visits',
  double threshold = 20,
  int rewardPoints = 250,
  bool active = true,
}) => IncentiveScheme(
  id: id,
  name: name,
  metric: metric,
  threshold: threshold,
  rewardPoints: rewardPoints,
  active: active,
);

LeaderboardEntry _agent({
  String agentId = 'a-1',
  String name = 'Thandi Mokoena',
  int visits = 14,
  int tasks = 3,
  double avg = 85,
  int scored = 6,
}) => LeaderboardEntry(
  agentId: agentId,
  email: '$agentId@acme.test',
  displayName: name,
  visitsSubmitted: visits,
  tasksClosed: tasks,
  rank: 1,
  avgScorecard: avg,
  scorecardsCounted: scored,
  points: 94,
);

class _FakeIncentives implements IncentivesRepository {
  _FakeIncentives({
    this.schemes = const <IncentiveScheme>[],
    this.failure,
    this.pending = false,
    this.writeFailure,
  });

  final List<IncentiveScheme> schemes;
  final Object? failure;
  final bool pending;
  final Object? writeFailure;

  final List<({String id, bool active})> toggled =
      <({String id, bool active})>[];
  final List<String> deleted = <String>[];
  final List<({String name, String metric, double threshold, int reward})>
  created = <({String name, String metric, double threshold, int reward})>[];

  @override
  Future<PaginatedResponse<IncentiveScheme>> listSchemes() async {
    if (failure != null) throw failure!;
    if (pending) return Completer<PaginatedResponse<IncentiveScheme>>().future;
    return PaginatedResponse<IncentiveScheme>(data: schemes, nextCursor: null);
  }

  @override
  Future<IncentiveScheme> createScheme({
    required String name,
    required String metric,
    required double threshold,
    required int rewardPoints,
  }) async {
    created.add((
      name: name,
      metric: metric,
      threshold: threshold,
      reward: rewardPoints,
    ));
    if (writeFailure != null) throw writeFailure!;
    return _scheme(name: name, metric: metric, threshold: threshold);
  }

  @override
  Future<void> deleteScheme(String id) async {
    deleted.add(id);
    if (writeFailure != null) throw writeFailure!;
  }

  @override
  Future<IncentiveScheme> setActive(String id, bool active) async {
    toggled.add((id: id, active: active));
    if (writeFailure != null) throw writeFailure!;
    return _scheme(id: id, active: active);
  }

  @override
  Future<List<EarnedIncentive>> earned() async => const <EarnedIncentive>[];
}

class _FakeGamification implements GamificationRepository {
  _FakeGamification({
    this.board = const <LeaderboardEntry>[],
    this.fails = false,
  });

  final List<LeaderboardEntry> board;
  final bool fails;

  @override
  Future<List<LeaderboardEntry>> leaderboard() async {
    if (fails) throw StateError('board is down');
    return board;
  }

  @override
  Future<AgentPointsHistory> agentPoints(String agentId) async =>
      throw UnimplementedError();
}

Future<_FakeIncentives> _pump(
  WidgetTester tester, {
  List<IncentiveScheme> schemes = const <IncentiveScheme>[],
  List<LeaderboardEntry> board = const <LeaderboardEntry>[],
  bool boardFails = false,
  Object? failure,
  Object? writeFailure,
  bool pending = false,
  TiqSkin? skin,
  double textScale = 1.0,
  Size size = const Size(360, 720),
  Locale? locale,
}) async {
  final repo = _FakeIncentives(
    schemes: schemes,
    failure: failure,
    pending: pending,
    writeFailure: writeFailure,
  );
  await pumpWorklist(
    tester,
    const IncentivesScreen(),
    skin: skin,
    size: size,
    textScale: textScale,
    locale: locale,
    path: '/incentives',
    settle: !pending,
    overrides: <Override>[
      incentivesRepositoryProvider.overrideWithValue(repo),
      gamificationRepositoryProvider.overrideWithValue(
        _FakeGamification(board: board, fails: boardFails),
      ),
    ],
  );
  return repo;
}

void main() {
  group('the view model', () {
    test('ranks who is closest to the reward, earners after them', () {
      final view = IncentivesView(
        rows: <IncentiveSchemeRow>[],
        agentsMeasured: 0,
      );
      expect(view.rows, isEmpty);
    });

    test('an average nobody has scored is not a zero', () {
      // `mean([])` is 0 on the wire, so a bar drawn from it would tell an
      // agent they had made no progress when nobody has measured them.
      final unmeasured = _agent(avg: 0, scored: 0);
      expect(
        IncentiveMetric.valueFor(IncentiveMetric.scorecard, unmeasured),
        isNull,
      );
      final measured = _agent(avg: 0, scored: 4);
      expect(IncentiveMetric.valueFor(IncentiveMetric.scorecard, measured), 0);
    });

    test(
      'a count of nought IS a zero — nothing closed is a measured nothing',
      () {
        expect(
          IncentiveMetric.valueFor(
            IncentiveMetric.tasksClosed,
            _agent(tasks: 0),
          ),
          0,
        );
      },
    );

    test('a metric this client has not been taught is not renamed away', () {
      expect(IncentiveMetric.fromWire('visits'), IncentiveMetric.visits);
      expect(IncentiveMetric.fromWire('spend'), isNull);
    });

    test('progress has no fraction where the figure is unknown', () {
      const progress = IncentiveProgress(
        agentId: 'a',
        name: 'A',
        value: null,
        threshold: 20,
      );
      expect(progress.earned, isFalse);
      expect(progress.remaining, isNull);
    });
  });

  group('the progress-to-reward bar', () {
    testWidgets('names the reward on the bar, and who is closest to it', (
      tester,
    ) async {
      await _pump(
        tester,
        schemes: <IncentiveScheme>[_scheme()],
        board: <LeaderboardEntry>[
          _agent(visits: 14),
          _agent(agentId: 'a-2', name: 'Busi Dlamini', visits: 3),
        ],
      );

      final bar = tester.widget<TorchProgressBar>(
        find.byKey(const ValueKey<String>('scheme-bar-s-1')),
      );
      expect(bar.label, 'Closest: Thandi Mokoena');
      expect(bar.value, 14);
      expect(bar.total, 20);
      // A bar with no reward on it is a progress bar, not a reward bar.
      expect(bar.milestones.single.reward, isTrue);
      expect(bar.milestones.single.label, '250 pts at 20 visits');
      // The fraction is always text; the bar is never the only statement.
      expect(bar.fractionText, '14 of 20 visits');
    });

    testWidgets('the closest is the one on the way, not the one who won', (
      tester,
    ) async {
      await _pump(
        tester,
        schemes: <IncentiveScheme>[_scheme()],
        board: <LeaderboardEntry>[
          _agent(agentId: 'a-earned', name: 'Sipho Ndlovu', visits: 40),
          _agent(agentId: 'a-close', name: 'Thandi Mokoena', visits: 19),
        ],
      );

      final bar = tester.widget<TorchProgressBar>(
        find.byKey(const ValueKey<String>('scheme-bar-s-1')),
      );
      expect(bar.label, 'Closest: Thandi Mokoena');
      expect(
        find.textContaining('1 of 2 agents have earned it.'),
        findsOneWidget,
      );
    });

    testWidgets('nobody on the way says so rather than drawing an empty bar', (
      tester,
    ) async {
      await _pump(
        tester,
        schemes: <IncentiveScheme>[_scheme()],
        board: <LeaderboardEntry>[_agent(visits: 40)],
      );

      expect(find.byType(TorchProgressBar), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('scheme-nobody-close-s-1')),
        findsOneWidget,
      );
    });

    testWidgets('no board means no bar, never a bar out of an invented total', (
      tester,
    ) async {
      await _pump(
        tester,
        schemes: <IncentiveScheme>[_scheme()],
        boardFails: true,
      );

      expect(find.byType(TorchProgressBar), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('scheme-no-board-s-1')),
        findsOneWidget,
      );
      // And the scheme is still listed and still administrable.
      expect(find.text('Twenty visits'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('toggle-s-1')), findsOneWidget);
    });

    testWidgets('an unrecognised metric says so rather than drawing a bar', (
      tester,
    ) async {
      await _pump(
        tester,
        schemes: <IncentiveScheme>[_scheme(metric: 'spend')],
        board: <LeaderboardEntry>[_agent()],
      );

      expect(find.byType(TorchProgressBar), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('scheme-unknown-metric-s-1')),
        findsOneWidget,
      );
      // The key is shown, not renamed and not hidden.
      expect(find.textContaining('spend'), findsWidgets);
    });

    testWidgets('an unmeasured agent gets words, never a bar at nought', (
      tester,
    ) async {
      await _pump(
        tester,
        schemes: <IncentiveScheme>[_scheme(metric: 'scorecard', threshold: 80)],
        board: <LeaderboardEntry>[
          _agent(agentId: 'a-1', name: 'Thandi Mokoena', avg: 72, scored: 5),
          _agent(agentId: 'a-2', name: 'Sipho Ndlovu', avg: 0, scored: 0),
        ],
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('scheme-everyone-s-1')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('scheme-progress-a-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('scheme-unmeasured-a-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('scheme-progress-a-2')),
        findsNothing,
      );
    });
  });

  group('the denominator is who the metric measures', () {
    testWidgets('a metric that can measure nobody counts nobody', (
      tester,
    ) async {
      // A client whose scorecards have not run this window. Eleven agents are
      // on the board and the scorecard metric can answer for none of them.
      // "0 of 11 agents have earned it" is eleven people who failed; nobody
      // was measured. That is the invented total this screen is written
      // against.
      await _pump(
        tester,
        schemes: <IncentiveScheme>[_scheme(metric: 'scorecard', threshold: 80)],
        board: <LeaderboardEntry>[
          for (var i = 0; i < 11; i++)
            _agent(agentId: 'a-$i', name: 'Agent $i', avg: 0, scored: 0),
        ],
      );

      expect(find.textContaining('of 11'), findsNothing);
      expect(find.textContaining('earned it.'), findsNothing);
      expect(find.textContaining('Nobody is on the way'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('scheme-none-measured-s-1')),
        findsOneWidget,
      );
      expect(find.byType(TorchProgressBar), findsNothing);
      // The board answered, so this is not the no-board panel.
      expect(
        find.byKey(const ValueKey<String>('scheme-no-board-s-1')),
        findsNothing,
      );
    });

    testWidgets('an unmeasurable agent is not counted into the fraction', (
      tester,
    ) async {
      await _pump(
        tester,
        schemes: <IncentiveScheme>[_scheme(metric: 'scorecard', threshold: 80)],
        board: <LeaderboardEntry>[
          _agent(agentId: 'a-1', name: 'Thandi Mokoena', avg: 91, scored: 5),
          _agent(agentId: 'a-2', name: 'Busi Dlamini', avg: 64, scored: 4),
          _agent(agentId: 'a-3', name: 'Sipho Ndlovu', avg: 0, scored: 0),
          _agent(agentId: 'a-4', name: 'Lerato Khoza', avg: 0, scored: 0),
        ],
      );

      expect(
        find.textContaining('1 of 2 agents have earned it.'),
        findsOneWidget,
      );
      expect(find.textContaining('of 4'), findsNothing);
    });

    testWidgets('the sheet does not count the rows it calls unmeasured', (
      tester,
    ) async {
      // The contradiction at its plainest: four rows each saying "Not measured
      // on this metric yet", and a footer counting all four.
      await _pump(
        tester,
        schemes: <IncentiveScheme>[_scheme(metric: 'scorecard', threshold: 80)],
        board: <LeaderboardEntry>[
          for (var i = 0; i < 4; i++)
            _agent(agentId: 'a-$i', name: 'Agent $i', avg: 0, scored: 0),
        ],
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('scheme-everyone-s-1')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Not measured on this metric'), findsNWidgets(4));
      expect(find.textContaining('of 4'), findsNothing);
      expect(find.textContaining('earned it.'), findsNothing);
      expect(
        find.textContaining('has been measured on this metric'),
        findsOneWidget,
      );
    });

    testWidgets('the sheet counts the measurable ones, and only those', (
      tester,
    ) async {
      await _pump(
        tester,
        schemes: <IncentiveScheme>[_scheme(metric: 'scorecard', threshold: 80)],
        board: <LeaderboardEntry>[
          _agent(agentId: 'a-1', name: 'Thandi Mokoena', avg: 91, scored: 5),
          _agent(agentId: 'a-2', name: 'Busi Dlamini', avg: 64, scored: 4),
          _agent(agentId: 'a-3', name: 'Sipho Ndlovu', avg: 0, scored: 0),
        ],
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('scheme-everyone-s-1')),
      );
      await tester.pumpAndSettle();

      // The sheet's own footer, and the list behind it, say the same thing.
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('scheme-progress-earned')),
            )
            .data,
        '1 of 2 agents have earned it.',
      );
      expect(find.textContaining('of 3'), findsNothing);
      // Every agent is still listed — the unmeasured one is stated, not
      // dropped. Only the counting changed.
      expect(find.text('Sipho Ndlovu'), findsOneWidget);
    });

    test('the row knows how many of its own figures exist', () {
      IncentiveProgress p(String id, double? value) => IncentiveProgress(
        agentId: id,
        name: id,
        value: value,
        threshold: 80,
      );
      final none = IncentiveSchemeRow(
        scheme: _scheme(metric: 'scorecard', threshold: 80),
        metric: IncentiveMetric.scorecard,
        progress: <IncentiveProgress>[p('a', null), p('b', null)],
      );
      expect(none.measuredCount, 0);
      expect(none.nobodyMeasured, isTrue);

      final some = IncentiveSchemeRow(
        scheme: _scheme(metric: 'scorecard', threshold: 80),
        metric: IncentiveMetric.scorecard,
        progress: <IncentiveProgress>[p('a', 91), p('b', 40), p('c', null)],
      );
      expect(some.measuredCount, 2);
      expect(some.nobodyMeasured, isFalse);
      expect(some.earnedCount, 1);
    });
  });

  group('the state is a word, never a fill step alone', () {
    testWidgets('a paused scheme says Paused and an awarding one says so', (
      tester,
    ) async {
      await _pump(
        tester,
        schemes: <IncentiveScheme>[
          _scheme(),
          _scheme(id: 's-2', name: 'Ten closures', active: false),
        ],
        board: <LeaderboardEntry>[_agent()],
      );

      // The word leads the row's own reason line, so the state survives
      // greyscale, deuteranopia and a screen reader without the control.
      expect(
        find.textContaining('Awarding · Visits submitted'),
        findsOneWidget,
      );
      await scrollWorklistTo(tester, find.textContaining('Paused ·'));
      expect(find.textContaining('Paused · Visits submitted'), findsOneWidget);
    });

    testWidgets('the control keeps a node a screen reader can activate', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        schemes: <IncentiveScheme>[_scheme()],
        board: <LeaderboardEntry>[_agent()],
      );

      // A row excludes what is beneath it, so a control that is not declared
      // as one is a scheme a TalkBack manager cannot pause.
      final node = tester.getSemantics(
        find.bySemanticsLabel('Pause Twenty visits'),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets('pausing a scheme sends the change', (tester) async {
      final repo = await _pump(
        tester,
        schemes: <IncentiveScheme>[_scheme()],
        board: <LeaderboardEntry>[_agent()],
      );

      await tester.tap(find.byKey(const ValueKey<String>('toggle-s-1')));
      await tester.pumpAndSettle();

      expect(repo.toggled.single.id, 's-1');
      expect(repo.toggled.single.active, isFalse);
    });
  });

  group('deleting a scheme', () {
    testWidgets('asks first, and names what it costs', (tester) async {
      final repo = await _pump(
        tester,
        schemes: <IncentiveScheme>[_scheme()],
        board: <LeaderboardEntry>[_agent(visits: 40)],
      );

      await tester.tap(find.byKey(const ValueKey<String>('delete-s-1')));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmSheet), findsOneWidget);
      expect(
        find.textContaining('It stops awarding immediately.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('1 agent has earned it so far.'),
        findsOneWidget,
      );
      // Nothing is destroyed on the way to the question.
      expect(repo.deleted, isEmpty);
    });

    testWidgets('the commit deletes it', (tester) async {
      final repo = await _pump(
        tester,
        schemes: <IncentiveScheme>[_scheme()],
        board: <LeaderboardEntry>[_agent()],
      );

      await tester.tap(find.byKey(const ValueKey<String>('delete-s-1')));
      await tester.pumpAndSettle();
      // Scoped to the sheet: the row behind it carries the same verb, and the
      // one that destroys something is the one inside the confirm.
      final commit = find.descendant(
        of: find.byType(ConfirmSheet),
        matching: find.text('Delete this scheme'),
      );
      await scrollSheetTo(tester, commit);
      await tester.tap(commit);
      await tester.pumpAndSettle();

      expect(repo.deleted.single, 's-1');
    });
  });

  group('adding a scheme is a sheet, not a dialog', () {
    Future<_FakeIncentives> openForm(
      WidgetTester tester, {
      Object? writeFailure,
    }) async {
      final repo = await _pump(
        tester,
        schemes: <IncentiveScheme>[_scheme()],
        board: <LeaderboardEntry>[_agent()],
        writeFailure: writeFailure,
      );
      await tester.tap(find.text('Add a scheme'));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('the one modal container carries the form', (tester) async {
      await openForm(tester);

      expect(find.byType(TorchSheet), findsOneWidget);
      // `AlertDialog` is deleted outright (unify §1.7).
      expect(find.byType(ChoiceRow<IncentiveMetric>), findsOneWidget);
      expect(find.text('No metric chosen yet'), findsOneWidget);
    });

    testWidgets('the commit is blocked until the form is answerable', (
      tester,
    ) async {
      final repo = await openForm(tester);

      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('create-scheme')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('create-scheme')));
      await tester.pumpAndSettle();

      expect(repo.created, isEmpty);
      expect(
        find.textContaining('A scheme needs a name, a metric'),
        findsOneWidget,
      );
    });

    testWidgets('a filled form creates the scheme under the wire metric', (
      tester,
    ) async {
      final repo = await openForm(tester);

      await tester.enterText(
        find.byKey(const ValueKey<String>('new-name')),
        'Thirty visits',
      );
      await tester.pumpAndSettle();
      await scrollSheetTo(tester, find.text('Visits submitted'));
      await tester.tap(find.text('Visits submitted'));
      await tester.pumpAndSettle();
      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('new-threshold')),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('new-threshold')),
        '30',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('new-reward-points')),
        '500',
      );
      await tester.pumpAndSettle();
      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('create-scheme')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('create-scheme')));
      await tester.pumpAndSettle();

      expect(repo.created.single.name, 'Thirty visits');
      // The screen word is "Visits submitted"; `visits` is what the engine
      // knows, and the mapping happens once.
      expect(repo.created.single.metric, 'visits');
      expect(repo.created.single.threshold, 30);
      expect(repo.created.single.reward, 500);
    });

    testWidgets('a failure keeps the sheet and what was typed', (tester) async {
      await openForm(
        tester,
        writeFailure: StateError('SocketException: api.tradeiq.co.za'),
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('new-name')),
        'Thirty visits',
      );
      await tester.pumpAndSettle();
      await scrollSheetTo(tester, find.text('Visits submitted'));
      await tester.tap(find.text('Visits submitted'));
      await tester.pumpAndSettle();
      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('new-threshold')),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('new-threshold')),
        '30',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('new-reward-points')),
        '500',
      );
      await tester.pumpAndSettle();
      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('create-scheme')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('create-scheme')));
      await tester.pumpAndSettle();

      // A form that closes and loses four fields is a form nobody retries.
      expect(find.byType(TorchSheet), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('new-scheme-failure')),
        findsOneWidget,
      );
    });
  });

  group('the states', () {
    testWidgets('loading is a skeleton', (tester) async {
      await _pump(tester, pending: true);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(Skeleton), findsOneWidget);
    });

    testWidgets('an empty list says nothing pays out until there is one', (
      tester,
    ) async {
      await _pump(tester);

      expect(
        find.byKey(const ValueKey<String>('incentives-empty')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Nothing pays out until there is a scheme.'),
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
        find.byKey(const ValueKey<String>('incentives-retry')),
        findsOneWidget,
      );
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
      'loaded': (t) => _pump(
        t,
        schemes: <IncentiveScheme>[
          _scheme(),
          _scheme(id: 's-2', name: 'Ten closures', active: false),
        ],
        board: <LeaderboardEntry>[
          _agent(),
          _agent(agentId: 'a-2', visits: 40),
        ],
      ),
      'empty': (t) => _pump(t),
      'error': (t) =>
          _pump(t, failure: StateError('SocketException: api.tradeiq.co.za')),
      'no-board': (t) =>
          _pump(t, schemes: <IncentiveScheme>[_scheme()], boardFails: true),
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
        'loaded': (t) => _pump(
          t,
          skin: skin,
          schemes: <IncentiveScheme>[
            _scheme(),
            _scheme(id: 's-2', name: 'Ten closures', active: false),
          ],
          board: <LeaderboardEntry>[
            _agent(),
            _agent(agentId: 'a-2', visits: 40),
          ],
        ),
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
        'no-board': (t) => _pump(
          t,
          skin: skin,
          schemes: <IncentiveScheme>[_scheme()],
          boardFails: true,
        ),
      };
      for (final phase in phases.entries) {
        testWidgets('${skin.mode.name}, ${phase.key}: $lit', (tester) async {
          await phase.value(tester);
          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'incentives',
            phase: phase.key,
          );
          expect(census.objectCount, lit, reason: census.describe());
        });
      }
    }

    testWidgets('a reached reward turns the bar good, never amber', (
      tester,
    ) async {
      // The most motivating object an agent sees, and therefore the most
      // tempting thing in the product to light. The near-reward amber
      // exception was written, argued and deleted.
      await _pump(
        tester,
        schemes: <IncentiveScheme>[_scheme()],
        board: <LeaderboardEntry>[
          _agent(visits: 19),
          _agent(agentId: 'a-2', name: 'Busi Dlamini', visits: 40),
        ],
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('scheme-everyone-s-1')),
      );
      await tester.pumpAndSettle();

      final census = await amberCensus(tester);
      expect(census.objectCount, 0, reason: census.describe());
    });
  });

  group('2.0x text and Afrikaans', () {
    testWidgets('nothing overflows at 2.0x', (tester) async {
      await _pump(
        tester,
        textScale: 2.0,
        schemes: <IncentiveScheme>[_scheme()],
        board: <LeaderboardEntry>[_agent()],
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('nothing overflows at 320dp in Afrikaans', (tester) async {
      await _pump(
        tester,
        size: const Size(320, 640),
        locale: const Locale('af'),
        schemes: <IncentiveScheme>[_scheme()],
        board: <LeaderboardEntry>[_agent()],
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Veld is built and the reward is still named', (tester) async {
      await _pump(
        tester,
        skin: TiqSkin.veld(),
        schemes: <IncentiveScheme>[_scheme()],
        board: <LeaderboardEntry>[_agent()],
      );

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('scheme-bar-s-1')),
      );
      final bar = tester.widget<TorchProgressBar>(
        find.byKey(const ValueKey<String>('scheme-bar-s-1')),
      );
      expect(bar.milestones.single.label, '250 pts at 20 visits');
      expect(tester.takeException(), isNull);
    });
  });
}

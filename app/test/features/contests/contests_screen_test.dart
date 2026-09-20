import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart' show GoRouterWidgetBuilder;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/contests/data/contests_repository.dart';
import 'package:tradeiq_app/features/contests/presentation/contest_standings_screen.dart';
import 'package:tradeiq_app/features/contests/presentation/contests_screen.dart';

import '../../core/design/amber_golden.dart';
import '../clientadmin_harness.dart';
import 'contests_fakes.dart';

FakeContestsRepository _repo() => FakeContestsRepository(
  contests: const <Contest>[
    activeContest,
    upcomingContest,
    endedContest,
    cancelledContest,
  ],
  standingsById: const <String, ContestStandings>{
    'c-active': ContestStandings(
      contest: activeContest,
      participantCount: 2,
      standings: <ContestStanding>[aisha, bongani],
    ),
  },
);

Future<FakeContestsRepository> _pump(
  WidgetTester tester, {
  FakeContestsRepository? repo,
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
  bool settle = true,
}) async {
  final fake = repo ?? _repo();
  await pumpConsole(
    tester,
    const ContestsScreen(),
    skin: skin,
    textScale: textScale,
    locale: locale,
    settle: settle,
    path: '/contests',
    overrides: <Override>[
      contestsRepositoryProvider.overrideWithValue(fake),
      sessionAs('manager'),
    ],
    // The real standings screen, so "a row opens its standings" is the real
    // navigation and not a stub that would pass whatever the row did.
    routes: <String, GoRouterWidgetBuilder>{
      '/contests/:id': (context, state) => const ContestStandingsScreen(
        contestId: 'c-active',
      ),
    },
  );
  return fake;
}

void main() {
  group('the list', () {
    testWidgets('each row offers only what its status allows', (tester) async {
      await _pump(tester, textScale: 1.0);

      await scrollConsoleTo(tester, keyed('contest-c-active'));
      expect(
        find.text(
          '2026-10-01 → 2026-10-31 · All territories · '
          'Visits submitted, Tasks closed',
        ),
        findsOneWidget,
      );
      expect(find.text('3 days left'), findsOneWidget);

      // Active: edit, cancel. Upcoming: edit, cancel, delete.
      expect(keyed('contest-edit-c-active'), findsOneWidget);
      expect(keyed('contest-cancel-c-active'), findsOneWidget);
      expect(keyed('contest-delete-c-active'), findsNothing);

      await scrollConsoleTo(tester, keyed('contest-c-upcoming'));
      expect(keyed('contest-edit-c-upcoming'), findsOneWidget);
      expect(keyed('contest-cancel-c-upcoming'), findsOneWidget);
      expect(keyed('contest-delete-c-upcoming'), findsOneWidget);
      expect(
        find.text('2026-11-01 → 2026-11-30 · North · All points'),
        findsOneWidget,
      );

      // Ended: edit only. Cancelled: delete only.
      await scrollConsoleTo(tester, keyed('contest-c-ended'));
      expect(keyed('contest-edit-c-ended'), findsOneWidget);
      expect(keyed('contest-cancel-c-ended'), findsNothing);
      expect(keyed('contest-delete-c-ended'), findsNothing);

      await scrollConsoleTo(tester, keyed('contest-c-cancelled'));
      expect(keyed('contest-edit-c-cancelled'), findsNothing);
      expect(keyed('contest-cancel-c-cancelled'), findsNothing);
      expect(keyed('contest-delete-c-cancelled'), findsOneWidget);
    });

    testWidgets('the section rule counts what it is showing', (tester) async {
      await _pump(tester);
      expect(find.byType(SectionRule), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('a status is a word and a silhouette, never a hue alone', (
      tester,
    ) async {
      await _pump(tester);
      await scrollConsoleTo(tester, keyed('contest-c-active'));

      final chips = tester
          .widgetList<StatusChip>(find.byType(StatusChip))
          .toList();
      expect(chips.map((c) => c.label), contains('Active'));
      // A running contest is the only `live` one; the rest are Oatmeal and a
      // square, because ending or being cancelled is not a fault.
      final active = chips.firstWhere((c) => c.label == 'Active');
      expect(active.level, StatusLevel.live);

      await scrollConsoleTo(tester, keyed('contest-c-cancelled'));
      final cancelled = tester
          .widgetList<StatusChip>(find.byType(StatusChip))
          .firstWhere((c) => c.label == 'Cancelled');
      expect(cancelled.level, StatusLevel.held);
    });

    testWidgets('the row verbs are nodes, not only pixels', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      await scrollConsoleTo(tester, keyed('contest-c-active'));

      // `meta` is inside the row's excluded label, so a button there would be
      // painted and announced nowhere. The verbs live in `actions`.
      expect(
        find.bySemanticsLabel('Edit'),
        findsWidgets,
        reason: 'the Edit verb has no semantics node',
      );
      expect(find.bySemanticsLabel('Cancel'), findsWidgets);
      handle.dispose();
    });

    testWidgets("the row's own tap carries a tap action, not just a flag", (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      await scrollConsoleTo(tester, keyed('contest-c-active'));

      final node = tester.getSemantics(keyed('contest-c-active'));
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason:
            'a row a screen reader can focus and cannot activate is the bug '
            'the kit already had once',
      );
      handle.dispose();
    });

    testWidgets('a row opens its standings', (tester) async {
      await _pump(tester);
      await scrollConsoleTo(tester, keyed('contest-c-active'));

      await tester.tap(find.text('October Sprint'));
      await tester.pumpAndSettle();
      await scrollConsoleTo(tester, find.text('Aisha Patel'));
      expect(find.text('Aisha Patel'), findsOneWidget);
    });

    testWidgets('New contest opens the form', (tester) async {
      await _pump(tester);
      await scrollConsoleTo(tester, keyed('contest-create'));
      await tester.tap(keyed('contest-create'));
      await tester.pumpAndSettle();
      expect(find.text('New contest'), findsOneWidget);
    });
  });

  group('destroying one', () {
    testWidgets('cancelling asks in a sheet, then calls the API', (
      tester,
    ) async {
      final repo = await _pump(tester);
      await scrollConsoleTo(tester, keyed('contest-cancel-c-active'));

      await tester.tap(keyed('contest-cancel-c-active'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmSheet), findsOneWidget);
      expect(find.text('Cancel “October Sprint”?'), findsOneWidget);
      // The record, so a manager can check they are cancelling the right one.
      expect(find.text('c-active'), findsOneWidget);

      await tester.tap(find.text('Cancel contest'));
      await tester.pumpAndSettle();
      expect(repo.calls, <String>['cancel:c-active']);
    });

    testWidgets('keeping it calls nothing', (tester) async {
      final repo = await _pump(tester);
      await scrollConsoleTo(tester, keyed('contest-delete-c-cancelled'));

      await tester.tap(keyed('contest-delete-c-cancelled'));
      await tester.pumpAndSettle();
      expect(find.text('Delete “Scrapped”?'), findsOneWidget);

      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
      expect(find.byType(ConfirmSheet), findsNothing);
    });

    testWidgets('a failure says so and the contest stays', (tester) async {
      final repo = FakeContestsRepository(
        contests: const <Contest>[activeContest],
        cancelFailure: StateError('SocketException: api.tradeiq.co.za'),
      );
      await _pump(tester, repo: repo);
      await scrollConsoleTo(tester, keyed('contest-cancel-c-active'));

      await tester.tap(keyed('contest-cancel-c-active'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel contest'));
      await tester.pumpAndSettle();

      expect(find.byType(TorchToast), findsOneWidget);
      // Sanitised: never the exception's own text, which one day carries a
      // host name into a screenshot in a WhatsApp group.
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(find.text('October Sprint'), findsOneWidget);
      await settleToasts(tester);
    });
  });

  group('the states', () {
    testWidgets('empty is a designed state, not a centred "No data"', (
      tester,
    ) async {
      await _pump(tester, repo: FakeContestsRepository());
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No contests yet.'), findsOneWidget);
      // The rule and its name still render: a section that vanishes when
      // empty makes a manager think the feature is gone.
      expect(find.byType(SectionRule), findsOneWidget);
      expect(find.byType(SoftRow), findsNothing);
    });

    testWidgets('loading is a skeleton, and nothing before 600ms', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: FakeContestsRepository(listPending: true),
        settle: false,
      );
      expect(find.byType(SkeletonRows), findsNothing);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(Skeleton), findsOneWidget);
    });

    testWidgets('a failure is sanitised and offers one retry', (tester) async {
      final repo = FakeContestsRepository(
        listFailure: StateError('SocketException: api.tradeiq.co.za'),
      );
      await _pump(tester, repo: repo);

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(keyed('contests-retry'), findsOneWidget);
    });
  });

  group('the amber census, every phase in every skin', () {
    for (final skin in <TiqSkin>[
      TiqSkin.night(),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      // Night paints the nav's active tab and nothing else: this route
      // nominates no content amber. Day and Veld have one rung — the primary
      // commit block — and this route has no primary.
      final lit = skin.mode == SkinMode.night ? 1 : 0;
      final phases = <String, Future<void> Function(WidgetTester)>{
        'loaded': (t) => _pump(t, skin: skin),
        'empty': (t) => _pump(t, skin: skin, repo: FakeContestsRepository()),
        'loading': (t) async {
          await _pump(
            t,
            skin: skin,
            repo: FakeContestsRepository(listPending: true),
            settle: false,
          );
          await t.pump(const Duration(milliseconds: 700));
        },
        'error': (t) => _pump(
          t,
          skin: skin,
          repo: FakeContestsRepository(listFailure: StateError('boom')),
        ),
      };
      for (final phase in phases.entries) {
        testWidgets('${skin.mode.name}, ${phase.key}: $lit', (tester) async {
          await phase.value(tester);
          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'contests',
            phase: phase.key,
          );
          expect(census.objectCount, lit, reason: census.describe());
        });
      }
    }

    testWidgets('beneath a sheet, Night goes out entirely', (tester) async {
      await _pump(tester);
      await scrollConsoleTo(tester, keyed('contest-cancel-c-active'));
      await tester.tap(keyed('contest-cancel-c-active'));
      await tester.pumpAndSettle();

      final census = await amberCensus(tester);
      expect(
        census.objectCount,
        0,
        reason:
            'while a sheet is up every amber on the route beneath it is '
            'extinguished.\n${census.describe()}',
      );
    });
  });

  group('2.0x text and Afrikaans lengths', () {
    testWidgets('the structure survives and nothing overflows', (tester) async {
      await _pump(tester, textScale: 2.0);
      expect(tester.takeException(), isNull);
      await scrollConsoleTo(tester, keyed('contest-c-active'));
      expect(find.byType(SoftRow), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an Afrikaans-length name at 2.0x does not overflow', (
      tester,
    ) async {
      await _pump(
        tester,
        textScale: 2.0,
        locale: const Locale('af'),
        repo: FakeContestsRepository(
          contests: const <Contest>[
            Contest(
              id: 'c-long',
              name: 'Kwartaalwedstryd vir die Bloemfontein-Noord-span',
              startDate: '2026-10-01',
              endDate: '2026-10-31',
              status: 'active',
              daysLeft: 3,
            ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      await scrollConsoleTo(tester, keyed('contest-c-long'));
      expect(tester.takeException(), isNull);
    });
  });
}

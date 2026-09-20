import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/contests/data/contests_repository.dart';
import 'package:tradeiq_app/features/contests/presentation/contest_standings_screen.dart';

import '../../core/design/amber_golden.dart';
import '../clientadmin_harness.dart';
import 'contests_fakes.dart';

FakeContestsRepository _repo() => FakeContestsRepository(
  standingsById: const <String, ContestStandings>{
    'c-active': ContestStandings(
      contest: activeContest,
      participantCount: 3,
      standings: <ContestStanding>[aisha, bongani, me],
    ),
  },
);

Future<void> _pump(
  WidgetTester tester, {
  FakeContestsRepository? repo,
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
  bool settle = true,
}) => pumpConsole(
  tester,
  const ContestStandingsScreen(contestId: 'c-active'),
  skin: skin,
  textScale: textScale,
  locale: locale,
  settle: settle,
  path: '/contests/c-active',
  overrides: <Override>[
    contestsRepositoryProvider.overrideWithValue(repo ?? _repo()),
    sessionAs('manager'),
  ],
);

void main() {
  group('the contest, then every agent', () {
    testWidgets('the facts are stated, and the missing one says so', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('October Sprint'), findsWidgets);
      expect(find.text('Most points in October wins.'), findsOneWidget);
      expect(find.text('2026-10-01 → 2026-10-31 (inclusive)'), findsOneWidget);
      expect(find.text('R500 voucher'), findsOneWidget);
      expect(find.text('All territories'), findsOneWidget);
      expect(find.text('Visits submitted, Tasks closed'), findsOneWidget);
    });

    testWidgets('a contest with no prize says so, never a blank', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: FakeContestsRepository(
          standingsById: const <String, ContestStandings>{
            'c-active': ContestStandings(
              contest: endedContest,
              participantCount: 0,
              standings: <ContestStanding>[],
            ),
          },
        ),
      );
      expect(find.text('None set'), findsOneWidget);
    });

    testWidgets('ties share a rank, and a name is a person not an id', (
      tester,
    ) async {
      await _pump(tester);
      await scrollConsoleTo(tester, keyed('standing-a-1'));

      expect(find.text('Aisha Patel'), findsOneWidget);
      // No display name: the sign-in address stands in, never a UUID.
      await scrollConsoleTo(tester, keyed('standing-a-2'));
      expect(find.text('bongani@example.com'), findsOneWidget);
      expect(find.text('a-2'), findsNothing);

      // Two agents on 14 points share rank 1.
      expect(find.text('1'), findsNWidgets(2));
      await scrollConsoleTo(tester, keyed('standing-a-me'));
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('a rank in a trailing slot is still announced', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      await scrollConsoleTo(tester, keyed('standing-a-1'));

      // A widget in `trailing` sits inside the row's excluded label. Without
      // `trailingLabel` the rank is painted and said nowhere.
      final node = tester.getSemantics(keyed('standing-a-1'));
      expect(
        node.label,
        contains('Rank 1'),
        reason: 'the rank is inside the row label: ${node.label}',
      );
      expect(node.label, contains('Aisha Patel'));
      handle.dispose();
    });

    testWidgets('a measured zero keeps its place', (tester) async {
      await _pump(
        tester,
        repo: FakeContestsRepository(
          standingsById: const <String, ContestStandings>{
            'c-active': ContestStandings(
              contest: activeContest,
              participantCount: 1,
              standings: <ContestStanding>[
                ContestStanding(
                  rank: 1,
                  agentId: 'a-0',
                  email: 'zero@example.com',
                  displayName: 'Zero Points',
                  points: 0,
                ),
              ],
            ),
          },
        ),
      );
      await scrollConsoleTo(tester, keyed('standing-a-0'));
      expect(find.text('Zero Points'), findsOneWidget);
      // A measured nought renders 0 — never an em dash, and never dropped.
      expect(find.text('0'), findsOneWidget);
    });
  });

  group('the states', () {
    testWidgets('nobody on the board is a designed empty state', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: FakeContestsRepository(
          standingsById: const <String, ContestStandings>{
            'c-active': ContestStandings(
              contest: activeContest,
              participantCount: 0,
              standings: <ContestStanding>[],
            ),
          },
        ),
      );
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Nobody on the board.'), findsOneWidget);
      expect(find.byType(PersonRow), findsNothing);
    });

    testWidgets('a failed load is sanitised and offers one retry', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: FakeContestsRepository(
          standingsFailure: StateError('SocketException: api.tradeiq.co.za'),
        ),
      );
      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(keyed('standings-retry'), findsOneWidget);
    });

    testWidgets('loading is a skeleton, and nothing before 600ms', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: FakeContestsRepository(standingsPending: true),
        settle: false,
      );
      expect(find.byType(SkeletonRows), findsNothing);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(Skeleton), findsOneWidget);
    });
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
          repo: FakeContestsRepository(
            standingsById: const <String, ContestStandings>{
              'c-active': ContestStandings(
                contest: activeContest,
                participantCount: 0,
                standings: <ContestStanding>[],
              ),
            },
          ),
        ),
        'loading': (t) async {
          await _pump(
            t,
            skin: skin,
            repo: FakeContestsRepository(standingsPending: true),
            settle: false,
          );
          await t.pump(const Duration(milliseconds: 700));
        },
        'error': (t) => _pump(
          t,
          skin: skin,
          repo: FakeContestsRepository(standingsFailure: StateError('boom')),
        ),
      };
      for (final phase in phases.entries) {
        testWidgets('${skin.mode.name}, ${phase.key}: $lit', (tester) async {
          await phase.value(tester);
          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'contest standings',
            phase: phase.key,
          );
          expect(census.objectCount, lit, reason: census.describe());
        });
      }
    }
  });

  group('2.0x text and Afrikaans lengths', () {
    testWidgets('a hyphenated name at 2.0x does not overflow', (tester) async {
      await _pump(
        tester,
        textScale: 2.0,
        locale: const Locale('af'),
        repo: FakeContestsRepository(
          standingsById: const <String, ContestStandings>{
            'c-active': ContestStandings(
              contest: activeContest,
              participantCount: 1,
              standings: <ContestStanding>[
                ContestStanding(
                  rank: 1,
                  agentId: 'a-long',
                  email: 'nomsa@example.com',
                  displayName: 'Nomsa Dlamini-Mkhize van der Westhuizen',
                  points: 1284,
                ),
              ],
            ),
          },
        ),
      );
      expect(tester.takeException(), isNull);
      await scrollConsoleTo(tester, keyed('standing-a-long'));
      expect(tester.takeException(), isNull);
    });
  });
}

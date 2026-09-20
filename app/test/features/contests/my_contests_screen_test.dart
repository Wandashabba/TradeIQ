import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/contests/data/contests_repository.dart';
import 'package:tradeiq_app/features/contests/presentation/my_contests_screen.dart';

import '../../core/design/amber_golden.dart';
import '../agent_harness.dart';
import 'contests_fakes.dart';

final List<CurrentContest> _current = <CurrentContest>[
  const CurrentContest(
    contest: activeContest,
    participantCount: 5,
    standings: <ContestStanding>[aisha, bongani, me],
    me: me,
  ),
  const CurrentContest(
    contest: endedContest,
    participantCount: 4,
    standings: <ContestStanding>[aisha],
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  FakeContestsRepository? repo,
  SkinMode skin = SkinMode.night,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
  bool settle = true,
}) async {
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);
  await pumpAgentScreen(
    tester,
    const MyContestsScreen(),
    path: '/leaderboard/contests',
    textScale: textScale,
    locale: locale,
    settle: settle,
    overrides: <Override>[
      ...agentBaseOverrides(db: db, skin: skin),
      contestsRepositoryProvider.overrideWithValue(
        repo ?? FakeContestsRepository(current: _current),
      ),
    ],
  );
}

Finder _keyed(String key) => find.byKey(ValueKey<String>(key));

/// Drag the agent's scroll view up until [finder] is on screen.
///
/// Fixed pumps, never `scrollUntilVisible` — which calls `pumpAndSettle` on
/// every step, and the drift trap in §12.7 is one stubbed provider away.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
    await dragAgentUp(tester);
  }
  expect(finder, findsWidgets, reason: 'never scrolled into view');
}

void main() {
  group('what is running, and what just ended', () {
    testWidgets('running first, then ended, each with its facts', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Contests'), findsOneWidget);
      expect(find.text('Running now'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('October Sprint')).dy,
        lessThan(tester.getTopLeft(find.text('Running now')).dy + 2000),
      );

      expect(find.text('3 days left'), findsOneWidget);
      expect(find.text('1 Oct – 31 Oct'), findsOneWidget);
      expect(find.text('R500 voucher'), findsOneWidget);
      expect(find.text('Submitted visits · Closed tasks'), findsOneWidget);

      // The section marker is the knocked-out rule at title.m in sentence
      // case — never the uppercase kicker the eyebrow used to be.
      expect(find.text('RUNNING NOW'), findsNothing);
      expect(find.byType(SectionRule), findsWidgets);
    });

    testWidgets('a running contest is live; an ended one is a square', (
      tester,
    ) async {
      await _pump(tester);
      final running = tester.widget<StatusChip>(_keyed('contest-when-c-active'));
      expect(running.level, StatusLevel.live);
      expect(running.label, '3 days left');

      await _scrollTo(tester, _keyed('contest-when-c-ended'));
      final ended = tester.widget<StatusChip>(_keyed('contest-when-c-ended'));
      expect(ended.level, StatusLevel.held);
      expect(ended.label, 'Ended');
    });

    testWidgets('the last day reads "1 day left"', (tester) async {
      await _pump(
        tester,
        repo: FakeContestsRepository(
          current: const <CurrentContest>[
            CurrentContest(
              contest: Contest(
                id: 'c-last',
                name: 'Final day',
                startDate: '2026-10-01',
                endDate: '2026-10-31',
                status: 'active',
                daysLeft: 1,
              ),
              participantCount: 1,
              standings: <ContestStanding>[me],
              me: me,
            ),
          ],
        ),
      );
      expect(find.text('1 day left'), findsOneWidget);
      expect(find.text('All points'), findsOneWidget);
    });
  });

  group('where the agent stands: unknown versus zero', () {
    testWidgets('a rank they have gets a figure, and the count beside it', (
      tester,
    ) async {
      await _pump(tester);
      await _scrollTo(tester, _keyed('contest-me-c-active'));

      expect(find.text('YOUR RANK'), findsWidgets);
      expect(find.text('3'), findsWidgets);
      expect(find.text('of 5 agents'), findsOneWidget);
      expect(find.text('7.5'), findsWidgets);
    });

    testWidgets('a rank they do not have is an em dash and a sentence', (
      tester,
    ) async {
      await _pump(tester);
      await _scrollTo(tester, _keyed('contest-me-c-ended'));

      // Never invented, never a 0, never a blank.
      expect(find.text(emDash), findsWidgets);
      expect(
        find.text('You’re not on this contest’s standings'),
        findsWidgets,
      );
      // And no count beside an absence.
      expect(find.text('of 4 agents'), findsNothing);
    });

    testWidgets('a measured nought keeps its place', (tester) async {
      await _pump(
        tester,
        repo: FakeContestsRepository(
          current: const <CurrentContest>[
            CurrentContest(
              contest: activeContest,
              participantCount: 1,
              standings: <ContestStanding>[
                ContestStanding(
                  rank: 1,
                  agentId: 'a-me',
                  email: 'me@example.com',
                  displayName: 'Thandi Mokoena',
                  points: 0,
                ),
              ],
              me: ContestStanding(
                rank: 1,
                agentId: 'a-me',
                email: 'me@example.com',
                displayName: 'Thandi Mokoena',
                points: 0,
              ),
            ),
          ],
        ),
      );
      await _scrollTo(tester, _keyed('contest-me-c-active'));
      expect(find.text('0'), findsWidgets);
      expect(find.text(emDash), findsNothing);
    });
  });

  group('the standings', () {
    testWidgets('ties share a rank and the agent’s own row says so', (
      tester,
    ) async {
      await _pump(tester);
      // No display name: the sign-in address stands in, never a UUID. The
      // row middle-truncates what it paints, so the whole address is asserted
      // where a screen reader gets it — which is the rule PersonRow states.
      final handle = tester.ensureSemantics();
      await _scrollTo(tester, _keyed('contest-standing-c-active-a-2'));
      final bongani = tester.getSemantics(
        _keyed('contest-standing-c-active-a-2'),
      );
      expect(bongani.label, contains('bongani@example.com'));
      expect(bongani.label, isNot(contains('a-2')));
      handle.dispose();

      final myRow = _keyed('contest-standing-c-active-a-me');
      await _scrollTo(tester, myRow);
      expect(
        find.descendant(of: myRow, matching: find.text('You')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: myRow, matching: find.text('7.5 pts')),
        findsOneWidget,
      );
    });

    testWidgets('a rank in a trailing slot is still announced', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      final myRow = _keyed('contest-standing-c-active-a-me');
      await _scrollTo(tester, myRow);

      final node = tester.getSemantics(myRow);
      expect(node.label, contains('You'));
      expect(node.label, contains('7.5 pts'));
      handle.dispose();
    });
  });

  group('the states', () {
    testWidgets('nothing current is a designed empty state', (tester) async {
      await _pump(tester, repo: FakeContestsRepository());
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No contests right now'), findsOneWidget);
      expect(find.byType(PersonRow), findsNothing);
    });

    testWidgets('a failed load says so and offers a retry', (tester) async {
      await _pump(tester, repo: FakeContestsRepository(failCurrent: true));
      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Couldn’t load contests'), findsOneWidget);
      expect(_keyed('contests-retry'), findsOneWidget);
    });
  });

  group('Afrikaans', () {
    testWidgets('every word on the screen is translated', (tester) async {
      await _pump(tester, locale: const Locale('af'));

      expect(find.text('Kompetisies'), findsOneWidget);
      expect(find.text('Loop nou'), findsOneWidget);
      expect(find.text('Nog 3 dae'), findsOneWidget);
      expect(find.text('Prys'), findsOneWidget);
      expect(find.text('Wat tel'), findsOneWidget);
      // An English string inside an Afrikaans screen is a defect.
      expect(find.text('Running now'), findsNothing);
      expect(find.text('Prize'), findsNothing);

      await _scrollTo(tester, _keyed('contest-me-c-active'));
      expect(find.text('JOU POSISIE'), findsWidgets);
      expect(find.text('uit 5 agente'), findsOneWidget);
    });

    testWidgets('the figures use the locale’s own decimal mark', (
      tester,
    ) async {
      await _pump(tester, locale: const Locale('af'));
      final myRow = _keyed('contest-standing-c-active-a-me');
      await _scrollTo(tester, myRow);
      // 7.5 on an English phone, 7,5 on an Afrikaans one — through the one
      // formatter, never `toStringAsFixed`.
      expect(
        find.descendant(of: myRow, matching: find.text('7,5 punte')),
        findsOneWidget,
      );
      expect(find.text('7.5 pts'), findsNothing);
    });
  });

  group('the amber census, every phase in every skin', () {
    for (final skin in <SkinMode>[
      SkinMode.night,
      SkinMode.day,
      SkinMode.veld,
    ]) {
      final resolved = switch (skin) {
        SkinMode.night => TiqSkin.night(),
        SkinMode.day => TiqSkin.day(),
        SkinMode.veld || SkinMode.auto => TiqSkin.veld(),
      };
      final phases = <String, Future<void> Function(WidgetTester)>{
        'loaded': (t) => _pump(t, skin: skin),
        'empty': (t) => _pump(t, skin: skin, repo: FakeContestsRepository()),
        'error': (t) =>
            _pump(t, skin: skin, repo: FakeContestsRepository(failCurrent: true)),
      };
      for (final phase in phases.entries) {
        testWidgets('${skin.name}, ${phase.key}: 0', (tester) async {
          await phase.value(tester);
          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            resolved,
            route: 'my contests',
            phase: phase.key,
          );
          expect(
            census.objectCount,
            0,
            reason:
                'nothing on this route is a commit: a contest is something an '
                'agent reads.\n${census.describe()}',
          );
        });
      }
    }
  });

  group('2.0x text', () {
    testWidgets('an Afrikaans screen at 2.0x does not overflow', (
      tester,
    ) async {
      await _pump(tester, textScale: 2.0, locale: const Locale('af'));
      expect(tester.takeException(), isNull);
      await _scrollTo(tester, _keyed('contest-me-c-active'));
      expect(tester.takeException(), isNull);
    });
  });
}

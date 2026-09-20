import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/contests/data/contests_repository.dart';
import 'package:tradeiq_app/features/contests/presentation/contest_form_screen.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';

import '../../core/design/amber_golden.dart';
import '../clientadmin_harness.dart';
import 'contests_fakes.dart';

String _fmt(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

Future<void> _pump(
  WidgetTester tester, {
  required FakeContestsRepository repo,
  Contest? contest,
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
  Object? territoriesFailure,
}) => pumpPushedConsole(
  tester,
  ContestFormScreen(contest: contest),
  skin: skin,
  textScale: textScale,
  locale: locale,
  path: '/contests',
  overrides: <Override>[
    contestsRepositoryProvider.overrideWithValue(repo),
    sessionAs('manager'),
    territoriesListProvider.overrideWith(
      (ref) async => territoriesFailure != null
          ? throw territoriesFailure
          : const <Territory>[Territory(id: 't-1', name: 'North', code: 'N1')],
    ),
  ],
);

void main() {
  group('creating', () {
    testWidgets('a week-long contest from today, by default', (tester) async {
      final repo = FakeContestsRepository();
      await _pump(tester, repo: repo);

      expect(find.text('New contest'), findsWidgets);

      await tester.enterText(keyed('contest-name-field'), '  Diwali Dash ');
      await scrollConsoleTo(tester, keyed('contest-prize-field'));
      await tester.enterText(keyed('contest-prize-field'), 'Airtime');
      await scrollConsoleTo(tester, keyed('contest-event-task_closed'));
      await tester.tap(keyed('contest-event-task_closed'));
      await tester.pumpAndSettle();
      await tester.tap(keyed('contest-event-visit_submitted'));
      await tester.pumpAndSettle();

      await tester.tap(keyed('contest-save-button'));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final input = repo.created!;
      expect(input.name, 'Diwali Dash');
      expect(input.prizeDescription, 'Airtime');
      expect(input.description, isNull);
      expect(input.territoryId, isNull);
      // Canonical order, not tick order.
      expect(input.eventTypes, <String>['visit_submitted', 'task_closed']);
      expect(input.startDate, _fmt(today));
      expect(input.endDate, _fmt(today.add(const Duration(days: 6))));
    });

    testWidgets('a name is required, and the trough says so', (tester) async {
      final repo = FakeContestsRepository();
      await _pump(tester, repo: repo);

      await tester.tap(keyed('contest-save-button'));
      await tester.pumpAndSettle();

      expect(find.text('A contest needs a name.'), findsOneWidget);
      expect(repo.created, isNull);

      // And it stops shouting once it is fixed.
      await tester.enterText(keyed('contest-name-field'), 'Diwali Dash');
      await tester.pumpAndSettle();
      expect(find.text('A contest needs a name.'), findsNothing);
    });

    testWidgets('nothing ticked says what that means', (tester) async {
      await _pump(tester, repo: FakeContestsRepository());
      await scrollConsoleTo(tester, keyed('contest-event-note'));
      expect(
        find.text(
          'Nothing ticked counts all points. Tick kinds to count only those.',
        ),
        findsOneWidget,
      );

      await tester.tap(keyed('contest-event-scorecard'));
      await tester.pumpAndSettle();
      expect(
        find.text('Counts only the ticked kinds of points.'),
        findsOneWidget,
      );
    });

    testWidgets('a failed save keeps everything typed and says why', (
      tester,
    ) async {
      final repo = FakeContestsRepository(
        saveFailure: StateError('SocketException: api.tradeiq.co.za'),
      );
      await _pump(tester, repo: repo);

      await tester.enterText(keyed('contest-name-field'), 'Diwali Dash');
      await tester.pumpAndSettle();
      await tester.tap(keyed('contest-save-button'));
      await tester.pumpAndSettle();

      // The typed name is still there — the screen stayed up.
      expect(find.text('Diwali Dash'), findsOneWidget);
      await scrollConsoleTo(tester, keyed('contest-save-error'));
      expect(find.byType(ErrorState), findsWidgets);
      // Sanitised: the exception's own text never reaches a screenshot.
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
    });
  });

  group('editing', () {
    testWidgets('keeps the stored dates and can widen the territory', (
      tester,
    ) async {
      final repo = FakeContestsRepository(
        contests: const <Contest>[upcomingContest],
      );
      await _pump(tester, repo: repo, contest: upcomingContest);

      expect(find.text('November Push'), findsWidgets);
      await tester.enterText(keyed('contest-name-field'), 'November Blitz');
      await tester.pumpAndSettle();

      await scrollConsoleTo(tester, keyed('contest-start-date'));
      expect(find.text('2026-11-01'), findsOneWidget);
      await scrollConsoleTo(tester, keyed('contest-territory-field'));
      expect(find.text('North (N1)'), findsWidgets);

      await tester.tap(keyed('contest-territory-field'));
      await tester.pumpAndSettle();
      await tester.tap(keyed('territory-option-all'));
      await tester.pumpAndSettle();

      await tester.tap(keyed('contest-save-button'));
      await tester.pumpAndSettle();

      expect(repo.updatedId, 'c-upcoming');
      final input = repo.updated!;
      expect(input.name, 'November Blitz');
      expect(input.territoryId, isNull);
      expect(input.startDate, '2026-11-01');
      expect(input.endDate, '2026-11-30');
      expect(input.eventTypes, isEmpty);
    });

    testWidgets('a territory list that will not load keeps the scope it has', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: FakeContestsRepository(
          contests: const <Contest>[upcomingContest],
        ),
        contest: upcomingContest,
        territoriesFailure: StateError('boom'),
      );
      await scrollConsoleTo(tester, keyed('contest-territory-error'));
      expect(
        find.text(
          'The territory list did not load, so the contest keeps the scope '
          'it has.',
        ),
        findsOneWidget,
      );
      // And the row is not operable, so a stale list cannot silently widen
      // the contest.
      final row = tester.widget<SoftRow>(keyed('contest-territory-field'));
      expect(row.onTap, isNull);
    });
  });

  group('the amber census, every phase in every skin', () {
    for (final skin in <TiqSkin>[
      TiqSkin.night(),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      testWidgets('${skin.mode.name}, editing: the save block, and only it', (
        tester,
      ) async {
        await _pump(tester, repo: FakeContestsRepository(), skin: skin);
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'contest form',
          phase: 'editing',
        );
        expect(
          census.objectCount,
          1,
          reason:
              'not a tab root and no nav, so the only lit object is the '
              'primary commit block.\n${census.describe()}',
        );
      });

      testWidgets('${skin.mode.name}, saving: nothing is armed', (
        tester,
      ) async {
        // A save that never resolves: the primary is busy, so nothing is
        // claimable and the frame goes dark.
        final repo = FakeContestsRepository(savePending: true);
        await _pump(tester, repo: repo, skin: skin);
        await tester.enterText(keyed('contest-name-field'), 'Diwali Dash');
        await tester.pumpAndSettle();
        await tester.tap(keyed('contest-save-button'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final census = await amberCensus(tester);
        expect(census.objectCount, 0, reason: census.describe());
      });
    }
  });

  group('2.0x text and Afrikaans lengths', () {
    testWidgets('the form survives and nothing overflows', (tester) async {
      await _pump(
        tester,
        repo: FakeContestsRepository(),
        textScale: 2.0,
        locale: const Locale('af'),
      );
      expect(tester.takeException(), isNull);
      await scrollConsoleTo(tester, keyed('contest-event-note'));
      expect(tester.takeException(), isNull);
    });
  });
}

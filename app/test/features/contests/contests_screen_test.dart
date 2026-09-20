import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/features/contests/data/contests_repository.dart';
import 'package:tradeiq_app/features/contests/presentation/contest_standings_screen.dart';
import 'package:tradeiq_app/features/contests/presentation/contests_screen.dart';

import 'contests_fakes.dart';

/// The list and its standings drill-down under real routes, as in app_router.
Widget _routed(FakeContestsRepository repo, {ThemeData? theme}) =>
    ProviderScope(
      overrides: [contestsRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(
        theme: theme,
        routerConfig: GoRouter(
          initialLocation: '/contests',
          routes: [
            GoRoute(
              path: '/contests',
              builder: (context, state) => const ContestsScreen(),
            ),
            GoRoute(
              path: '/contests/:id',
              builder: (context, state) => ContestStandingsScreen(
                contestId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
      ),
    );

FakeContestsRepository _repo() => FakeContestsRepository(
      contests: const [
        activeContest,
        upcomingContest,
        endedContest,
        cancelledContest,
      ],
      standingsById: const {
        'c-active': ContestStandings(
          contest: activeContest,
          participantCount: 2,
          standings: [aisha, bongani],
        ),
      },
    );

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder _key(String key) => find.byKey(ValueKey<String>(key));

void main() {
  for (final (label, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    testWidgets('$label: each row offers only what its status allows', (
      tester,
    ) async {
      _tallView(tester);
      await tester.pumpWidget(_routed(_repo(), theme: theme));
      await tester.pumpAndSettle();

      expect(find.text('4 contests'), findsOneWidget);
      expect(
        find.text(
          '2026-10-01 → 2026-10-31 · All territories · '
          'Visits submitted, Tasks closed',
        ),
        findsOneWidget,
      );
      expect(
        find.text('2026-11-01 → 2026-11-30 · North · All points'),
        findsOneWidget,
      );
      expect(find.text('3 days left'), findsOneWidget);

      // Active: edit, cancel. Upcoming: edit, cancel, delete.
      expect(_key('contest-edit-c-active'), findsOneWidget);
      expect(_key('contest-cancel-c-active'), findsOneWidget);
      expect(_key('contest-delete-c-active'), findsNothing);
      expect(_key('contest-edit-c-upcoming'), findsOneWidget);
      expect(_key('contest-cancel-c-upcoming'), findsOneWidget);
      expect(_key('contest-delete-c-upcoming'), findsOneWidget);
      // Ended: edit only. Cancelled: delete only.
      expect(_key('contest-edit-c-ended'), findsOneWidget);
      expect(_key('contest-cancel-c-ended'), findsNothing);
      expect(_key('contest-delete-c-ended'), findsNothing);
      expect(_key('contest-edit-c-cancelled'), findsNothing);
      expect(_key('contest-cancel-c-cancelled'), findsNothing);
      expect(_key('contest-delete-c-cancelled'), findsOneWidget);
    });

    testWidgets('$label: a row opens its standings, and Contests returns', (
      tester,
    ) async {
      _tallView(tester);
      await tester.pumpWidget(_routed(_repo(), theme: theme));
      await tester.pumpAndSettle();

      await tester.tap(find.text('October Sprint'));
      await tester.pumpAndSettle();

      expect(find.text('Contest standings'), findsOneWidget);
      expect(find.text('Aisha Patel'), findsOneWidget);

      await tester.tap(_key('standings-back-to-contests'));
      await tester.pumpAndSettle();
      expect(find.text('Contest standings'), findsNothing);
      expect(_key('contest-c-active'), findsOneWidget);
    });
  }

  testWidgets('cancelling asks first, then calls the API', (tester) async {
    _tallView(tester);
    final repo = _repo();
    await tester.pumpWidget(_routed(repo));
    await tester.pumpAndSettle();

    await tester.tap(_key('contest-cancel-c-active'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel “October Sprint”?'), findsOneWidget);

    await tester.tap(_key('contest-confirm-go'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['cancel:c-active']);
  });

  testWidgets('keeping it calls nothing', (tester) async {
    _tallView(tester);
    final repo = _repo();
    await tester.pumpWidget(_routed(repo));
    await tester.pumpAndSettle();

    await tester.tap(_key('contest-delete-c-cancelled'));
    await tester.pumpAndSettle();
    expect(find.text('Delete “Scrapped”?'), findsOneWidget);

    await tester.tap(_key('contest-confirm-keep'));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
    expect(find.text('Delete “Scrapped”?'), findsNothing);
  });

  testWidgets('the add button opens the form', (tester) async {
    _tallView(tester);
    await tester.pumpWidget(_routed(_repo(), theme: AppTheme.light()));
    await tester.pumpAndSettle();

    await tester.tap(_key('contest-create-fab'));
    await tester.pumpAndSettle();
    expect(find.text('New Contest'), findsOneWidget);
  });

  testWidgets('no contests: an empty state that says what they are for', (
    tester,
  ) async {
    await tester.pumpWidget(_routed(FakeContestsRepository()));
    await tester.pumpAndSettle();

    expect(find.text('No contests yet'), findsOneWidget);
  });
}

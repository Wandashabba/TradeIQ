import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/features/contests/data/contests_repository.dart';
import 'package:tradeiq_app/features/contests/presentation/contest_standings_screen.dart';

import '../../helpers/routed_app.dart';
import 'contests_fakes.dart';

Widget _app(FakeContestsRepository repo, {ThemeData? theme}) => routedApp(
  const ContestStandingsScreen(contestId: 'c-active'),
  theme: theme,
  overrides: [contestsRepositoryProvider.overrideWithValue(repo)],
);

final _repo = FakeContestsRepository(
  standingsById: const {
    'c-active': ContestStandings(
      contest: activeContest,
      participantCount: 3,
      standings: [aisha, bongani, me],
    ),
  },
);

const _aishaLine = '14 pts · 2 visits · 2 tasks closed';

void main() {
  // Light and night are Lumen Glass; `null` is the flat dark palette.
  for (final (label, theme) in <(String, ThemeData?)>[
    ('light', AppTheme.light()),
    ('night', AppTheme.dark()),
    ('flat dark', null),
  ]) {
    testWidgets('$label: the contest, then every agent with ties sharing a '
        'rank', (tester) async {
      tester.view.physicalSize = const Size(1400, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(_repo, theme: theme));
      await tester.pumpAndSettle();

      expect(find.text('October Sprint'), findsOneWidget);
      expect(find.text('Most points in October wins.'), findsOneWidget);
      expect(find.text('2026-10-01 → 2026-10-31 (inclusive)'), findsOneWidget);
      expect(find.text('R500 voucher'), findsOneWidget);
      expect(find.text('All territories'), findsOneWidget);
      expect(find.text('Visits submitted, Tasks closed'), findsOneWidget);

      expect(find.text('3 agents'), findsOneWidget);
      expect(find.text('Aisha Patel'), findsOneWidget);
      // No display name: the email stands in.
      expect(find.text('bongani@example.com'), findsOneWidget);
      expect(
        find.textContaining(RegExp('^rank 1\$', caseSensitive: false)),
        findsNWidgets(2),
      );
      expect(
        find.textContaining(RegExp('^rank 3\$', caseSensitive: false)),
        findsOneWidget,
      );
      expect(find.text('7.5 pts · 1 visits · 1 tasks closed'), findsOneWidget);

      final style = tester.widget<Text>(find.text(_aishaLine)).style;
      if (theme?.extension<TiqColors>()?.glass ?? false) {
        expect(style!.fontFamily, LumenGlass.mono);
      } else {
        expect(style, isNull);
      }
    });
  }

  testWidgets('a failed load offers a retry', (tester) async {
    await tester.pumpWidget(_app(FakeContestsRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load standings'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

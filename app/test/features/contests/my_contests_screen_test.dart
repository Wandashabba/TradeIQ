import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/contests/data/contests_repository.dart';
import 'package:tradeiq_app/features/contests/presentation/my_contests_screen.dart';

import '../../helpers/routed_app.dart';
import 'contests_fakes.dart';

final _current = [
  const CurrentContest(
    contest: activeContest,
    participantCount: 5,
    standings: [aisha, bongani, me],
    me: me,
  ),
  const CurrentContest(
    contest: endedContest,
    participantCount: 4,
    standings: [aisha],
  ),
];

Widget _app(FakeContestsRepository repo, {ThemeData? theme, Locale? locale}) {
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);
  return routedApp(
    const MyContestsScreen(),
    theme: theme,
    locale: locale,
    overrides: [
      localDbProvider.overrideWithValue(db),
      syncStatusProvider.overrideWith((ref) => Stream.value(SyncStatus.empty)),
      contestsRepositoryProvider.overrideWithValue(repo),
    ],
  );
}

void main() {
  // Light and night are Lumen Glass; `null` is the flat dark palette.
  for (final (label, theme) in <(String, ThemeData?)>[
    ('light', AppTheme.light()),
    ('night', AppTheme.dark()),
    ('flat dark', null),
  ]) {
    testWidgets('$label: active then ended, with days left, prize, rank and '
        'standings', (tester) async {
      await tester.pumpWidget(
        _app(FakeContestsRepository(current: _current), theme: theme),
      );
      await tester.pumpAndSettle();

      expect(find.text('Contests'), findsOneWidget);
      expect(find.text('RUNNING NOW'), findsOneWidget);
      expect(find.text('RECENTLY ENDED'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('October Sprint')).dy,
        lessThan(tester.getTopLeft(find.text('September Cup')).dy),
      );

      expect(find.text('3 days left'), findsOneWidget);
      expect(find.text('Ended'), findsOneWidget);
      expect(find.text('1 Oct – 31 Oct'), findsOneWidget);
      expect(find.text('R500 voucher'), findsOneWidget);
      expect(find.text('Submitted visits · Closed tasks'), findsOneWidget);
      expect(find.text('Your rank: 3 of 5'), findsOneWidget);

      // Equal points share a rank; the agent's own row is tagged.
      final active = find.byKey(const ValueKey('contest-card-c-active'));
      expect(
        find.descendant(of: active, matching: find.text('#1')),
        findsNWidgets(2),
      );
      final myRow = find.byKey(
        const ValueKey('contest-standing-c-active-a-me'),
      );
      expect(
        find.descendant(of: myRow, matching: find.text('You')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: myRow, matching: find.text('7.5 pts')),
        findsOneWidget,
      );

      // Not on the ended contest's board: said, not left blank.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('contest-me-c-ended')),
          matching: find.text('You’re not on this contest’s standings'),
        ),
        findsOneWidget,
      );

      // Glass cards on glass themes; flat surfaces otherwise.
      expect(
        tester.widget(active) is GlassPane,
        theme?.extension<TiqColors>()?.glass ?? false,
      );
    });
  }

  testWidgets('Afrikaans: the view renders in Afrikaans', (tester) async {
    await tester.pumpWidget(
      _app(
        FakeContestsRepository(current: _current),
        locale: const Locale('af'),
        theme: AppTheme.dark(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kompetisies'), findsOneWidget);
    expect(find.text('LOOP NOU'), findsOneWidget);
    expect(find.text('ONLANGS AFGELOOP'), findsOneWidget);
    expect(find.text('Nog 3 dae'), findsOneWidget);
    expect(find.text('Afgeloop'), findsOneWidget);
    expect(find.text('Prys'), findsOneWidget);
    expect(find.text('Jou posisie: 3 van 5'), findsOneWidget);
    // Once for "your rank", once on the agent's own standings row.
    expect(find.text('7.5 punte'), findsNWidgets(2));
    expect(find.text('Jy'), findsOneWidget);
    expect(find.text('Your rank: 3 of 5'), findsNothing);
  });

  testWidgets('the last day reads "1 day left"', (tester) async {
    await tester.pumpWidget(
      _app(
        FakeContestsRepository(
          current: const [
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
              standings: [me],
              me: me,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 day left'), findsOneWidget);
    expect(find.text('All points'), findsOneWidget);
  });

  testWidgets('nothing current: an empty state, in both languages', (
    tester,
  ) async {
    await tester.pumpWidget(_app(FakeContestsRepository()));
    await tester.pumpAndSettle();
    expect(find.text('No contests right now'), findsOneWidget);

    await tester.pumpWidget(
      _app(FakeContestsRepository(), locale: const Locale('af')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tans geen kompetisies nie'), findsOneWidget);
  });

  testWidgets('a failed load says so and offers a retry', (tester) async {
    await tester.pumpWidget(_app(FakeContestsRepository(failCurrent: true)));
    await tester.pumpAndSettle();

    expect(find.text('Couldn’t load contests'), findsOneWidget);
    expect(find.byKey(const ValueKey('contests-retry')), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/contests/data/contests_repository.dart';
import 'package:tradeiq_app/features/contests/presentation/contest_form_screen.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';

import 'contests_fakes.dart';

/// The form is pushed on top of the list in the app, so it is pushed here too:
/// saving pops it.
Widget _host(
  FakeContestsRepository repo, {
  Contest? contest,
  ThemeData? theme,
}) => ProviderScope(
  overrides: [
    contestsRepositoryProvider.overrideWithValue(repo),
    territoriesListProvider.overrideWith(
      (ref) async => const [Territory(id: 't-1', name: 'North', code: 'N1')],
    ),
  ],
  child: MaterialApp(
    theme: theme,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            key: const ValueKey('open-form'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ContestFormScreen(contest: contest),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);

String _fmt(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Finder _key(String key) => find.byKey(ValueKey<String>(key));

Future<void> _open(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.tap(_key('open-form'));
  await tester.pumpAndSettle();
}

void main() {
  // Light and night are Lumen Glass; `null` is the flat dark palette.
  for (final (label, theme) in <(String, ThemeData?)>[
    ('light', AppTheme.light()),
    ('night', AppTheme.dark()),
    ('flat dark', null),
  ]) {
    testWidgets('$label: creates a week-long contest from today by default', (
      tester,
    ) async {
      final repo = FakeContestsRepository();
      await _open(tester, _host(repo, theme: theme));

      expect(find.text('New Contest'), findsOneWidget);
      expect(
        find.byType(GlassPane).evaluate().isNotEmpty,
        theme?.extension<TiqColors>()?.glass ?? false,
      );

      await tester.enterText(_key('contest-name-field'), '  Diwali Dash ');
      await tester.enterText(_key('contest-prize-field'), 'Airtime');
      await tester.tap(_key('contest-event-task_closed'));
      await tester.tap(_key('contest-event-visit_submitted'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_key('contest-save-button'));
      await tester.tap(_key('contest-save-button'));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final input = repo.created!;
      expect(input.name, 'Diwali Dash');
      expect(input.prizeDescription, 'Airtime');
      expect(input.description, isNull);
      expect(input.territoryId, isNull);
      // Canonical order, not tick order.
      expect(input.eventTypes, ['visit_submitted', 'task_closed']);
      expect(input.startDate, _fmt(today));
      expect(input.endDate, _fmt(today.add(const Duration(days: 6))));
      expect(find.text('New Contest'), findsNothing);
    });
  }

  testWidgets('a name is required', (tester) async {
    final repo = FakeContestsRepository();
    await _open(tester, _host(repo));

    await tester.ensureVisible(_key('contest-save-button'));
    await tester.tap(_key('contest-save-button'));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsOneWidget);
    expect(repo.created, isNull);
  });

  testWidgets('edits keep the stored dates and can widen the territory', (
    tester,
  ) async {
    final repo = FakeContestsRepository(contests: const [upcomingContest]);
    await _open(
      tester,
      _host(repo, contest: upcomingContest, theme: AppTheme.light()),
    );

    expect(find.text('Edit Contest'), findsOneWidget);
    expect(find.text('November Push'), findsOneWidget);
    expect(find.textContaining('2026-11-01'), findsOneWidget);
    expect(find.text('North (N1)'), findsOneWidget);

    await tester.enterText(_key('contest-name-field'), 'November Blitz');
    await tester.tap(_key('contest-territory-field'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All territories').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(_key('contest-save-button'));
    await tester.tap(_key('contest-save-button'));
    await tester.pumpAndSettle();

    expect(repo.updatedId, 'c-upcoming');
    final input = repo.updated!;
    expect(input.name, 'November Blitz');
    expect(input.territoryId, isNull);
    expect(input.startDate, '2026-11-01');
    expect(input.endDate, '2026-11-30');
    expect(input.eventTypes, isEmpty);
    expect(find.text('Edit Contest'), findsNothing);
  });
}

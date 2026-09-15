import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/beatplans/presentation/today_screen.dart';
import 'package:tradeiq_app/features/contests/data/contests_repository.dart';

import '../../helpers/routed_app.dart';
import 'contests_fakes.dart';

class _Session extends SessionController {
  _Session(this._role);
  final String _role;

  @override
  Future<SessionState> build() async => SessionState(role: _role);
}

const _running = [
  CurrentContest(contest: activeContest, participantCount: 3, standings: []),
  CurrentContest(
    contest: Contest(
      id: 'c-active-2',
      name: 'Weekend Blitz',
      startDate: '2026-10-10',
      endDate: '2026-10-12',
      status: 'active',
      daysLeft: 2,
    ),
    participantCount: 3,
    standings: [],
  ),
  CurrentContest(contest: endedContest, participantCount: 3, standings: []),
];

Widget _today(
  List<CurrentContest> current, {
  ThemeData? theme,
  Locale? locale,
  String role = 'field_agent',
}) {
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);
  return routedApp(
    const TodayScreen(),
    path: '/today',
    theme: theme,
    locale: locale,
    overrides: [
      localDbProvider.overrideWithValue(db),
      syncStatusProvider.overrideWith((ref) => Stream.value(SyncStatus.empty)),
      todayRouteProvider.overrideWith((ref) async => null),
      sessionControllerProvider.overrideWith(() => _Session(role)),
      contestsRepositoryProvider.overrideWithValue(
        FakeContestsRepository(current: current),
      ),
    ],
  );
}

final _action = find.byKey(const ValueKey('today-contests'));

String? _tooltip(WidgetTester tester) =>
    tester.widget<IconButton>(_action).tooltip;

bool _badgeShown(WidgetTester tester) => tester
    .widget<Badge>(find.byKey(const ValueKey('today-contests-badge')))
    .isLabelVisible;

void main() {
  for (final (label, theme) in [
    ('light', AppTheme.light()),
    ('night', AppTheme.dark()),
  ]) {
    testWidgets('$label: Today carries a Contests action badged with the '
        'running count', (tester) async {
      await tester.pumpWidget(_today(_running, theme: theme));
      await tester.pumpAndSettle();

      expect(_action, findsOneWidget);
      // Two active; the ended one is not "running".
      expect(_badgeShown(tester), isTrue);
      expect(
        find.descendant(of: _action, matching: find.text('2')),
        findsOneWidget,
      );
      expect(_tooltip(tester), '2 contests running');
    });
  }

  testWidgets('nothing running: the action stays, without a badge', (
    tester,
  ) async {
    await tester.pumpWidget(_today(const [], theme: AppTheme.light()));
    await tester.pumpAndSettle();

    expect(_action, findsOneWidget);
    expect(_badgeShown(tester), isFalse);
    expect(_tooltip(tester), 'Contests');
  });

  testWidgets('Afrikaans: the hint is translated', (tester) async {
    await tester.pumpWidget(
      _today(_running, theme: AppTheme.dark(), locale: const Locale('af')),
    );
    await tester.pumpAndSettle();

    expect(_tooltip(tester), '2 kompetisies loop nou');
  });

  testWidgets('a caller who is not a field agent is never asked for a count', (
    tester,
  ) async {
    await tester.pumpWidget(_today(_running, role: 'manager'));
    await tester.pumpAndSettle();

    expect(_badgeShown(tester), isFalse);
  });
}

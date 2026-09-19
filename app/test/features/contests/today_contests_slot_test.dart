import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/core/theme/torchlight/agent_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/beatplans/presentation/today_screen.dart';
import 'package:tradeiq_app/features/contests/data/contests_repository.dart';

import '../../helpers/routed_app.dart';
import '../agent_harness.dart';
import 'contests_fakes.dart';

/// THE AGENT'S WAY INTO CONTESTS (#124).
///
/// It used to be a trophy `IconButton` in the Today app bar. The Torchlight
/// header allows exactly one trailing icon button and on a tab root that one
/// is the skin cycle (unify §1.2), so the capability moved into the nav pill's
/// third slot — see `TodayFrame.slotsIn` for why that slot exists at all.
///
/// What is asserted here is the capability, not the widget: Today offers the
/// agent a way to their standings, it wears the number of contests actually
/// running, that number is said in words to a screen reader, and nobody but a
/// field agent is ever asked for it. The count itself still comes from the
/// real `runningContestsCountProvider` — it is the thing that used to be
/// wrong, so it is not stubbed here.

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
  Locale? locale,
  String role = 'field_agent',
  SkinMode skin = SkinMode.night,
}) {
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);
  return routedApp(
    const TodayScreen(),
    path: '/today',
    locale: locale,
    overrides: [
      localDbProvider.overrideWithValue(db),
      agentSkinProvider.overrideWith(() => PinnedAgentSkin(skin)),
      syncStatusProvider.overrideWith((ref) => Stream.value(SyncStatus.empty)),
      todayRouteProvider.overrideWith((ref) async => null),
      sessionControllerProvider.overrideWith(() => _Session(role)),
      contestsRepositoryProvider.overrideWithValue(
        FakeContestsRepository(current: current),
      ),
    ],
  );
}

/// The Contests slot, wherever it sits in the bar. Found by its glyph, not by
/// its label — the label is localised and one of these tests is Afrikaans.
TorchNavSlot _slot(WidgetTester tester) => tester
    .widget<TorchNavPill>(find.byType(TorchNavPill))
    .slots
    .firstWhere((s) => s.icon == Icons.emoji_events_outlined);

void main() {
  // Every skin, because the bar is the one piece of chrome that changes shape
  // between them — Veld docks it — and the slot has to survive all three.
  for (final skin in <SkinMode>[SkinMode.night, SkinMode.day, SkinMode.veld]) {
    testWidgets('${skin.name}: Today\'s nav carries a Contests slot badged '
        'with the running count', (tester) async {
      await tester.pumpWidget(_today(_running, skin: skin));
      await tester.pumpAndSettle();

      final slot = _slot(tester);
      // Two active; the ended one is not "running".
      expect(slot.badgeCount, 2);
      // A badge is a digit beside a glyph. The sentence is what a screen
      // reader gets, and it is the one the old tooltip carried.
      expect(slot.semanticLabel, '2 contests running');
      expect(
        find.descendant(
          of: find.byType(TorchNavPill),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('nothing running: the slot stays, without a badge', (
    tester,
  ) async {
    await tester.pumpWidget(_today(const []));
    await tester.pumpAndSettle();

    final slot = _slot(tester);
    // The slot never disappears: a destination that comes and goes is a
    // destination nobody learns. Only the badge is conditional.
    expect(slot.badgeCount, isNull);
    expect(slot.semanticLabel, isNull);
  });

  testWidgets('Afrikaans: the hint is translated', (tester) async {
    await tester.pumpWidget(_today(_running, locale: const Locale('af')));
    await tester.pumpAndSettle();

    expect(_slot(tester).semanticLabel, '2 kompetisies loop nou');
  });

  testWidgets('a caller who is not a field agent is never asked for a count', (
    tester,
  ) async {
    await tester.pumpWidget(_today(_running, role: 'manager'));
    await tester.pumpAndSettle();

    expect(_slot(tester).badgeCount, isNull);
  });
}

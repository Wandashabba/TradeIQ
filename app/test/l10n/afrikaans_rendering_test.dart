import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/features/audit/data/tasks_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s9_action_plan_screen.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/beatplans/presentation/today_screen.dart';

import '../features/agent_harness.dart';
import '../features/audit/section_harness.dart';
import '../helpers/routed_app.dart';

class _NoopTasksRepository implements TasksRepository {
  @override
  Future<void> saveTask({
    required String visitDraftId,
    required String outletId,
    required TaskDraft task,
  }) async {}
}

Widget _today(Locale locale) {
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);
  return routedApp(
    const TodayScreen(),
    locale: locale,
    overrides: [
      localDbProvider.overrideWithValue(db),
      syncStatusProvider.overrideWith((ref) => Stream.value(SyncStatus.empty)),
      todayRouteProvider.overrideWith((ref) async => null),
    ],
  );
}

Future<void> _actionPlan(WidgetTester tester, Locale locale) => pumpSection(
  tester,
  const S9ActionPlanScreen(visitDraftId: 'v1', outletId: 'o1'),
  overrides: <Override>[
    tasksRepositoryProvider.overrideWithValue(_NoopTasksRepository()),
  ],
  locale: locale,
  size: const Size(360, 1400),
);

void main() {
  group('Afrikaans', () {
    testWidgets('Today renders in Afrikaans, date included', (tester) async {
      await tester.pumpWidget(_today(const Locale('af')));
      await tester.pumpAndSettle();

      // "Today" is now on the screen twice — the header's title and the nav
      // pill's first slot — so this names which is which. Both have to be
      // Afrikaans: a bar that stays English under an Afrikaans header is the
      // worst of both, and a bare `findsOneWidget` could not tell them apart.
      expect(
        find.descendant(
          of: find.byType(TorchAppHeader),
          matching: find.text('Vandag'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(TorchNavPill),
          matching: find.text('Vandag'),
        ),
        findsOneWidget,
      );
      expect(find.text('Geen roete vir vandag beplan nie'), findsOneWidget);
      // The Torchlight sync chip, whose copy is shorter than the banner's
      // that used to say this ("Alles gestuur", not "Alles is gestuur") —
      // it is a chip in the header now, not a line in the body.
      expect(find.text('Alles gestuur'), findsOneWidget);
      // "Maandag, 14 September" — the weekday and month come from intl.
      final heading = DateFormat('EEEE, d MMMM', 'af').format(DateTime.now());
      expect(find.text(heading), findsOneWidget);
      expect(find.text('Today'), findsNothing);
    });

    testWidgets('an audit section (S9 action plan) renders in Afrikaans', (
      tester,
    ) async {
      await _actionPlan(tester, const Locale('af'));

      expect(find.text('Soort bevinding'), findsOneWidget);
      expect(find.text('Prioriteit'), findsOneWidget);
      expect(find.text('Kritiek'), findsOneWidget);
      expect(find.text('Voeg taak by'), findsOneWidget);
      expect(find.text('Add task'), findsNothing);
      await disposeAgentScreen(tester);
    });
  });

  group('fallback', () {
    testWidgets('an unsupported locale renders Today in English', (
      tester,
    ) async {
      await tester.pumpWidget(_today(const Locale('zu', 'ZA')));
      await tester.pumpAndSettle();

      // The header's title and the nav pill's first slot, both in English.
      expect(
        find.descendant(
          of: find.byType(TorchAppHeader),
          matching: find.text('Today'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(TorchNavPill),
          matching: find.text('Today'),
        ),
        findsOneWidget,
      );
      expect(find.text('No route planned for today'), findsOneWidget);
      final heading = DateFormat('EEEE, d MMMM', 'en').format(DateTime.now());
      expect(find.text(heading), findsOneWidget);
    });

    testWidgets('an unsupported locale renders S9 in English', (tester) async {
      await _actionPlan(tester, const Locale('zu'));

      expect(find.text('Finding type'), findsOneWidget);
      expect(find.text('Add task'), findsOneWidget);
      await disposeAgentScreen(tester);
    });
  });
}

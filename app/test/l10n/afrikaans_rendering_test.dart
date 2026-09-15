import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/features/audit/data/tasks_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s9_action_plan_screen.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/beatplans/presentation/today_screen.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

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

Widget _actionPlan(Locale locale) => ProviderScope(
  overrides: [tasksRepositoryProvider.overrideWithValue(_NoopTasksRepository())],
  child: MaterialApp(
    locale: locale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    localeListResolutionCallback: resolveAppLocale,
    home: const Scaffold(
      body: SingleChildScrollView(
        child: S9ActionPlanScreen(visitDraftId: 'v1', outletId: 'o1'),
      ),
    ),
  ),
);

void main() {
  group('Afrikaans', () {
    testWidgets('Today renders in Afrikaans, date included', (tester) async {
      await tester.pumpWidget(_today(const Locale('af')));
      await tester.pumpAndSettle();

      expect(find.text('Vandag'), findsOneWidget);
      expect(find.text('Geen roete vir vandag beplan nie'), findsOneWidget);
      expect(find.text('Alles is gestuur'), findsOneWidget);
      // "Maandag, 14 September" — the weekday and month come from intl.
      final heading = DateFormat('EEEE, d MMMM', 'af').format(DateTime.now());
      expect(find.text(heading), findsOneWidget);
      expect(find.text('Today'), findsNothing);
    });

    testWidgets('an audit section (S9 action plan) renders in Afrikaans', (
      tester,
    ) async {
      await tester.pumpWidget(_actionPlan(const Locale('af')));
      await tester.pumpAndSettle();

      expect(find.text('Soort bevinding'), findsOneWidget);
      expect(find.text('Prioriteit'), findsOneWidget);
      expect(find.text('Kritiek'), findsOneWidget);
      expect(find.text('Voeg taak by'), findsOneWidget);
      expect(find.text('Add task'), findsNothing);
    });
  });

  group('fallback', () {
    testWidgets('an unsupported locale renders Today in English', (
      tester,
    ) async {
      await tester.pumpWidget(_today(const Locale('zu', 'ZA')));
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('No route planned for today'), findsOneWidget);
      final heading = DateFormat('EEEE, d MMMM', 'en').format(DateTime.now());
      expect(find.text(heading), findsOneWidget);
    });

    testWidgets('an unsupported locale renders S9 in English', (tester) async {
      await tester.pumpWidget(_actionPlan(const Locale('zu')));
      await tester.pumpAndSettle();

      expect(find.text('Finding type'), findsOneWidget);
      expect(find.text('Add task'), findsOneWidget);
    });
  });
}

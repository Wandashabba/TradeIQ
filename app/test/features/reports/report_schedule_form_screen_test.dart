import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/reports/data/report_schedules_repository.dart';
import 'package:tradeiq_app/features/reports/data/reports_repository.dart';
import 'package:tradeiq_app/features/reports/presentation/report_schedule_form_screen.dart';

import '../../core/design/amber_golden.dart';
import '../worklist_harness.dart';
import 'reports_harness.dart';
import 'schedules_fakes.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required FakeSchedulesRepository repo,
    FakeReportsRepository? reports,
    ReportSchedule? editing,
    TiqSkin? skin,
    double textScale = 1.0,
  }) => pumpPushedReports(
    tester,
    ReportScheduleFormScreen(schedule: editing),
    skin: skin,
    textScale: textScale,
    overrides: <Override>[
      reportSchedulesRepositoryProvider.overrideWithValue(repo),
      reportsRepositoryProvider.overrideWithValue(
        reports ?? FakeReportsRepository(),
      ),
    ],
  );

  Future<void> type(WidgetTester tester, String key, String text) async {
    await scrollWorklistTo(tester, find.byKey(ValueKey<String>(key)));
    await tester.enterText(find.byKey(ValueKey<String>(key)), text);
    await tester.pumpAndSettle();
  }

  Future<void> pickReport(WidgetTester tester, String name) async {
    await scrollWorklistTo(
      tester,
      find.byKey(const ValueKey<String>('schedule-report-field')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('schedule-report-field')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  group('parseRecipients', () {
    test('splits on commas, semicolons and lines, trimming blanks away', () {
      expect(parseRecipients('a@x.test, b@x.test;c@x.test\nd@x.test'), <String>[
        'a@x.test',
        'b@x.test',
        'c@x.test',
        'd@x.test',
      ]);
    });

    test('whitespace and separators alone are no recipients', () {
      expect(parseRecipients('  ,\n ; '), isEmpty);
    });
  });

  group('recipientsError', () {
    test('accepts 1 to 50 email addresses', () {
      expect(recipientsError('a@x.test'), isNull);
      expect(
        recipientsError(
          List<String>.generate(50, (i) => 'a$i@x.test').join('\n'),
        ),
        isNull,
      );
    });

    test('says what is wrong otherwise', () {
      expect(recipientsError(''), 'Add at least one recipient');
      expect(recipientsError('not-an-email'), contains('Not an email address'));
      expect(
        recipientsError(
          List<String>.generate(51, (i) => 'a$i@x.test').join('\n'),
        ),
        'At most 50 recipients',
      );
    });
  });

  group('creating', () {
    testWidgets('creates with the picked report, cadence and list', (
      tester,
    ) async {
      final repo = FakeSchedulesRepository();
      await pump(tester, repo: repo);

      await pickReport(tester, 'Coverage by outlet');
      await type(
        tester,
        'schedule-recipients-field',
        'ops@acme.test\nlead@acme.test',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('schedule-save-button')),
      );
      await tester.pumpAndSettle();

      expect(repo.createdReportId, 'r-a');
      // The first allowed cadence, so nothing is committed by a default
      // nobody chose beyond the one the API itself lists first.
      expect(repo.createdCadence, 'daily');
      expect(repo.createdRecipients, <String>[
        'ops@acme.test',
        'lead@acme.test',
      ]);
    });

    testWidgets('with no saved reports there is nothing to schedule, and the '
        'button says so', (tester) async {
      await pump(
        tester,
        repo: FakeSchedulesRepository(),
        reports: FakeReportsRepository(reports: const <ReportDefinition>[]),
      );

      expect(
        find.byKey(const ValueKey<String>('schedule-no-reports')),
        findsOneWidget,
      );
      expect(
        find.text('There are no saved reports yet. Build one on Reports first.'),
        findsOneWidget,
      );
    });

    testWidgets('a failed create keeps the form and says why', (tester) async {
      final repo = FakeSchedulesRepository(updateFailure: networkFailure);
      await pump(tester, repo: repo);

      await pickReport(tester, 'Coverage by outlet');
      await type(tester, 'schedule-recipients-field', 'ops@acme.test');
      await tester.tap(
        find.byKey(const ValueKey<String>('schedule-save-button')),
      );
      await tester.pumpAndSettle();

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('schedule-save-error')),
      );
      expect(find.text('The schedule was not created.'), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      // The draft survives the failure: the recipients the manager typed are
      // still in the box beside the reason it did not save.
      expect(find.text('ops@acme.test'), findsOneWidget);
    });
  });

  group('a form that cannot save says why on the button', () {
    testWidgets('no report picked', (tester) async {
      await pump(tester, repo: FakeSchedulesRepository());
      expect(
        find.text('Pick the report this schedule runs.'),
        findsOneWidget,
      );
    });

    testWidgets('no recipients', (tester) async {
      await pump(tester, repo: FakeSchedulesRepository());
      await pickReport(tester, 'Coverage by outlet');
      expect(find.text('Add at least one recipient'), findsWidgets);
    });

    testWidgets('a recipient that is not an email address', (tester) async {
      await pump(tester, repo: FakeSchedulesRepository());
      await pickReport(tester, 'Coverage by outlet');
      await type(tester, 'schedule-recipients-field', 'ops@acme.test, nope');
      expect(find.textContaining('Not an email address: nope'), findsWidgets);
    });
  });

  group('editing', () {
    testWidgets('is prefilled, and the report is locked', (tester) async {
      await pump(
        tester,
        repo: FakeSchedulesRepository(),
        editing: activeSchedule,
      );

      expect(find.text('Edit schedule'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('schedule-report-readonly')),
        findsOneWidget,
      );
      expect(find.text(scheduleReportLockedNote), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('schedule-report-field')),
        findsNothing,
      );
    });

    testWidgets('saves the new cadence and recipients, blanks dropped', (
      tester,
    ) async {
      final repo = FakeSchedulesRepository();
      await pump(tester, repo: repo, editing: activeSchedule);

      await scrollWorklistTo(tester, find.text('Daily'));
      await tester.tap(find.text('Daily'));
      await tester.pumpAndSettle();
      await type(
        tester,
        'schedule-recipients-field',
        'ops@acme.test, , new@acme.test',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('schedule-save-button')),
      );
      await tester.pumpAndSettle();

      expect(repo.updatedId, 's-active');
      expect(repo.updatedCadence, 'daily');
      expect(repo.updatedRecipients, <String>[
        'ops@acme.test',
        'new@acme.test',
      ]);
    });

    testWidgets('a cadence outside the allow-list must be re-picked', (
      tester,
    ) async {
      await pump(
        tester,
        repo: FakeSchedulesRepository(),
        editing: const ReportSchedule(
          id: 's-odd',
          reportDefinitionId: 'r-a',
          reportName: 'Coverage by outlet',
          cadence: 'fortnightly',
          recipients: <String>['ops@acme.test'],
          active: true,
        ),
      );

      expect(find.text('Pick how often it runs.'), findsWidgets);
    });

    testWidgets('a failed save keeps the form, the edits, and says why', (
      tester,
    ) async {
      final repo = FakeSchedulesRepository(updateFailure: networkFailure);
      await pump(tester, repo: repo, editing: activeSchedule);

      await type(tester, 'schedule-recipients-field', 'changed@acme.test');
      await tester.tap(
        find.byKey(const ValueKey<String>('schedule-save-button')),
      );
      await tester.pumpAndSettle();

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('schedule-save-error')),
      );
      expect(find.text('The changes were not saved.'), findsOneWidget);
      expect(find.text('changed@acme.test'), findsOneWidget);
    });
  });

  group('the amber census', () {
    testWidgets('Night, blocked: nothing is armed, so nothing is lit', (
      tester,
    ) async {
      await pump(tester, repo: FakeSchedulesRepository());

      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        TiqSkin.night(),
        route: 'reports/schedules/new',
        phase: 'blocked',
      );
      expect(census.objectCount, 0, reason: census.describe());
    });

    testWidgets('Night, armed: exactly the commit', (tester) async {
      await pump(tester, repo: FakeSchedulesRepository());
      await pickReport(tester, 'Coverage by outlet');
      await type(tester, 'schedule-recipients-field', 'ops@acme.test');

      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        TiqSkin.night(),
        route: 'reports/schedules/new',
        phase: 'armed',
      );
      expect(census.objectCount, 1, reason: census.describe());
    });

    for (final skin in <TiqSkin>[TiqSkin.day(), TiqSkin.veld()]) {
      testWidgets('${skin.mode.name}: zero blocked, one armed', (tester) async {
        await pump(
          tester,
          repo: FakeSchedulesRepository(),
          editing: activeSchedule,
          skin: skin,
        );

        var census = await amberCensus(tester);
        expect(census.objectCount, 1, reason: census.describe());

        await type(tester, 'schedule-recipients-field', '');
        census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'reports/schedules/edit',
          phase: 'blocked',
        );
        expect(census.objectCount, 0, reason: census.describe());
      });
    }
  });

  testWidgets('2.0x: the form survives and nothing overflows', (tester) async {
    await pump(
      tester,
      repo: FakeSchedulesRepository(),
      editing: activeSchedule,
      textScale: 2.0,
    );

    expect(find.byType(ErrorState), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

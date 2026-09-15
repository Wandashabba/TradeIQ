import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/widgets/lumen_kit.dart';
import 'package:tradeiq_app/features/reports/data/report_schedules_repository.dart';
import 'package:tradeiq_app/features/reports/data/reports_repository.dart';
import 'package:tradeiq_app/features/reports/presentation/report_schedule_form_screen.dart';

class _RecordingSchedulesRepository implements ReportSchedulesRepository {
  _RecordingSchedulesRepository({
    this.failCreate = false,
    this.failUpdate = false,
  });

  final bool failCreate;
  final bool failUpdate;
  Map<String, dynamic>? createdArgs;
  Map<String, dynamic>? updatedArgs;
  int updateCalls = 0;

  @override
  Future<ReportSchedule> updateSchedule(
    String id, {
    String? cadence,
    List<String>? recipients,
  }) async {
    updateCalls++;
    if (failUpdate) throw Exception('boom');
    updatedArgs = {'id': id, 'cadence': cadence, 'recipients': recipients};
    return ReportSchedule(
      id: id,
      reportDefinitionId: 'r-a',
      cadence: cadence ?? 'daily',
      recipients: recipients ?? const [],
      active: true,
    );
  }

  @override
  Future<PaginatedResponse<ReportSchedule>> listSchedules() async =>
      const PaginatedResponse(data: [], nextCursor: null);

  @override
  Future<ReportSchedule> createSchedule({
    required String reportDefinitionId,
    required String cadence,
    required List<String> recipients,
  }) async {
    if (failCreate) throw Exception('boom');
    createdArgs = {
      'reportDefinitionId': reportDefinitionId,
      'cadence': cadence,
      'recipients': recipients,
    };
    return ReportSchedule(
      id: 's-new',
      reportDefinitionId: reportDefinitionId,
      cadence: cadence,
      recipients: recipients,
      active: true,
    );
  }

  @override
  Future<ReportSchedule> setActive(String id, bool active) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteSchedule(String id) async => throw UnimplementedError();

  @override
  Future<ScheduleRunResult> runNow(String id) async =>
      throw UnimplementedError();
}

class _FakeReportsRepository implements ReportsRepository {
  _FakeReportsRepository({this.reports = _twoReports});

  static const _twoReports = [
    ReportDefinition(id: 'r-a', name: 'Coverage by outlet', type: 'visits'),
    ReportDefinition(id: 'r-b', name: 'Sales by SKU', type: 'orders'),
  ];

  final List<ReportDefinition> reports;

  @override
  Future<PaginatedResponse<ReportDefinition>> listReports() async =>
      PaginatedResponse(data: reports, nextCursor: null);

  @override
  Future<ReportResult> generate(String id) async => throw UnimplementedError();

  @override
  Future<ReportDefinition> createReport({
    required String name,
    required String type,
    required Map<String, dynamic> filters,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteReport(String id) async => throw UnimplementedError();
}

Widget _app(
  _RecordingSchedulesRepository repo, {
  _FakeReportsRepository? reports,
  ThemeData? theme,
  ReportSchedule? schedule,
}) =>
    ProviderScope(
      overrides: [
        reportSchedulesRepositoryProvider.overrideWithValue(repo),
        reportsRepositoryProvider
            .overrideWithValue(reports ?? _FakeReportsRepository()),
      ],
      child: MaterialApp(
        theme: theme,
        home: ReportScheduleFormScreen(schedule: schedule),
      ),
    );

const _existing = ReportSchedule(
  id: 's-1',
  reportDefinitionId: 'r-a',
  reportName: 'Coverage by outlet',
  cadence: 'weekly',
  recipients: ['ops@acme.test', 'lead@acme.test'],
  active: true,
);

final _recipients =
    find.byKey(const ValueKey<String>('schedule-recipients-field'));

String _recipientsText(WidgetTester tester) =>
    tester.widget<TextFormField>(_recipients).controller!.text;

final _save = find.byKey(const ValueKey<String>('schedule-save-button'));

Future<void> _tapSave(WidgetTester tester) async {
  await tester.ensureVisible(_save);
  await tester.tap(_save);
  await tester.pumpAndSettle();
}

Future<void> _fillValid(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('schedule-report-field')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sales by SKU').last);
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey<String>('schedule-cadence-field')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Weekly').last);
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const ValueKey<String>('schedule-recipients-field')),
    'ops@acme.test, lead@acme.test\n\nsales@acme.test',
  );
}

void main() {
  group('parseRecipients', () {
    test('splits on commas, semicolons and lines, trimming blanks away', () {
      expect(
        parseRecipients(' a@acme.test,b@acme.test ;\n\n c@acme.test , '),
        ['a@acme.test', 'b@acme.test', 'c@acme.test'],
      );
    });

    test('whitespace and separators alone are no recipients', () {
      expect(parseRecipients('  , ;\n '), isEmpty);
    });
  });

  testWidgets('creates a schedule with the picked report, cadence and list',
      (tester) async {
    final repo = _RecordingSchedulesRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _fillValid(tester);
    await _tapSave(tester);

    expect(repo.createdArgs, {
      'reportDefinitionId': 'r-b',
      'cadence': 'weekly',
      'recipients': ['ops@acme.test', 'lead@acme.test', 'sales@acme.test'],
    });
  });

  testWidgets('cadence defaults to daily, the first allowed value',
      (tester) async {
    final repo = _RecordingSchedulesRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('schedule-report-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coverage by outlet').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('schedule-recipients-field')),
      'ops@acme.test',
    );
    await _tapSave(tester);

    expect(repo.createdArgs!['cadence'], 'daily');
    expect(repo.createdArgs!['reportDefinitionId'], 'r-a');
  });

  testWidgets('blocks submit without a report or any recipient',
      (tester) async {
    final repo = _RecordingSchedulesRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('schedule-recipients-field')),
      ' , \n',
    );
    await _tapSave(tester);

    expect(find.text('Pick a report'), findsOneWidget);
    expect(find.text('Add at least one recipient'), findsOneWidget);
    expect(repo.createdArgs, isNull);
  });

  testWidgets('with no saved reports there is nothing to schedule',
      (tester) async {
    final repo = _RecordingSchedulesRepository();
    await tester.pumpWidget(
      _app(repo, reports: _FakeReportsRepository(reports: const [])),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('schedule-no-reports')),
      findsOneWidget,
    );
    expect(tester.widget<GlassPrimaryButton>(_save).onPressed, isNull);
  });

  testWidgets('a failed create keeps the form and says why', (tester) async {
    final repo = _RecordingSchedulesRepository(failCreate: true);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _fillValid(tester);
    await _tapSave(tester);

    expect(
      find.text('Failed to create schedule. Something went wrong. Please try '
          'again.'),
      findsOneWidget,
    );
    expect(find.text('New Schedule'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('the cadence field says it runs automatically, email not yet',
      (tester) async {
    await tester.pumpWidget(_app(_RecordingSchedulesRepository()));
    await tester.pumpAndSettle();

    expect(find.text(scheduleCadenceHelp), findsOneWidget);
    expect(scheduleCadenceHelp, contains('Runs automatically'));
    expect(scheduleCadenceHelp, contains('report.generated'));
    expect(scheduleCadenceHelp, contains('Email is not set up yet'));
    expect(find.textContaining('Nothing sends'), findsNothing);
  });

  group('edit mode', () {
    testWidgets('is prefilled with the schedule, report read-only',
        (tester) async {
      final repo = _RecordingSchedulesRepository();
      await tester.pumpWidget(_app(repo, schedule: _existing));
      await tester.pumpAndSettle();

      expect(find.text('Edit Schedule'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
      expect(_recipientsText(tester), 'ops@acme.test\nlead@acme.test');

      // The API cannot relink a schedule: no picker, the name and why.
      expect(
        find.byKey(const ValueKey<String>('schedule-report-field')),
        findsNothing,
      );
      final readonly =
          find.byKey(const ValueKey<String>('schedule-report-readonly'));
      expect(
        find.descendant(of: readonly, matching: find.text('Coverage by outlet')),
        findsOneWidget,
      );
      expect(find.text(scheduleReportLockedNote), findsOneWidget);
      // Still honest about delivery: runs automatically, email not set up.
      expect(find.text(scheduleCadenceHelp), findsOneWidget);
    });

    testWidgets('saves the new cadence and recipients, blanks dropped',
        (tester) async {
      final repo = _RecordingSchedulesRepository();
      await tester.pumpWidget(_app(repo, schedule: _existing));
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey<String>('schedule-cadence-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Daily').last);
      await tester.pumpAndSettle();
      await tester.enterText(_recipients, ' new@acme.test ;\n\n, ops@acme.test');
      await _tapSave(tester);

      expect(repo.updatedArgs, {
        'id': 's-1',
        'cadence': 'daily',
        'recipients': ['new@acme.test', 'ops@acme.test'],
      });
      expect(repo.createdArgs, isNull);
    });

    testWidgets('blocks saving with no recipients left', (tester) async {
      final repo = _RecordingSchedulesRepository();
      await tester.pumpWidget(_app(repo, schedule: _existing));
      await tester.pumpAndSettle();

      await tester.enterText(_recipients, ' , \n ; ');
      await _tapSave(tester);

      expect(find.text('Add at least one recipient'), findsOneWidget);
      expect(repo.updateCalls, 0);
    });

    testWidgets('a cadence outside the allow-list must be re-picked',
        (tester) async {
      final repo = _RecordingSchedulesRepository();
      await tester.pumpWidget(
        _app(
          repo,
          schedule: const ReportSchedule(
            id: 's-odd',
            reportDefinitionId: 'r-a',
            cadence: 'monthly',
            recipients: ['ops@acme.test'],
            active: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A bare row has no joined name.
      expect(find.text('Untitled report'), findsOneWidget);

      await _tapSave(tester);
      expect(find.text('Pick a cadence'), findsOneWidget);
      expect(repo.updateCalls, 0);

      await tester
          .tap(find.byKey(const ValueKey<String>('schedule-cadence-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekly').last);
      await tester.pumpAndSettle();
      await _tapSave(tester);

      expect(repo.updatedArgs!['cadence'], 'weekly');
    });

    testWidgets('a failed save keeps the form, the edits, and says why',
        (tester) async {
      final repo = _RecordingSchedulesRepository(failUpdate: true);
      await tester.pumpWidget(_app(repo, schedule: _existing));
      await tester.pumpAndSettle();

      await tester.enterText(_recipients, 'new@acme.test');
      await _tapSave(tester);

      expect(repo.updateCalls, 1);
      final error = find.byKey(const ValueKey<String>('schedule-save-error'));
      expect(
        find.descendant(
          of: error,
          matching: find.text(
            'Failed to save changes. Something went wrong. Please try again.',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Edit Schedule'), findsOneWidget);
      expect(_recipientsText(tester), 'new@acme.test');
    });
  });

  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    testWidgets('$name: edit mode is glass, and saves', (tester) async {
      final repo = _RecordingSchedulesRepository();
      await tester.pumpWidget(_app(repo, theme: theme, schedule: _existing));
      await tester.pumpAndSettle();

      for (final kicker in const ['REPORT', 'SCHEDULE']) {
        final pane = tester.widget<GlassPane>(
          find
              .ancestor(of: find.text(kicker), matching: find.byType(GlassPane))
              .first,
        );
        expect(pane.kind, GlassKind.panel, reason: kicker);
      }
      expect(tester.widget(_save), isA<GlassPrimaryButton>());

      await _tapSave(tester);
      expect(repo.updatedArgs!['recipients'], [
        'ops@acme.test',
        'lead@acme.test',
      ]);
    });

    testWidgets('$name: a failed save reads in the crit text colour',
        (tester) async {
      final repo = _RecordingSchedulesRepository(failUpdate: true);
      await tester.pumpWidget(_app(repo, theme: theme, schedule: _existing));
      await tester.pumpAndSettle();
      await _tapSave(tester);

      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('schedule-save-error')),
          matching: find.byType(Text),
        ),
      );
      final context = tester.element(_save);
      expect(text.style!.color, context.colors.critText);
    });
  }

  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    testWidgets('$name: sections are glass panels, create is glass',
        (tester) async {
      final repo = _RecordingSchedulesRepository();
      await tester.pumpWidget(_app(repo, theme: theme));
      await tester.pumpAndSettle();

      for (final kicker in const ['REPORT', 'SCHEDULE']) {
        final pane = tester.widget<GlassPane>(
          find
              .ancestor(of: find.text(kicker), matching: find.byType(GlassPane))
              .first,
        );
        expect(pane.kind, GlassKind.panel, reason: kicker);
      }
      expect(tester.widget(_save), isA<GlassPrimaryButton>());

      await _fillValid(tester);
      await _tapSave(tester);
      expect(repo.createdArgs!['reportDefinitionId'], 'r-b');
    });
  }
}

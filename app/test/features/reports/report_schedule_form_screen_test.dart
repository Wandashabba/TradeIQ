import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/widgets/lumen_kit.dart';
import 'package:tradeiq_app/features/reports/data/report_schedules_repository.dart';
import 'package:tradeiq_app/features/reports/data/reports_repository.dart';
import 'package:tradeiq_app/features/reports/presentation/report_schedule_form_screen.dart';

class _RecordingSchedulesRepository implements ReportSchedulesRepository {
  _RecordingSchedulesRepository({this.failCreate = false});

  final bool failCreate;
  Map<String, dynamic>? createdArgs;

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
}) =>
    ProviderScope(
      overrides: [
        reportSchedulesRepositoryProvider.overrideWithValue(repo),
        reportsRepositoryProvider
            .overrideWithValue(reports ?? _FakeReportsRepository()),
      ],
      child: MaterialApp(theme: theme, home: const ReportScheduleFormScreen()),
    );

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

  testWidgets('the cadence field says it is stored, not sent', (tester) async {
    await tester.pumpWidget(_app(_RecordingSchedulesRepository()));
    await tester.pumpAndSettle();

    expect(
      find.text('Saved with the schedule. Nothing sends on it yet.'),
      findsOneWidget,
    );
  });

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

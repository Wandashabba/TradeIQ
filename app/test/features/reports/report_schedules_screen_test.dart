import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/widgets/lumen_kit.dart';
import 'package:tradeiq_app/features/reports/data/report_schedules_repository.dart';
import 'package:tradeiq_app/features/reports/data/reports_repository.dart';
import 'package:tradeiq_app/features/reports/presentation/report_schedules_screen.dart';

import '../../core/theme/tiq_colors_test.dart' show contrastRatio;
import '../../helpers/routed_app.dart';

const _active = ReportSchedule(
  id: 's-active',
  reportDefinitionId: 'r-a',
  reportName: 'Coverage by outlet',
  cadence: 'weekly',
  recipients: ['ops@acme.test', 'lead@acme.test'],
  active: true,
);

const _paused = ReportSchedule(
  id: 's-paused',
  reportDefinitionId: 'r-b',
  reportName: 'Sales by SKU',
  cadence: 'daily',
  recipients: ['sales@acme.test'],
  active: false,
);

class _FakeSchedulesRepository implements ReportSchedulesRepository {
  _FakeSchedulesRepository({
    this.schedules = const [_active, _paused],
    this.failList = false,
    this.failRun = false,
    this.pendingList,
  });

  final List<ReportSchedule> schedules;
  final bool failList;
  final bool failRun;
  final Completer<PaginatedResponse<ReportSchedule>>? pendingList;

  String? toggledId;
  bool? toggledValue;
  String? runId;
  String? deletedId;

  @override
  Future<PaginatedResponse<ReportSchedule>> listSchedules() async {
    if (pendingList != null) return pendingList!.future;
    if (failList) throw Exception('boom');
    return PaginatedResponse(data: schedules, nextCursor: null);
  }

  @override
  Future<ReportSchedule> createSchedule({
    required String reportDefinitionId,
    required String cadence,
    required List<String> recipients,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ReportSchedule> setActive(String id, bool active) async {
    toggledId = id;
    toggledValue = active;
    return _active;
  }

  @override
  Future<void> deleteSchedule(String id) async {
    deletedId = id;
  }

  @override
  Future<ScheduleRunResult> runNow(String id) async {
    runId = id;
    if (failRun) throw Exception('boom');
    return const ScheduleRunResult(
      schedule: _active,
      generatedAt: '2026-09-14T10:05:00.000Z',
      rowCount: 42,
      deliveredTo: ['ops@acme.test', 'lead@acme.test'],
    );
  }
}

class _FakeReportsRepository implements ReportsRepository {
  @override
  Future<PaginatedResponse<ReportDefinition>> listReports() async =>
      const PaginatedResponse(
        data: [ReportDefinition(id: 'r-a', name: 'Coverage by outlet', type: 'visits')],
        nextCursor: null,
      );

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

Widget _app(ReportSchedulesRepository repo, {ThemeData? theme}) => routedApp(
      const ReportSchedulesScreen(),
      theme: theme,
      overrides: [
        reportSchedulesRepositoryProvider.overrideWithValue(repo),
        reportsRepositoryProvider.overrideWithValue(_FakeReportsRepository()),
      ],
    );

void main() {
  testWidgets('each row shows report, cadence, recipients and status word',
      (tester) async {
    await tester.pumpWidget(_app(_FakeSchedulesRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Coverage by outlet'), findsOneWidget);
    expect(find.text('Sales by SKU'), findsOneWidget);
    expect(find.text('Weekly · Never run'), findsOneWidget);
    expect(find.text('Daily · Never run'), findsOneWidget);
    expect(find.text('To ops@acme.test, lead@acme.test'), findsOneWidget);
    expect(find.text('To sales@acme.test'), findsOneWidget);
    // Status is a word, never colour alone.
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.text('2 schedules'), findsOneWidget);
    expect(find.text('1 active'), findsOneWidget);
  });

  testWidgets('a run stamp is shown as the last run', (tester) async {
    await tester.pumpWidget(
      _app(
        _FakeSchedulesRepository(
          schedules: [
            ReportSchedule(
              id: 's-run',
              reportDefinitionId: 'r-a',
              reportName: 'Coverage by outlet',
              cadence: 'weekly',
              recipients: const ['ops@acme.test'],
              active: true,
              lastRunAt: DateTime(2026, 9, 14, 10, 5),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekly · Last run 2026-09-14 10:05'), findsOneWidget);
  });

  testWidgets('says plainly that nothing is sent automatically',
      (tester) async {
    await tester.pumpWidget(_app(_FakeSchedulesRepository()));
    await tester.pumpAndSettle();

    expect(find.text(scheduleDeliveryNote), findsOneWidget);
    expect(scheduleDeliveryNote, contains('not sent automatically'));
  });

  testWidgets('pause and resume follow each row\'s state', (tester) async {
    final repo = _FakeSchedulesRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    final pause = find.byKey(const ValueKey<String>('toggle-s-active'));
    final resume = find.byKey(const ValueKey<String>('toggle-s-paused'));
    expect(find.descendant(of: pause, matching: find.text('Pause')), findsOneWidget);
    expect(find.descendant(of: resume, matching: find.text('Resume')), findsOneWidget);

    await tester.tap(pause);
    await tester.pumpAndSettle();
    expect(repo.toggledId, 's-active');
    expect(repo.toggledValue, isFalse);

    await tester.tap(resume);
    await tester.pumpAndSettle();
    expect(repo.toggledId, 's-paused');
    expect(repo.toggledValue, isTrue);
  });

  testWidgets('run now reports what the API did — generated, not sent',
      (tester) async {
    final repo = _FakeSchedulesRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('run-s-active')));
    await tester.pumpAndSettle();

    expect(repo.runId, 's-active');
    expect(
      find.text('Generated 42 rows. Not sent to recipients: delivery is not '
          'built yet.'),
      findsOneWidget,
    );
    // `deliveredTo` is an echo of the recipients, not a delivery receipt.
    expect(find.textContaining('Delivered'), findsNothing);
    expect(find.textContaining('Sent to'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  test('run now wording counts one row in the singular', () {
    expect(
      runNowMessage(
        const ScheduleRunResult(
          schedule: _active,
          generatedAt: '2026-09-14T10:05:00.000Z',
          rowCount: 1,
          deliveredTo: [],
        ),
      ),
      startsWith('Generated 1 row. '),
    );
  });

  testWidgets('a failed run says so, in human words', (tester) async {
    final repo = _FakeSchedulesRepository(failRun: true);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('run-s-paused')));
    await tester.pumpAndSettle();

    expect(repo.runId, 's-paused');
    expect(
      find.text('Run failed. Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('Generated'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('delete asks first, and cancel keeps the schedule',
      (tester) async {
    final repo = _FakeSchedulesRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('delete-s-paused')));
    await tester.pumpAndSettle();
    expect(find.text('Delete schedule?'), findsOneWidget);
    expect(find.textContaining('Sales by SKU will no longer'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('cancel-delete')));
    await tester.pumpAndSettle();
    expect(repo.deletedId, isNull);

    await tester.tap(find.byKey(const ValueKey<String>('delete-s-paused')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('confirm-delete')));
    await tester.pumpAndSettle();
    expect(repo.deletedId, 's-paused');
  });

  testWidgets('shows a spinner while the schedules load', (tester) async {
    final pending = Completer<PaginatedResponse<ReportSchedule>>();
    await tester.pumpWidget(
      _app(_FakeSchedulesRepository(pendingList: pending)),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // The delivery note does not wait on the network.
    expect(find.text(scheduleDeliveryNote), findsOneWidget);

    pending.complete(const PaginatedResponse(data: [], nextCursor: null));
    await tester.pumpAndSettle();
  });

  testWidgets('an empty list is a stated result', (tester) async {
    await tester.pumpWidget(_app(_FakeSchedulesRepository(schedules: const [])));
    await tester.pumpAndSettle();

    expect(find.text('No report schedules'), findsOneWidget);
    expect(find.text('0 schedules'), findsOneWidget);
  });

  testWidgets('shows an error with a retry when loading fails', (tester) async {
    await tester.pumpWidget(_app(_FakeSchedulesRepository(failList: true)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load report schedules'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('the add button opens the create form', (tester) async {
    await tester.pumpWidget(_app(_FakeSchedulesRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('schedule-create-fab')));
    await tester.pumpAndSettle();

    expect(find.text('New Schedule'), findsOneWidget);
  });

  for (final (name, theme, palette) in [
    ('light', AppTheme.light(), TiqColors.light),
    ('dark', AppTheme.dark(), TiqColors.night),
  ]) {
    group('Lumen Glass ($name)', () {
      testWidgets('rows are no-blur glass tiles inside a glass panel',
          (tester) async {
        await tester.pumpWidget(_app(_FakeSchedulesRepository(), theme: theme));
        await tester.pumpAndSettle();

        expect(palette.glass, isTrue);
        final panes = tester
            .widgetList<GlassPane>(
              find.ancestor(
                of: find.text('Coverage by outlet'),
                matching: find.byType(GlassPane),
              ),
            )
            .toList();
        expect(panes.any((p) => p.kind == GlassKind.tile && !p.blur), isTrue);
        expect(panes.any((p) => p.kind == GlassKind.panel), isTrue);
        // The delivery note sits on glass too.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey<String>('schedule-delivery-note')),
            matching: find.byType(GlassPane),
          ),
          findsWidgets,
        );
      });

      testWidgets('status pills clear AA 4.5:1 on their wash', (tester) async {
        await tester.pumpWidget(_app(_FakeSchedulesRepository(), theme: theme));
        await tester.pumpAndSettle();

        for (final word in const ['ACTIVE', 'PAUSED']) {
          final pill = find.ancestor(
            of: find.text(word),
            matching: find.byType(LumenStatusPill),
          );
          expect(pill, findsOneWidget, reason: '$word is a glass status pill');
          final box = tester.widget<Container>(
            find.descendant(of: pill, matching: find.byType(Container)).first,
          );
          final wash = (box.decoration! as BoxDecoration).color!;
          final ink = tester.widget<Text>(find.text(word)).style!.color!;
          // The wash is translucent: judge it composited over the pane.
          final ratio = contrastRatio(ink, Color.alphaBlend(wash, palette.surface1));
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '$word ($name) is $ratio:1 — pill text is 8.5px, so AA '
                'demands 4.5:1.',
          );
        }
      });
    });
  }
}

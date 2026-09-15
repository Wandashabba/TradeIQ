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

final _nextRun = DateTime(2026, 9, 21, 9, 0);

final _active = ReportSchedule(
  id: 's-active',
  reportDefinitionId: 'r-a',
  reportName: 'Coverage by outlet',
  cadence: 'weekly',
  recipients: const ['ops@acme.test', 'lead@acme.test'],
  active: true,
  nextRunAt: _nextRun,
);

// Paused: the backend clears nextRunAt.
const _paused = ReportSchedule(
  id: 's-paused',
  reportDefinitionId: 'r-b',
  reportName: 'Sales by SKU',
  cadence: 'daily',
  recipients: ['sales@acme.test'],
  active: false,
);

const _emailNotConfigured = ReportDeliveryOutcome(
  channel: 'email',
  status: 'not_configured',
  targets: ['ops@acme.test', 'lead@acme.test'],
  detail: 'Email delivery not configured',
);

ScheduleRunResult _runResult({
  int rowCount = 42,
  List<String> deliveredTo = const ['https://hooks.acme.test/reports'],
  ReportDeliveryOutcome? webhook,
}) =>
    ScheduleRunResult(
      schedule: _active,
      runId: 'run-1',
      generatedAt: '2026-09-14T10:05:00.000Z',
      rowCount: rowCount,
      deliveredTo: deliveredTo,
      deliveries: [
        webhook ??
            ReportDeliveryOutcome(
              channel: 'webhook',
              status: deliveredTo.isEmpty ? 'no_subscribers' : 'queued',
              targets: deliveredTo,
            ),
        _emailNotConfigured,
      ],
    );

class _FakeSchedulesRepository implements ReportSchedulesRepository {
  _FakeSchedulesRepository({
    List<ReportSchedule>? schedules,
    this.failList = false,
    this.failRun = false,
    this.failUpdate = false,
    this.pendingList,
    ScheduleRunResult? runResult,
  })  : schedules = [...(schedules ?? [_active, _paused])],
        runResult = runResult ?? _runResult();

  /// Mutable, so an update is visible on the next list — like the server.
  final List<ReportSchedule> schedules;
  final bool failList;
  final bool failRun;
  final bool failUpdate;
  final Completer<PaginatedResponse<ReportSchedule>>? pendingList;
  final ScheduleRunResult runResult;

  String? toggledId;
  bool? toggledValue;
  String? runId;
  String? deletedId;
  String? updatedId;
  int listCalls = 0;

  @override
  Future<PaginatedResponse<ReportSchedule>> listSchedules() async {
    listCalls++;
    if (pendingList != null) return pendingList!.future;
    if (failList) throw Exception('boom');
    return PaginatedResponse(data: [...schedules], nextCursor: null);
  }

  @override
  Future<ReportSchedule> updateSchedule(
    String id, {
    String? cadence,
    List<String>? recipients,
  }) async {
    updatedId = id;
    if (failUpdate) throw Exception('boom');
    final i = schedules.indexWhere((s) => s.id == id);
    final old = schedules[i];
    final updated = ReportSchedule(
      id: old.id,
      reportDefinitionId: old.reportDefinitionId,
      reportName: old.reportName,
      cadence: cadence ?? old.cadence,
      recipients: recipients ?? old.recipients,
      active: old.active,
      lastRunAt: old.lastRunAt,
      nextRunAt: old.nextRunAt,
    );
    schedules[i] = updated;
    return updated;
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
    return runResult;
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
  testWidgets('each row shows report, cadence, next and last run, recipients and status word',
      (tester) async {
    await tester.pumpWidget(_app(_FakeSchedulesRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Coverage by outlet'), findsOneWidget);
    expect(find.text('Sales by SKU'), findsOneWidget);
    expect(find.text('Weekly · Next run 2026-09-21 09:00'), findsOneWidget);
    // A paused schedule has no next run, and says so.
    expect(find.text('Daily · Paused, no next run'), findsOneWidget);
    expect(find.text('Never run'), findsNWidgets(2));
    expect(find.text('To ops@acme.test, lead@acme.test'), findsOneWidget);
    expect(find.text('To sales@acme.test'), findsOneWidget);
    // Status is a word, never colour alone.
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.text('2 schedules'), findsOneWidget);
    expect(find.text('1 active'), findsOneWidget);
  });

  testWidgets('next and last run sit on the row they belong to', (tester) async {
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
              nextRunAt: DateTime(2026, 9, 21, 10, 5),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey<String>('schedule-s-run'));
    expect(
      find.descendant(of: row, matching: find.text('Last run 2026-09-14 10:05')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row,
        matching: find.text('Weekly · Next run 2026-09-21 10:05'),
      ),
      findsOneWidget,
    );
  });

  test('nextRunLabel covers active, paused and unscheduled', () {
    expect(nextRunLabel(_active), 'Next run 2026-09-21 09:00');
    expect(nextRunLabel(_paused), 'Paused, no next run');
    expect(
      nextRunLabel(
        const ReportSchedule(
          id: 'x',
          reportDefinitionId: 'r',
          cadence: 'daily',
          recipients: [],
          active: true,
        ),
      ),
      'Next run not scheduled',
    );
    expect(lastRunLabel(null), 'Never run');
  });

  testWidgets('says schedules run automatically to webhooks, and email is not set up',
      (tester) async {
    await tester.pumpWidget(_app(_FakeSchedulesRepository()));
    await tester.pumpAndSettle();

    expect(find.text(scheduleDeliveryNote), findsOneWidget);
    expect(scheduleDeliveryNote, contains('run automatically'));
    expect(scheduleDeliveryNote, contains('webhooks subscribed to report.generated'));
    expect(scheduleDeliveryNote, contains('Email is not set up yet'));
    expect(scheduleDeliveryNote, isNot(contains('not sent automatically')));
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

  testWidgets('run now reports what the API did — rows, webhooks queued, no email',
      (tester) async {
    final repo = _FakeSchedulesRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('run-s-active')));
    await tester.pumpAndSettle();

    expect(repo.runId, 's-active');
    expect(
      find.text('Generated 42 rows. Queued for 1 webhook. Email is not set up yet.'),
      findsOneWidget,
    );
    // Queued, not received: never claimed as delivered.
    expect(find.textContaining('Delivered'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  group('runNowMessage', () {
    test('counts one row and many webhooks', () {
      expect(
        runNowMessage(
          _runResult(
            rowCount: 1,
            deliveredTo: const ['https://a.test', 'https://b.test'],
          ),
        ),
        'Generated 1 row. Queued for 2 webhooks. Email is not set up yet.',
      );
    });

    test('says plainly when no webhook listens', () {
      expect(
        runNowMessage(_runResult(deliveredTo: const [])),
        'Generated 42 rows. Not sent: no webhook is subscribed to '
        'report.generated. Email is not set up yet.',
      );
    });

    test('says when the webhook channel failed', () {
      expect(
        runNowMessage(
          _runResult(
            deliveredTo: const [],
            webhook: const ReportDeliveryOutcome(
              channel: 'webhook',
              status: 'failed',
            ),
          ),
        ),
        'Generated 42 rows. Webhook delivery failed. Email is not set up yet.',
      );
    });
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

  group('edit', () {
    final recipientsField =
        find.byKey(const ValueKey<String>('schedule-recipients-field'));
    final save = find.byKey(const ValueKey<String>('schedule-save-button'));

    testWidgets('each row has Edit beside its other actions', (tester) async {
      await tester.pumpWidget(_app(_FakeSchedulesRepository()));
      await tester.pumpAndSettle();

      for (final id in const ['s-active', 's-paused']) {
        final row = find.byKey(ValueKey<String>('schedule-$id'));
        for (final key in ['toggle-$id', 'run-$id', 'edit-$id', 'delete-$id']) {
          expect(
            find.descendant(of: row, matching: find.byKey(ValueKey(key))),
            findsOneWidget,
            reason: key,
          );
        }
        expect(
          find.descendant(
            of: find.byKey(ValueKey<String>('edit-$id')),
            matching: find.text('Edit'),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('Edit opens the form prefilled with that schedule',
        (tester) async {
      await tester.pumpWidget(_app(_FakeSchedulesRepository()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('edit-s-paused')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Schedule'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('schedule-report-readonly')),
          matching: find.text('Sales by SKU'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('schedule-cadence-field')),
          matching: find.text('Daily'),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<TextFormField>(recipientsField).controller!.text,
        'sales@acme.test',
      );
    });

    testWidgets('a save returns to the list, which shows the change',
        (tester) async {
      final repo = _FakeSchedulesRepository();
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      final listsBefore = repo.listCalls;

      await tester.tap(find.byKey(const ValueKey<String>('edit-s-active')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey<String>('schedule-cadence-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Daily').last);
      await tester.pumpAndSettle();
      await tester.enterText(recipientsField, 'new@acme.test\n\n');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(repo.updatedId, 's-active');
      expect(find.text('Edit Schedule'), findsNothing);
      expect(repo.listCalls, greaterThan(listsBefore));
      expect(find.text('To new@acme.test'), findsOneWidget);
      expect(find.text('To ops@acme.test, lead@acme.test'), findsNothing);
      expect(find.text('Daily · Next run 2026-09-21 09:00'), findsOneWidget);
    });

    testWidgets('a failed save stays on the form and says why',
        (tester) async {
      final repo = _FakeSchedulesRepository(failUpdate: true);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('edit-s-active')));
      await tester.pumpAndSettle();
      await tester.enterText(recipientsField, 'new@acme.test');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(repo.updatedId, 's-active');
      expect(find.text('Edit Schedule'), findsOneWidget);
      expect(
        find.text(
          'Failed to save changes. Something went wrong. Please try again.',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<TextFormField>(recipientsField).controller!.text,
        'new@acme.test',
      );
    });
  });

  for (final (name, theme, palette) in [
    ('light', AppTheme.light(), TiqColors.light),
    ('dark', AppTheme.dark(), TiqColors.night),
  ]) {
    group('Lumen Glass ($name)', () {
      testWidgets('Edit sits in the glass row and opens a glass form',
          (tester) async {
        await tester.pumpWidget(_app(_FakeSchedulesRepository(), theme: theme));
        await tester.pumpAndSettle();

        final edit = find.byKey(const ValueKey<String>('edit-s-active'));
        expect(
          find.ancestor(of: edit, matching: find.byType(GlassPane)),
          findsWidgets,
        );

        await tester.tap(edit);
        await tester.pumpAndSettle();
        final pane = tester.widget<GlassPane>(
          find
              .ancestor(
                of: find.byKey(
                  const ValueKey<String>('schedule-report-readonly'),
                ),
                matching: find.byType(GlassPane),
              )
              .first,
        );
        expect(pane.kind, GlassKind.panel);
        expect(tester.takeException(), isNull);
      });

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
        // The next/last run lines sit inside the same glass tile.
        final nextRun = find.byKey(const ValueKey<String>('schedule-next-run-s-active'));
        expect(
          tester
              .widgetList<GlassPane>(
                find.ancestor(of: nextRun, matching: find.byType(GlassPane)),
              )
              .any((p) => p.kind == GlassKind.tile && !p.blur),
          isTrue,
        );
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

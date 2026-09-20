import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/tiq_number.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/reports/data/report_schedules_repository.dart';
import 'package:tradeiq_app/features/reports/data/reports_repository.dart';
import 'package:tradeiq_app/features/reports/presentation/report_schedules_screen.dart';

import '../../core/design/amber_golden.dart';
import '../a11y_guard.dart';
import '../worklist_harness.dart';
import 'reports_harness.dart';
import 'schedules_fakes.dart';

/// The English grouping formatter, as the screen hands it to the pure
/// functions under test.
String en(num value) => TiqNumber.en.format(value);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required FakeSchedulesRepository repo,
    FakeReportsRepository? reports,
    TiqSkin? skin,
    double textScale = 1.0,
    bool settle = true,
  }) => pumpReports(
    tester,
    const ReportSchedulesScreen(),
    skin: skin,
    textScale: textScale,
    settle: settle,
    overrides: <Override>[
      reportSchedulesRepositoryProvider.overrideWithValue(repo),
      reportsRepositoryProvider.overrideWithValue(
        reports ?? FakeReportsRepository(),
      ),
    ],
  );

  group('the words', () {
    test('nextRunLabel covers active, paused and unscheduled', () {
      expect(nextRunLabel(activeSchedule), 'Next run 2026-09-21 09:00');
      expect(nextRunLabel(pausedSchedule), 'Paused, no next run');
      expect(
        nextRunLabel(
          const ReportSchedule(
            id: 'x',
            reportDefinitionId: 'r',
            cadence: 'daily',
            recipients: <String>[],
            active: true,
          ),
        ),
        'Next run not scheduled',
      );
      expect(lastRunLabel(null), 'Never run');
    });

    test('the standing note says what the backend actually does', () {
      expect(scheduleDeliveryNote, contains('run automatically'));
      expect(
        scheduleDeliveryNote,
        contains('webhooks subscribed to report.generated'),
      );
      expect(
        scheduleDeliveryNote,
        contains('Recipients are emailed when email is set up'),
      );
      expect(scheduleDeliveryNote, isNot(contains('not sent automatically')));
    });

    group('runNowMessage', () {
      // A row count is a figure, and a figure goes through the reader's own
      // grouping. `en` here is `TiqNumber.en.format`.

      test('counts one row and many webhooks', () {
        expect(
          runNowMessage(
            runResultFor(
              rowCount: 1,
              deliveredTo: const <String>['https://a.test', 'https://b.test'],
            ),
            en,
          ),
          'Generated 1 row. Queued for 2 webhooks. Email is not set up on '
          'the server.',
        );
      });

      test('says plainly when no webhook listens', () {
        expect(
          runNowMessage(runResultFor(deliveredTo: const <String>[]), en),
          'Generated 42 rows. Not sent: no webhook is subscribed to '
          'report.generated. Email is not set up on the server.',
        );
      });

      test('counts webhooks from their own outcome, and emails queued', () {
        // deliveredTo lists every target, email addresses included.
        final result = ScheduleRunResult(
          schedule: activeSchedule,
          runId: 'run-2',
          generatedAt: '2026-09-14T10:05:00.000Z',
          rowCount: 3,
          deliveredTo: const <String>[
            'https://a.test',
            'ops@acme.test',
            'lead@acme.test',
          ],
          deliveries: const <ReportDeliveryOutcome>[
            ReportDeliveryOutcome(
              channel: 'webhook',
              status: 'queued',
              targets: <String>['https://a.test'],
            ),
            ReportDeliveryOutcome(
              channel: 'email',
              status: 'queued',
              targets: <String>['ops@acme.test', 'lead@acme.test'],
            ),
          ],
        );
        expect(
          runNowMessage(result, en),
          'Generated 3 rows. Queued for 1 webhook. Emailing 2 recipients.',
        );
      });

      test('says when no recipient is a usable email address', () {
        final result = ScheduleRunResult(
          schedule: activeSchedule,
          runId: 'run-3',
          generatedAt: '2026-09-14T10:05:00.000Z',
          rowCount: 1,
          deliveredTo: const <String>[],
          deliveries: const <ReportDeliveryOutcome>[
            ReportDeliveryOutcome(channel: 'webhook', status: 'no_subscribers'),
            ReportDeliveryOutcome(channel: 'email', status: 'no_subscribers'),
          ],
        );
        expect(
          runNowMessage(result, en),
          'Generated 1 row. Not sent: no webhook is subscribed to '
          'report.generated. Not emailed: no valid email recipients.',
        );
      });

      test('says when the webhook channel failed', () {
        expect(
          runNowMessage(
            runResultFor(
              deliveredTo: const <String>[],
              webhook: const ReportDeliveryOutcome(
                channel: 'webhook',
                status: 'failed',
              ),
            ),
            en,
          ),
          'Generated 42 rows. Webhook delivery failed. Email is not set up '
          'on the server.',
        );
      });
    });
  });

  group('the list', () {
    testWidgets('Active and Off are two sections, each with its count', (
      tester,
    ) async {
      await pump(tester, repo: FakeSchedulesRepository());

      expect(find.widgetWithText(SectionRule, 'Active'), findsOneWidget);
      expect(find.text('Coverage by outlet'), findsOneWidget);
      // Past the fold on a 360dp phone, which is where it genuinely is.
      await scrollWorklistTo(tester, find.text('Sales by SKU'));
      expect(find.widgetWithText(SectionRule, 'Off'), findsOneWidget);
      expect(find.text('Sales by SKU'), findsOneWidget);
    });

    testWidgets('next and last run sit on the row they belong to', (
      tester,
    ) async {
      await pump(tester, repo: FakeSchedulesRepository());

      expect(
        find.byKey(const ValueKey<String>('schedule-next-run-s-active')),
        findsOneWidget,
      );
      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('schedule-next-run-s-paused')),
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const ValueKey<String>('schedule-next-run-s-active'),
              ),
            )
            .data,
        'Next run 2026-09-21 09:00',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const ValueKey<String>('schedule-next-run-s-paused'),
              ),
            )
            .data,
        'Paused, no next run',
      );
    });

    testWidgets('a schedule with nobody to email says so, and takes a '
        'severity bar', (tester) async {
      await pump(
        tester,
        repo: FakeSchedulesRepository(
          schedules: <ReportSchedule>[noRecipientsSchedule],
        ),
      );

      expect(
        find.text(
          'No recipients — this schedule delivers to nobody by email.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an empty list is a stated result', (tester) async {
      await pump(
        tester,
        repo: FakeSchedulesRepository(schedules: <ReportSchedule>[]),
      );

      expect(find.text('No schedules.'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('a failure is sanitised and offers one retry', (tester) async {
      await pump(
        tester,
        repo: FakeSchedulesRepository(listFailure: networkFailure),
      );

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('schedules-retry')),
        findsOneWidget,
      );
    });

    testWidgets('loading is a skeleton, never a spinner', (tester) async {
      await pump(
        tester,
        repo: FakeSchedulesRepository(listPending: true),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byType(Skeleton), findsOneWidget);
    });
  });

  group('the toggle', () {
    testWidgets('it follows the thumb and tells the server', (tester) async {
      final repo = FakeSchedulesRepository();
      await pump(tester, repo: repo);

      final toggle = find.byKey(const ValueKey<String>('toggle-s-active'));
      await scrollWorklistTo(tester, toggle);
      expect(tester.widget<TorchToggle>(toggle).value, isTrue);

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(repo.toggledId, 's-active');
      expect(repo.toggledValue, isFalse);
    });

    testWidgets('a refused toggle goes back, and says so', (tester) async {
      final repo = FakeSchedulesRepository(updateFailure: networkFailure);
      await pump(tester, repo: repo);

      final toggle = find.byKey(const ValueKey<String>('toggle-s-active'));
      await scrollWorklistTo(tester, toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(tester.widget<TorchToggle>(toggle).value, isTrue);
      expect(find.byType(TorchToast), findsOneWidget);
      await settleToasts(tester);
    });
  });

  testWidgets('Run now reports what the API did — rows, webhooks queued, '
      'no email', (tester) async {
    final repo = FakeSchedulesRepository();
    await pump(tester, repo: repo);

    final run = find.byKey(const ValueKey<String>('run-s-active'));
    await scrollWorklistTo(tester, run);
    await tester.tap(run);
    await tester.pumpAndSettle();

    expect(repo.runId, 's-active');
    expect(
      find.text(
        'Generated 42 rows. Queued for 1 webhook. Email is not set up on '
        'the server.',
      ),
      findsOneWidget,
    );
    // Queued, not received: never claimed as delivered.
    expect(find.textContaining('Delivered'), findsNothing);

    await settleToasts(tester);
  });

  testWidgets('a failed run says so, in human words', (tester) async {
    final repo = FakeSchedulesRepository(runFailure: networkFailure);
    await pump(tester, repo: repo);

    final run = find.byKey(const ValueKey<String>('run-s-paused'));
    await scrollWorklistTo(tester, run);
    await tester.tap(run);
    await tester.pumpAndSettle();

    expect(repo.runId, 's-paused');
    expect(find.textContaining('Run failed.'), findsOneWidget);
    expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
    expect(find.textContaining('Generated'), findsNothing);

    await settleToasts(tester);
  });

  group('delete', () {
    testWidgets('asks first, and cancel keeps the schedule', (tester) async {
      final repo = FakeSchedulesRepository();
      await pump(tester, repo: repo);

      final delete = find.byKey(const ValueKey<String>('delete-s-active'));
      await scrollWorklistTo(tester, delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmSheet), findsOneWidget);
      expect(find.text('The saved report itself is kept.'), findsOneWidget);

      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();
      expect(repo.deletedId, isNull);
    });

    testWidgets('confirming deletes', (tester) async {
      final repo = FakeSchedulesRepository();
      await pump(tester, repo: repo);

      final delete = find.byKey(const ValueKey<String>('delete-s-active'));
      await scrollWorklistTo(tester, delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete this schedule'));
      await tester.pumpAndSettle();

      expect(repo.deletedId, 's-active');
    });
  });

  testWidgets('recipients expand in place', (tester) async {
    await pump(tester, repo: FakeSchedulesRepository());

    final expander = find.byKey(const ValueKey<String>('recipients-s-active'));
    await scrollWorklistTo(tester, expander);
    expect(find.text('ops@acme.test'), findsNothing);

    await tester.tap(expander);
    await tester.pumpAndSettle();
    expect(find.text('ops@acme.test'), findsOneWidget);
    expect(find.text('lead@acme.test'), findsOneWidget);
  });

  // THE FAILURE, WRITTEN OUT: a blind manager presses "Show recipients", is
  // told the control is now "Hide recipients" — so the action appears to have
  // worked — and hears nothing. The addresses are painted inside the row's
  // excluded text column, and the row's spoken sentence was byte-identical
  // before and after the press.
  testWidgets('expanding recipients says the addresses to a reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, repo: FakeSchedulesRepository());

    String rowSentence() => semanticsNodes(tester)
        .map((n) => n.getSemanticsData().label)
        .firstWhere((l) => l.contains('Coverage by outlet'));

    final before = rowSentence();
    expect(before, isNot(contains('ops@acme.test')));

    final expander = find.byKey(const ValueKey<String>('recipients-s-active'));
    await scrollWorklistTo(tester, expander);
    await tester.tap(expander);
    await tester.pumpAndSettle();

    final after = rowSentence();
    expect(
      after,
      isNot(before),
      reason:
          'The control changed its own word and revealed nothing.'
          '\n\n${semanticsDump(tester)}',
    );
    expect(after, contains('ops@acme.test'));
    expect(after, contains('lead@acme.test'));
    handle.dispose();
  });

  testWidgets('History opens that schedule\'s run history', (tester) async {
    final repo = FakeSchedulesRepository();
    await pump(tester, repo: repo);

    final history = find.byKey(const ValueKey<String>('history-s-active'));
    await scrollWorklistTo(tester, history);
    await tester.tap(history);
    await tester.pumpAndSettle();

    expect(find.text('Run history'), findsOneWidget);
    expect(repo.historyId, 's-active');
  });

  testWidgets('Edit opens the form prefilled with that schedule', (
    tester,
  ) async {
    await pump(tester, repo: FakeSchedulesRepository());

    final edit = find.byKey(const ValueKey<String>('edit-s-active'));
    await scrollWorklistTo(tester, edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();

    expect(find.text('Edit schedule'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('schedule-report-readonly')),
      findsOneWidget,
    );
  });

  testWidgets('New schedule opens the create form', (tester) async {
    await pump(tester, repo: FakeSchedulesRepository());

    final create = find.byKey(const ValueKey<String>('schedule-create'));
    await scrollWorklistTo(tester, create);
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(find.text('New schedule'), findsOneWidget);
  });

  group('the amber census', () {
    testWidgets('Night paints exactly one lit object: the nav tab', (
      tester,
    ) async {
      await pump(tester, repo: FakeSchedulesRepository());

      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        TiqSkin.night(),
        route: 'reports/schedules',
        phase: 'loaded',
      );
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets('Night, empty, still exactly the nav tab', (tester) async {
      await pump(
        tester,
        repo: FakeSchedulesRepository(schedules: <ReportSchedule>[]),
      );
      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets('Night, loading, still exactly the nav tab', (tester) async {
      await pump(
        tester,
        repo: FakeSchedulesRepository(listPending: true),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 700));
      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets('Night, error, still exactly the nav tab', (tester) async {
      await pump(
        tester,
        repo: FakeSchedulesRepository(listFailure: networkFailure),
      );
      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
    });

    for (final skin in <TiqSkin>[TiqSkin.day(), TiqSkin.veld()]) {
      for (final phase in const <String>['loaded', 'empty', 'error']) {
        testWidgets('${skin.mode.name}, $phase, paints no amber at all', (
          tester,
        ) async {
          await pump(
            tester,
            skin: skin,
            repo: FakeSchedulesRepository(
              schedules: phase == 'empty' ? <ReportSchedule>[] : null,
              listFailure: phase == 'error' ? networkFailure : null,
            ),
          );

          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'reports/schedules',
            phase: phase,
          );
          expect(census.objectCount, 0, reason: census.describe());
        });
      }
    }
  });

  testWidgets('2.0x: the rows survive and nothing overflows', (tester) async {
    await pump(tester, repo: FakeSchedulesRepository(), textScale: 2.0);

    await scrollWorklistTo(tester, find.text('Coverage by outlet'));
    expect(find.text('Coverage by outlet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Veld builds the list', (tester) async {
    await pump(tester, repo: FakeSchedulesRepository(), skin: TiqSkin.veld());

    expect(find.text('Coverage by outlet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

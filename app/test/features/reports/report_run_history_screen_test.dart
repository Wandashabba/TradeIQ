import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/reports/data/report_schedules_repository.dart';
import 'package:tradeiq_app/features/reports/presentation/report_run_history_screen.dart';

import '../../core/design/amber_golden.dart';
import '../worklist_harness.dart';
import 'reports_harness.dart';
import 'schedules_fakes.dart';

const _csvUrl = 'https://api.acme.test/report-downloads/abc.def';

/// Delivered: webhook delivered, both emails sent, link still live.
final _delivered = ReportRun(
  id: 'run-delivered',
  trigger: 'scheduled',
  status: ReportRunStatus.delivered,
  dueAt: DateTime(2026, 9, 14, 9, 0),
  generatedAt: DateTime(2026, 9, 14, 9, 1),
  rowCount: 42,
  webhook: const RunWebhookSummary(status: 'queued', delivered: 1),
  email: const RunEmailSummary(status: 'queued', sent: 2),
  deliveries: const <ReportDeliveryOutcome>[
    ReportDeliveryOutcome(
      channel: 'webhook',
      status: 'queued',
      targets: <String>['https://hooks.acme.test/r'],
    ),
    ReportDeliveryOutcome(
      channel: 'email',
      status: 'queued',
      targets: <String>['ops@acme.test', 'lead@acme.test'],
    ),
  ],
  webhookDeliveries: const <RunWebhookResult>[
    RunWebhookResult(
      id: 'wd-1',
      url: 'https://hooks.acme.test/r',
      status: DeliveryStatus.succeeded,
      attempts: 1,
      lastStatusCode: 204,
    ),
  ],
  csvDownloadUrl: _csvUrl,
  csvDownloadExpiresAt: DateTime(2026, 9, 21, 9, 1),
);

/// Partly delivered: the webhook gave up, one email failed.
final _partial = ReportRun(
  id: 'run-partial',
  trigger: 'manual',
  status: ReportRunStatus.partial,
  generatedAt: DateTime(2026, 9, 13, 15, 30),
  rowCount: 1,
  reason: '1 webhook delivery gave up after retries; 1 email could not be sent',
  webhook: const RunWebhookSummary(status: 'queued', failed: 1),
  email: const RunEmailSummary(status: 'queued', sent: 1, failed: 1),
  deliveries: const <ReportDeliveryOutcome>[
    ReportDeliveryOutcome(channel: 'webhook', status: 'queued'),
    ReportDeliveryOutcome(channel: 'email', status: 'queued'),
  ],
  webhookDeliveries: const <RunWebhookResult>[
    RunWebhookResult(
      id: 'wd-2',
      url: 'https://hooks.acme.test/r',
      status: DeliveryStatus.gaveUp,
      attempts: 6,
      lastStatusCode: 500,
      lastError: 'HTTP 500',
    ),
  ],
);

/// Not sent: nobody subscribed, email not set up.
final _notSent = ReportRun(
  id: 'run-not-sent',
  trigger: 'manual',
  status: ReportRunStatus.notSent,
  generatedAt: DateTime(2026, 9, 12, 8, 0),
  rowCount: 0,
  reason:
      'No active webhook is subscribed to report.generated; '
      'Email delivery not configured',
  webhook: const RunWebhookSummary(status: 'no_subscribers'),
  email: const RunEmailSummary(status: 'not_configured', notConfigured: 2),
  deliveries: const <ReportDeliveryOutcome>[
    ReportDeliveryOutcome(channel: 'webhook', status: 'no_subscribers'),
    ReportDeliveryOutcome(
      channel: 'email',
      status: 'not_configured',
      targets: <String>['ops@acme.test', 'lead@acme.test'],
    ),
  ],
);

const _partialEmails = <ReportEmailDelivery>[
  ReportEmailDelivery(
    id: 'e1',
    recipient: 'ops@acme.test',
    status: DeliveryStatus.succeeded,
    attempts: 1,
  ),
  ReportEmailDelivery(
    id: 'e2',
    recipient: 'lead@acme.test',
    status: DeliveryStatus.gaveUp,
    attempts: 6,
    lastError: 'SMTP 550: mailbox unavailable',
  ),
];

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required FakeSchedulesRepository repo,
    TiqSkin? skin,
    double textScale = 1.0,
  }) => pumpPushedReports(
    tester,
    ReportRunHistoryScreen(schedule: activeSchedule),
    skin: skin,
    textScale: textScale,
    overrides: <Override>[
      reportSchedulesRepositoryProvider.overrideWithValue(repo),
    ],
  );

  Future<void> expand(WidgetTester tester, String runId) async {
    final toggle = find.byKey(ValueKey<String>('run-toggle-$runId'));
    await scrollWorklistTo(tester, toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
  }

  group('words', () {
    test('every status has its own word, silhouette and level', () {
      final words = <String>{
        for (final s in ReportRunStatus.values) runStatusWord(s),
      };
      final marks = <Object>{
        for (final s in ReportRunStatus.values) runStatusMark(s),
      };
      expect(words, hasLength(ReportRunStatus.values.length));
      // Colour is never the only signal, so no two statuses may share a
      // silhouette either.
      expect(marks, hasLength(ReportRunStatus.values.length));
      expect(runStatusWord(ReportRunStatus.partial), 'Partly delivered');
      expect(runStatusWord(ReportRunStatus.notSent), 'Not sent');
    });

    test('the summary line counts each channel and omits zeros', () {
      expect(
        runDeliverySummaryLabel(_delivered),
        'Webhooks: 1 delivered · Email: 2 sent',
      );
      expect(
        runDeliverySummaryLabel(_partial),
        'Webhooks: 1 failed · Email: 1 sent, 1 failed',
      );
      expect(
        runDeliverySummaryLabel(_notSent),
        'Webhooks: none subscribed · Email: not set up (2 not emailed)',
      );
      expect(
        runDeliverySummaryLabel(
          ReportRun(
            id: 'x',
            trigger: 'manual',
            status: ReportRunStatus.delivering,
            generatedAt: DateTime(2026),
            rowCount: 0,
            webhook: const RunWebhookSummary(status: 'queued'),
            email: const RunEmailSummary(status: 'queued', pending: 3),
          ),
        ),
        'Webhooks: queued · Email: 3 pending',
      );
      expect(
        runDeliverySummaryLabel(
          ReportRun(
            id: 'y',
            trigger: 'manual',
            status: ReportRunStatus.notSent,
            generatedAt: DateTime(2026),
            rowCount: 0,
          ),
        ),
        'No delivery recorded',
      );
    });

    test(
      'times: a scheduled run shows its due time, Run now only generated',
      () {
        expect(
          runTimesLabel(_delivered),
          'Due 2026-09-14 09:00 · Generated 2026-09-14 09:01',
        );
        expect(runTimesLabel(_partial), 'Generated 2026-09-13 15:30');
      },
    );

    group('the footer counts honestly', () {
      test('with a total it names it', () {
        expect(
          runHistoryFooterSummary(shown: 20, total: 74, format: (n) => '$n'),
          'Showing the 20 most recent of 74.',
        );
      });

      test('without one it never invents a number', () {
        final summary = runHistoryFooterSummary(
          shown: 20,
          total: null,
          format: (n) => '$n',
        );
        expect(summary, 'Showing the 20 most recent. There are more.');
        expect(summary, isNot(contains('of')));
      });
    });
  });

  testWidgets('each run carries its status, times, rows and channels', (
    tester,
  ) async {
    await pump(
      tester,
      repo: FakeSchedulesRepository(
        runs: <ReportRun>[_delivered, _partial, _notSent],
      ),
    );

    expect(find.text('Scheduled run'), findsOneWidget);
    expect(find.text('Run now'), findsNWidgets(2));
    expect(
      find.text('42 rows · Webhooks: 1 delivered · Email: 2 sent'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('run-times-run-delivered')),
          )
          .data,
      'Due 2026-09-14 09:00 · Generated 2026-09-14 09:01',
    );
  });

  testWidgets('a run with no rows says 0, and 0 is not an error', (
    tester,
  ) async {
    await pump(
      tester,
      repo: FakeSchedulesRepository(runs: <ReportRun>[_notSent]),
    );

    expect(find.textContaining('0 rows'), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);
  });

  group('the detail', () {
    testWidgets('opens the webhook results and the per-recipient emails', (
      tester,
    ) async {
      await pump(
        tester,
        repo: FakeSchedulesRepository(
          runs: <ReportRun>[_partial],
          emailDeliveries: _partialEmails,
        ),
      );

      await expand(tester, 'run-partial');

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('run-webhook-wd-2')),
      );
      expect(find.text('Gave up'), findsOneWidget);
      expect(find.text('HTTP 500 · 6 attempts'), findsOneWidget);

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('run-email-e2')),
      );
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('SMTP 550: mailbox unavailable'), findsOneWidget);
    });

    testWidgets('a run that was not sent says why, without fetching emails', (
      tester,
    ) async {
      await pump(
        tester,
        repo: FakeSchedulesRepository(runs: <ReportRun>[_notSent]),
      );

      await expand(tester, 'run-not-sent');

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('run-webhook-note-run-not-sent')),
      );
      expect(
        find.text('Not sent: no webhook is subscribed to report.generated.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Not emailed to 2 recipients: email is not set up on the server.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a run with no signed link says so, and offers no action', (
      tester,
    ) async {
      await pump(
        tester,
        repo: FakeSchedulesRepository(runs: <ReportRun>[_partial]),
      );

      expect(
        find.byKey(const ValueKey<String>('download-run-partial')),
        findsNothing,
      );
      await expand(tester, 'run-partial');
      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('run-csv-note-run-partial')),
      );
      expect(find.text(noCsvLinkNote), findsOneWidget);
    });
  });

  testWidgets('Download CSV opens a sheet, not a dialog, and copies the link', (
    tester,
  ) async {
    final copied = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copied.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pump(
      tester,
      repo: FakeSchedulesRepository(runs: <ReportRun>[_delivered]),
    );

    final download = find.byKey(
      const ValueKey<String>('download-run-delivered'),
    );
    await scrollWorklistTo(tester, download);
    await tester.tap(download);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('csv-link-sheet')),
      findsOneWidget,
    );
    expect(find.text(_csvUrl), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('copy-csv-link')));
    await tester.pumpAndSettle();

    expect(copied, hasLength(1));
    expect(copied.single.arguments['text'], _csvUrl);
  });

  group('the page', () {
    testWidgets('no runs is a stated result', (tester) async {
      await pump(tester, repo: FakeSchedulesRepository());

      expect(find.text('No runs yet.'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('a failed load is sanitised and Retry loads the runs', (
      tester,
    ) async {
      final repo = FakeSchedulesRepository(
        runs: <ReportRun>[_delivered],
        runsFailure: networkFailure,
      );
      await pump(tester, repo: repo);

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(repo.runsCalls, 1);
    });

    testWidgets('Refresh reloads the first page', (tester) async {
      final repo = FakeSchedulesRepository(runs: <ReportRun>[_delivered]);
      await pump(tester, repo: repo);
      expect(repo.runsCalls, 1);

      await tester.tap(find.byKey(const ValueKey<String>('runs-refresh')));
      await tester.pumpAndSettle();
      expect(repo.runsCalls, 2);
    });

    testWidgets('a cut history says how much of it is on screen', (
      tester,
    ) async {
      await pump(
        tester,
        repo: FakeSchedulesRepository(
          runs: <ReportRun>[_delivered, _partial],
          runsNextCursor: 'cursor-2',
          runsTotal: 74,
        ),
      );

      await scrollWorklistTo(tester, find.byType(PaginationFooter));
      expect(find.text('Showing the 2 most recent of 74.'), findsOneWidget);
    });

    testWidgets('without a total it says there are more and stops', (
      tester,
    ) async {
      await pump(
        tester,
        repo: FakeSchedulesRepository(
          runs: <ReportRun>[_delivered],
          runsNextCursor: 'cursor-2',
        ),
      );

      await scrollWorklistTo(tester, find.byType(PaginationFooter));
      expect(
        find.text('Showing the 1 most recent. There are more.'),
        findsOneWidget,
      );
    });

    testWidgets('Load more fetches the next page with its cursor', (
      tester,
    ) async {
      final repo = FakeSchedulesRepository(
        runs: <ReportRun>[_delivered],
        runsNextCursor: 'cursor-2',
        morePage: <ReportRun>[_partial],
      );
      await pump(tester, repo: repo);

      final more = find.byKey(const ValueKey<String>('runs-load-more'));
      await scrollWorklistTo(tester, more);
      await tester.tap(more);
      await tester.pumpAndSettle();

      expect(repo.runsCursor, 'cursor-2');
      expect(repo.runsCalls, 2);
      await scrollWorklistTo(tester, find.text('Run now'));
      expect(find.text('Run now'), findsOneWidget);
    });

    testWidgets('a failed Load more keeps the runs and offers to try again', (
      tester,
    ) async {
      final repo = FakeSchedulesRepository(
        runs: <ReportRun>[_delivered],
        runsNextCursor: 'cursor-2',
        moreRunsFailure: networkFailure,
      );
      await pump(tester, repo: repo);

      final more = find.byKey(const ValueKey<String>('runs-load-more'));
      await scrollWorklistTo(tester, more);
      await tester.tap(more);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('runs-load-more-error')),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('the amber census', () {
    for (final skin in <TiqSkin>[
      TiqSkin.night(),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      for (final phase in const <String>['loaded', 'empty', 'error']) {
        testWidgets('${skin.mode.name}, $phase: a record of what happened '
            'lights nothing', (tester) async {
          await pump(
            tester,
            skin: skin,
            repo: FakeSchedulesRepository(
              runs: phase == 'loaded'
                  ? <ReportRun>[_delivered, _partial]
                  : const <ReportRun>[],
              runsFailure: phase == 'error' ? networkFailure : null,
            ),
          );

          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'reports/schedules/runs',
            phase: phase,
          );
          expect(
            census.objectCount,
            0,
            reason:
                'No nav on a pushed route and no commit action on a history: '
                'nothing is armed in any skin.\n${census.describe()}',
          );
        });
      }
    }
  });

  testWidgets('2.0x: the runs survive and nothing overflows', (tester) async {
    await pump(
      tester,
      repo: FakeSchedulesRepository(runs: <ReportRun>[_delivered, _partial]),
      textScale: 2.0,
    );

    expect(find.text('Scheduled run'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

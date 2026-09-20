import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/widgets/lumen_kit.dart';
import 'package:tradeiq_app/features/reports/data/report_schedules_repository.dart';
import 'package:tradeiq_app/features/reports/presentation/report_run_history_screen.dart';

import '../../core/theme/tiq_colors_test.dart' show contrastRatio;
import '../../helpers/routed_app.dart';

const _schedule = ReportSchedule(
  id: 's1',
  reportDefinitionId: 'r1',
  reportName: 'Coverage by outlet',
  cadence: 'daily',
  recipients: ['ops@acme.test', 'lead@acme.test'],
  active: true,
);

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
  deliveries: const [
    ReportDeliveryOutcome(
      channel: 'webhook',
      status: 'queued',
      targets: ['https://hooks.acme.test/r'],
    ),
    ReportDeliveryOutcome(
      channel: 'email',
      status: 'queued',
      targets: ['ops@acme.test', 'lead@acme.test'],
    ),
  ],
  webhookDeliveries: const [
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
  deliveries: const [
    ReportDeliveryOutcome(channel: 'webhook', status: 'queued'),
    ReportDeliveryOutcome(channel: 'email', status: 'queued'),
  ],
  webhookDeliveries: const [
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
  deliveries: const [
    ReportDeliveryOutcome(channel: 'webhook', status: 'no_subscribers'),
    ReportDeliveryOutcome(
      channel: 'email',
      status: 'not_configured',
      targets: ['ops@acme.test', 'lead@acme.test'],
    ),
  ],
);

const _partialEmails = [
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

class _FakeRunsRepository implements ReportSchedulesRepository {
  _FakeRunsRepository({
    List<List<ReportRun>>? pages,
    this.failRuns = false,
    this.failMore = false,
    this.failEmails = false,
    this.pendingRuns,
  }) : pages =
           pages ??
           [
             [_delivered, _partial, _notSent],
           ];

  /// Each inner list is one page; every page but the last has a next cursor.
  List<List<ReportRun>> pages;
  bool failRuns;
  final bool failMore;
  final bool failEmails;
  final Completer<PaginatedResponse<ReportRun>>? pendingRuns;

  final runCalls = <String?>[];
  final emailCalls = <String>[];

  @override
  Future<PaginatedResponse<ReportRun>> listRuns(
    String scheduleId, {
    String? cursor,
    int limit = reportRunsPageSize,
  }) async {
    runCalls.add(cursor);
    if (pendingRuns != null && cursor == null) return pendingRuns!.future;
    if (failRuns) throw Exception('boom');
    if (cursor != null && failMore) throw Exception('boom');
    final index = cursor == null ? 0 : int.parse(cursor.substring(5));
    return PaginatedResponse(
      data: pages[index],
      nextCursor: index + 1 < pages.length ? 'page-${index + 1}' : null,
    );
  }

  @override
  Future<List<ReportEmailDelivery>> listEmailDeliveries(
    String scheduleId,
    String runId,
  ) async {
    emailCalls.add(runId);
    if (failEmails) throw Exception('boom');
    return runId == _partial.id ? _partialEmails : const [];
  }

  @override
  Future<PaginatedResponse<ReportSchedule>> listSchedules() async =>
      throw UnimplementedError();

  @override
  Future<ReportSchedule> createSchedule({
    required String reportDefinitionId,
    required String cadence,
    required List<String> recipients,
  }) async => throw UnimplementedError();

  @override
  Future<ReportSchedule> setActive(String id, bool active) async =>
      throw UnimplementedError();

  @override
  Future<ReportSchedule> updateSchedule(
    String id, {
    String? cadence,
    List<String>? recipients,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteSchedule(String id) async => throw UnimplementedError();

  @override
  Future<ScheduleRunResult> runNow(String id) async =>
      throw UnimplementedError();
}

Widget _app(ReportSchedulesRepository repo, {ThemeData? theme}) => routedApp(
  const ReportRunHistoryScreen(schedule: _schedule),
  theme: theme,
  overrides: [reportSchedulesRepositoryProvider.overrideWithValue(repo)],
);

Finder _inRow(String runId, Finder matching) => find.descendant(
  of: find.byKey(ValueKey<String>('run-$runId')),
  matching: matching,
);

void main() {
  group('words', () {
    test('every status has its own word, glyph and level', () {
      final words = {for (final s in ReportRunStatus.values) runStatusWord(s)};
      final glyphs = {
        for (final s in ReportRunStatus.values) runStatusGlyph(s),
      };
      expect(words, hasLength(ReportRunStatus.values.length));
      expect(glyphs, hasLength(ReportRunStatus.values.length));
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
  });

  testWidgets(
    'lists runs with a glyph and a word, times, rows, summary and reason',
    (tester) async {
      await tester.pumpWidget(_app(_FakeRunsRepository()));
      await tester.pumpAndSettle();

      expect(find.text('Run history'), findsOneWidget);
      expect(find.text('Coverage by outlet'), findsOneWidget);
      expect(find.text('3 runs'), findsOneWidget);

      // Status is a glyph and a word, never colour alone.
      for (final (run, glyph, word) in [
        (_delivered, '✓', 'DELIVERED'),
        (_partial, '!', 'PARTLY DELIVERED'),
        (_notSent, '–', 'NOT SENT'),
      ]) {
        expect(
          _inRow(run.id, find.text(glyph)),
          findsOneWidget,
          reason: run.id,
        );
        expect(_inRow(run.id, find.text(word)), findsOneWidget, reason: run.id);
      }

      expect(find.text('Scheduled run'), findsOneWidget);
      expect(find.text('Run now'), findsNWidgets(2));
      expect(
        find.text('Due 2026-09-14 09:00 · Generated 2026-09-14 09:01'),
        findsOneWidget,
      );
      expect(
        find.text('42 rows · Webhooks: 1 delivered · Email: 2 sent'),
        findsOneWidget,
      );
      expect(
        find.text('1 row · Webhooks: 1 failed · Email: 1 sent, 1 failed'),
        findsOneWidget,
      );
      expect(
        _inRow(
          _notSent.id,
          find.textContaining('No active webhook is subscribed'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Download CSV appears only with a link, and copies it', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(_app(_FakeRunsRepository()));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('download-run-delivered')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('download-run-partial')), findsNothing);
    expect(find.byKey(const ValueKey('download-run-not-sent')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('download-run-delivered')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('csv-link-dialog')), findsOneWidget);
    expect(find.text(_csvUrl), findsOneWidget);
    expect(find.textContaining('until 2026-09-21 09:01'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('copy-csv-link')));
    await tester.pumpAndSettle();

    expect(copied, _csvUrl);
    expect(find.byKey(const ValueKey('csv-link-dialog')), findsNothing);
    expect(find.text('Download link copied'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'opening a run shows webhook results and per-recipient email deliveries',
    (tester) async {
      final repo = _FakeRunsRepository();
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      expect(repo.emailCalls, isEmpty, reason: 'fetched only when opened');

      await tester.tap(find.byKey(const ValueKey('run-toggle-run-partial')));
      await tester.pumpAndSettle();

      expect(repo.emailCalls, ['run-partial']);
      final detail = find.byKey(const ValueKey('run-detail-run-partial'));
      Finder inDetail(Finder f) => find.descendant(of: detail, matching: f);

      final webhook = find.byKey(const ValueKey('run-webhook-wd-2'));
      expect(
        find.descendant(
          of: webhook,
          matching: find.text('https://hooks.acme.test/r'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: webhook, matching: find.text('GAVE UP')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: webhook, matching: find.text('HTTP 500')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: webhook, matching: find.text('6 attempts')),
        findsOneWidget,
      );

      final sent = find.byKey(const ValueKey('run-email-e1'));
      expect(
        find.descendant(of: sent, matching: find.text('ops@acme.test')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sent, matching: find.text('SENT')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sent, matching: find.text('1 attempt')),
        findsOneWidget,
      );

      final failed = find.byKey(const ValueKey('run-email-e2'));
      expect(
        find.descendant(of: failed, matching: find.text('lead@acme.test')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: failed, matching: find.text('FAILED')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: failed, matching: find.text('6 attempts')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: failed,
          matching: find.text('SMTP 550: mailbox unavailable'),
        ),
        findsOneWidget,
      );

      expect(inDetail(find.text(noCsvLinkNote)), findsOneWidget);

      // Closing hides it again.
      await tester.tap(find.byKey(const ValueKey('run-toggle-run-partial')));
      await tester.pumpAndSettle();
      expect(detail, findsNothing);
    },
  );

  testWidgets('a run that was not sent says why, without fetching emails', (
    tester,
  ) async {
    final repo = _FakeRunsRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('run-toggle-run-not-sent')));
    await tester.pumpAndSettle();

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
    expect(repo.emailCalls, isEmpty);
  });

  testWidgets(
    'a failed email log load is an error with a retry, in the detail',
    (tester) async {
      await tester.pumpWidget(_app(_FakeRunsRepository(failEmails: true)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('run-toggle-run-partial')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Failed to load email deliveries'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    },
  );

  testWidgets('shows a spinner while runs load', (tester) async {
    final pending = Completer<PaginatedResponse<ReportRun>>();
    await tester.pumpWidget(_app(_FakeRunsRepository(pendingRuns: pending)));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Coverage by outlet'), findsOneWidget);

    pending.complete(const PaginatedResponse(data: [], nextCursor: null));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('no runs is a stated result', (tester) async {
    await tester.pumpWidget(_app(_FakeRunsRepository(pages: [const []])));
    await tester.pumpAndSettle();

    expect(find.text('No runs yet'), findsOneWidget);
    expect(find.text('0 runs'), findsOneWidget);
  });

  testWidgets('a failed load shows an error, and Retry loads the runs', (
    tester,
  ) async {
    final repo = _FakeRunsRepository(failRuns: true);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Failed to load report runs. Something went wrong. Please try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('3 runs'), findsNothing);

    repo.failRuns = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('3 runs'), findsOneWidget);
    expect(repo.runCalls, [null, null]);
  });

  testWidgets('Refresh reloads the first page', (tester) async {
    final repo = _FakeRunsRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text('3 runs'), findsOneWidget);

    repo.pages = [
      [_partial],
    ];
    await tester.tap(find.byKey(const ValueKey('runs-refresh')));
    await tester.pumpAndSettle();

    expect(repo.runCalls, [null, null]);
    expect(find.text('1 run'), findsOneWidget);
    expect(find.byKey(const ValueKey('run-run-delivered')), findsNothing);
  });

  testWidgets('Load more fetches the next page with its cursor and appends', (
    tester,
  ) async {
    final repo = _FakeRunsRepository(
      pages: [
        [_delivered, _partial],
        [_notSent],
      ],
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('2 runs shown'), findsOneWidget);
    expect(find.byKey(const ValueKey('run-run-not-sent')), findsNothing);

    final more = find.byKey(const ValueKey('runs-load-more'));
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();

    expect(repo.runCalls, [null, 'page-1']);
    expect(find.text('3 runs'), findsOneWidget);
    expect(find.byKey(const ValueKey('run-run-not-sent')), findsOneWidget);
    expect(more, findsNothing, reason: 'the last page has no next cursor');
  });

  testWidgets('a failed Load more keeps the runs and offers to try again', (
    tester,
  ) async {
    final repo = _FakeRunsRepository(
      failMore: true,
      pages: [
        [_delivered],
        [_notSent],
      ],
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    final more = find.byKey(const ValueKey('runs-load-more'));
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('run-run-delivered')), findsOneWidget);
    expect(find.byKey(const ValueKey('runs-load-more-error')), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  for (final (name, theme, palette) in [
    ('light', AppTheme.light(), TiqColors.light),
    ('night', AppTheme.dark(), TiqColors.night),
  ]) {
    group('Lumen Glass ($name)', () {
      testWidgets('runs are no-blur glass tiles inside a glass panel', (
        tester,
      ) async {
        await tester.pumpWidget(_app(_FakeRunsRepository(), theme: theme));
        await tester.pumpAndSettle();

        expect(palette.glass, isTrue);
        final panes = tester
            .widgetList<GlassPane>(
              find.ancestor(
                of: find.byKey(const ValueKey('run-times-run-delivered')),
                matching: find.byType(GlassPane),
              ),
            )
            .toList();
        expect(panes.any((p) => p.kind == GlassKind.tile && !p.blur), isTrue);
        expect(panes.any((p) => p.kind == GlassKind.panel), isTrue);
        // The glyph is a Lumen status tile beside the word.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('run-glyph-run-delivered')),
            matching: find.text('✓'),
          ),
          findsOneWidget,
        );
        expect(
          find.ancestor(
            of: find.text('DELIVERED'),
            matching: find.byType(LumenStatusPill),
          ),
          findsOneWidget,
        );

        // Detail deliveries are glass tiles too.
        await tester.tap(find.byKey(const ValueKey('run-toggle-run-partial')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<GlassPane>(
                find.ancestor(
                  of: find.text('lead@acme.test').last,
                  matching: find.byType(GlassPane),
                ),
              )
              .any((p) => p.kind == GlassKind.tile && !p.blur),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('status words clear AA 4.5:1 on their wash', (tester) async {
        await tester.pumpWidget(_app(_FakeRunsRepository(), theme: theme));
        await tester.pumpAndSettle();

        for (final word in const [
          'DELIVERED',
          'PARTLY DELIVERED',
          'NOT SENT',
        ]) {
          final pill = find.ancestor(
            of: find.text(word),
            matching: find.byType(LumenStatusPill),
          );
          final box = tester.widget<Container>(
            find.descendant(of: pill, matching: find.byType(Container)).first,
          );
          final wash = (box.decoration! as BoxDecoration).color!;
          final ink = tester.widget<Text>(find.text(word)).style!.color!;
          final ratio = contrastRatio(
            ink,
            Color.alphaBlend(wash, palette.surface1),
          );
          expect(ratio, greaterThanOrEqualTo(4.5), reason: '$word ($name)');
        }
      });

      testWidgets('the error state renders on glass', (tester) async {
        await tester.pumpWidget(
          _app(_FakeRunsRepository(failRuns: true), theme: theme),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Failed to load report runs'),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsOneWidget);
        expect(
          find.ancestor(
            of: find.text('Coverage by outlet'),
            matching: find.byType(GlassPane),
          ),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      });
    });
  }
}

import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/console_page.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../data/report_schedules_repository.dart';
import 'report_schedules_screen.dart' show reportStamp;

// ── Words ───────────────────────────────────────────────────────────────────
//
// Pure, so every phrasing is tested without pumping a screen. State is always
// a word as well as a mark, and the mark is a silhouette rather than a hue.

String runStatusWord(ReportRunStatus status) => switch (status) {
  ReportRunStatus.delivering => 'Delivering',
  ReportRunStatus.delivered => 'Delivered',
  ReportRunStatus.partial => 'Partly delivered',
  ReportRunStatus.failed => 'Failed',
  ReportRunStatus.notSent => 'Not sent',
  ReportRunStatus.unknown => 'Unknown',
};

StatusLevel runStatusLevel(ReportRunStatus status) => switch (status) {
  ReportRunStatus.delivered => StatusLevel.onTarget,
  ReportRunStatus.partial => StatusLevel.watch,
  ReportRunStatus.failed => StatusLevel.critical,
  ReportRunStatus.delivering => StatusLevel.live,
  ReportRunStatus.notSent || ReportRunStatus.unknown => StatusLevel.held,
};

/// The mark beside the word: a distinct silhouette per status, so two quiet
/// states (still sending, never sent) never read alike in greyscale.
MarkShape runStatusMark(ReportRunStatus status) => switch (status) {
  ReportRunStatus.delivered => MarkShape.sectionTickDisc,
  ReportRunStatus.partial => MarkShape.watchTriangle,
  ReportRunStatus.failed => MarkShape.criticalTriangle,
  ReportRunStatus.delivering => MarkShape.sectionHalfDisc,
  ReportRunStatus.notSent => MarkShape.heldSquare,
  ReportRunStatus.unknown => MarkShape.sectionBarredRing,
};

String runTitle(ReportRun run) => run.scheduled ? 'Scheduled run' : 'Run now';

/// "Due 2026-09-14 09:00 · Generated 2026-09-14 09:01", in the same local
/// stamp the schedules list uses. A Run now has no due time.
String runTimesLabel(ReportRun run) {
  final generated = 'Generated ${reportStamp(run.generatedAt)}';
  final due = run.dueAt;
  return run.scheduled && due != null
      ? 'Due ${reportStamp(due)} · $generated'
      : generated;
}

/// "1 284 rows", through the reader's own grouping.
///
/// [format] is [TiqNumber.format]: a row count is a figure, and a figure that
/// bypasses it is the one place in the app that ignores an Afrikaans reader's
/// group separator.
String rowCountLabel(int n, String Function(num) format) =>
    '${format(n)} ${n == 1 ? 'row' : 'rows'}';

/// What the history footer says when the list has been cut.
///
/// With a total it names it — "Showing the 20 most recent of 74." Without one
/// it says there are more and **never invents a number**: a fabricated total
/// on a delivery history is a manager believing they have seen every failure.
String runHistoryFooterSummary({
  required int shown,
  required int? total,
  required String Function(num) format,
}) {
  if (total == null) {
    return 'Showing the ${format(shown)} most recent. There are more.';
  }
  return 'Showing the ${format(shown)} most recent of ${format(total)}.';
}

String _counts(List<(int, String)> parts, String none) {
  final said = <String>[
    for (final (n, word) in parts)
      if (n > 0) '$n $word',
  ];
  return said.isEmpty ? none : said.join(', ');
}

/// What each channel did with the run, in one line:
/// "Webhooks: 1 delivered · Email: 2 sent, 1 failed".
String runDeliverySummaryLabel(ReportRun run) {
  final parts = <String>[];

  final webhook = run.webhook;
  switch (webhook.status) {
    case 'queued':
      parts.add(
        'Webhooks: ${_counts(<(int, String)>[
          (webhook.delivered, 'delivered'),
          (webhook.pending, 'pending'),
          (webhook.failed, 'failed'),
        ], 'queued')}',
      );
    case 'no_subscribers':
      parts.add('Webhooks: none subscribed');
    case 'failed':
      parts.add('Webhooks: failed');
  }

  final email = run.email;
  switch (email.status) {
    case 'queued':
      parts.add(
        'Email: ${_counts(<(int, String)>[
          (email.sent, 'sent'),
          (email.pending, 'pending'),
          (email.failed, 'failed'),
        ], 'queued')}',
      );
    case 'not_configured':
      parts.add('Email: not set up (${email.notConfigured} not emailed)');
    case 'no_subscribers':
      parts.add('Email: no valid recipients');
    case 'failed':
      parts.add('Email: failed');
  }

  return parts.isEmpty ? 'No delivery recorded' : parts.join(' · ');
}

String webhookDeliveryWord(DeliveryStatus status) => switch (status) {
  DeliveryStatus.pending => 'Queued',
  DeliveryStatus.succeeded => 'Delivered',
  DeliveryStatus.failedRetrying => 'Retrying',
  DeliveryStatus.gaveUp => 'Gave up',
};

String emailDeliveryWord(DeliveryStatus status) => switch (status) {
  DeliveryStatus.pending => 'Queued',
  DeliveryStatus.succeeded => 'Sent',
  DeliveryStatus.failedRetrying => 'Retrying',
  DeliveryStatus.gaveUp => 'Failed',
};

StatusLevel deliveryLevel(DeliveryStatus status) => switch (status) {
  DeliveryStatus.pending => StatusLevel.held,
  DeliveryStatus.succeeded => StatusLevel.onTarget,
  DeliveryStatus.failedRetrying => StatusLevel.watch,
  DeliveryStatus.gaveUp => StatusLevel.critical,
};

String attemptsLabel(int n) => n == 1 ? '1 attempt' : '$n attempts';

/// Said when a run has no download link. The API does not say which of the
/// two it is, so both are named.
const noCsvLinkNote =
    'No download link. Links need signed links set up on the server, and '
    'stop working 7 days after the run.';

// ── Screen ──────────────────────────────────────────────────────────────────

/// RUN HISTORY — a schedule's runs, newest first (#66).
///
/// Each run carries a silhouette and a word, its times, its row count and what
/// each channel did. Opening a run shows its webhook results and its
/// per-recipient email deliveries; a run whose signed link still works offers
/// the CSV link to copy.
///
/// ## The footer counts honestly
///
/// A cut history says how much of it is on screen. Where the endpoint sends a
/// total it is named — "Showing the 20 most recent of 74." — and where it does
/// not, the footer says there are more and stops there. A delivery history
/// that reads as complete when it is not is a manager who believes they have
/// seen every failure.
///
/// ## Amber, counted
///
/// Not a tab root and no nav, so Night has two content grants and Day and Veld
/// one. Nothing here is armed and nothing is claimed: **zero in every skin**.
/// A record of what already happened has nothing to light.
class ReportRunHistoryScreen extends ConsumerStatefulWidget {
  const ReportRunHistoryScreen({super.key, required this.schedule});

  final ReportSchedule schedule;

  @override
  ConsumerState<ReportRunHistoryScreen> createState() =>
      _ReportRunHistoryScreenState();
}

class _ReportRunHistoryScreenState
    extends ConsumerState<ReportRunHistoryScreen> {
  List<ReportRun> _runs = const <ReportRun>[];
  String? _nextCursor;
  int? _total;
  bool _loading = true;
  Object? _error;

  bool _loadingMore = false;
  Object? _moreError;

  /// Bumped by every reload, so a slow page from before a refresh is dropped
  /// rather than overwriting the fresh one.
  int _generation = 0;

  ReportSchedulesRepository get _repo =>
      ref.read(reportSchedulesRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _fetchFirstPage();
  }

  Future<void> _fetchFirstPage() async {
    final generation = ++_generation;
    try {
      final page = await _repo.listRuns(widget.schedule.id);
      if (!mounted || generation != _generation) return;
      setState(() {
        _runs = page.data;
        _nextCursor = page.nextCursor;
        _total = page.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _refresh() {
    setState(() {
      _loading = true;
      _error = null;
      _moreError = null;
      _loadingMore = false;
    });
    // Delivery states move on; opened runs refetch their emails too.
    ref.invalidate(reportRunEmailDeliveriesProvider);
    return _fetchFirstPage();
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) return;
    final generation = _generation;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    try {
      final page = await _repo.listRuns(widget.schedule.id, cursor: cursor);
      if (!mounted || generation != _generation) return;
      setState(() {
        _runs = <ReportRun>[..._runs, ...page.data];
        _nextCursor = page.nextCursor;
        _total = page.total ?? _total;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _moreError = e;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final s = widget.schedule;

    final List<Widget> body;
    final String phase;
    if (_loading) {
      phase = 'loading';
      body = <Widget>[
        Skeleton(
          label: 'report runs',
          child: const SkeletonRows(count: 4, rowHeight: 80),
        ),
      ];
    } else if (_error != null) {
      phase = 'error';
      body = <Widget>[
        TorchErrorRegion(
          name: 'report runs',
          child: ErrorState(
            message: TorchErrorMessage.sanitise(_error),
            action: TorchSecondaryButton(
              key: const ValueKey<String>('runs-retry'),
              label: 'Try again',
              onPressed: _refresh,
            ),
          ),
        ),
      ];
    } else if (_runs.isEmpty) {
      phase = 'empty';
      body = <Widget>[
        const EmptyState(
          scope: EmptyScope.inPanel,
          headline: 'No runs yet.',
          body: 'A run appears each time the schedule fires or you use Run '
              'now.',
        ),
      ];
    } else {
      phase = 'loaded';
      body = _runList(skin.space.gutter);
    }

    return ConsolePage(
      phase: phase,
      title: 'Run history',
      facts: <String>[
        s.reportName ?? 'Untitled report',
        cadenceLabel(s.cadence),
        s.recipients.isEmpty
            ? 'No recipients'
            : '${s.recipients.length} '
                  '${s.recipients.length == 1 ? 'recipient' : 'recipients'}',
      ],
      back: ConsolePage.backTo(
        'Back to Report schedules',
        () => Navigator.of(context).pop(),
      ),
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchSecondaryButton(
            key: const ValueKey<String>('runs-refresh'),
            label: 'Refresh',
            onPressed: _loading ? null : _refresh,
          ),
        ),
        const SizedBox(height: TiqSpace.s6),
        SectionRule('Runs', count: _runs.isEmpty ? null : _runs.length),
        const SizedBox(height: TiqSpace.s5),
        ...body,
      ],
    );
  }

  List<Widget> _runList(double gutter) {
    final numbers = TiqNumber.of(context);
    final moreError = _moreError;
    return <Widget>[
      TorchBleed(
        extra: gutter * 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var i = 0; i < _runs.length; i++)
              _RunRow(
                key: ValueKey<String>('run-${_runs[i].id}'),
                scheduleId: widget.schedule.id,
                run: _runs[i],
                last: i == _runs.length - 1,
              ),
          ],
        ),
      ),
      if (_nextCursor != null) ...<Widget>[
        const SizedBox(height: TiqSpace.s6),
        if (moreError != null) ...<Widget>[
          ErrorState(
            key: const ValueKey<String>('runs-load-more-error'),
            scope: ErrorScope.inline,
            message: TorchErrorMessage.sanitise(moreError),
          ),
          const SizedBox(height: TiqSpace.s3),
        ],
        TorchBleed(
          extra: gutter * 2,
          child: PaginationFooter(
            key: const ValueKey<String>('runs-footer'),
            summary: runHistoryFooterSummary(
              shown: _runs.length,
              total: _total,
              format: numbers.format,
            ),
            action: TorchSecondaryButton(
              key: const ValueKey<String>('runs-load-more'),
              label: moreError == null ? 'Load more' : 'Try again',
              busy: _loadingMore,
              onPressed: _loadingMore ? null : _loadMore,
            ),
          ),
        ),
      ],
    ];
  }
}

/// Shows the run's signed CSV link to copy.
///
/// A sheet, not a dialog: the ruling deleted the dialog (unify §1.7), and one
/// modal container is one set of insets, one dismissal rule and one answer to
/// what happens to the amber underneath. The console still has no way to open
/// a URL in a browser, so the link is text and Copy is the action.
Future<void> showCsvLinkSheet(BuildContext context, ReportRun run) {
  final url = run.csvDownloadUrl;
  if (url == null) return Future<void>.value();
  final expires = run.csvDownloadExpiresAt;
  return showTorchSheet<void>(
    context,
    builder: (sheetContext) {
      final skin = sheetContext.skin;
      return TorchSheet(
        key: const ValueKey<String>('csv-link-sheet'),
        title: 'Download CSV',
        subtitle:
            'Open this link in a browser to download the report. Anyone with '
            'the link can download it'
            '${expires == null ? '' : ' until ${reportStamp(expires)}'}.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SelectableText(
              url,
              key: const ValueKey<String>('csv-link-text'),
              style: skin.text.monoIdent.style(color: skin.palette.ink1),
            ),
            SizedBox(height: skin.space.blockGap),
            TorchSecondaryButton(
              key: const ValueKey<String>('copy-csv-link'),
              label: 'Copy the link',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
              },
            ),
          ],
        ),
      );
    },
  );
}

class _RunRow extends StatefulWidget {
  const _RunRow({
    super.key,
    required this.scheduleId,
    required this.run,
    required this.last,
  });

  final String scheduleId;
  final ReportRun run;
  final bool last;

  @override
  State<_RunRow> createState() => _RunRowState();
}

class _RunRowState extends State<_RunRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final numbers = TiqNumber.of(context);
    final run = widget.run;
    final level = runStatusLevel(run.status);
    final word = runStatusWord(run.status);
    final reason = run.reason;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SoftRow(
          key: ValueKey<String>('run-row-${run.id}'),
          density: SoftRowDensity.tall,
          title: runTitle(run),
          subtitle: '${rowCountLabel(run.rowCount, numbers.format)} · '
              '${runDeliverySummaryLabel(run)}',
          severity: run.status == ReportRunStatus.failed
              ? SoftRowSeverity.critical
              : run.status == ReportRunStatus.partial
              ? SoftRowSeverity.watch
              : SoftRowSeverity.none,
          severityLabel: run.status == ReportRunStatus.failed
              ? 'Failed'
              : run.status == ReportRunStatus.partial
              ? 'Partly delivered'
              : null,
          leading: TiqMark(
            key: ValueKey<String>('run-glyph-${run.id}'),
            shape: runStatusMark(run.status),
            color: switch (level) {
              StatusLevel.onTarget => skin.palette.good,
              StatusLevel.critical || StatusLevel.watch => skin.palette.bad,
              _ => skin.palette.ink2,
            },
            size: MarkScale.glyph(context, 16),
          ),
          meta: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                runTimesLabel(run),
                key: ValueKey<String>('run-times-${run.id}'),
                style: skin.text.monoIdent.style(color: skin.palette.ink3),
              ),
              const SizedBox(height: TiqSpace.s1),
              Text(
                word,
                key: ValueKey<String>('run-status-${run.id}'),
                style: skin.text.meta.style(color: skin.palette.ink3),
              ),
              if (reason != null)
                Padding(
                  padding: const EdgeInsets.only(top: TiqSpace.s1),
                  child: Text(
                    reason,
                    key: ValueKey<String>('run-reason-${run.id}'),
                    maxLines: _expanded ? null : 2,
                    overflow: _expanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: skin.text.meta.style(color: skin.palette.ink2),
                  ),
                ),
            ],
          ),
          actions: Wrap(
            spacing: TiqSpace.s4,
            children: <Widget>[
              TorchTertiaryButton(
                key: ValueKey<String>('run-toggle-${run.id}'),
                label: _expanded ? 'Hide run details' : 'Show run details',
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
              // A link with nowhere to go is dishonest chrome: a run with no
              // signed link gets no action, not a disabled one.
              if (run.csvDownloadUrl != null)
                TorchTertiaryButton(
                  key: ValueKey<String>('download-${run.id}'),
                  label: 'Download CSV',
                  onPressed: () => showCsvLinkSheet(context, run),
                ),
            ],
          ),
          separator: widget.last && !_expanded
              ? SoftRowSeparator.none
              : SoftRowSeparator.auto,
          semanticsLabel: <String>[
            runTitle(run),
            word,
            runTimesLabel(run),
            rowCountLabel(run.rowCount, numbers.format),
            runDeliverySummaryLabel(run),
            // The reason is the only thing on this screen that says WHICH
            // channel gave up and why. It is painted inside the excluded text
            // column, so if it is not in this list a reader hears "Partly
            // delivered" and never learns what failed — which is what
            // `_DeliveryRow` below already gets right with `?error`.
            ?reason,
          ].join('. '),
        ),
        if (_expanded)
          _RunDetail(
            key: ValueKey<String>('run-detail-${run.id}'),
            scheduleId: widget.scheduleId,
            run: run,
          ),
      ],
    );
  }
}

class _RunDetail extends StatelessWidget {
  const _RunDetail({super.key, required this.scheduleId, required this.run});

  final String scheduleId;
  final ReportRun run;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final note = skin.text.meta.style(color: skin.palette.ink3);
    final expires = run.csvDownloadExpiresAt;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        skin.space.gutter,
        TiqSpace.s3,
        skin.space.gutter,
        TiqSpace.s5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SectionRule('Webhooks'),
          const SizedBox(height: TiqSpace.s3),
          ..._webhookResults(note),
          const SizedBox(height: TiqSpace.s5),
          const SectionRule('Email'),
          const SizedBox(height: TiqSpace.s3),
          _emailResults(note),
          const SizedBox(height: TiqSpace.s5),
          const SectionRule('The file'),
          const SizedBox(height: TiqSpace.s3),
          Text(
            run.csvDownloadUrl == null
                ? noCsvLinkNote
                : 'Signed download link'
                      '${expires == null ? '' : ', works until ${reportStamp(expires)}'}.',
            key: ValueKey<String>('run-csv-note-${run.id}'),
            style: note,
          ),
        ],
      ),
    );
  }

  List<Widget> _webhookResults(TextStyle note) {
    if (run.webhookDeliveries.isNotEmpty) {
      return <Widget>[
        for (var i = 0; i < run.webhookDeliveries.length; i++)
          _DeliveryRow(
            key: ValueKey<String>(
              'run-webhook-${run.webhookDeliveries[i].id}',
            ),
            // A URL is a thing the system calls, not prose.
            subject: run.webhookDeliveries[i].url,
            word: webhookDeliveryWord(run.webhookDeliveries[i].status),
            level: deliveryLevel(run.webhookDeliveries[i].status),
            facts: <String>[
              run.webhookDeliveries[i].lastStatusCode != null
                  ? 'HTTP ${run.webhookDeliveries[i].lastStatusCode}'
                  : run.webhookDeliveries[i].attempts == 0
                  ? 'Not sent yet'
                  : 'No response',
              attemptsLabel(run.webhookDeliveries[i].attempts),
            ],
            // A non-2xx is recorded as "HTTP <code>", which the facts say.
            error:
                run.webhookDeliveries[i].status == DeliveryStatus.succeeded ||
                    run.webhookDeliveries[i].lastError ==
                        'HTTP ${run.webhookDeliveries[i].lastStatusCode}'
                ? null
                : run.webhookDeliveries[i].lastError,
            last: i == run.webhookDeliveries.length - 1,
          ),
      ];
    }
    final outcome = run.outcomeFor('webhook');
    final text = switch (outcome?.status) {
      'no_subscribers' =>
        'Not sent: no webhook is subscribed to $reportGeneratedEvent.',
      'failed' =>
        'Webhook delivery failed'
            '${outcome?.detail == null ? '.' : ': ${outcome!.detail}'}',
      'queued' => 'The webhooks this run was sent to have since been deleted.',
      _ => 'No webhook delivery was recorded.',
    };
    return <Widget>[
      Text(
        text,
        key: ValueKey<String>('run-webhook-note-${run.id}'),
        style: note,
      ),
    ];
  }

  Widget _emailResults(TextStyle note) {
    final outcome = run.outcomeFor('email');
    final n = run.email.notConfigured;
    final text = switch (outcome?.status) {
      'queued' => null,
      'not_configured' =>
        'Not emailed to $n ${n == 1 ? 'recipient' : 'recipients'}: '
            'email is not set up on the server.',
      'no_subscribers' => 'Not emailed: no valid email recipients.',
      'failed' =>
        'Email delivery failed'
            '${outcome?.detail == null ? '.' : ': ${outcome!.detail}'}',
      _ => 'No email delivery was recorded.',
    };
    if (text != null) {
      return Text(
        text,
        key: ValueKey<String>('run-email-note-${run.id}'),
        style: note,
      );
    }
    return _EmailDeliveries(scheduleId: scheduleId, runId: run.id);
  }
}

class _EmailDeliveries extends ConsumerWidget {
  const _EmailDeliveries({required this.scheduleId, required this.runId});

  final String scheduleId;
  final String runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (scheduleId, runId);
    final deliveries = ref.watch(reportRunEmailDeliveriesProvider(key));
    return deliveries.when(
      loading: () => Skeleton(
        label: 'email deliveries',
        child: const SkeletonRows(count: 2, rowHeight: 56),
      ),
      error: (error, stack) => ErrorState(
        scope: ErrorScope.inline,
        message: TorchErrorMessage.sanitise(error),
        action: TorchSecondaryButton(
          label: 'Try again',
          onPressed: () => ref.invalidate(reportRunEmailDeliveriesProvider(key)),
        ),
      ),
      data: (list) => list.isEmpty
          ? Text(
              'No emails were queued for this run.',
              style: context.skin.text.meta.style(
                color: context.skin.palette.ink3,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 0; i < list.length; i++)
                  _DeliveryRow(
                    key: ValueKey<String>('run-email-${list[i].id}'),
                    subject: list[i].recipient,
                    word: emailDeliveryWord(list[i].status),
                    level: deliveryLevel(list[i].status),
                    facts: <String>[attemptsLabel(list[i].attempts)],
                    error: list[i].status == DeliveryStatus.succeeded
                        ? null
                        : list[i].lastError,
                    last: i == list.length - 1,
                  ),
              ],
            ),
    );
  }
}

/// One delivery — a webhook call or an email — as a row: what it went to, its
/// state as a mark and a word, the facts, and the last real diagnostic.
class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({
    super.key,
    required this.subject,
    required this.word,
    required this.level,
    required this.facts,
    required this.last,
    this.error,
  });

  final String subject;
  final String word;
  final StatusLevel level;
  final List<String> facts;
  final String? error;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return SoftRow(
      density: SoftRowDensity.tall,
      title: subject,
      titleTruncation: SoftRowTruncation.middle,
      trailing: StatusChip(level: level, label: word),
      meta: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            facts.join(' · '),
            style: skin.text.monoIdent.style(color: skin.palette.ink3),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: TiqSpace.s1),
              child: Text(
                error!,
                style: skin.text.meta.style(color: skin.palette.ink2),
              ),
            ),
        ],
      ),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[
        subject,
        word,
        ...facts,
        ?error,
      ].join('. '),
    );
  }
}

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
import '../../../l10n/l10n.dart';
import '../data/report_schedules_repository.dart';
import 'report_schedules_screen.dart' show reportStamp;

// ── Words ───────────────────────────────────────────────────────────────────
//
// Pure, so every phrasing is tested without pumping a screen. State is always
// a word as well as a mark, and the mark is a silhouette rather than a hue.

String runStatusWord(ReportRunStatus status, AppLocalizations l10n) =>
    switch (status) {
      ReportRunStatus.delivering => l10n.runStatusDelivering,
      ReportRunStatus.delivered => l10n.runStatusDelivered,
      ReportRunStatus.partial => l10n.runStatusPartial,
      ReportRunStatus.failed => l10n.runStatusFailed,
      ReportRunStatus.notSent => l10n.runStatusNotSent,
      ReportRunStatus.unknown => l10n.runStatusUnknown,
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

String runTitle(ReportRun run, AppLocalizations l10n) =>
    run.scheduled ? l10n.runTitleScheduled : l10n.runTitleManual;

/// "Due 2026-09-14 09:00 · Generated 2026-09-14 09:01", in the same local
/// stamp the schedules list uses. A Run now has no due time.
String runTimesLabel(ReportRun run, AppLocalizations l10n) {
  final generated = l10n.runGeneratedAt(reportStamp(run.generatedAt));
  final due = run.dueAt;
  return run.scheduled && due != null
      ? l10n.runDueAndGenerated(reportStamp(due), generated)
      : generated;
}

/// "1 284 rows", through the reader's own grouping.
///
/// [format] is [TiqNumber.format]: a row count is a figure, and a figure that
/// bypasses it is the one place in the app that ignores an Afrikaans reader's
/// group separator.
String rowCountLabel(int n, String Function(num) format, AppLocalizations l10n) =>
    l10n.runRowCount(format(n), n);

/// What the history footer says when the list has been cut.
///
/// With a total it names it — "Showing the 20 most recent of 74." Without one
/// it says there are more and **never invents a number**: a fabricated total
/// on a delivery history is a manager believing they have seen every failure.
String runHistoryFooterSummary({
  required int shown,
  required int? total,
  required String Function(num) format,
  required AppLocalizations l10n,
}) {
  if (total == null) return l10n.runHistoryFooterMore(format(shown));
  return l10n.runHistoryFooterOf(format(shown), format(total));
}

/// The non-zero counts, joined — "1 delivered, 2 pending" — or [none] when
/// every one of them is zero.
String _counts(List<(int, String)> parts, String none) {
  final said = <String>[
    for (final (n, said) in parts)
      if (n > 0) said,
  ];
  return said.isEmpty ? none : said.join(', ');
}

/// What each channel did with the run, in one line:
/// "Webhooks: 1 delivered · Email: 2 sent, 1 failed".
String runDeliverySummaryLabel(ReportRun run, AppLocalizations l10n) {
  final parts = <String>[];

  final webhook = run.webhook;
  switch (webhook.status) {
    case 'queued':
      parts.add(
        l10n.runWebhooksLine(
          _counts(<(int, String)>[
            (webhook.delivered, l10n.runCountDelivered(webhook.delivered)),
            (webhook.pending, l10n.runCountPending(webhook.pending)),
            (webhook.failed, l10n.runCountFailed(webhook.failed)),
          ], l10n.runCountsQueued),
        ),
      );
    case 'no_subscribers':
      parts.add(l10n.runWebhooksNoneSubscribed);
    case 'failed':
      parts.add(l10n.runWebhooksFailedLine);
  }

  final email = run.email;
  switch (email.status) {
    case 'queued':
      parts.add(
        l10n.runEmailLine(
          _counts(<(int, String)>[
            (email.sent, l10n.runCountSent(email.sent)),
            (email.pending, l10n.runCountPending(email.pending)),
            (email.failed, l10n.runCountFailed(email.failed)),
          ], l10n.runCountsQueued),
        ),
      );
    case 'not_configured':
      parts.add(l10n.runEmailNotSetUpLine(email.notConfigured));
    case 'no_subscribers':
      parts.add(l10n.runEmailNoRecipientsLine);
    case 'failed':
      parts.add(l10n.runEmailFailedLine);
  }

  return parts.isEmpty ? l10n.runNoDeliveryRecorded : parts.join(' · ');
}

String webhookDeliveryWord(DeliveryStatus status, AppLocalizations l10n) =>
    switch (status) {
      DeliveryStatus.pending => l10n.deliveryWordQueued,
      DeliveryStatus.succeeded => l10n.deliveryWordDelivered,
      DeliveryStatus.failedRetrying => l10n.deliveryWordRetrying,
      DeliveryStatus.gaveUp => l10n.deliveryWordGaveUp,
    };

String emailDeliveryWord(DeliveryStatus status, AppLocalizations l10n) =>
    switch (status) {
      DeliveryStatus.pending => l10n.deliveryWordQueued,
      DeliveryStatus.succeeded => l10n.deliveryWordSent,
      DeliveryStatus.failedRetrying => l10n.deliveryWordRetrying,
      DeliveryStatus.gaveUp => l10n.deliveryWordEmailFailed,
    };

StatusLevel deliveryLevel(DeliveryStatus status) => switch (status) {
  DeliveryStatus.pending => StatusLevel.held,
  DeliveryStatus.succeeded => StatusLevel.onTarget,
  DeliveryStatus.failedRetrying => StatusLevel.watch,
  DeliveryStatus.gaveUp => StatusLevel.critical,
};

String attemptsLabel(int n, AppLocalizations l10n) => l10n.deliveryAttempts(n);

/// Said when a run has no download link. The API does not say which of the
/// two it is, so both are named.

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
    final l10n = context.l10n;
    final s = widget.schedule;

    final List<Widget> body;
    final String phase;
    if (_loading) {
      phase = 'loading';
      body = <Widget>[
        Skeleton(
          label: l10n.runHistorySkeleton,
          child: const SkeletonRows(count: 4, rowHeight: 80),
        ),
      ];
    } else if (_error != null) {
      phase = 'error';
      body = <Widget>[
        TorchErrorRegion(
          name: l10n.runHistorySkeleton,
          child: ErrorState(
            message: TorchErrorMessage.sanitise(_error),
            action: TorchSecondaryButton(
              key: const ValueKey<String>('runs-retry'),
              label: l10n.torchTryAgain,
              onPressed: _refresh,
            ),
          ),
        ),
      ];
    } else if (_runs.isEmpty) {
      phase = 'empty';
      body = <Widget>[
        EmptyState(
          scope: EmptyScope.inPanel,
          headline: l10n.runHistoryEmptyHeadline,
          body: l10n.runHistoryEmptyBody,
        ),
      ];
    } else {
      phase = 'loaded';
      body = _runList(skin.space.gutter);
    }

    return ConsolePage(
      phase: phase,
      title: l10n.runHistoryTitle,
      facts: <String>[
        s.reportName ?? l10n.scheduleUntitledReport,
        cadenceLabel(s.cadence, l10n),
        s.recipients.isEmpty
            ? l10n.scheduleNoRecipients
            : l10n.scheduleRecipientCount(s.recipients.length),
      ],
      back: ConsolePage.backTo(
        l10n.runHistoryBack,
        () => Navigator.of(context).pop(),
      ),
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchSecondaryButton(
            key: const ValueKey<String>('runs-refresh'),
            label: l10n.runHistoryRefresh,
            onPressed: _loading ? null : _refresh,
          ),
        ),
        const SizedBox(height: TiqSpace.s6),
        SectionRule(
          l10n.runHistorySection,
          count: _runs.isEmpty ? null : _runs.length,
        ),
        const SizedBox(height: TiqSpace.s5),
        ...body,
      ],
    );
  }

  List<Widget> _runList(double gutter) {
    final l10n = context.l10n;
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
              l10n: l10n,
            ),
            action: TorchSecondaryButton(
              key: const ValueKey<String>('runs-load-more'),
              label: moreError == null
                  ? l10n.runHistoryLoadMore
                  : l10n.torchTryAgain,
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
      final l10n = sheetContext.l10n;
      return TorchSheet(
        key: const ValueKey<String>('csv-link-sheet'),
        title: l10n.runDownloadCsv,
        subtitle: expires == null
            ? l10n.csvLinkSheetSubtitle
            : l10n.csvLinkSheetSubtitleUntil(reportStamp(expires)),
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
              label: l10n.csvLinkCopy,
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
    final l10n = context.l10n;
    final numbers = TiqNumber.of(context);
    final run = widget.run;
    final level = runStatusLevel(run.status);
    final word = runStatusWord(run.status, l10n);
    final reason = run.reason;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SoftRow(
          key: ValueKey<String>('run-row-${run.id}'),
          density: SoftRowDensity.tall,
          title: runTitle(run, l10n),
          subtitle: l10n.runRowSubtitle(
            rowCountLabel(run.rowCount, numbers.format, l10n),
            runDeliverySummaryLabel(run, l10n),
          ),
          severity: run.status == ReportRunStatus.failed
              ? SoftRowSeverity.critical
              : run.status == ReportRunStatus.partial
              ? SoftRowSeverity.watch
              : SoftRowSeverity.none,
          severityLabel: run.status == ReportRunStatus.failed
              ? l10n.runStatusFailed
              : run.status == ReportRunStatus.partial
              ? l10n.runStatusPartial
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
                runTimesLabel(run, l10n),
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
                label: _expanded
                    ? l10n.runHideDetails
                    : l10n.runShowDetails,
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
              // A link with nowhere to go is dishonest chrome: a run with no
              // signed link gets no action, not a disabled one.
              if (run.csvDownloadUrl != null)
                TorchTertiaryButton(
                  key: ValueKey<String>('download-${run.id}'),
                  label: l10n.runDownloadCsv,
                  onPressed: () => showCsvLinkSheet(context, run),
                ),
            ],
          ),
          separator: widget.last && !_expanded
              ? SoftRowSeparator.none
              : SoftRowSeparator.auto,
          semanticsLabel: <String>[
            runTitle(run, l10n),
            word,
            runTimesLabel(run, l10n),
            rowCountLabel(run.rowCount, numbers.format, l10n),
            runDeliverySummaryLabel(run, l10n),
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
    final l10n = context.l10n;
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
          SectionRule(l10n.runDetailSectionWebhooks),
          const SizedBox(height: TiqSpace.s3),
          ..._webhookResults(note, l10n),
          const SizedBox(height: TiqSpace.s5),
          SectionRule(l10n.runDetailSectionEmail),
          const SizedBox(height: TiqSpace.s3),
          _emailResults(note, l10n),
          const SizedBox(height: TiqSpace.s5),
          SectionRule(l10n.runDetailSectionFile),
          const SizedBox(height: TiqSpace.s3),
          Text(
            run.csvDownloadUrl == null
                ? l10n.runNoCsvLinkNote
                : expires == null
                ? l10n.runSignedLink
                : l10n.runSignedLinkUntil(reportStamp(expires)),
            key: ValueKey<String>('run-csv-note-${run.id}'),
            style: note,
          ),
        ],
      ),
    );
  }

  List<Widget> _webhookResults(TextStyle note, AppLocalizations l10n) {
    if (run.webhookDeliveries.isNotEmpty) {
      return <Widget>[
        for (var i = 0; i < run.webhookDeliveries.length; i++)
          _DeliveryRow(
            key: ValueKey<String>(
              'run-webhook-${run.webhookDeliveries[i].id}',
            ),
            // A URL is a thing the system calls, not prose.
            subject: run.webhookDeliveries[i].url,
            word: webhookDeliveryWord(
              run.webhookDeliveries[i].status,
              l10n,
            ),
            level: deliveryLevel(run.webhookDeliveries[i].status),
            facts: <String>[
              run.webhookDeliveries[i].lastStatusCode != null
                  ? l10n.deliveryHttpStatus(
                      run.webhookDeliveries[i].lastStatusCode!,
                    )
                  : run.webhookDeliveries[i].attempts == 0
                  ? l10n.deliveryNotSentYet
                  : l10n.deliveryNoResponse,
              attemptsLabel(run.webhookDeliveries[i].attempts, l10n),
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
      'no_subscribers' => l10n.runWebhookNoSubscriber,
      'failed' => outcome?.detail == null
          ? l10n.runWebhookDeliveryFailed
          : l10n.runWebhookDeliveryFailedWhy(outcome!.detail!),
      'queued' => l10n.runWebhookTargetsDeleted,
      _ => l10n.runWebhookNoneRecorded,
    };
    return <Widget>[
      Text(
        text,
        key: ValueKey<String>('run-webhook-note-${run.id}'),
        style: note,
      ),
    ];
  }

  Widget _emailResults(TextStyle note, AppLocalizations l10n) {
    final outcome = run.outcomeFor('email');
    final n = run.email.notConfigured;
    final text = switch (outcome?.status) {
      'queued' => null,
      'not_configured' => l10n.runEmailNotConfiguredDetail(n),
      'no_subscribers' => l10n.runEmailNoRecipientsDetail,
      'failed' => outcome?.detail == null
          ? l10n.runEmailDeliveryFailed
          : l10n.runEmailDeliveryFailedWhy(outcome!.detail!),
      _ => l10n.runEmailNoneRecorded,
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
    final l10n = context.l10n;
    final key = (scheduleId, runId);
    final deliveries = ref.watch(reportRunEmailDeliveriesProvider(key));
    return deliveries.when(
      loading: () => Skeleton(
        label: l10n.runEmailSkeleton,
        child: const SkeletonRows(count: 2, rowHeight: 56),
      ),
      error: (error, stack) => ErrorState(
        scope: ErrorScope.inline,
        message: TorchErrorMessage.sanitise(error),
        action: TorchSecondaryButton(
          label: l10n.torchTryAgain,
          onPressed: () => ref.invalidate(reportRunEmailDeliveriesProvider(key)),
        ),
      ),
      data: (list) => list.isEmpty
          ? Text(
              l10n.runEmailNoneQueued,
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
                    word: emailDeliveryWord(list[i].status, l10n),
                    level: deliveryLevel(list[i].status),
                    facts: <String>[attemptsLabel(list[i].attempts, l10n)],
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

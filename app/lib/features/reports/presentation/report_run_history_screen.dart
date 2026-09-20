import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/human_error.dart';
import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/glass_page_scaffold.dart';
import '../../../core/widgets/lumen_kit.dart';
import '../../../core/widgets/worklist.dart';
import '../data/report_schedules_repository.dart';
import 'report_schedules_screen.dart' show reportStamp;

// ── Words ───────────────────────────────────────────────────────────────────
//
// Pure, so every phrasing is tested without pumping a screen. State is always
// a word as well as a colour and a glyph.

String runStatusWord(ReportRunStatus status) => switch (status) {
  ReportRunStatus.delivering => 'Delivering',
  ReportRunStatus.delivered => 'Delivered',
  ReportRunStatus.partial => 'Partly delivered',
  ReportRunStatus.failed => 'Failed',
  ReportRunStatus.notSent => 'Not sent',
  ReportRunStatus.unknown => 'Unknown',
};

StatusLevel runStatusLevel(ReportRunStatus status) => switch (status) {
  ReportRunStatus.delivered => StatusLevel.good,
  ReportRunStatus.partial => StatusLevel.warning,
  ReportRunStatus.failed => StatusLevel.critical,
  ReportRunStatus.delivering ||
  ReportRunStatus.notSent ||
  ReportRunStatus.unknown => StatusLevel.neutral,
};

/// The mark beside the word: distinct per status, so two neutral states
/// (still sending, never sent) never read alike.
String runStatusGlyph(ReportRunStatus status) => switch (status) {
  ReportRunStatus.delivered => '✓',
  ReportRunStatus.partial => '!',
  ReportRunStatus.failed => '✕',
  ReportRunStatus.delivering => '…',
  ReportRunStatus.notSent => '–',
  ReportRunStatus.unknown => '?',
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

String rowCountLabel(int n) => '$n ${n == 1 ? 'row' : 'rows'}';

String _counts(List<(int, String)> parts, String none) {
  final said = [
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
        'Webhooks: ${_counts([(webhook.delivered, 'delivered'), (webhook.pending, 'pending'), (webhook.failed, 'failed')], 'queued')}',
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
        'Email: ${_counts([(email.sent, 'sent'), (email.pending, 'pending'), (email.failed, 'failed')], 'queued')}',
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
  DeliveryStatus.pending => StatusLevel.neutral,
  DeliveryStatus.succeeded => StatusLevel.good,
  DeliveryStatus.failedRetrying => StatusLevel.warning,
  DeliveryStatus.gaveUp => StatusLevel.critical,
};

String attemptsLabel(int n) => n == 1 ? '1 attempt' : '$n attempts';

/// Said when a run has no download link. The API does not say which of the
/// two it is, so both are named.
const noCsvLinkNote =
    'No download link. Links need signed links set up on the server, and '
    'stop working 7 days after the run.';

// ── Screen ──────────────────────────────────────────────────────────────────

/// A schedule's run history (#66): every run newest first, each with a status
/// glyph and word, its times, row count and what each channel did. Opening a
/// run shows its webhook results and per-recipient email deliveries; a run
/// whose signed link still works offers the CSV link to copy.
class ReportRunHistoryScreen extends ConsumerStatefulWidget {
  const ReportRunHistoryScreen({super.key, required this.schedule});

  final ReportSchedule schedule;

  @override
  ConsumerState<ReportRunHistoryScreen> createState() =>
      _ReportRunHistoryScreenState();
}

class _ReportRunHistoryScreenState
    extends ConsumerState<ReportRunHistoryScreen> {
  List<ReportRun> _runs = const [];
  String? _nextCursor;
  bool _loading = true;
  Object? _error;
  StackTrace? _stack;

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
        _loading = false;
      });
    } catch (e, st) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e;
        _stack = st;
        _loading = false;
      });
    }
  }

  Future<void> _refresh() {
    setState(() {
      _loading = true;
      _error = null;
      _stack = null;
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
        _runs = [..._runs, ...page.data];
        _nextCursor = page.nextCursor;
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

  AsyncValue<List<ReportRun>> get _value {
    if (_loading) return const AsyncValue.loading();
    final error = _error;
    if (error != null) {
      return AsyncValue.error(error, _stack ?? StackTrace.empty);
    }
    return AsyncValue.data(_runs);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final s = widget.schedule;

    return GlassPageScaffold(
      title: const Text('Run history'),
      actions: [
        IconButton(
          key: const ValueKey<String>('runs-refresh'),
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: _loading ? null : _refresh,
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PanelCard(
            key: const ValueKey<String>('run-history-schedule'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.reportName ?? 'Untitled report',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.ink1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${cadenceLabel(s.cadence)} · '
                  '${s.recipients.isEmpty ? 'No recipients' : 'To ${s.recipients.join(', ')}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: colors.ink2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AsyncSection<List<ReportRun>>(
            value: _value,
            label: 'report runs',
            onRetry: _refresh,
            builder: (runs) => PanelCard(
              title:
                  '${runs.length} ${runs.length == 1 ? 'run' : 'runs'}'
                  '${_nextCursor != null ? ' shown' : ''}',
              subtitle: 'Newest first',
              padded: false,
              child: runs.isEmpty
                  ? const EmptyState(
                      message: 'No runs yet',
                      hint:
                          'A run appears each time the schedule fires or '
                          'you use Run now.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final run in runs)
                          _RunRow(
                            key: ValueKey<String>('run-${run.id}'),
                            scheduleId: s.id,
                            run: run,
                          ),
                        if (_nextCursor != null) _loadMoreFooter(colors),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadMoreFooter(TiqColors colors) {
    final error = _moreError;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Failed to load more runs. ${humanErrorMessage(error)}',
                key: const ValueKey<String>('runs-load-more-error'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: colors.ink2),
              ),
            ),
          _loadingMore
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : OutlinedButton(
                  key: const ValueKey<String>('runs-load-more'),
                  onPressed: _loadMore,
                  child: Text(error == null ? 'Load more' : 'Try again'),
                ),
        ],
      ),
    );
  }
}

/// Shows the run's signed CSV link to copy. The console has no way to open a
/// URL in a browser, so the link is selectable and copied on request.
Future<void> showCsvLinkDialog(BuildContext context, ReportRun run) {
  final url = run.csvDownloadUrl;
  if (url == null) return Future.value();
  final expires = run.csvDownloadExpiresAt;
  final messenger = ScaffoldMessenger.of(context);
  final colors = context.colors;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey<String>('csv-link-dialog'),
      title: const Text('Download CSV'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Open this link in a browser to download the report. Anyone with '
            'the link can download it'
            '${expires == null ? '' : ' until ${reportStamp(expires)}'}.',
            style: TextStyle(fontSize: 12.5, color: colors.ink2),
          ),
          const SizedBox(height: 10),
          SelectableText(
            url,
            key: const ValueKey<String>('csv-link-text'),
            style: TextStyle(
              fontFamily: colors.glass ? LumenGlass.mono : 'monospace',
              fontSize: 11.5,
              color: colors.ink1,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          key: const ValueKey<String>('copy-csv-link'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            messenger.showSnackBar(
              const SnackBar(content: Text('Download link copied')),
            );
          },
          child: const Text('Copy link'),
        ),
      ],
    ),
  );
}

class _RunRow extends StatefulWidget {
  const _RunRow({super.key, required this.scheduleId, required this.run});

  final String scheduleId;
  final ReportRun run;

  @override
  State<_RunRow> createState() => _RunRowState();
}

class _RunRowState extends State<_RunRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final colors = context.colors;
    final level = runStatusLevel(run.status);
    final meta = TextStyle(fontSize: 11.5, color: colors.ink3);
    final reason = run.reason;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        WorklistCardShell(
          edgeColor: level.colorOf(colors),
          child: InkWell(
            key: ValueKey<String>('run-toggle-${run.id}'),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  StatusTile(
                    key: ValueKey<String>('run-glyph-${run.id}'),
                    status: level.lumen,
                    glyph: runStatusGlyph(run.status),
                    size: 28,
                    fontSize: 13,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              runTitle(run),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: colors.ink1,
                              ),
                            ),
                            StatusChip(
                              key: ValueKey<String>('run-status-${run.id}'),
                              label: runStatusWord(run.status),
                              level: level,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          runTimesLabel(run),
                          key: ValueKey<String>('run-times-${run.id}'),
                          style: meta,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${rowCountLabel(run.rowCount)} · '
                          '${runDeliverySummaryLabel(run)}',
                          key: ValueKey<String>('run-summary-${run.id}'),
                          style: meta,
                        ),
                        if (reason != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              reason,
                              key: ValueKey<String>('run-reason-${run.id}'),
                              maxLines: _expanded ? null : 2,
                              overflow: _expanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: colors.ink2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (run.csvDownloadUrl != null)
                    RowAction(
                      key: ValueKey<String>('download-${run.id}'),
                      label: 'Download CSV',
                      onPressed: () => showCsvLinkDialog(context, run),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: colors.ink3,
                      semanticLabel: _expanded
                          ? 'Hide run details'
                          : 'Show run details',
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    final colors = context.colors;
    final note = TextStyle(fontSize: 11.5, color: colors.ink3);
    final expires = run.csvDownloadExpiresAt;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 2, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Kicker('Webhooks'),
          const SizedBox(height: 6),
          ..._webhookResults(note),
          const SizedBox(height: 10),
          const Kicker('Email'),
          const SizedBox(height: 6),
          _emailResults(note),
          const SizedBox(height: 10),
          const Kicker('CSV'),
          const SizedBox(height: 6),
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
      return [
        for (final w in run.webhookDeliveries)
          _DeliveryResultTile(
            key: ValueKey<String>('run-webhook-${w.id}'),
            subject: CodeToken(w.url),
            word: webhookDeliveryWord(w.status),
            level: deliveryLevel(w.status),
            facts: [
              w.lastStatusCode != null
                  ? 'HTTP ${w.lastStatusCode}'
                  : w.attempts == 0
                  ? 'Not sent yet'
                  : 'No response',
              attemptsLabel(w.attempts),
            ],
            // A non-2xx is recorded as "HTTP <code>", which the facts say.
            error:
                w.status == DeliveryStatus.succeeded ||
                    w.lastError == 'HTTP ${w.lastStatusCode}'
                ? null
                : w.lastError,
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
    return [
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
    return AsyncSection<List<ReportEmailDelivery>>(
      value: deliveries,
      label: 'email deliveries',
      onRetry: () => ref.invalidate(reportRunEmailDeliveriesProvider(key)),
      builder: (list) => list.isEmpty
          ? Text(
              'No emails were queued for this run.',
              style: TextStyle(fontSize: 11.5, color: context.colors.ink3),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in list)
                  _DeliveryResultTile(
                    key: ValueKey<String>('run-email-${e.id}'),
                    subject: Text(
                      e.recipient,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: context.colors.ink1,
                      ),
                    ),
                    word: emailDeliveryWord(e.status),
                    level: deliveryLevel(e.status),
                    facts: [attemptsLabel(e.attempts)],
                    error: e.status == DeliveryStatus.succeeded
                        ? null
                        : e.lastError,
                  ),
              ],
            ),
    );
  }
}

/// One delivery — a webhook call or an email — as a no-blur glass tile: what
/// it went to, its state as a word, the facts, and the last error.
class _DeliveryResultTile extends StatelessWidget {
  const _DeliveryResultTile({
    super.key,
    required this.subject,
    required this.word,
    required this.level,
    required this.facts,
    this.error,
  });

  final Widget subject;
  final String word;
  final StatusLevel level;
  final List<String> facts;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final figure = TextStyle(
      fontFamily: colors.glass ? LumenGlass.mono : 'monospace',
      fontSize: 11,
      color: colors.ink3,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GlassPane(
        kind: GlassKind.tile,
        // Repeated down a list: never blurred, and the panel owns the shadow.
        blur: false,
        shadow: false,
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                subject,
                StatusChip(label: word, level: level),
              ],
            ),
            const SizedBox(height: 3),
            Wrap(
              spacing: 10,
              runSpacing: 2,
              children: [for (final f in facts) Text(f, style: figure)],
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  error!,
                  style: TextStyle(fontSize: 11.5, color: colors.ink2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

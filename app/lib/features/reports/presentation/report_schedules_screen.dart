import 'package:flutter/material.dart' show Icons, MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../data/report_schedules_repository.dart';
import 'report_run_history_screen.dart';
import 'report_schedule_form_screen.dart';

/// The standing note on this screen, worded from what the backend does (#66):
/// active schedules fire on their cadence and go to the client's webhooks
/// subscribed to `report.generated`, and are emailed to the recipients once
/// the server has email (SMTP) set up.
/// What a successful Run now is reported as, from what the API says happened:
/// how many rows, how many webhooks a delivery was queued for (or that none
/// listens), and what the email channel did.
///
/// [format] is [TiqNumber.format]: the row count here is the same figure the
/// Reports list and the run history print, and all three have to group it the
/// same way or a manager cross-checking them cannot tell they match.
String runNowMessage(
  ScheduleRunResult result,
  String Function(num) format,
  AppLocalizations l10n,
) {
  final parts = <String>[
    l10n.runNowGeneratedRows(format(result.rowCount), result.rowCount),
  ];

  // Counted from the webhook outcome: `deliveredTo` also lists the email
  // addresses queued to.
  final webhook = result.outcomeFor('webhook');
  final queued = webhook == null
      ? result.deliveredTo.length
      : webhook.status == 'queued'
      ? webhook.targets.length
      : 0;
  if (queued > 0) {
    parts.add(l10n.runNowQueuedWebhooks(queued));
  } else if (webhook?.status == 'failed') {
    parts.add(l10n.runNowWebhookFailed);
  } else {
    parts.add(l10n.runNowNoSubscriber);
  }

  final email = result.outcomeFor('email');
  switch (email?.status) {
    case 'queued':
      parts.add(l10n.runNowEmailing(email!.targets.length));
    case 'not_configured':
      parts.add(l10n.runNowEmailNotConfigured);
    case 'no_subscribers':
      parts.add(l10n.runNowEmailNoSubscribers);
    case 'failed':
      parts.add(l10n.runNowEmailFailed);
  }
  return parts.join(' ');
}

/// "2026-09-14 10:05" in local time — how every report schedule and run time
/// is shown in the console.
String reportStamp(DateTime at) {
  final l = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} '
      '${two(l.hour)}:${two(l.minute)}';
}

/// "Last run 2026-09-14 10:05" in local time, or "Never run".
String lastRunLabel(DateTime? at, AppLocalizations l10n) =>
    at == null ? l10n.scheduleNeverRun : l10n.scheduleLastRun(reportStamp(at));

/// "Next run 2026-09-15 09:00" in local time. A paused schedule has no next
/// run and says so rather than showing a stale time.
String nextRunLabel(ReportSchedule schedule, AppLocalizations l10n) {
  if (!schedule.active) return l10n.schedulePausedNoNextRun;
  final at = schedule.nextRunAt;
  return at == null
      ? l10n.scheduleNextRunNone
      : l10n.scheduleNextRun(reportStamp(at));
}

/// REPORT SCHEDULES — which saved reports run on their own, when, and to whom.
///
/// ## Off is a section, not a shade
///
/// Active and Off are two groups under two section rules, in that order, each
/// with its count. A paused schedule keeps full strength and full type: the
/// toggle's own word carries the state, never a fill step and never a colour,
/// and a schedule nobody can read is a schedule nobody notices has stopped.
///
/// ## A schedule that delivers to nobody says so
///
/// An empty recipients list is almost certainly a mistake, so the row takes
/// the `watch` severity bar and the words with it. It is not crimson-solid:
/// the schedule still runs and still reaches the webhooks, so this is a thing
/// to look at, not a failure that has happened.
///
/// ## The one amber, counted
///
/// A tab root: the nav pill's active tab is slot 1 and nothing here is armed,
/// so the content grant goes unspent. Day and Veld paint zero.
class ReportSchedulesScreen extends ConsumerStatefulWidget {
  const ReportSchedulesScreen({super.key});

  @override
  ConsumerState<ReportSchedulesScreen> createState() =>
      _ReportSchedulesScreenState();
}

class _ReportSchedulesScreenState
    extends ConsumerState<ReportSchedulesScreen> {
  void _refresh() => ref.invalidate(reportSchedulesListProvider);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final schedules = ref.watch(reportSchedulesListProvider);

    return schedules.when(
      loading: () => _frame(
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: l10n.schedulesSkeleton,
            child: const SkeletonRows(count: 3, rowHeight: 80),
          ),
        ],
      ),
      error: (error, stack) => _frame(
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: l10n.schedulesSkeleton,
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('schedules-retry'),
                label: l10n.torchTryAgain,
                onPressed: _refresh,
              ),
            ),
          ),
        ],
      ),
      data: _loaded,
    );
  }

  Widget _frame({required String phase, required List<Widget> children}) {
    final l10n = context.l10n;
    return ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.menu,
      header: TorchAppHeader(
        title: l10n.schedulesTitle,
        facts: <String>[l10n.schedulesFact],
        trailing: TorchIconButton(
          key: const ValueKey<String>('schedules-refresh'),
          icon: Icons.refresh,
          semanticLabel: l10n.schedulesRefresh,
          onPressed: _refresh,
        ),
      ),
      children: children,
    );
  }

  void _create() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => const ReportScheduleFormScreen(),
    ),
  );

  Widget _loaded(List<ReportSchedule> schedules) {
    final l10n = context.l10n;
    final gutter = context.skin.space.gutter;
    final active = <ReportSchedule>[
      for (final s in schedules)
        if (s.active) s,
    ];
    final off = <ReportSchedule>[
      for (final s in schedules)
        if (!s.active) s,
    ];

    return _frame(
      phase: schedules.isEmpty ? 'empty' : 'loaded',
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchTertiaryButton(
            key: const ValueKey<String>('schedules-back-to-reports'),
            label: l10n.schedulesBackToReports,
            onPressed: () => context.go('/reports'),
          ),
        ),
        const SizedBox(height: TiqSpace.s5),
        Text(
          l10n.schedulesDeliveryNote,
          key: const ValueKey<String>('schedule-delivery-note'),
          style: context.skin.text.meta.style(color: context.skin.palette.ink3),
        ),
        const SizedBox(height: TiqSpace.s6),

        if (schedules.isEmpty)
          EmptyState(
            scope: EmptyScope.inPanel,
            headline: l10n.schedulesEmptyHeadline,
            body: l10n.schedulesEmptyBody,
            action: TorchSecondaryButton(
              key: const ValueKey<String>('schedule-create-empty'),
              label: l10n.schedulesNew,
              onPressed: _create,
            ),
          )
        else ...<Widget>[
          _group(
            l10n.schedulesGroupActive,
            l10n.schedulesGroupActiveEmpty,
            active,
            gutter,
          ),
          _group(
            l10n.schedulesGroupOff,
            l10n.schedulesGroupOffEmpty,
            off,
            gutter,
          ),
          const SizedBox(height: TiqSpace.s6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchSecondaryButton(
              key: const ValueKey<String>('schedule-create'),
              label: l10n.schedulesNew,
              onPressed: _create,
            ),
          ),
        ],
      ],
    );
  }

  Widget _group(
    String name,
    String emptyLine,
    List<ReportSchedule> rows,
    double gutter,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // A section that vanishes when empty makes a manager think the group
        // is gone. The rule and its name render whatever the count is.
        SectionRule(
          name,
          count: rows.isEmpty ? null : rows.length,
          emptyLine: rows.isEmpty ? emptyLine : null,
        ),
        const SizedBox(height: TiqSpace.s5),
        if (rows.isNotEmpty)
          TorchBleed(
            extra: gutter * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < rows.length; i++)
                  _ScheduleRow(
                    key: ValueKey<String>('schedule-${rows[i].id}'),
                    schedule: rows[i],
                    last: i == rows.length - 1,
                  ),
              ],
            ),
          ),
        const SizedBox(height: TiqSpace.s6),
      ],
    );
  }
}

class _ScheduleRow extends ConsumerStatefulWidget {
  const _ScheduleRow({super.key, required this.schedule, required this.last});

  final ReportSchedule schedule;
  final bool last;

  @override
  ConsumerState<_ScheduleRow> createState() => _ScheduleRowState();
}

class _ScheduleRowState extends ConsumerState<_ScheduleRow> {
  /// One request per row at a time — a double-tapped Run now must not
  /// generate the report twice.
  bool _busy = false;

  /// The toggle is optimistic from touch-up and reverts on failure, so the
  /// switch follows the thumb rather than the round trip.
  bool? _optimisticActive;

  /// Recipients expand in place rather than into a sheet: they are the
  /// schedule's own content, and a sheet for a four-line list is a modal for
  /// reading.
  bool _showRecipients = false;

  String get _name =>
      widget.schedule.reportName ?? context.l10n.scheduleUntitledReport;

  bool get _active => _optimisticActive ?? widget.schedule.active;

  Future<void> _perform(
    Future<String?> Function() action, {
    required String failure,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = await action();
      if (!mounted) return;
      if (message != null) {
        showTorchToast(context, message: message, kind: ToastKind.neutral);
      }
    } catch (error) {
      if (!mounted) return;
      showTorchToast(
        context,
        message: context.l10n.scheduleFailureToast(
          failure,
          TorchErrorMessage.sanitise(error).body,
        ),
        kind: ToastKind.failure,
      );
      rethrow;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refreshList() {
    if (mounted) ref.invalidate(reportSchedulesListProvider);
  }

  Future<void> _setActive(bool active) async {
    final l10n = context.l10n;
    setState(() => _optimisticActive = active);
    try {
      await _perform(() async {
        await ref
            .read(reportSchedulesRepositoryProvider)
            .setActive(widget.schedule.id, active);
        // Pausing clears the next run and resuming sets a new one.
        _refreshList();
        return null;
      }, failure: active ? l10n.scheduleResumeFailed : l10n.schedulePauseFailed);
    } catch (_) {
      // Honesty: the change did NOT happen, so the switch goes back.
      if (mounted) setState(() => _optimisticActive = null);
    }
  }

  Future<void> _runNow() async {
    // Read the locale's formatter before the round trip: the message is
    // composed after an await, and a figure still has to group the reader's
    // way.
    final format = TiqNumber.of(context).format;
    final l10n = context.l10n;
    try {
      await _perform(() async {
        final result = await ref
            .read(reportSchedulesRepositoryProvider)
            .runNow(widget.schedule.id);
        // The run stamps lastRunAt; reload so the row shows it.
        _refreshList();
        return runNowMessage(result, format, l10n);
      }, failure: l10n.scheduleRunFailed);
    } catch (_) {
      // Reported by _perform; the row simply stays as it was.
    }
  }

  void _edit() {
    if (_busy) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            ReportScheduleFormScreen(schedule: widget.schedule),
      ),
    );
  }

  void _history() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ReportRunHistoryScreen(schedule: widget.schedule),
      ),
    );
  }

  Future<void> _delete() async {
    if (_busy) return;
    final l10n = context.l10n;
    final name = _name;
    final confirmed = await showTorchSheet<bool>(
      context,
      builder: (_) => ConfirmSheet(
        key: const ValueKey<String>('schedule-delete-sheet'),
        action: l10n.scheduleDeleteAction,
        consequences: <String>[
          l10n.scheduleDeleteConsequenceStops(name),
          l10n.scheduleDeleteConsequenceReportKept,
          l10n.scheduleDeleteConsequenceRuns,
        ],
        commitLabel: l10n.scheduleDeleteCommit,
        cancelLabel: l10n.scheduleDeleteCancel,
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _perform(() async {
        await ref
            .read(reportSchedulesRepositoryProvider)
            .deleteSchedule(widget.schedule.id);
        _refreshList();
        return null;
      }, failure: l10n.scheduleDeleteFailed);
    } catch (_) {
      // Reported by _perform.
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final s = widget.schedule;
    final noRecipients = s.recipients.isEmpty;
    final meta = skin.text.meta.style(color: skin.palette.ink3);

    return SoftRow(
      key: ValueKey<String>('schedule-row-${s.id}'),
      density: SoftRowDensity.tall,
      title: _name,
      subtitle: cadenceLabel(s.cadence, l10n),
      // A schedule with nobody to deliver to is almost certainly a mistake.
      // Outlined crimson plus the silhouette plus the word — never the colour
      // on its own.
      severity: noRecipients ? SoftRowSeverity.watch : SoftRowSeverity.none,
      severityLabel: noRecipients ? l10n.scheduleNoRecipients : null,
      leading: TiqMark(
        shape: _active ? MarkShape.onTargetCircle : MarkShape.heldSquare,
        color: _active ? skin.palette.good : skin.palette.ink2,
        size: MarkScale.glyph(context, 16),
      ),
      meta: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Times are machine-read as much as human-read, so they wear the
          // identifier face and line up down the column.
          Text(
            nextRunLabel(_active ? s : _paused(s), l10n),
            key: ValueKey<String>('schedule-next-run-${s.id}'),
            style: skin.text.monoIdent.style(color: skin.palette.ink3),
          ),
          const SizedBox(height: TiqSpace.s1),
          Text(
            lastRunLabel(s.lastRunAt, l10n),
            key: ValueKey<String>('schedule-last-run-${s.id}'),
            style: skin.text.monoIdent.style(color: skin.palette.ink3),
          ),
          const SizedBox(height: TiqSpace.s1),
          Text(
            noRecipients
                ? l10n.scheduleNoRecipientsLine
                : l10n.scheduleRecipientCount(s.recipients.length),
            key: ValueKey<String>('schedule-recipients-${s.id}'),
            style: meta,
          ),
          if (_showRecipients)
            for (final recipient in s.recipients)
              Padding(
                padding: const EdgeInsets.only(top: TiqSpace.s1),
                child: Text(
                  recipient,
                  style: skin.text.monoIdent.style(color: skin.palette.ink2),
                ),
              ),
        ],
      ),
      actions: Wrap(
        spacing: TiqSpace.s4,
        runSpacing: TiqSpace.s2,
        children: <Widget>[
          SizedBox(
            width: double.infinity,
            child: TorchToggle(
              key: ValueKey<String>('toggle-${s.id}'),
              label: l10n.scheduleRunsOnItsOwn,
              value: _active,
              onWord: l10n.scheduleOn,
              offWord: l10n.scheduleOff,
              onChanged: _busy ? null : _setActive,
              disabledReason: _busy ? l10n.scheduleWaitingForServer : null,
            ),
          ),
          if (s.recipients.isNotEmpty)
            TorchTertiaryButton(
              key: ValueKey<String>('recipients-${s.id}'),
              label: _showRecipients
                  ? l10n.scheduleHideRecipients
                  : l10n.scheduleShowRecipients,
              onPressed: () =>
                  setState(() => _showRecipients = !_showRecipients),
            ),
          TorchTertiaryButton(
            key: ValueKey<String>('run-${s.id}'),
            label: l10n.scheduleRunNow,
            onPressed: _busy ? null : _runNow,
          ),
          TorchTertiaryButton(
            key: ValueKey<String>('history-${s.id}'),
            label: l10n.scheduleHistory,
            onPressed: _busy ? null : _history,
          ),
          TorchTertiaryButton(
            key: ValueKey<String>('edit-${s.id}'),
            label: l10n.scheduleEdit,
            onPressed: _busy ? null : _edit,
          ),
          TorchTertiaryButton(
            key: ValueKey<String>('delete-${s.id}'),
            label: l10n.scheduleDelete,
            onPressed: _busy ? null : _delete,
          ),
        ],
      ),
      separator: widget.last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[
        _name,
        cadenceLabel(s.cadence, l10n),
        nextRunLabel(_active ? s : _paused(s), l10n),
        lastRunLabel(s.lastRunAt, l10n),
        if (noRecipients)
          l10n.scheduleNoRecipients
        else
          l10n.scheduleRecipientCount(s.recipients.length),
        // "Show recipients" paints the addresses inside the row's excluded
        // text column. Without them here the control flips its own word to
        // "Hide recipients" and reveals nothing a reader can hear — the one
        // fact it exists to disclose.
        if (_showRecipients) ...s.recipients,
        _active ? l10n.scheduleRunningOnItsOwn : l10n.scheduleOff,
      ].join('. '),
    );
  }

  /// The schedule as the optimistic toggle has just left it, so "Paused, no
  /// next run" appears on the touch-up rather than one round trip later.
  static ReportSchedule _paused(ReportSchedule s) => ReportSchedule(
    id: s.id,
    reportDefinitionId: s.reportDefinitionId,
    reportName: s.reportName,
    cadence: s.cadence,
    recipients: s.recipients,
    active: false,
    lastRunAt: s.lastRunAt,
  );
}

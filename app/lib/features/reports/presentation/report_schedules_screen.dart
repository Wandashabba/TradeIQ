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
import '../data/report_schedules_repository.dart';
import 'report_run_history_screen.dart';
import 'report_schedule_form_screen.dart';

/// The standing note on this screen, worded from what the backend does (#66):
/// active schedules fire on their cadence and go to the client's webhooks
/// subscribed to `report.generated`, and are emailed to the recipients once
/// the server has email (SMTP) set up.
const scheduleDeliveryNote =
    'Active schedules run automatically on their cadence and are sent to '
    'your webhooks subscribed to $reportGeneratedEvent. Recipients are '
    'emailed when email is set up on the server.';

/// What a successful Run now is reported as, from what the API says happened:
/// how many rows, how many webhooks a delivery was queued for (or that none
/// listens), and what the email channel did.
///
/// [format] is [TiqNumber.format]: the row count here is the same figure the
/// Reports list and the run history print, and all three have to group it the
/// same way or a manager cross-checking them cannot tell they match.
String runNowMessage(ScheduleRunResult result, String Function(num) format) {
  final parts = <String>[
    'Generated ${format(result.rowCount)} '
        '${result.rowCount == 1 ? 'row' : 'rows'}.',
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
    parts.add('Queued for $queued ${queued == 1 ? 'webhook' : 'webhooks'}.');
  } else if (webhook?.status == 'failed') {
    parts.add('Webhook delivery failed.');
  } else {
    parts.add('Not sent: no webhook is subscribed to $reportGeneratedEvent.');
  }

  final email = result.outcomeFor('email');
  switch (email?.status) {
    case 'queued':
      final n = email!.targets.length;
      parts.add('Emailing $n ${n == 1 ? 'recipient' : 'recipients'}.');
    case 'not_configured':
      parts.add('Email is not set up on the server.');
    case 'no_subscribers':
      parts.add('Not emailed: no valid email recipients.');
    case 'failed':
      parts.add('Email delivery failed.');
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
String lastRunLabel(DateTime? at) =>
    at == null ? 'Never run' : 'Last run ${reportStamp(at)}';

/// "Next run 2026-09-15 09:00" in local time. A paused schedule has no next
/// run and says so rather than showing a stale time.
String nextRunLabel(ReportSchedule schedule) {
  if (!schedule.active) return 'Paused, no next run';
  final at = schedule.nextRunAt;
  return at == null ? 'Next run not scheduled' : 'Next run ${reportStamp(at)}';
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
    final schedules = ref.watch(reportSchedulesListProvider);

    return schedules.when(
      loading: () => _frame(
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: 'report schedules',
            child: const SkeletonRows(count: 3, rowHeight: 80),
          ),
        ],
      ),
      error: (error, stack) => _frame(
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'report schedules',
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('schedules-retry'),
                label: 'Try again',
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
    return ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.menu,
      header: TorchAppHeader(
        title: 'Report schedules',
        facts: const <String>[
          'A schedule runs its report server-side and delivers the result.',
        ],
        trailing: TorchIconButton(
          key: const ValueKey<String>('schedules-refresh'),
          icon: Icons.refresh,
          semanticLabel: 'Refresh the schedules',
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
            label: 'Back to reports',
            onPressed: () => context.go('/reports'),
          ),
        ),
        const SizedBox(height: TiqSpace.s5),
        Text(
          scheduleDeliveryNote,
          key: const ValueKey<String>('schedule-delivery-note'),
          style: context.skin.text.meta.style(color: context.skin.palette.ink3),
        ),
        const SizedBox(height: TiqSpace.s6),

        if (schedules.isEmpty)
          EmptyState(
            scope: EmptyScope.inPanel,
            headline: 'No schedules.',
            body: 'A report runs on demand until you schedule it.',
            action: TorchSecondaryButton(
              key: const ValueKey<String>('schedule-create-empty'),
              label: 'New schedule',
              onPressed: _create,
            ),
          )
        else ...<Widget>[
          _group('Active', active, gutter),
          _group('Off', off, gutter),
          const SizedBox(height: TiqSpace.s6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchSecondaryButton(
              key: const ValueKey<String>('schedule-create'),
              label: 'New schedule',
              onPressed: _create,
            ),
          ),
        ],
      ],
    );
  }

  Widget _group(String name, List<ReportSchedule> rows, double gutter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // A section that vanishes when empty makes a manager think the group
        // is gone. The rule and its name render whatever the count is.
        SectionRule(
          name,
          count: rows.isEmpty ? null : rows.length,
          emptyLine: rows.isEmpty
              ? name == 'Active'
                    ? 'Nothing is running on its own.'
                    : 'Nothing is paused.'
              : null,
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

  String get _name => widget.schedule.reportName ?? 'Untitled report';

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
        message: '$failure ${TorchErrorMessage.sanitise(error).body}',
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
    setState(() => _optimisticActive = active);
    try {
      await _perform(() async {
        await ref
            .read(reportSchedulesRepositoryProvider)
            .setActive(widget.schedule.id, active);
        // Pausing clears the next run and resuming sets a new one.
        _refreshList();
        return null;
      }, failure: 'Could not ${active ? 'resume' : 'pause'} the schedule.');
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
    try {
      await _perform(() async {
        final result = await ref
            .read(reportSchedulesRepositoryProvider)
            .runNow(widget.schedule.id);
        // The run stamps lastRunAt; reload so the row shows it.
        _refreshList();
        return runNowMessage(result, format);
      }, failure: 'Run failed.');
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
    final confirmed = await showTorchSheet<bool>(
      context,
      builder: (_) => ConfirmSheet(
        key: const ValueKey<String>('schedule-delete-sheet'),
        action: 'Delete this schedule?',
        consequences: <String>[
          '$_name stops running on its own.',
          'The saved report itself is kept.',
          'Runs already delivered are not withdrawn.',
        ],
        commitLabel: 'Delete this schedule',
        cancelLabel: 'Keep it',
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
      }, failure: 'Could not delete the schedule.');
    } catch (_) {
      // Reported by _perform.
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final s = widget.schedule;
    final noRecipients = s.recipients.isEmpty;
    final meta = skin.text.meta.style(color: skin.palette.ink3);

    return SoftRow(
      key: ValueKey<String>('schedule-row-${s.id}'),
      density: SoftRowDensity.tall,
      title: _name,
      subtitle: cadenceLabel(s.cadence),
      // A schedule with nobody to deliver to is almost certainly a mistake.
      // Outlined crimson plus the silhouette plus the word — never the colour
      // on its own.
      severity: noRecipients ? SoftRowSeverity.watch : SoftRowSeverity.none,
      severityLabel: noRecipients ? 'No recipients' : null,
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
            nextRunLabel(_active ? s : _paused(s)),
            key: ValueKey<String>('schedule-next-run-${s.id}'),
            style: skin.text.monoIdent.style(color: skin.palette.ink3),
          ),
          const SizedBox(height: TiqSpace.s1),
          Text(
            lastRunLabel(s.lastRunAt),
            key: ValueKey<String>('schedule-last-run-${s.id}'),
            style: skin.text.monoIdent.style(color: skin.palette.ink3),
          ),
          const SizedBox(height: TiqSpace.s1),
          Text(
            noRecipients
                ? 'No recipients — this schedule delivers to nobody by email.'
                : '${s.recipients.length} '
                      '${s.recipients.length == 1 ? 'recipient' : 'recipients'}',
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
              label: 'Runs on its own',
              value: _active,
              onWord: 'On',
              offWord: 'Off',
              onChanged: _busy ? null : _setActive,
              disabledReason: _busy ? 'Waiting for the server.' : null,
            ),
          ),
          if (s.recipients.isNotEmpty)
            TorchTertiaryButton(
              key: ValueKey<String>('recipients-${s.id}'),
              label: _showRecipients ? 'Hide recipients' : 'Show recipients',
              onPressed: () =>
                  setState(() => _showRecipients = !_showRecipients),
            ),
          TorchTertiaryButton(
            key: ValueKey<String>('run-${s.id}'),
            label: 'Run now',
            onPressed: _busy ? null : _runNow,
          ),
          TorchTertiaryButton(
            key: ValueKey<String>('history-${s.id}'),
            label: 'History',
            onPressed: _busy ? null : _history,
          ),
          TorchTertiaryButton(
            key: ValueKey<String>('edit-${s.id}'),
            label: 'Edit',
            onPressed: _busy ? null : _edit,
          ),
          TorchTertiaryButton(
            key: ValueKey<String>('delete-${s.id}'),
            label: 'Delete',
            onPressed: _busy ? null : _delete,
          ),
        ],
      ),
      separator: widget.last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[
        _name,
        cadenceLabel(s.cadence),
        nextRunLabel(_active ? s : _paused(s)),
        lastRunLabel(s.lastRunAt),
        if (noRecipients)
          'No recipients'
        else
          '${s.recipients.length} recipients',
        // "Show recipients" paints the addresses inside the row's excluded
        // text column. Without them here the control flips its own word to
        // "Hide recipients" and reveals nothing a reader can hear — the one
        // fact it exists to disclose.
        if (_showRecipients) ...s.recipients,
        _active ? 'Running on its own' : 'Off',
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

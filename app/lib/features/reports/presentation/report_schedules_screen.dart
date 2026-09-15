import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/human_error.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/report_schedules_repository.dart';
import 'report_schedule_form_screen.dart';

/// The standing note on this screen. Nothing fires a schedule on its cadence
/// (#66), and `POST /report-schedules/:id/run` generates the report and
/// records the run but sends nothing — so the screen says both, plainly.
const scheduleDeliveryNote =
    'Schedules are saved but not sent automatically yet. Run now generates '
    'the report and records the run; it does not send it to recipients.';

/// What a successful Run now is reported as. Worded from what the API actually
/// did: `rowCount` is real, while `deliveredTo` only echoes the configured
/// recipients, so it is deliberately not presented as a delivery.
String runNowMessage(ScheduleRunResult result) =>
    'Generated ${result.rowCount} ${result.rowCount == 1 ? 'row' : 'rows'}. '
    'Not sent to recipients: delivery is not built yet.';

/// "Last run 2026-09-14 10:05" in local time, or "Never run".
String lastRunLabel(DateTime? at) {
  if (at == null) return 'Never run';
  final l = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return 'Last run ${l.year}-${two(l.month)}-${two(l.day)} '
      '${two(l.hour)}:${two(l.minute)}';
}

/// Report schedules, as a worklist: which saved report, how often, to whom,
/// and whether the schedule is active or paused — a mark and a word.
class ReportSchedulesScreen extends ConsumerWidget {
  const ReportSchedulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(reportSchedulesListProvider);
    final colors = context.colors;

    return ManagerScaffold(
      title: 'Report schedules',
      floatingActionButton: FloatingActionButton(
        key: const ValueKey<String>('schedule-create-fab'),
        tooltip: 'New schedule',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => const ReportScheduleFormScreen(),
          ),
        ),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PanelCard(
            key: const ValueKey<String>('schedule-delivery-note'),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: colors.ink2),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    scheduleDeliveryNote,
                    style: TextStyle(fontSize: 12.5, color: colors.ink2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AsyncSection<List<ReportSchedule>>(
            value: schedules,
            label: 'report schedules',
            onRetry: () => ref.invalidate(reportSchedulesListProvider),
            builder: (list) {
              final active = list.where((s) => s.active).length;
              return PanelCard(
                title: '${list.length} '
                    '${list.length == 1 ? 'schedule' : 'schedules'}',
                subtitle: '$active active',
                padded: false,
                child: list.isEmpty
                    ? const EmptyState(
                        message: 'No report schedules',
                        hint: 'Schedule a saved report to keep its cadence '
                            'and recipients on file.',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final s in list)
                            _ScheduleRow(
                              key: ValueKey<String>('schedule-${s.id}'),
                              schedule: s,
                            ),
                        ],
                      ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends ConsumerStatefulWidget {
  const _ScheduleRow({super.key, required this.schedule});

  final ReportSchedule schedule;

  @override
  ConsumerState<_ScheduleRow> createState() => _ScheduleRowState();
}

class _ScheduleRowState extends ConsumerState<_ScheduleRow> {
  /// One request per row at a time — a double-tapped Run now must not
  /// generate the report twice.
  bool _busy = false;

  String get _name => widget.schedule.reportName ?? 'Untitled report';

  Future<void> _perform(
    Future<String?> Function() action, {
    required String failure,
  }) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final message = await action();
      if (message != null) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$failure ${humanErrorMessage(e)}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refresh() {
    if (mounted) ref.invalidate(reportSchedulesListProvider);
  }

  Future<void> _setActive(bool active) => _perform(
        () async {
          await ref
              .read(reportSchedulesRepositoryProvider)
              .setActive(widget.schedule.id, active);
          _refresh();
          return null;
        },
        failure: 'Could not ${active ? 'resume' : 'pause'} the schedule.',
      );

  Future<void> _runNow() => _perform(
        () async {
          final result = await ref
              .read(reportSchedulesRepositoryProvider)
              .runNow(widget.schedule.id);
          // The run stamps lastRunAt; reload so the row shows it.
          _refresh();
          return runNowMessage(result);
        },
        failure: 'Run failed.',
      );

  /// Opens the form in edit mode. The form saves, refreshes the list and pops
  /// itself; a failed save stays on the form.
  void _edit() {
    if (_busy) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            ReportScheduleFormScreen(schedule: widget.schedule),
      ),
    );
  }

  Future<void> _delete() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete schedule?'),
        content: Text(
          '$_name will no longer be scheduled. The saved report itself is '
          'kept.',
        ),
        actions: [
          TextButton(
            key: const ValueKey<String>('cancel-delete'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey<String>('confirm-delete'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _perform(
      () async {
        await ref
            .read(reportSchedulesRepositoryProvider)
            .deleteSchedule(widget.schedule.id);
        _refresh();
        return null;
      },
      failure: 'Could not delete the schedule.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.schedule;
    final recipients = s.recipients.isEmpty
        ? 'No recipients'
        : 'To ${s.recipients.join(', ')}';

    return WorklistRow(
      title: _name,
      meta: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${cadenceLabel(s.cadence)} · ${lastRunLabel(s.lastRunAt)}'),
          const SizedBox(height: 2),
          Text(recipients, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
      // Paused is a state, not "done": the row keeps full strength and the
      // word carries the difference, never the colour alone.
      level: s.active ? StatusLevel.good : StatusLevel.neutral,
      statusLabel: s.active ? 'Active' : 'Paused',
      actions: [
        RowAction(
          key: ValueKey<String>('toggle-${s.id}'),
          label: s.active ? 'Pause' : 'Resume',
          onPressed: () => _setActive(!s.active),
        ),
        RowAction(
          key: ValueKey<String>('run-${s.id}'),
          label: 'Run now',
          onPressed: _runNow,
        ),
        RowAction(
          key: ValueKey<String>('edit-${s.id}'),
          label: 'Edit',
          onPressed: _edit,
        ),
        RowAction(
          key: ValueKey<String>('delete-${s.id}'),
          label: 'Delete',
          tone: StatusLevel.critical,
          onPressed: _delete,
        ),
      ],
    );
  }
}

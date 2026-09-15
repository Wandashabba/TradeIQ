import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/brand_media.dart';
import '../../../core/camera/photo_capture_service.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/evidence_thumb.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/pill_segment.dart';
import '../../../core/widgets/sla_pill.dart';
import '../../../core/widgets/worklist.dart';
import '../../../core/widgets/photo_capture_field.dart';
import '../../audit/data/photos_repository.dart';
import '../data/tasks_admin_repository.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key, this.clock = DateTime.now});

  /// The screen's one time source — read ONCE per build and threaded down, so
  /// every SLA pill and the Overdue count agree on the same instant, and
  /// tests can pin it.
  final DateTime Function() clock;

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

/// The chip axis is STATE: Open is all open work (overdue included — overdue
/// is a focus subset, not a separate state), Overdue narrows to open work
/// past its SLA, Done is closed, All is everything. Priority lives on the
/// triage strip, a different axis.
enum _Filter { open, overdue, done, all }

class _TasksScreenState extends ConsumerState<TasksScreen> {
  _Filter _filter = _Filter.open;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksListProvider);
    final now = widget.clock();

    return ManagerScaffold(
      title: 'Tasks',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Risks, stockouts and price deviations open a task automatically, '
            'with an SLA due date set by priority.',
            style: TextStyle(fontSize: 12, color: context.colors.ink3),
          ),
          const SizedBox(height: 12),
          AsyncSection<List<TaskItem>>(
            value: tasks,
            label: 'tasks',
            onRetry: () => ref.invalidate(tasksListProvider),
            builder: (list) {
              final open = list.where((t) => t.status != 'closed').toList();
              final closed = list.where((t) => t.status == 'closed').toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TriageStrip(
                    counts: [
                      (
                        label: 'Critical',
                        count: open
                            .where((t) => t.priority == 'critical')
                            .length,
                        level: StatusLevel.critical,
                      ),
                      (
                        label: 'High',
                        count: open.where((t) => t.priority == 'high').length,
                        level: StatusLevel.warning,
                      ),
                      (
                        label: 'Normal',
                        count: open.where((t) => t.priority == 'normal').length,
                        level: StatusLevel.neutral,
                      ),
                      (
                        label: 'Closed',
                        count: closed.length,
                        level: StatusLevel.good,
                      ),
                    ],
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SectionLabel('Awaiting verification'),
                        const SizedBox(height: 3),
                        Text(
                          '${closed.where((t) => !t.closureVerified).length}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.4,
                            color: context.colors.ink1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilterRow(
                    children: [
                      const SectionLabel('State'),
                      // The chip row is the SINGLE source of list filtering;
                      // the triage strip above reads on a different axis
                      // (priority) and filters nothing.
                      _FilterChips(
                        chips: [
                          (label: 'Open · ${open.length}', value: _Filter.open),
                          (
                            label:
                                'Overdue · ${open.where((t) => t.slaDueAt.isBefore(now)).length}',
                            value: _Filter.overdue,
                          ),
                          // Plain, per the spec's example — the count lives
                          // one tap away, in the list header.
                          (label: 'Done', value: _Filter.done),
                          (label: 'All', value: _Filter.all),
                        ],
                        selected: _filter,
                        onChanged: (f) => setState(() => _filter = f),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _TaskList(tasks: _visible(list, now), now: now),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<TaskItem> _visible(List<TaskItem> all, DateTime now) {
    final filtered = all.where((t) {
      final open = t.status != 'closed';
      return switch (_filter) {
        _Filter.open => open,
        _Filter.overdue => open && t.slaDueAt.isBefore(now),
        _Filter.done => !open,
        _Filter.all => true,
      };
    }).toList();

    const order = {'critical': 0, 'high': 1, 'normal': 2};
    int rank(TaskItem t) =>
        (t.status == 'closed' ? 10 : 0) + (order[t.priority] ?? 3);
    filtered.sort((a, b) => rank(a).compareTo(rank(b)));
    return filtered;
  }
}

/// The sub-2 pill filter treatment, rendered via the shared [PillSegment]:
/// active is solid brand under white, inactive a surface1 chip with a hairline,
/// 11px w600, fully rounded. Labels carry the per-filter counts.
class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.chips,
    required this.selected,
    required this.onChanged,
  });

  final List<({String label, _Filter value})> chips;
  final _Filter selected;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final chip in chips)
          PillSegment(
            key: ValueKey('filter-${chip.value.name}'),
            label: chip.label,
            selected: chip.value == selected,
            onTap: () => onChanged(chip.value),
          ),
      ],
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.tasks, required this.now});

  final List<TaskItem> tasks;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: '${tasks.length} ${tasks.length == 1 ? 'task' : 'tasks'}',
      subtitle: 'Sorted by priority, open first',
      padded: false,
      child: tasks.isEmpty
          ? const EmptyState(
              message: 'Nothing outstanding',
              hint:
                  'Tasks open automatically from risks, stockouts and price '
                  'deviations on a submitted visit.',
              illustration: BrandMedia.tasksAllClear,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < tasks.length; i++)
                  WorklistCascade(
                    index: i,
                    child: _TaskRow(task: tasks[i], now: now),
                  ),
              ],
            ),
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task, required this.now});

  final TaskItem task;

  /// The screen's clock, taken once per build — see [TasksScreen.clock].
  final DateTime now;

  /// Closing a task means producing evidence it was actually fixed. The photo is
  /// the evidence, so the capture is the gate: no photo, no closure. (Until #41
  /// this uploaded a 1×1 transparent placeholder, which meant "photo-verified
  /// closure" verified nothing.)
  ///
  /// The photo is geotagged at the shutter (#317), so the closure evidence
  /// also says where the fix was photographed. Its `timestamp` is the capture
  /// time, in UTC — the same contract as the audit sections (#310). The fraud
  /// engine does not place a closure photo against its visit's outlet
  /// (`isTaskClosurePhoto`), so a closure taken away from the outlet, days
  /// later, flags nobody. No fix means an empty tag and the closure goes ahead.
  Future<void> _close(BuildContext context, WidgetRef ref) async {
    final photo = await showDialog<CapturedPhoto>(
      context: context,
      builder: (_) => _ClosurePhotoDialog(task: task),
    );
    if (photo == null) return;

    final result = await ref
        .read(photosRepositoryProvider)
        .uploadPhoto(
          visitId: task.visitId!,
          section: 'task_closure',
          dataUrl: photo.dataUrl,
          gpsTag: photo.gpsTag,
          timestamp: photo.capturedAt.toUtc().toIso8601String(),
        );
    await ref
        .read(tasksAdminRepositoryProvider)
        .closeTask(id: task.id, closurePhotoUrl: result.url);
    ref.invalidate(tasksListProvider);
  }

  Future<void> _verify(WidgetRef ref) async {
    await ref.read(tasksAdminRepositoryProvider).verifyTask(task.id);
    ref.invalidate(tasksListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isClosed = task.status == 'closed';
    final level = switch (task.priority) {
      'critical' => StatusLevel.critical,
      'high' => StatusLevel.warning,
      _ => StatusLevel.neutral,
    };

    return WorklistRow(
      key: ValueKey('task-${task.id}'),
      title: task.findingType,
      // The thumbnail IS the evidence — a task without a photo shows no
      // thumb and no placeholder. evidencePhotoId implies a linked visit,
      // but the guard keeps a malformed row honest rather than crashing.
      thumb: task.evidencePhotoId != null && task.visitId != null
          ? EvidenceThumb(
              photoId: task.evidencePhotoId!,
              visitId: task.visitId!,
            )
          : null,
      meta: Row(
        children: [
          SlaPill(task.slaDueAt, done: isClosed, now: now),
          const SizedBox(width: 8),
          Flexible(
            child: Text(task.requiredFix, overflow: TextOverflow.ellipsis),
          ),
          if (task.closureVerified) ...[
            const SizedBox(width: 8),
            // colorOf is the plain `good` in dark and the status INK in glass
            // — the handoff's ink is the one that reads as words on glass.
            Icon(
              Icons.verified_outlined,
              size: 12,
              color: StatusLevel.good.colorOf(context.colors),
            ),
            const SizedBox(width: 3),
            Text(
              'Verified',
              style: TextStyle(
                fontSize: 11,
                color: StatusLevel.good.colorOf(context.colors),
              ),
            ),
          ],
        ],
      ),
      level: isClosed ? StatusLevel.good : level,
      statusLabel: isClosed ? 'Closed' : task.priority,
      resolved: isClosed && task.closureVerified,
      actions: [
        // Closure requires a photo — the backend enforces it, so the button
        // says so rather than failing after the fact.
        if (!isClosed && task.visitId != null)
          RowAction(
            key: ValueKey('close-${task.id}'),
            label: 'Close with photo',
            onPressed: () => _close(context, ref),
          ),
        if (isClosed && !task.closureVerified)
          RowAction(
            key: ValueKey('verify-${task.id}'),
            label: 'Verify',
            onPressed: () => _verify(ref),
          ),
      ],
    );
  }
}

/// The closure gate. Returns the geotagged [CapturedPhoto], or null if the
/// manager backs out — in which case the task stays open, which is the correct
/// outcome.
class _ClosurePhotoDialog extends StatefulWidget {
  const _ClosurePhotoDialog({required this.task});

  final TaskItem task;

  @override
  State<_ClosurePhotoDialog> createState() => _ClosurePhotoDialogState();
}

class _ClosurePhotoDialogState extends State<_ClosurePhotoDialog> {
  CapturedPhoto? _photo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      backgroundColor: colors.surface1,
      title: const Text('Close with photo', style: TextStyle(fontSize: 15)),
      content: SizedBox(
        width: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.task.requiredFix,
              style: TextStyle(fontSize: 12.5, color: colors.ink2),
            ),
            const SizedBox(height: 14),
            PhotoCaptureField(
              label: 'Closure evidence',
              helperText:
                  'The photo is what makes the closure verifiable — a manager '
                  'has to be able to see the fix, not take your word for it.',
              geotag: true,
              onPhotoCaptured: (photo) => setState(() => _photo = photo),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const ValueKey('confirm-closure'),
          // No photo, no closure. Disabled rather than hidden, so the reason the
          // button will not fire is visible.
          onPressed: _photo == null
              ? null
              : () => Navigator.of(context).pop(_photo),
          child: const Text('Close task'),
        ),
      ],
    );
  }
}

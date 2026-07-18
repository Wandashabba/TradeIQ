import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tiq_colors.dart';
import '../../../core/theme/tiq_geometry.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../../../core/widgets/photo_capture_field.dart';
import '../../audit/data/photos_repository.dart';
import '../data/tasks_admin_repository.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

enum _Tab { open, closed, all }

class _TasksScreenState extends ConsumerState<TasksScreen> {
  _Tab _tab = _Tab.open;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksListProvider);

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
                        count: open.where((t) => t.priority == 'critical').length,
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
                      _Segmented(
                        segments: [
                          (label: 'Open · ${open.length}', value: _Tab.open),
                          (label: 'Closed', value: _Tab.closed),
                          (label: 'All', value: _Tab.all),
                        ],
                        selected: _tab,
                        onChanged: (t) => setState(() => _tab = t),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _TaskList(tasks: _visible(list)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<TaskItem> _visible(List<TaskItem> all) {
    final filtered = all.where((t) {
      return switch (_tab) {
        _Tab.open => t.status != 'closed',
        _Tab.closed => t.status == 'closed',
        _Tab.all => true,
      };
    }).toList();

    const order = {'critical': 0, 'high': 1, 'normal': 2};
    int rank(TaskItem t) =>
        (t.status == 'closed' ? 10 : 0) + (order[t.priority] ?? 3);
    filtered.sort((a, b) => rank(a).compareTo(rank(b)));
    return filtered;
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<({String label, T value})> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: c.lineStrong),
        borderRadius: BorderRadius.circular(TiqGeometry.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < segments.length; i++)
            InkWell(
              key: ValueKey('tab-${segments[i].value}'),
              onTap: () => onChanged(segments[i].value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: segments[i].value == selected
                      ? c.surface3
                      : Colors.transparent,
                  border: Border(
                    right: BorderSide(
                      color: i == segments.length - 1
                          ? Colors.transparent
                          : c.lineStrong,
                    ),
                  ),
                ),
                child: Text(
                  segments[i].label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: segments[i].value == selected
                        ? c.ink1
                        : c.ink2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.tasks});

  final List<TaskItem> tasks;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: '${tasks.length} ${tasks.length == 1 ? 'task' : 'tasks'}',
      subtitle: 'Sorted by priority, open first',
      padded: false,
      child: tasks.isEmpty
          ? const EmptyState(
              message: 'Nothing outstanding',
              hint: 'Tasks open automatically from risks, stockouts and price '
                  'deviations on a submitted visit.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [for (final t in tasks) _TaskRow(task: t)],
            ),
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task});

  final TaskItem task;

  /// Closing a task means producing evidence it was actually fixed. The photo is
  /// the evidence, so the capture is the gate: no photo, no closure. (Until #41
  /// this uploaded a 1×1 transparent placeholder, which meant "photo-verified
  /// closure" verified nothing.)
  Future<void> _close(BuildContext context, WidgetRef ref) async {
    final dataUrl = await showDialog<String>(
      context: context,
      builder: (_) => _ClosurePhotoDialog(task: task),
    );
    if (dataUrl == null) return;

    final result = await ref.read(photosRepositoryProvider).uploadPhoto(
          visitId: task.visitId!,
          section: 'task_closure',
          dataUrl: dataUrl,
          gpsTag: const <String, double>{},
          timestamp: DateTime.now().toIso8601String(),
        );
    await ref.read(tasksAdminRepositoryProvider).closeTask(
          id: task.id,
          closurePhotoUrl: result.url,
        );
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
      meta: Row(
        children: [
          Flexible(
            child: Text(task.requiredFix, overflow: TextOverflow.ellipsis),
          ),
          if (task.closureVerified) ...[
            const SizedBox(width: 8),
            Icon(Icons.verified_outlined, size: 12, color: context.colors.good),
            const SizedBox(width: 3),
            Text(
              'Verified',
              style: TextStyle(fontSize: 11, color: context.colors.good),
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

/// The closure gate. Returns the captured data URL, or null if the manager backs
/// out — in which case the task stays open, which is the correct outcome.
class _ClosurePhotoDialog extends StatefulWidget {
  const _ClosurePhotoDialog({required this.task});

  final TaskItem task;

  @override
  State<_ClosurePhotoDialog> createState() => _ClosurePhotoDialogState();
}

class _ClosurePhotoDialogState extends State<_ClosurePhotoDialog> {
  String? _dataUrl;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.surface1,
      title: const Text('Close with photo', style: TextStyle(fontSize: 15)),
      content: SizedBox(
        width: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.task.requiredFix,
              style: TextStyle(fontSize: 12.5, color: context.colors.ink2),
            ),
            const SizedBox(height: 14),
            PhotoCaptureField(
              label: 'Closure evidence',
              helperText:
                  'The photo is what makes the closure verifiable — a manager '
                  'has to be able to see the fix, not take your word for it.',
              onCaptured: (dataUrl) => setState(() => _dataUrl = dataUrl),
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
          onPressed: _dataUrl == null
              ? null
              : () => Navigator.of(context).pop(_dataUrl),
          child: const Text('Close task'),
        ),
      ],
    );
  }
}

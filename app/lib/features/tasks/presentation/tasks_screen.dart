import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/manager_scaffold.dart';
import '../../audit/data/photos_repository.dart';
import '../data/tasks_admin_repository.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksListProvider);
    return ManagerScaffold(
      title: 'Tasks',
      body: tasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load tasks: $err'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(tasksListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) => _TaskCard(task: list[index]),
        ),
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});

  final TaskItem task;

  Future<void> _close(WidgetRef ref) async {
    final result = await ref.read(photosRepositoryProvider).uploadPhoto(
          visitId: task.visitId!,
          section: 'task_closure',
          dataUrl: kPlaceholderPhotoDataUrl,
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
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(task.findingType),
            subtitle: Text(
              '${task.requiredFix}\n${task.priority} · ${task.status}',
            ),
            isThreeLine: true,
            trailing: task.closureVerified
                ? const Icon(Icons.verified, color: Colors.green)
                : null,
          ),
          if (!isClosed && task.visitId != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: ValueKey('close-${task.id}'),
                onPressed: () => _close(ref),
                child: const Text('Close with photo'),
              ),
            ),
          if (isClosed && !task.closureVerified)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: ValueKey('verify-${task.id}'),
                onPressed: () => _verify(ref),
                child: const Text('Verify'),
              ),
            ),
        ],
      ),
    );
  }
}

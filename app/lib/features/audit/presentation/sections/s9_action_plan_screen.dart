import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/tasks_repository.dart';

/// S9 — Action Plan: manual corrective tasks raised by the agent. Risks
/// flagged in S8 auto-create tasks server-side; this section only captures
/// additional manual tasks, queued offline for sync (POST /tasks).
class S9ActionPlanScreen extends ConsumerStatefulWidget {
  const S9ActionPlanScreen({super.key, required this.visitDraftId, required this.outletId});

  final String visitDraftId;
  final String outletId;

  @override
  ConsumerState<S9ActionPlanScreen> createState() => _S9State();
}

class _S9State extends ConsumerState<S9ActionPlanScreen> {
  static const _priorities = ['critical', 'high', 'normal'];

  final _findingType = TextEditingController();
  final _requiredFix = TextEditingController();
  String _priority = 'normal';
  bool _saved = false;

  @override
  void dispose() {
    _findingType.dispose();
    _requiredFix.dispose();
    super.dispose();
  }

  Future<void> _addTask() async {
    await ref.read(tasksRepositoryProvider).saveTask(
          visitDraftId: widget.visitDraftId,
          outletId: widget.outletId,
          task: TaskDraft(
            findingType: _findingType.text,
            requiredFix: _requiredFix.text,
            priority: _priority,
          ),
        );
    if (mounted) {
      _findingType.clear();
      _requiredFix.clear();
      setState(() => _saved = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('S9 Action Plan'),
        const SizedBox(height: 8),
        const Text('Risks flagged in S8 auto-create tasks with an SLA server-side. '
            'Add any extra manual tasks below.'),
        TextField(
          key: const ValueKey('task-type'),
          controller: _findingType,
          decoration: const InputDecoration(labelText: 'Finding type', isDense: true),
        ),
        TextField(
          key: const ValueKey('task-fix'),
          controller: _requiredFix,
          decoration: const InputDecoration(labelText: 'Required fix', isDense: true),
        ),
        DropdownButtonFormField<String>(
          key: const ValueKey('task-priority'),
          initialValue: _priority,
          decoration: const InputDecoration(labelText: 'Priority', isDense: true),
          items: [
            for (final priority in _priorities)
              DropdownMenuItem(value: priority, child: Text(priority)),
          ],
          onChanged: (v) => setState(() => _priority = v ?? 'normal'),
        ),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _addTask, child: const Text('Add task')),
        if (_saved)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Task queued for sync'),
          ),
      ],
    );
  }
}

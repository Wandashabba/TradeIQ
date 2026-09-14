import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/lumen_glass.dart';
import '../../../../core/theme/tiq_colors.dart';
import '../../../../core/widgets/agent_kit.dart';
import '../../../../core/widgets/console.dart';
import '../../../../core/widgets/glass.dart';
import '../../data/tasks_repository.dart';

/// S9 — Action Plan: manual corrective tasks raised by the agent. Risks
/// flagged in S8 auto-create tasks server-side; this section only captures
/// additional manual tasks, queued offline for sync (POST /tasks).
class S9ActionPlanScreen extends ConsumerStatefulWidget {
  const S9ActionPlanScreen({
    super.key,
    required this.visitDraftId,
    required this.outletId,
  });

  final String visitDraftId;
  final String outletId;

  @override
  ConsumerState<S9ActionPlanScreen> createState() => _S9State();
}

class _S9State extends ConsumerState<S9ActionPlanScreen> {
  static const _priorityOptions = <({String value, String label})>[
    (value: 'critical', label: 'Critical'),
    (value: 'high', label: 'High'),
    (value: 'normal', label: 'Normal'),
  ];

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
    await ref
        .read(tasksRepositoryProvider)
        .saveTask(
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
    final colors = context.colors;
    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AgentField(
          label: 'Finding type',
          child: TextField(
            key: const ValueKey('task-type'),
            controller: _findingType,
            decoration: const InputDecoration(hintText: 'What needs fixing'),
          ),
        ),
        AgentField(
          label: 'Required fix',
          child: TextField(
            key: const ValueKey('task-fix'),
            controller: _requiredFix,
            decoration: const InputDecoration(
              hintText: 'The corrective action',
            ),
          ),
        ),
        Text(
          'Priority',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.ink2,
          ),
        ),
        const SizedBox(height: 7),
        ChoiceRow<String>(
          options: _priorityOptions,
          selected: _priority,
          onChanged: (v) => setState(() => _priority = v),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Risks flagged in S8 auto-create tasks with an SLA server-side. '
          'Add any extra manual tasks below.',
          style: TextStyle(color: colors.ink2, height: 1.4),
        ),
        const SizedBox(height: 12),
        if (colors.glass)
          // Glass: the task being written is one no-blur tile.
          GlassPane(
            kind: GlassKind.tile,
            blur: false,
            radius: LumenGlass.radiusCard,
            padding: const EdgeInsets.all(16),
            child: form,
          )
        else
          PanelCard(child: form),
        const SizedBox(height: 12),
        AgentButton(label: 'Add task', onPressed: _addTask),
        if (_saved)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Task queued for sync',
              style: TextStyle(color: colors.ink2),
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/lumen_glass.dart';
import '../../../../core/theme/tiq_colors.dart';
import '../../../../core/widgets/agent_kit.dart';
import '../../../../core/widgets/console.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../l10n/l10n.dart';
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
    final l10n = context.l10n;
    final priorityOptions = <({String value, String label})>[
      (value: 'critical', label: l10n.s9PriorityCritical),
      (value: 'high', label: l10n.s9PriorityHigh),
      (value: 'normal', label: l10n.s9PriorityNormal),
    ];
    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AgentField(
          label: l10n.s9FindingTypeLabel,
          child: TextField(
            key: const ValueKey('task-type'),
            controller: _findingType,
            decoration: InputDecoration(hintText: l10n.s9FindingTypeHint),
          ),
        ),
        AgentField(
          label: l10n.s9RequiredFixLabel,
          child: TextField(
            key: const ValueKey('task-fix'),
            controller: _requiredFix,
            decoration: InputDecoration(hintText: l10n.s9RequiredFixHint),
          ),
        ),
        Text(
          l10n.s9PriorityLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.ink2,
          ),
        ),
        const SizedBox(height: 7),
        ChoiceRow<String>(
          options: priorityOptions,
          selected: _priority,
          onChanged: (v) => setState(() => _priority = v),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.s9Intro,
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
        AgentButton(label: l10n.s9AddButton, onPressed: _addTask),
        if (_saved)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              l10n.s9Saved,
              style: TextStyle(color: colors.ink2),
            ),
          ),
      ],
    );
  }
}

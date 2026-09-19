import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/torchlight/tiq_skin.dart';
import '../../../../core/widgets/torchlight/input.dart';
import '../../../../core/widgets/torchlight/marks.dart';
import '../../../../core/widgets/torchlight/row/row.dart';
import '../../../../core/widgets/torchlight/section_rule.dart';
import '../../../../l10n/l10n.dart';
import '../../data/tasks_repository.dart';
import 'section_form.dart';

/// S9 — ACTION PLAN. The corrective tasks the agent raises by hand.
///
/// Risks flagged in S8 auto-create tasks server-side; this section captures
/// the extra ones, queued offline for sync (`POST /tasks`). Each Save queues
/// **one** task and clears the form for the next — the behaviour this section
/// has always had — and the tasks already raised on this visit are listed
/// above it as rows, so the agent can see what they have said about the store
/// rather than trusting a counter.
///
/// **Amber:** one object, the inline Save, once the form has something in it.
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
  bool _dirty = false;

  /// What this visit has already queued, in the order it was raised. Local to
  /// the screen: `POST /tasks` is write-only from here and reading them back
  /// would be a different query than the one the hub already runs.
  final _raised = <TaskDraft>[];

  @override
  void dispose() {
    _findingType.dispose();
    _requiredFix.dispose();
    super.dispose();
  }

  void _touch(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  Future<void> _addTask() async {
    final task = TaskDraft(
      findingType: _findingType.text,
      requiredFix: _requiredFix.text,
      priority: _priority,
    );
    await ref
        .read(tasksRepositoryProvider)
        .saveTask(
          visitDraftId: widget.visitDraftId,
          outletId: widget.outletId,
          task: task,
        );
    if (!mounted) return;
    _findingType.clear();
    _requiredFix.clear();
    setState(() {
      _raised.add(task);
      _dirty = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final priorityOptions = <ChoiceOption<String>>[
      ChoiceOption<String>(value: 'critical', label: l10n.s9PriorityCritical),
      ChoiceOption<String>(value: 'high', label: l10n.s9PriorityHigh),
      ChoiceOption<String>(value: 'normal', label: l10n.s9PriorityNormal),
    ];

    return SectionForm(
      title: l10n.visitSectionActionPlan,
      phase: 'action-plan',
      intro: l10n.s9Intro,
      dirty: _dirty,
      onSave: _addTask,
      // Each commit queues ONE task and clears the form for the next, so the
      // verb says so: "Save" on a form that then empties itself reads as lost.
      saveLabel: l10n.s9AddButton,
      savedLine: l10n.s9Saved,
      children: <Widget>[
        SectionFieldGroup(
          children: <Widget>[
            TorchTextField(
              key: const ValueKey<String>('task-type'),
              label: l10n.s9FindingTypeLabel,
              controller: _findingType,
              hint: l10n.s9FindingTypeHint,
              onChanged: (_) => _touch(() {}),
            ),
            TorchTextField(
              key: const ValueKey<String>('task-fix'),
              label: l10n.s9RequiredFixLabel,
              controller: _requiredFix,
              hint: l10n.s9RequiredFixHint,
              onChanged: (_) => _touch(() {}),
            ),
            SectionChoice(
              label: l10n.s9PriorityLabel,
              child: ChoiceRow<String>(
                key: const ValueKey<String>('task-priority'),
                label: l10n.s9PriorityLabel,
                options: priorityOptions,
                value: _priority,
                notAnsweredLine: l10n.sectionNotAnsweredYet,
                onChanged: (v) => _touch(() => _priority = v),
              ),
            ),
          ],
        ),
        Column(
          key: const ValueKey<String>('tasks-raised'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SectionRule(
              l10n.visitSectionActionPlan,
              count: _raised.isEmpty ? null : _raised.length,
              emptyLine: _raised.isEmpty ? l10n.s9NoTasks : null,
            ),
            if (_raised.isNotEmpty) ...<Widget>[
              const SizedBox(height: TiqSpace.s5),
              for (final (i, task) in _raised.indexed)
                SoftRow(
                  key: ValueKey<String>('task-raised-$i'),
                  title: task.findingType,
                  subtitle: task.requiredFix,
                  leading: const RowMarkTile(mark: RowMark.square),
                  meta: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: StatusChip(
                      level: switch (task.priority) {
                        'critical' => StatusLevel.critical,
                        'high' => StatusLevel.watch,
                        _ => StatusLevel.held,
                      },
                      label: switch (task.priority) {
                        'critical' => l10n.s9PriorityCritical,
                        'high' => l10n.s9PriorityHigh,
                        _ => l10n.s9PriorityNormal,
                      },
                    ),
                  ),
                  separator: i == _raised.length - 1
                      ? SoftRowSeparator.none
                      : SoftRowSeparator.auto,
                ),
              const SizedBox(height: TiqSpace.s3),
              Text(
                l10n.s9AddedTasks(_raised.length),
                style: context.skin.text.meta.style(
                  color: context.skin.palette.ink3,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

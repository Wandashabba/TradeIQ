import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/evidence_thumb.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../audit/data/photos_repository.dart';
import '../data/tasks_admin_repository.dart';
import '../data/tasks_view.dart';
import 'close_with_photo_sheet.dart';

/// TASKS — open work with a clock on it, sorted by consequence.
///
/// ```text
///   Tasks                                         [ ⟳ ]
///   Risks, stockouts and price deviations open a task
///   automatically, with a due date set by priority.
///   ┌────────────────────────────────────────┐
///   │ ▲  OVERDUE                          3  │
///   │    12 open · 4 awaiting verification    │
///   └────────────────────────────────────────┘
///   ( Open 12 )( Overdue 3 )( Done )( All )
///   ── Open 12 ──────────────────────────────
///   ▌ Shelf talker missing              [img]
///   ▌ Overdue by 2 days · replace the shelf talker
///   ▌ Kasi Corner Spaza
///   ▌ Close with photo
///   …
///   [ nav pill ]
/// ```
///
/// ## The one amber, counted
///
/// A tab root: the nav pill's active tab is slot 1 and this screen nominates
/// nothing. The overdue lead figure and the SLA phrasing carry the urgency —
/// a crimson outline, a filled triangle and a word — and the earlier draft's
/// reasoning that the filter chip should be lit *because a slot was free* is
/// not a possibility the ruling leaves open. Day and Veld paint zero.
///
/// The one lit object in this feature is `Close task`, and it lives on the
/// closure sheet, where the amber beneath it has already gone out.
///
/// ## The clock is read once
///
/// [clock] is the screen's one time source, read once per build and threaded
/// down, so every "overdue" on the screen agrees on the same instant and a
/// test can pin it.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key, this.clock = DateTime.now});

  final DateTime Function() clock;

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  TaskFilter _filter = TaskFilter.open;

  void _refresh() {
    ref.invalidate(tasksPageProvider);
    // The Floor reads the plain list; keeping them in step means a manager who
    // closes a task here does not walk back to a board that still shows it.
    ref.invalidate(tasksListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(tasksPageProvider);

    return page.when(
      loading: () => _frame(
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: 'tasks',
            child: const SkeletonRows(count: 4, rowHeight: 76),
          ),
        ],
      ),
      error: (error, stack) => _frame(
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'tasks',
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('tasks-retry'),
                label: 'Try again',
                onPressed: _refresh,
              ),
            ),
          ),
        ],
      ),
      data: (data) => _loaded(
        TasksView.resolve(
          data.entries,
          widget.clock(),
          nextCursor: data.nextCursor,
        ),
      ),
    );
  }

  Widget _frame({required String phase, required List<Widget> children}) {
    return ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.work,
      header: TorchAppHeader(
        title: 'Tasks',
        facts: const <String>[
          'Risks, stockouts and price deviations open a task automatically, '
              'with a due date set by priority.',
        ],
        trailing: TorchIconButton(
          key: const ValueKey<String>('tasks-refresh'),
          icon: Icons.refresh,
          semanticLabel: 'Refresh the tasks list',
          onPressed: _refresh,
        ),
      ),
      children: children,
    );
  }

  Widget _loaded(TasksView view) {
    final visible = view.visible(_filter);
    final gutter = context.skin.space.gutter;

    return _frame(
      phase: view.rows.isEmpty
          ? 'empty'
          : visible.isEmpty
          ? 'filtered-empty'
          : 'loaded',
      children: <Widget>[
        // THE LEAD INDICATOR. Overdue is the dominant figure because the SLA
        // is the axis that costs something; open and awaiting-verification are
        // its subordinates, not its peers.
        _LeadIndicator(view: view),
        const SizedBox(height: TiqSpace.s6),

        TorchBleed(
          extra: gutter * 2,
          child: _Filters(
            filter: _filter,
            view: view,
            onChanged: (f) => setState(() => _filter = f),
          ),
        ),
        const SizedBox(height: TiqSpace.s6),

        SectionRule(
          _sectionName(),
          count: visible.isEmpty ? null : visible.length,
        ),
        const SizedBox(height: TiqSpace.s5),

        if (view.rows.isEmpty)
          const EmptyState(
            scope: EmptyScope.inPanel,
            headline: 'Nothing outstanding.',
            body:
                'Tasks open automatically from risks, stockouts and price '
                'deviations on a submitted visit.',
          )
        else if (visible.isEmpty)
          EmptyState(
            scope: EmptyScope.inPanel,
            headline: _filteredEmptyHeadline(),
            body: 'Clear the filter to see the rest.',
            action: TorchSecondaryButton(
              key: const ValueKey<String>('clear-filters'),
              label: 'Show all tasks',
              onPressed: () => setState(() => _filter = TaskFilter.all),
            ),
          )
        else
          TorchBleed(
            extra: gutter * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < visible.length; i++)
                  _TaskRowTile(
                    key: ValueKey<String>('task-row-${visible[i].id}'),
                    task: visible[i],
                    last: i == visible.length - 1,
                    onChanged: _refresh,
                  ),
              ],
            ),
          ),

        if (view.hasMore) ...<Widget>[
          const SizedBox(height: TiqSpace.s6),
          TorchBleed(
            extra: gutter * 2,
            child: PaginationFooter(
              summary: 'Showing the first ${view.rows.length}. There are more.',
              narrowLine: 'Narrow by state to see the rest.',
            ),
          ),
        ],
      ],
    );
  }

  String _sectionName() => switch (_filter) {
    TaskFilter.open => 'Open',
    TaskFilter.overdue => 'Overdue',
    TaskFilter.done => 'Done',
    TaskFilter.all => 'All tasks',
  };

  String _filteredEmptyHeadline() => switch (_filter) {
    TaskFilter.open => 'Nothing outstanding.',
    TaskFilter.overdue => 'Nothing is overdue.',
    TaskFilter.done => 'Nothing closed yet.',
    TaskFilter.all => 'Nothing outstanding.',
  };
}

/// Overdue, as the one figure that costs something.
///
/// Three channels: the crimson `bad` outline, the filled triangle beside it,
/// and the word in the eyebrow. Never amber.
class _LeadIndicator extends StatelessWidget {
  const _LeadIndicator({required this.view});

  final TasksView view;

  @override
  Widget build(BuildContext context) {
    final overdue = view.overdue;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: TiqSpace.s5),
          child: SeverityMark(
            kind: overdue > 0
                ? SeverityMarkKind.critical
                : SeverityMarkKind.onTarget,
          ),
        ),
        const SizedBox(width: TiqSpace.s3),
        Expanded(
          child: StatTile(
            eyebrow: 'Overdue',
            // A measured zero renders 0 and keeps its place: nothing overdue
            // is a fact worth reading, not an absence.
            value: overdue,
            lead: true,
            severity: overdue > 0 ? SeverityMarkKind.critical : null,
            subordinates:
                '${view.open} open · ${view.awaitingVerification} awaiting '
                'verification',
          ),
        ),
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.filter,
    required this.view,
    required this.onChanged,
  });

  final TaskFilter filter;
  final TasksView view;
  final ValueChanged<TaskFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return TorchFilterRail(
      semanticsLabel: 'Filters',
      chips: <Widget>[
        TorchFilterChip(
          key: const ValueKey<String>('filter-open'),
          label: 'Open',
          count: view.open,
          selected: filter == TaskFilter.open,
          onSelected: () => onChanged(TaskFilter.open),
        ),
        TorchFilterChip(
          key: const ValueKey<String>('filter-overdue'),
          label: 'Overdue',
          count: view.overdue,
          selected: filter == TaskFilter.overdue,
          onSelected: () => onChanged(TaskFilter.overdue),
        ),
        TorchFilterChip(
          key: const ValueKey<String>('filter-done'),
          label: 'Done',
          count: view.closed,
          selected: filter == TaskFilter.done,
          onSelected: () => onChanged(TaskFilter.done),
        ),
        TorchFilterChip(
          key: const ValueKey<String>('filter-all'),
          label: 'All',
          count: view.rows.length,
          selected: filter == TaskFilter.all,
          onSelected: () => onChanged(TaskFilter.all),
        ),
      ],
    );
  }
}

/// One task, as a row.
///
/// The SLA is a phrase in the reason line, behind its own mark — "Overdue by
/// 2 days · replace the shelf talker" — rather than a pill. A pill is a badge
/// somebody decodes; a sentence is read.
class _TaskRowTile extends ConsumerStatefulWidget {
  const _TaskRowTile({
    super.key,
    required this.task,
    required this.last,
    required this.onChanged,
  });

  final TaskRow task;
  final bool last;
  final VoidCallback onChanged;

  @override
  ConsumerState<_TaskRowTile> createState() => _TaskRowTileState();
}

class _TaskRowTileState extends ConsumerState<_TaskRowTile> {
  /// True from the tap until the closure or the verification resolves. One
  /// tap, one receipt, one outcome.
  bool _busy = false;

  /// Closing a task means producing evidence it was actually fixed. The photo
  /// is the evidence, so the capture is the gate: no photo, no closure.
  ///
  /// The photo is geotagged at the shutter (#317), so the closure evidence
  /// also says where the fix was photographed, and its `timestamp` is the
  /// capture time in UTC — the same contract as the audit sections (#310).
  /// The fraud engine does not place a closure photo against its visit's
  /// outlet (`isTaskClosurePhoto`), so a closure taken away from the outlet,
  /// days later, flags nobody. No fix means an empty tag and the closure goes
  /// ahead.
  Future<void> _close() async {
    if (_busy) return;
    final photo = await showCloseWithPhotoSheet(context, task: widget.task);
    // Backing out leaves the task open, which is the correct outcome.
    if (photo == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await ref
          .read(photosRepositoryProvider)
          .uploadPhoto(
            visitId: widget.task.visitId!,
            section: 'task_closure',
            dataUrl: photo.dataUrl,
            gpsTag: photo.gpsTag,
            timestamp: photo.capturedAt.toUtc().toIso8601String(),
          );
      await ref
          .read(tasksAdminRepositoryProvider)
          .closeTask(id: widget.task.id, closurePhotoUrl: result.url);
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onChanged();
      showTorchToast(
        context,
        message: 'Closed · ${widget.task.title}',
        kind: ToastKind.success,
      );
    } catch (error) {
      if (!mounted) return;
      // The task stays open and the failure is named. A closure that silently
      // did not happen is the worklist lying.
      setState(() => _busy = false);
      showTorchToast(
        context,
        message: 'That task was not closed. It is still open.',
        kind: ToastKind.failure,
        action: TorchTertiaryButton(label: 'Try again', onPressed: _close),
      );
    }
  }

  Future<void> _verify() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(tasksAdminRepositoryProvider).verifyTask(widget.task.id);
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showTorchToast(
        context,
        message: 'That closure was not verified.',
        kind: ToastKind.failure,
        action: TorchTertiaryButton(label: 'Try again', onPressed: _verify),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final task = widget.task;
    final markKind = switch (task.slaState) {
      TaskSlaState.overdue => SeverityMarkKind.critical,
      TaskSlaState.dueSoon => SeverityMarkKind.watch,
      TaskSlaState.closed || TaskSlaState.verified => SeverityMarkKind.onTarget,
      TaskSlaState.open => null,
    };
    final phraseInk = switch (task.slaState) {
      TaskSlaState.overdue => skin.palette.badSolid,
      TaskSlaState.dueSoon => skin.palette.bad,
      _ => skin.palette.ink2,
    };

    return SoftRow(
      key: ValueKey<String>('task-${task.id}'),
      density: SoftRowDensity.tall,
      title: task.title,
      subtitle: task.outletName,
      severity: task.severity,
      severityLabel: task.severity == SoftRowSeverity.none
          ? null
          : task.severityLabel,
      // The thumbnail IS the evidence — a task with no photo shows no thumb
      // and no placeholder.
      trailing: task.evidencePhotoId != null && task.visitId != null
          ? TorchEvidenceThumb(
              photoId: task.evidencePhotoId!,
              semanticLabel:
                  'Shelf photograph from ${task.outletName} for ${task.title}',
            )
          : null,
      meta: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // The SLA, in words, behind its own silhouette — never a hue alone.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (markKind != null) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SeverityMark(kind: markKind),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  '${task.slaPhrase} · ${task.requiredFix}',
                  style: skin.text.meta.style(color: phraseInk),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: TiqSpace.s4,
            children: <Widget>[
              // Closure uploads the photo against the visit, so a task with no
              // visit gets no closure action at all — not a disabled one that
              // would fail afterwards.
              if (!task.isClosed && task.visitId != null)
                TorchTertiaryButton(
                  key: ValueKey<String>('close-${task.id}'),
                  label: 'Close with photo',
                  busy: _busy,
                  onPressed: _close,
                ),
              if (task.slaState == TaskSlaState.closed)
                TorchTertiaryButton(
                  key: ValueKey<String>('verify-${task.id}'),
                  label: 'Verify',
                  busy: _busy,
                  onPressed: _verify,
                ),
            ],
          ),
        ],
      ),
      separator: widget.last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[
        if (task.severity != SoftRowSeverity.none) task.severityLabel,
        task.slaPhrase,
        task.title,
        task.requiredFix,
        task.outletName,
      ].join('. '),
    );
  }
}

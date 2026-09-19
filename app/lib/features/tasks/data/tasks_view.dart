import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/torchlight/row/row.dart';
import '../../outlets/data/outlets_repository.dart';
import 'tasks_admin_repository.dart';

/// THE TASKS WORKLIST'S VIEW MODEL — open work with a clock on it, sorted by
/// consequence.
///
/// Four decisions live here rather than in the screen:
///
/// 1. **The clock is read once and threaded.** [TasksView.resolve] takes
///    `now`, so every "overdue" on the screen agrees with every other and a
///    test owns time. A view model that read `DateTime.now()` per row could
///    have two rows disagree across a midnight.
/// 2. **The bar is the SLA, not the priority.** A task past its deadline is
///    solid; one inside 24 hours is outlined; a closed one has no bar at all,
///    because a bar-less row in this system means *fine* and nothing else.
///    The priority still raises the bar for a critical finding that is not yet
///    late — the two axes are combined, never shown as two bars.
/// 3. **The SLA is a phrase, not a pill.** "Overdue by 2 days" is a sentence a
///    person reads; `OVERDUE 2d` is a badge they decode. Overdue is measured
///    in whole days and never in fake-precise hours.
/// 4. **A row names an outlet, never a UUID.**

/// Which slice of the page the rail is showing. The axis is **state**: Open is
/// all open work (overdue included — overdue is a focus subset, not a separate
/// state), Overdue narrows to open work past its SLA, Done is closed, All is
/// everything.
enum TaskFilter { open, overdue, done, all }

/// Where a task stands against its deadline.
enum TaskSlaState {
  /// Open, with more than a day to run.
  open,

  /// Open, inside 24 hours.
  dueSoon,

  /// Open, past the deadline.
  overdue,

  /// Closed, awaiting verification.
  closed,

  /// Closed and verified.
  verified,
}

/// One task plus the outlet name it needs to be readable — everything the
/// server said, before the clock is applied.
class TaskEntry {
  const TaskEntry({required this.task, required this.outletName});

  final TaskItem task;

  /// Resolved against the outlet list; the id only while that list has not
  /// arrived, because a row with no name is a row a manager cannot act on.
  final String outletName;
}

/// One task, ready to render.
class TaskRow {
  const TaskRow({
    required this.id,
    required this.title,
    required this.requiredFix,
    required this.outletName,
    required this.priority,
    required this.slaState,
    required this.slaPhrase,
    required this.severity,
    required this.severityLabel,
    this.visitId,
    this.evidencePhotoId,
  });

  final String id;

  /// The finding, in words. The wire sends a slug (`out_of_stock`); a slug is
  /// machine-facing and this is the row's first line, so the underscores go
  /// and the first letter is raised. Nothing is invented: an unknown finding
  /// reads as itself.
  final String title;

  final String requiredFix;
  final String outletName;

  /// `critical` | `high` | `normal`, as the server stored it.
  final String priority;

  final TaskSlaState slaState;

  /// "Overdue by 2 days", "Due in 6 h", "Due Friday", "Closed", "Verified".
  final String slaPhrase;

  final SoftRowSeverity severity;

  /// The word behind the bar. Announced first, and the channel that survives
  /// greyscale, deuteranopia, glare and a screen reader.
  final String severityLabel;

  final String? visitId;
  final String? evidencePhotoId;

  bool get isClosed =>
      slaState == TaskSlaState.closed || slaState == TaskSlaState.verified;

  bool get isOverdue => slaState == TaskSlaState.overdue;

  /// Overdue, critical, high, normal, closed.
  static int compare(TaskRow a, TaskRow b) {
    final byRank = _rank(a).compareTo(_rank(b));
    if (byRank != 0) return byRank;
    return a.id.compareTo(b.id);
  }

  static int _rank(TaskRow t) {
    if (t.isClosed) return 10;
    if (t.slaState == TaskSlaState.overdue) return 0;
    return switch (t.priority) {
      'critical' => 1,
      'high' => 2,
      _ => 3,
    };
  }
}

/// The whole worklist, resolved against one instant.
class TasksView {
  const TasksView({required this.rows, this.nextCursor});

  final List<TaskRow> rows;

  /// The server's cursor for the page after this one. The API answers a first
  /// page and has never said how many rows exist, so a cut list says "there
  /// are more" and never a fabricated total.
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  int get overdue => rows.where((r) => r.isOverdue).length;

  int get open => rows.where((r) => !r.isClosed).length;

  int get closed => rows.where((r) => r.isClosed).length;

  int get awaitingVerification =>
      rows.where((r) => r.slaState == TaskSlaState.closed).length;

  List<TaskRow> visible(TaskFilter filter) {
    final out = rows.where((r) {
      return switch (filter) {
        TaskFilter.open => !r.isClosed,
        TaskFilter.overdue => r.isOverdue,
        TaskFilter.done => r.isClosed,
        TaskFilter.all => true,
      };
    }).toList();
    out.sort(TaskRow.compare);
    return out;
  }

  /// Apply one clock to one page.
  static TasksView resolve(
    List<TaskEntry> entries,
    DateTime now, {
    String? nextCursor,
  }) {
    return TasksView(
      nextCursor: nextCursor,
      rows: <TaskRow>[
        for (final entry in entries) _rowFor(entry, now),
      ]..sort(TaskRow.compare),
    );
  }

  static TaskRow _rowFor(TaskEntry entry, DateTime now) {
    final task = entry.task;
    final state = _slaStateFor(task, now);
    final severity = _severityFor(task, state);
    return TaskRow(
      id: task.id,
      title: findingLabel(task.findingType),
      requiredFix: task.requiredFix,
      outletName: entry.outletName,
      priority: task.priority,
      slaState: state,
      slaPhrase: slaPhrase(task.slaDueAt, state, now),
      severity: severity,
      severityLabel: _severityWord(task, state),
      visitId: task.visitId,
      evidencePhotoId: task.evidencePhotoId,
    );
  }

  static TaskSlaState _slaStateFor(TaskItem task, DateTime now) {
    if (task.status == 'closed') {
      return task.closureVerified ? TaskSlaState.verified : TaskSlaState.closed;
    }
    if (!now.isBefore(task.slaDueAt)) return TaskSlaState.overdue;
    return task.slaDueAt.difference(now) < const Duration(hours: 24)
        ? TaskSlaState.dueSoon
        : TaskSlaState.open;
  }

  static SoftRowSeverity _severityFor(TaskItem task, TaskSlaState state) {
    if (state == TaskSlaState.closed || state == TaskSlaState.verified) {
      return SoftRowSeverity.none;
    }
    if (state == TaskSlaState.overdue || task.priority == 'critical') {
      return SoftRowSeverity.critical;
    }
    // Open work is never "fine": a bar-less row means fine and nothing else,
    // and an open task is by definition something nobody has done yet.
    return SoftRowSeverity.watch;
  }

  static String _severityWord(TaskItem task, TaskSlaState state) {
    return switch (state) {
      TaskSlaState.verified => 'Verified',
      TaskSlaState.closed => 'Closed',
      TaskSlaState.overdue => 'Overdue',
      TaskSlaState.dueSoon => 'Due soon',
      TaskSlaState.open => switch (task.priority) {
        'critical' => 'Critical',
        'high' => 'High',
        _ => 'Normal',
      },
    };
  }

  /// `out_of_stock` → `Out of stock`. Nothing is mapped or renamed; the slug's
  /// own words are what a manager reads.
  static String findingLabel(String findingType) {
    final words = findingType.replaceAll('_', ' ').trim();
    if (words.isEmpty) return findingType;
    return words[0].toUpperCase() + words.substring(1);
  }

  /// The SLA, in words.
  ///
  /// Overdue is floored to whole days — a fake-precise "3 h" would claim the
  /// console knows when the fix crew reads it. Everything still to come is a
  /// calendar distance rather than elapsed hours, except the last day, where
  /// hours are what a person is actually counting.
  static String slaPhrase(DateTime due, TaskSlaState state, DateTime now) {
    switch (state) {
      case TaskSlaState.verified:
        return 'Verified';
      case TaskSlaState.closed:
        return 'Closed';
      case TaskSlaState.overdue:
        final days = now.difference(due).inDays;
        if (days < 1) return 'Overdue by less than a day';
        return days == 1 ? 'Overdue by 1 day' : 'Overdue by $days days';
      case TaskSlaState.dueSoon:
        final hours = due.difference(now).inHours;
        return hours < 1 ? 'Due within the hour' : 'Due in $hours h';
      case TaskSlaState.open:
        final local = due.toLocal();
        final dayDiff = _calendarDayDiff(now, local);
        if (dayDiff == 0) return 'Due today';
        if (dayDiff == 1) return 'Due tomorrow';
        if (dayDiff < 7) return 'Due ${_weekdays[local.weekday - 1]}';
        return 'Due ${local.day} ${_months[local.month - 1]}';
    }
  }

  static const List<String> _weekdays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Whole calendar days from one day to another.
  ///
  /// Both days are reconstructed at UTC midnight before subtracting: local
  /// midnights are 23h or 25h apart across a DST transition and
  /// `Duration.inDays` floors a 23h day to 0, which would label a
  /// tomorrow-due task "Due today" on every spring-forward. In UTC every day
  /// is exactly 24h by construction. (The same arithmetic the SLA pill used,
  /// carried across rather than re-derived.)
  static int _calendarDayDiff(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
}

/// One page of tasks, with the outlet names attached and the cursor kept.
class TasksPage {
  const TasksPage({required this.entries, this.nextCursor});

  final List<TaskEntry> entries;
  final String? nextCursor;
}

/// The tasks page, merged with the outlet names it needs to be readable.
///
/// It reads the repository rather than [tasksListProvider] because that
/// provider drops `nextCursor` on the floor, and a worklist that cannot say it
/// was cut reads as the whole truth. The Floor keeps watching the plain list.
final tasksPageProvider = FutureProvider<TasksPage>((ref) async {
  final page = await ref.read(tasksAdminRepositoryProvider).listTasks();

  // A base layer, never a blocker: a slow or failed outlet list must not take
  // the worklist down with it.
  final outlets = ref
      .watch(outletsListProvider)
      .maybeWhen(data: (list) => list, orElse: () => const <Outlet>[]);
  final names = <String, String>{for (final o in outlets) o.id: o.name};

  return TasksPage(
    nextCursor: page.nextCursor,
    entries: <TaskEntry>[
      for (final task in page.data)
        TaskEntry(
          task: task,
          outletName: names[task.outletId] ?? task.outletId,
        ),
    ],
  );
});

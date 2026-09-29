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
/// 4. **A row names an outlet and a person, never a UUID.** The outlet comes
///    from the outlet list and the owner from the roster; an id with no match
///    becomes words ("Outlet name unavailable") or, for the owner, silence.

/// Which slice of the list the rail is showing. The axis is **state**: Open is
/// all open work (overdue included — overdue is a focus subset, not a separate
/// state), Overdue narrows to open work past its SLA, Done is closed, All is
/// everything.
///
/// **It is the server's filter, not a client-side one.** It used to be a
/// `where` over the fifty rows in hand, which is why pressing `Open` on an
/// account with 1,190 open tasks produced an empty list: the page is ordered by
/// deadline across every status, so the fifty oldest deadlines are the closed
/// ones. The chips now ask the server for their own slice — [TaskState] is the
/// same four words on the wire — and the list underneath a chip is the list
/// that chip names.
enum TaskFilter {
  open,
  overdue,
  done,
  all;

  TaskState get state => switch (this) {
    TaskFilter.open => TaskState.open,
    TaskFilter.overdue => TaskState.overdue,
    TaskFilter.done => TaskState.done,
    TaskFilter.all => TaskState.all,
  };

  /// The section's name, and the chip's label with it. One string, so a rail
  /// and the list beneath it can never disagree about what is being shown.
  String get label => switch (this) {
    TaskFilter.open => 'Open',
    TaskFilter.overdue => 'Overdue',
    TaskFilter.done => 'Done',
    TaskFilter.all => 'All',
  };
}

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

  /// Resolved against the outlet list; [TasksView.unnamedOutlet] when the id
  /// is not on it — never the id itself.
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
    this.owner,
  });

  final String id;

  /// Who owns the fix, by name (or sign-in address where they have no name),
  /// or null when the roster has no match — in which case the row says
  /// nothing about the owner rather than printing an id.
  final String? owner;

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

  /// The priority in words, as the row paints it.
  ///
  /// The bar is the SLA and the SLA alone — a `high` and a `normal` task both
  /// due on Friday get the same watch bar — so the priority the list is
  /// *sorted* by has to be said somewhere a person can see. An unknown
  /// priority reads as itself rather than being rounded down to "Normal".
  String get priorityPhrase => switch (priority) {
    'critical' => 'Critical priority',
    'high' => 'High priority',
    'normal' => 'Normal priority',
    _ => '$priority priority',
  };

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
  const TasksView({
    required this.rows,
    required this.filter,
    this.nextCursor,
    this.total,
    this.counts,
  });

  /// What a row says when its outlet id is not on the outlet list. Words,
  /// never the UUID (#399/#400).
  static const String unnamedOutlet = 'Outlet name unavailable';

  /// The rows on this page — already the slice [filter] names, because the
  /// server applied it.
  final List<TaskRow> rows;

  /// Which slice the server was asked for. The rows are that slice; the
  /// [counts] are the whole account, whatever this says.
  final TaskFilter filter;

  /// The server's cursor for the page after this one.
  final String? nextCursor;

  /// Every task matching this filter, counted ignoring the page. Null from a
  /// server that does not count: the footer then says "there are more" and
  /// never a fabricated total.
  final int? total;

  /// THE WHOLE SET, COUNTED BY THE SERVER.
  ///
  /// Null from a server that does not count, and that null is the difference
  /// between the figures on this screen being measured and being guesses over
  /// fifty rows. Every getter below prefers it and falls back to the page —
  /// and [countsAreMeasured] is what the screen reads to decide whether it may
  /// print a zero at all.
  final TaskCounts? counts;

  bool get hasMore => nextCursor != null;

  /// Whether the figures above the list describe the account or only the page.
  ///
  /// Two ways to be true: the server counted, or the page is the whole list
  /// and counting it is counting everything. The second is not a consolation
  /// prize — a small account genuinely has nothing unmeasured about it.
  bool get countsAreMeasured => counts != null || !hasMore;

  /// What the pagination footer says, or null when this page is the whole
  /// list.
  ///
  /// The server sends tasks by deadline, earliest first, so a cut page is
  /// "the N with the earliest deadlines" — the order the server actually
  /// applied, not a ranking it did not do.
  ///
  /// **The second line is gone.** It read "The counts above are of these 50",
  /// which was true and was the whole defect: the figures above the list were
  /// of the page because nothing had counted the rest. They are of the account
  /// now, so the footer scopes the *list* — which is the only thing on the
  /// screen that is still a page — and says which slice it is a page of.
  ({String summary, String? scope})? footer(String Function(int) figure) {
    if (!hasMore) return null;
    final shown = figure(rows.length);
    final whole = total;
    final noun = switch (filter) {
      TaskFilter.open => 'open tasks',
      TaskFilter.overdue => 'overdue tasks',
      TaskFilter.done => 'closed tasks',
      TaskFilter.all => 'tasks',
    };
    return (
      summary: whole == null || whole <= rows.length
          ? 'Showing the first $shown. There are more.'
          : 'Showing the $shown $noun with the earliest deadlines, of '
                '${figure(whole)}.',
      // Only where the counts are the page's own, which is now only a server
      // that did not count. It is the honest sentence in that case and it must
      // not disappear with the defect it described.
      scope: counts == null ? 'The figures above are of these $shown.' : null,
    );
  }

  /// Past the deadline and still open, across the whole account.
  int get overdue =>
      counts?.overdue ?? rows.where((r) => r.isOverdue).length;

  /// Outstanding — not closed — across the whole account.
  int get open => counts?.open ?? rows.where((r) => !r.isClosed).length;

  /// Closed, across the whole account.
  int get closed => counts?.done ?? rows.where((r) => r.isClosed).length;

  /// Closed and not yet verified, across the whole account.
  int get awaitingVerification =>
      counts?.awaitingVerification ??
      rows.where((r) => r.slaState == TaskSlaState.closed).length;

  /// Every task, across the whole account.
  int get all => counts?.all ?? total ?? rows.length;

  /// The figure for one chip.
  int countFor(TaskFilter which) => switch (which) {
    TaskFilter.open => open,
    TaskFilter.overdue => overdue,
    TaskFilter.done => closed,
    TaskFilter.all => all,
  };

  /// The rows to draw.
  ///
  /// The server already applied the filter, so this is a sort and not a
  /// `where` — with one exception that earns its keep. A page fetched under
  /// one filter is still in the provider's cache when the manager presses
  /// another chip, and re-filtering it locally is what keeps a stale page from
  /// showing rows the new chip does not name while the new page is in flight.
  List<TaskRow> visible(TaskFilter which) {
    final out = rows.where((r) {
      return switch (which) {
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
  ///
  /// [owners] maps a user id to what to call them. It is the roster, a base
  /// layer: an owner missing from it is left unnamed, never shown as an id.
  static TasksView resolve(
    List<TaskEntry> entries,
    DateTime now, {
    TaskFilter filter = TaskFilter.all,
    String? nextCursor,
    int? total,
    TaskCounts? counts,
    Map<String, String> owners = const <String, String>{},
  }) {
    return TasksView(
      filter: filter,
      nextCursor: nextCursor,
      total: total,
      counts: counts,
      rows: <TaskRow>[for (final entry in entries) _rowFor(entry, now, owners)]
        ..sort(TaskRow.compare),
    );
  }

  static TaskRow _rowFor(
    TaskEntry entry,
    DateTime now,
    Map<String, String> owners,
  ) {
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
      owner: task.ownerId == null ? null : owners[task.ownerId],
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

/// One page of tasks, with the outlet names attached, the cursor kept and the
/// server's whole-set breakdown beside it.
class TasksPage {
  const TasksPage({
    required this.entries,
    this.nextCursor,
    this.total,
    this.counts,
  });

  final List<TaskEntry> entries;
  final String? nextCursor;
  final int? total;

  /// The whole account, counted by the server — null from one that does not.
  final TaskCounts? counts;
}

/// The tasks page for one filter, merged with the outlet names it needs to be
/// readable.
///
/// It reads the repository rather than [tasksListProvider] because that
/// provider drops `nextCursor` on the floor, and a worklist that cannot say it
/// was cut reads as the whole truth. The Floor keeps watching the plain list.
///
/// ## Why it takes the filter
///
/// The chips used to be a `where` over whatever page had arrived. On an
/// account of any size that is a filter over the wrong fifty rows: the server
/// orders by deadline across every status, so the page is the oldest deadlines
/// — which are the closed ones — and `Open` filtered fifty closed tasks down
/// to an empty list under a chip that said there were 1,190.
///
/// A family keyed by the filter is what makes the list underneath a chip the
/// list that chip names. Each filter keeps its own cache, so going back to one
/// already fetched is instant and does not flash a skeleton; the counts come
/// back with every one of them and are identical across all four, because the
/// server computes them before the state filter.
final tasksPageProvider = FutureProvider.family<TasksPage, TaskFilter>((
  ref,
  filter,
) async {
  final page = await ref
      .read(tasksAdminRepositoryProvider)
      .listTasks(state: filter.state);

  // A base layer, never a blocker: a slow or failed outlet list must not take
  // the worklist down with it.
  final outlets = ref
      .watch(outletsListProvider)
      .maybeWhen(data: (list) => list, orElse: () => const <Outlet>[]);
  final names = <String, String>{for (final o in outlets) o.id: o.name};

  return TasksPage(
    nextCursor: page.nextCursor,
    total: page.total,
    counts: page.counts,
    entries: <TaskEntry>[
      for (final task in page.data)
        TaskEntry(
          task: task,
          outletName: names[task.outletId] ?? TasksView.unnamedOutlet,
        ),
    ],
  );
});

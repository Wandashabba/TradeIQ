import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';

/// A manager-facing view of one S9 corrective task returned by GET /tasks.
class TaskItem {
  const TaskItem({
    required this.id,
    required this.findingType,
    required this.requiredFix,
    required this.priority,
    required this.status,
    required this.closureVerified,
    required this.outletId,
    required this.slaDueAt,
    this.closurePhotoUrl,
    this.visitId,
    this.evidencePhotoId,
    this.createdAt,
    this.ownerId,
  });
  final String id;
  final String findingType;
  final String requiredFix;
  final String priority;
  final String status;
  final String? closurePhotoUrl;
  final bool closureVerified;
  final String outletId;
  final String? visitId;

  /// The SLA deadline. Required, not nullable: the backend computes it from
  /// the priority at task creation and always sends it.
  final DateTime slaDueAt;

  /// The newest photo of the linked visit, or null — no visit, or a photoless
  /// visit. Null means the row shows NO thumbnail, never a placeholder.
  final String? evidencePhotoId;

  /// When the finding was raised. On the wire already; parsed here so The
  /// Floor can put a task and an alert in one column under one meaning —
  /// how long this has been broken — rather than mixing an age with a
  /// deadline and calling the result a figure.
  final DateTime? createdAt;

  /// The user who owns the fix. On the wire as an id only — the name comes
  /// from the roster, and a row with no match says nothing rather than
  /// printing the id.
  final String? ownerId;

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
    id: json['id'] as String,
    findingType: json['findingType'] as String,
    requiredFix: json['requiredFix'] as String,
    priority: json['priority'] as String,
    status: json['status'] as String,
    closurePhotoUrl: json['closurePhotoUrl'] as String?,
    closureVerified: json['closureVerified'] as bool? ?? false,
    outletId: json['outletId'] as String,
    visitId: json['visitId'] as String?,
    slaDueAt: DateTime.parse(json['slaDueAt'] as String),
    evidencePhotoId: json['evidencePhotoId'] as String?,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    ownerId: json['ownerId'] as String?,
  );
}

/// THE FOUR STATES THE WORKLIST IS FILTERED BY, as the wire spells them.
///
/// Not the stored status. `open` is every task that is not closed — a task
/// somebody has started is still outstanding — and `overdue` is not a column
/// at all. The server owns the definitions (`tasks.service.ts`); this is the
/// vocabulary, in one place, so no screen builds the string itself.
enum TaskState {
  all,
  open,
  overdue,
  done;

  String get wire => name;
}

/// THE WHOLE SET, COUNTED BY THE SERVER, ignoring the page.
///
/// Every field is a measured figure. A count that could not be made does not
/// arrive as a zero — the whole object is null, and the screen then falls back
/// to what it can see and says so. That distinction is the reason this is a
/// class and not five loose ints.
class TaskCounts {
  const TaskCounts({
    required this.all,
    required this.open,
    required this.overdue,
    required this.done,
    required this.awaitingVerification,
  });

  /// Every task in scope.
  final int all;

  /// Outstanding: not closed. `open` and `in_progress` together.
  final int open;

  /// Outstanding and past its deadline.
  final int overdue;

  /// Closed, verified or not.
  final int done;

  /// Closed and not yet verified by a manager.
  final int awaitingVerification;

  /// Null for a server that does not count, which is how this endpoint
  /// answered until the counts landed — and how a stubbed or older server
  /// still answers. Every key has to be a number: a partial object is a
  /// breakdown nobody can add up, and half a breakdown printed as figures
  /// would be the exact lie this whole change exists to end.
  static TaskCounts? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    int? read(String key) => (raw[key] as num?)?.toInt();
    final all = read('all');
    final open = read('open');
    final overdue = read('overdue');
    final done = read('done');
    final awaiting = read('awaitingVerification');
    if (all == null ||
        open == null ||
        overdue == null ||
        done == null ||
        awaiting == null) {
      return null;
    }
    return TaskCounts(
      all: all,
      open: open,
      overdue: overdue,
      done: done,
      awaitingVerification: awaiting,
    );
  }

  /// The figure for one filter, so the chip rail and the section marker read
  /// the same number off the same switch.
  int forState(TaskState state) => switch (state) {
    TaskState.all => all,
    TaskState.open => open,
    TaskState.overdue => overdue,
    TaskState.done => done,
  };
}

/// One page of tasks, plus what the server counted behind it.
///
/// A [PaginatedResponse] with a fifth field would be a fifth field on every
/// list in the product for the sake of one of them, so the tasks list carries
/// its own envelope. The page half is exactly the shared one.
class TaskListPage {
  const TaskListPage({
    required this.data,
    required this.nextCursor,
    this.total,
    this.counts,
  });

  final List<TaskItem> data;
  final String? nextCursor;

  /// Every task the request's filters match, ignoring the cursor.
  final int? total;

  /// The whole-set breakdown, or null from a server that does not count.
  final TaskCounts? counts;

  factory TaskListPage.fromJson(Map<String, dynamic> json) {
    final page = PaginatedResponse<TaskItem>.fromJson(
      json,
      (e) => TaskItem.fromJson(e as Map<String, dynamic>),
    );
    return TaskListPage(
      data: page.data,
      nextCursor: page.nextCursor,
      total: page.total,
      counts: TaskCounts.fromJson(json['counts']),
    );
  }
}

abstract class TasksAdminRepository {
  Future<TaskListPage> listTasks({
    TaskState? state,
    String? status,
    String? priority,
    String? outletId,
  });
  Future<TaskItem> closeTask({
    required String id,
    required String closurePhotoUrl,
  });
  Future<TaskItem> verifyTask(String id);
}

class DioTasksAdminRepository implements TasksAdminRepository {
  @override
  Future<TaskListPage> listTasks({
    TaskState? state,
    String? status,
    String? priority,
    String? outletId,
  }) async {
    final query = <String, dynamic>{};
    // The server refuses both at once, and it is right to: they are two
    // spellings of one axis.
    assert(
      state == null || status == null,
      'listTasks: state and status are two spellings of the same filter.',
    );
    if (state != null) query['state'] = state.wire;
    if (status != null) query['status'] = status;
    if (priority != null) query['priority'] = priority;
    if (outletId != null) query['outletId'] = outletId;
    final response = await dio.get('/tasks', queryParameters: query);
    return TaskListPage.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<TaskItem> closeTask({
    required String id,
    required String closurePhotoUrl,
  }) async {
    final response = await dio.patch(
      '/tasks/$id',
      data: {'status': 'closed', 'closurePhotoUrl': closurePhotoUrl},
    );
    return TaskItem.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<TaskItem> verifyTask(String id) async {
    final response = await dio.patch(
      '/tasks/$id',
      data: {'closureVerified': true},
    );
    return TaskItem.fromJson(response.data as Map<String, dynamic>);
  }
}

final tasksAdminRepositoryProvider = Provider<TasksAdminRepository>(
  (ref) => DioTasksAdminRepository(),
);

// The provider exposes the FIRST PAGE as a plain list: the admin task queue
// wants the current open tasks, not the whole history, and "load more" UI is
// deliberately out of scope for the pagination sweep (see the spec).
// `nextCursor` is available on the repository for any screen that later needs
// to page; this provider intentionally drops it.
//
// IT ASKS FOR THE OPEN WORK, and that is a repair rather than a tidy-up. Both
// consumers — The Floor's decision list and the overview's needs-attention row
// — take this page and immediately drop every closed row from it. The server
// orders by deadline across all statuses, so on a real account the fifty rows
// that arrive are the fifty oldest deadlines, which are overwhelmingly closed:
// 31,178 of 32,368 on the seeded database. Both screens were therefore
// filtering a page of closed tasks down to nothing and showing a manager no
// tasks at all. `state: open` asks the server the question the screens were
// asking the page.
final tasksListProvider = FutureProvider<List<TaskItem>>((ref) async {
  final page = await ref
      .read(tasksAdminRepositoryProvider)
      .listTasks(state: TaskState.open);
  return page.data;
});

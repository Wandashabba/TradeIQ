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
  );
}

abstract class TasksAdminRepository {
  Future<PaginatedResponse<TaskItem>> listTasks({
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
  Future<PaginatedResponse<TaskItem>> listTasks({
    String? status,
    String? priority,
    String? outletId,
  }) async {
    final query = <String, dynamic>{};
    if (status != null) query['status'] = status;
    if (priority != null) query['priority'] = priority;
    if (outletId != null) query['outletId'] = outletId;
    final response = await dio.get('/tasks', queryParameters: query);
    return PaginatedResponse<TaskItem>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => TaskItem.fromJson(e as Map<String, dynamic>),
    );
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
final tasksListProvider = FutureProvider<List<TaskItem>>((ref) async {
  final page = await ref.read(tasksAdminRepositoryProvider).listTasks();
  return page.data;
});

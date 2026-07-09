import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/local_db.dart';
import '../../../core/sync/sync_service.dart';

/// One manually-raised S9 corrective task for a visit.
class TaskDraft {
  const TaskDraft({
    required this.findingType,
    required this.requiredFix,
    required this.priority,
  });
  final String findingType;
  final String requiredFix;

  /// One of 'critical' | 'high' | 'normal'.
  final String priority;

  Map<String, dynamic> toJson() => {
        'findingType': findingType,
        'requiredFix': requiredFix,
        'priority': priority,
      };
}

abstract class TasksRepository {
  Future<void> saveTask({
    required String visitDraftId,
    required String outletId,
    required TaskDraft task,
  });
}

class DriftTasksRepository implements TasksRepository {
  DriftTasksRepository({required this.db, required this.syncService});

  final LocalDb db;
  final SyncService syncService;
  static const _uuid = Uuid();

  @override
  Future<void> saveTask({
    required String visitDraftId,
    required String outletId,
    required TaskDraft task,
  }) async {
    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
          entityType: 'task',
          entityId: _uuid.v4(),
          payloadJson: jsonEncode({
            'visitDraftId': visitDraftId,
            'outletId': outletId,
            ...task.toJson(),
          }),
        ));

    try {
      await syncService.flushPending();
    } catch (_) {
      // Best-effort: the task is queued and retried on the next flush.
    }
  }
}

final tasksRepositoryProvider = Provider<TasksRepository>((ref) => DriftTasksRepository(
      db: ref.read(localDbProvider),
      syncService: ref.read(syncServiceProvider),
    ));

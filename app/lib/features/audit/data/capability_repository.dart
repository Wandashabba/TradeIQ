import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/local_db.dart';
import '../../../core/sync/sync_service.dart';

/// One S7 sales-capability capture for a visit.
class CapabilityCapture {
  const CapabilityCapture({
    required this.staffHeadcountConfirmed,
    required this.repTrainingStatus,
    required this.quizScore,
  });
  final int staffHeadcountConfirmed;
  final Map<String, bool> repTrainingStatus;
  final int quizScore;

  Map<String, dynamic> toPayloadFields() => {
        'staffHeadcountConfirmed': staffHeadcountConfirmed,
        'repTrainingStatus': repTrainingStatus,
        'quizScore': quizScore,
      };
}

abstract class CapabilityRepository {
  Future<void> saveCapability({required String visitDraftId, required CapabilityCapture capture});
}

class DriftCapabilityRepository implements CapabilityRepository {
  DriftCapabilityRepository({required this.db, required this.syncService});

  final LocalDb db;
  final SyncService syncService;
  static const _uuid = Uuid();

  @override
  Future<void> saveCapability({required String visitDraftId, required CapabilityCapture capture}) async {
    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
          entityType: 'capability',
          entityId: _uuid.v4(),
          payloadJson: jsonEncode({'visitDraftId': visitDraftId, ...capture.toPayloadFields()}),
        ));

    try {
      await syncService.flushPending();
    } catch (_) {
      // Best-effort: the capture is queued and retried on the next flush.
    }
  }
}

final capabilityRepositoryProvider = Provider<CapabilityRepository>((ref) => DriftCapabilityRepository(
      db: ref.read(localDbProvider),
      syncService: ref.read(syncServiceProvider),
    ));

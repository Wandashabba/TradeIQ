import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/local_db.dart';
import '../../../core/sync/sync_service.dart';

/// One S3–S4 visibility/display capture for a visit.
class VisibilityCapture {
  const VisibilityCapture({
    required this.brandingElements,
    required this.planogramCompliancePct,
    required this.facingsCount,
    required this.highTrafficPass,
    required this.cleanlinessScore,
  });
  final Map<String, bool> brandingElements;
  final double planogramCompliancePct;
  final int facingsCount;
  final bool highTrafficPass;
  final int cleanlinessScore;

  Map<String, dynamic> toPayloadFields() => {
        'brandingElements': brandingElements,
        'planogramCompliancePct': planogramCompliancePct,
        'facingsCount': {'total': facingsCount},
        'highTrafficPass': highTrafficPass,
        'cleanlinessScore': cleanlinessScore,
      };
}

abstract class VisibilityRepository {
  Future<void> saveVisibility({required String visitDraftId, required VisibilityCapture capture});
}

class DriftVisibilityRepository implements VisibilityRepository {
  DriftVisibilityRepository({required this.db, required this.syncService});

  final LocalDb db;
  final SyncService syncService;
  static const _uuid = Uuid();

  @override
  Future<void> saveVisibility({required String visitDraftId, required VisibilityCapture capture}) async {
    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
          entityType: 'visibility',
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

final visibilityRepositoryProvider = Provider<VisibilityRepository>((ref) => DriftVisibilityRepository(
      db: ref.read(localDbProvider),
      syncService: ref.read(syncServiceProvider),
    ));
